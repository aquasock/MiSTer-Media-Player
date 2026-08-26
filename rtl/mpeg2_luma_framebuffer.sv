//============================================================================
// MiSTer Media Player - Phase 1Ob DDR-backed H.262 4:2:0 presentation
//
// kate - The large on-chip Phase 1N picture planes are gone.  Full-precision
// 8-bit Y/Cb/Cr samples are read back from the Phase 1Oa planar DDR3 layout
// through small ping-pong line caches:
//
//   Y  : two cached 720-pel lines, 90 x 64-bit words per line
//   Cb : two cached 360-pel lines, 45 x 64-bit words per line
//   Cr : two cached 360-pel lines, 45 x 64-bit words per line
//
// The memory side runs at the decoder/DDRAM clock.  The presentation side runs
// at the independent fixed 40 MHz video clock.  Each cache RAM is dual-clock.
//
// The first two luma lines and first two chroma lines are prefetched before a
// picture is published.  Once display begins, finishing source line N frees a
// ping-pong bank:
//   - refill Y line N+2;
//   - after each odd luma line, refill Cb/Cr row (N>>1)+2.
//
// This is an implementation architecture, not an H.262 syntax requirement.
// H.262 decoding/reconstruction remains upstream and full precision.
//============================================================================

module mpeg2_luma_framebuffer
(
    input  wire        reset,

    // DDR/read-control side - same clock as MiSTer DDRAM_CLK.
    input  wire        mem_clk,
    input  wire        picture_complete,
    input  wire [13:0] horizontal_size,
    input  wire [13:0] vertical_size,
    input  wire        native_interlaced,
    input  wire        top_field_first,

    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,

    // Sticky/readiness diagnostics.
    output reg         cache_ready,
    output reg         read_seen,
    output reg         cache_error,
    output reg         bank_overlap_error,
    output wire        picture_present_debug,
    output wire        prefill_deadline_missed_debug,
    // Entry 516: passive per-field readout evidence.  Levels and toggles only;
    // the external profiler counts their synchronized edges.
    output wire        sequence_phase_error_debug,
    output wire        first_field_fetch_toggle_debug,
    output wire        second_field_fetch_toggle_debug,
    // Entry 520: raw per-parity luma return event.  Entry 519 accumulated this
    // inside the framebuffer, where it cleared on every generation reset and
    // so reported whatever short generation preceded terminal quiet.  Export
    // the event instead and let the profiler accumulate it session-wide.
    output wire        luma_return_valid_debug,
    output wire        luma_return_first_field_debug,
    output wire [7:0]  luma_return_byte_debug,
    // Entry 523: one mem-clock pulse per completed displayed field, carrying
    // the generation-correlated raw-return and post-cache fingerprints.
    output reg         luma_fingerprint_valid_debug,
    output reg         luma_fingerprint_first_field_debug,
    output reg  [31:0] luma_fingerprint_raw_debug,
    output reg  [31:0] luma_fingerprint_display_debug,
    output reg         luma_fingerprint_mismatch_debug,

    // Independent fixed video side - 40 MHz.
    input  wire        rd_clk,
    input  wire [11:0] h_pos,
    input  wire [11:0] v_pos,
    input  wire        pixel_ce,
    input  wire        pixel_en,
    input  wire        h_sync,
    input  wire        v_sync,

    output reg  [7:0]  video_r,
    output reg  [7:0]  video_g,
    output reg  [7:0]  video_b,
    output reg         video_de,
    output reg         video_hs,
    output reg         video_vs
);

localparam integer SRC_WIDTH      = 720;
localparam integer SRC_HEIGHT     = 480;
localparam integer CHROMA_WIDTH   = SRC_WIDTH / 2;
localparam integer CHROMA_HEIGHT  = SRC_HEIGHT / 2;

// kate - Phase 1Ob address correction.  Keep the decoder picture away
// from MiSTer's system scaler RAM at physical byte 0x20000000.  These DDRAM
// word addresses begin at physical byte 0x30000000.
localparam [28:0] DDR_Y_BASE  = 29'h06000000;
localparam [28:0] DDR_CB_BASE = 29'h0600A8C0;
localparam [28:0] DDR_CR_BASE = 29'h0600D2F0;

localparam [1:0] FETCH_Y  = 2'd0;
localparam [1:0] FETCH_CB = 2'd1;
localparam [1:0] FETCH_CR = 2'd2;

localparam [1:0] MEM_IDLE  = 2'd0;
localparam [1:0] MEM_ISSUE = 2'd1;
localparam [1:0] MEM_RECV  = 2'd2;

function automatic [28:0] row_times_90;
    input [10:0] row;
    reg [28:0] r;
    begin
        r = {18'd0, row};
        row_times_90 = (r << 6) + (r << 4) + (r << 3) + (r << 1);
    end
endfunction

function automatic [28:0] row_times_45;
    input [10:0] row;
    reg [28:0] r;
    begin
        r = {18'd0, row};
        row_times_45 = (r << 5) + (r << 3) + (r << 2) + r;
    end
endfunction

// A low-cost position-sensitive fingerprint.  Rotating once per byte before
// XOR means the same byte stream produces the same value whether it arrives
// eight bytes per DDR word or one byte per displayed pixel.  This is passive
// diagnostic evidence, not a data-integrity guarantee or standard checksum.
function automatic [31:0] luma_fingerprint_byte;
    input [31:0] fingerprint;
    input [7:0] value;
    begin
        luma_fingerprint_byte = {fingerprint[30:0],fingerprint[31]} ^
                                {24'd0,value};
    end
endfunction

function automatic [31:0] luma_fingerprint_word;
    input [31:0] fingerprint;
    input [63:0] value;
    reg [31:0] next;
    integer lane;
    begin
        next = fingerprint;
        for (lane = 0; lane < 8; lane = lane + 1)
            next = luma_fingerprint_byte(next,value[lane*8 +: 8]);
        luma_fingerprint_word = next;
    end
endfunction

// -------------------------------------------------------------------------
// Memory-side picture descriptor and line-fetch controller.
// -------------------------------------------------------------------------

reg        picture_started;
reg [10:0] picture_height_mem;
reg [10:0] chroma_height_mem;
reg [11:0] picture_width_mem;
reg        native_interlaced_mem;
reg        first_field_mem;

reg [1:0]  mem_state;
reg [1:0]  fetch_kind;
reg [10:0] fetch_line;
reg [7:0]  fetch_line_words;
reg [7:0]  fetch_word_offset;
reg [7:0]  fetch_segment_words;
reg [7:0]  recv_word_index;
reg [28:0] fetch_address;
reg        fetch_cache_bank;

// Entry 516: passive per-field DDR service evidence.  A luma line address in
// native mode carries the field parity in bit 0, so each launched luma fetch
// can be attributed to the authored first field or the other field.
reg        first_field_fetch_toggle_mem;
reg        second_field_fetch_toggle_mem;
reg [31:0] first_field_raw_fingerprint_mem;
reg [31:0] second_field_raw_fingerprint_mem;

// Completed display fingerprints are stable before their toggle traverses
// this three-stage bundled-data handshake back to mem_clk.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0]  luma_fingerprint_toggle_sync;
reg        luma_fingerprint_toggle_seen;
reg        luma_fingerprint_first_m1;
reg        luma_fingerprint_first_m2;
reg [31:0] luma_fingerprint_display_m1;
reg [31:0] luma_fingerprint_display_m2;
reg [31:0] luma_fingerprint_accumulator_rd;
reg [31:0] luma_fingerprint_completed_rd;
reg        luma_fingerprint_first_field_rd;
reg        luma_fingerprint_toggle_rd;
reg        luma_fingerprint_first_reported_rd;
reg        luma_fingerprint_second_reported_rd;
reg [11:0] source_x_d;
reg [11:0] source_y_d;

assign ddram_burstcnt = (mem_state == MEM_ISSUE) ? fetch_segment_words : 8'd0;
assign ddram_addr     = (mem_state == MEM_ISSUE) ? fetch_address : 29'd0;
assign ddram_rd       = (mem_state == MEM_ISSUE);

// Initial prefetch sequence:
//   0 Y0, 1 Y1, 2 Cb0, 3 Cr0, 4 Cb1, 5 Cr1.
reg [2:0] prefill_step;
reg       prefill_done;

// Video -> memory line-consumed handshake.
// kate - Phase 1S CDC cleanup: only the single-bit event toggle crosses clock
// domains.  Source lines are consumed strictly in order, so the memory side
// maintains the associated line number locally instead of sampling an 11-bit
// binary bus asynchronously.
reg        line_done_toggle_rd;
reg        cache_scan_active_rd;
reg        cache_scan_y_bank_rd;
reg        cache_scan_c_bank_rd;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg        line_done_toggle_m1;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg        line_done_toggle_m2;
reg        line_done_toggle_seen;
reg [10:0] line_done_sequence_mem;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] cache_scan_active_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] cache_scan_y_bank_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] cache_scan_c_bank_sync;

reg        pending_event;
reg [10:0] pending_event_line;
reg        refill_active;
reg [1:0]  refill_phase;
reg [10:0] refill_event_line;

// Ping-pong line-cache write ports.
reg [7:0]  y_cache_wr_addr;
reg [63:0] y_cache_wr_data;
reg        y_cache_wr_en;

reg [6:0]  cb_cache_wr_addr;
reg [63:0] cb_cache_wr_data;
reg        cb_cache_wr_en;

reg [6:0]  cr_cache_wr_addr;
reg [63:0] cr_cache_wr_data;
reg        cr_cache_wr_en;

wire [7:0] y_fetch_cache_base =
    fetch_cache_bank ? 8'd90 : 8'd0;
wire [6:0] c_fetch_cache_base =
    fetch_cache_bank ? 7'd45 : 7'd0;

// Interlaced display sequence 0..479 is presentation order, not frame-raster
// order. Sequence 0..239 belongs to the authored first field and 240..479 to
// the other. The physical DDR frame remains ordinary frame order.
function automatic [10:0] interlaced_luma_row;
    input [8:0] sequence_line;
    input       first_field;
    reg [8:0] field_line;
    reg       field_parity;
    begin
        if (sequence_line < 9'd240) begin
            field_line = sequence_line;
            field_parity = first_field;
        end
        else begin
            field_line = sequence_line - 9'd240;
            field_parity = ~first_field;
        end
        interlaced_luma_row = {1'b0, field_line, 1'b0} + field_parity;
    end
endfunction

function automatic [10:0] interlaced_chroma_row;
    input [7:0] sequence_pair;
    input       first_field;
    reg [6:0] field_pair;
    reg       field_parity;
    begin
        if (sequence_pair < 8'd120) begin
            field_pair = sequence_pair[6:0];
            field_parity = first_field;
        end
        else begin
            field_pair = sequence_pair[6:0] - 7'd120;
            field_parity = ~first_field;
        end
        interlaced_chroma_row = {3'd0, field_pair, 1'b0} + field_parity;
    end
endfunction

wire [8:0] interlaced_future_y_sequence =
    (refill_event_line[8:0] >= 9'd478) ?
        (refill_event_line[8:0] - 9'd478) :
        (refill_event_line[8:0] + 9'd2);
wire [7:0] interlaced_current_pair = refill_event_line[8:1];
wire [7:0] interlaced_future_c_pair =
    (interlaced_current_pair >= 8'd238) ?
        (interlaced_current_pair - 8'd238) :
        (interlaced_current_pair + 8'd2);

wire [11:0] progressive_y_refill_raw =
    {1'b0, refill_event_line} + 12'd2;
wire [10:0] progressive_y_refill_line =
    (progressive_y_refill_raw >= {1'b0, picture_height_mem}) ?
        (progressive_y_refill_raw[10:0] - picture_height_mem) :
        progressive_y_refill_raw[10:0];
wire [11:0] progressive_c_refill_raw =
    {2'b00, refill_event_line[10:1]} + 12'd2;
wire [10:0] progressive_c_refill_line =
    (progressive_c_refill_raw >= {1'b0, chroma_height_mem}) ?
        (progressive_c_refill_raw[10:0] - chroma_height_mem) :
        progressive_c_refill_raw[10:0];

wire [10:0] y_refill_line = native_interlaced_mem ?
    interlaced_luma_row(interlaced_future_y_sequence, first_field_mem) :
    progressive_y_refill_line;
wire [10:0] c_refill_line = native_interlaced_mem ?
    interlaced_chroma_row(interlaced_future_c_pair, first_field_mem) :
    progressive_c_refill_line;
wire y_refill_bank = native_interlaced_mem ?
    interlaced_future_y_sequence[0] : y_refill_line[0];
wire c_refill_bank = native_interlaced_mem ?
    interlaced_future_c_pair[0] : c_refill_line[0];

wire [10:0] prefill_y0 = native_interlaced_mem ?
    interlaced_luma_row(9'd0, first_field_mem) : 11'd0;
wire [10:0] prefill_y1 = native_interlaced_mem ?
    interlaced_luma_row(9'd1, first_field_mem) : 11'd1;
wire [10:0] prefill_c0 = native_interlaced_mem ?
    interlaced_chroma_row(8'd0, first_field_mem) : 11'd0;
wire [10:0] prefill_c1 = native_interlaced_mem ?
    interlaced_chroma_row(8'd1, first_field_mem) : 11'd1;

task automatic launch_fetch;
    input [1:0]  kind;
    input [10:0] line_number;
    input        cache_bank;
    begin
        fetch_kind         <= kind;
        fetch_line         <= line_number;
        fetch_line_words   <= (kind == FETCH_Y) ? 8'd90 : 8'd45;
        fetch_word_offset  <= 8'd0;
        // Keep an individual MiSTer DDR burst at 64 words or less.  A 720-pel
        // luma line therefore uses 64+26 words; a chroma line uses one 45-word
        // burst.  This is a service-interface implementation choice.
        fetch_segment_words <= (kind == FETCH_Y) ? 8'd64 : 8'd45;
        recv_word_index    <= 8'd0;
        fetch_cache_bank   <= cache_bank;

        if ((kind == FETCH_Y) && native_interlaced_mem) begin
            if (line_number[0] == first_field_mem)
                first_field_fetch_toggle_mem <=
                    ~first_field_fetch_toggle_mem;
            else
                second_field_fetch_toggle_mem <=
                    ~second_field_fetch_toggle_mem;
        end

        if (kind == FETCH_Y)
            fetch_address <= DDR_Y_BASE + row_times_90(line_number);
        else if (kind == FETCH_CB)
            fetch_address <= DDR_CB_BASE + row_times_45(line_number);
        else
            fetch_address <= DDR_CR_BASE + row_times_45(line_number);

        mem_state <= MEM_ISSUE;
    end
endtask

always @(posedge mem_clk) begin
    if (reset) begin
        picture_started       <= 1'b0;
        picture_height_mem    <= 11'd0;
        chroma_height_mem     <= 11'd0;
        picture_width_mem     <= 12'd0;
        native_interlaced_mem <= 1'b0;
        first_field_mem       <= 1'b0;

        mem_state             <= MEM_IDLE;
        fetch_kind            <= FETCH_Y;
        fetch_line            <= 11'd0;
        fetch_line_words      <= 8'd0;
        fetch_word_offset     <= 8'd0;
        fetch_segment_words   <= 8'd0;
        recv_word_index       <= 8'd0;
        fetch_address         <= 29'd0;
        fetch_cache_bank      <= 1'b0;
        first_field_fetch_toggle_mem  <= 1'b0;
        second_field_fetch_toggle_mem <= 1'b0;
        first_field_raw_fingerprint_mem  <= 32'd0;
        second_field_raw_fingerprint_mem <= 32'd0;
        luma_fingerprint_toggle_sync     <= 3'b000;
        luma_fingerprint_toggle_seen     <= 1'b0;
        luma_fingerprint_first_m1        <= 1'b0;
        luma_fingerprint_first_m2        <= 1'b0;
        luma_fingerprint_display_m1      <= 32'd0;
        luma_fingerprint_display_m2      <= 32'd0;
        luma_fingerprint_valid_debug     <= 1'b0;
        luma_fingerprint_first_field_debug <= 1'b0;
        luma_fingerprint_raw_debug       <= 32'd0;
        luma_fingerprint_display_debug   <= 32'd0;
        luma_fingerprint_mismatch_debug  <= 1'b0;

        prefill_step          <= 3'd0;
        prefill_done          <= 1'b0;
        cache_ready           <= 1'b0;
        read_seen             <= 1'b0;
        cache_error           <= 1'b0;
        bank_overlap_error    <= 1'b0;

        line_done_toggle_m1   <= 1'b0;
        line_done_toggle_m2   <= 1'b0;
        line_done_toggle_seen <= 1'b0;
        line_done_sequence_mem <= 11'd0;
        cache_scan_active_sync <= 2'b00;
        cache_scan_y_bank_sync <= 2'b00;
        cache_scan_c_bank_sync <= 2'b00;

        pending_event         <= 1'b0;
        pending_event_line    <= 11'd0;
        refill_active         <= 1'b0;
        refill_phase          <= 2'd0;
        refill_event_line     <= 11'd0;

        y_cache_wr_addr       <= 8'd0;
        y_cache_wr_data       <= 64'd0;
        y_cache_wr_en         <= 1'b0;
        cb_cache_wr_addr      <= 7'd0;
        cb_cache_wr_data      <= 64'd0;
        cb_cache_wr_en        <= 1'b0;
        cr_cache_wr_addr      <= 7'd0;
        cr_cache_wr_data      <= 64'd0;
        cr_cache_wr_en        <= 1'b0;
    end
    else begin
        y_cache_wr_en  <= 1'b0;
        cb_cache_wr_en <= 1'b0;
        cr_cache_wr_en <= 1'b0;
        luma_fingerprint_valid_debug <= 1'b0;

        luma_fingerprint_toggle_sync <=
            {luma_fingerprint_toggle_sync[1:0],
             luma_fingerprint_toggle_rd};
        luma_fingerprint_first_m1 <=
            luma_fingerprint_first_field_rd;
        luma_fingerprint_first_m2 <= luma_fingerprint_first_m1;
        luma_fingerprint_display_m1 <=
            luma_fingerprint_completed_rd;
        luma_fingerprint_display_m2 <= luma_fingerprint_display_m1;

        if (luma_fingerprint_toggle_sync[2] !=
            luma_fingerprint_toggle_seen) begin
            luma_fingerprint_toggle_seen <=
                luma_fingerprint_toggle_sync[2];
            luma_fingerprint_valid_debug <= 1'b1;
            luma_fingerprint_first_field_debug <=
                luma_fingerprint_first_m2;
            luma_fingerprint_display_debug <=
                luma_fingerprint_display_m2;
            if (luma_fingerprint_first_m2) begin
                luma_fingerprint_raw_debug <=
                    first_field_raw_fingerprint_mem;
                luma_fingerprint_mismatch_debug <=
                    first_field_raw_fingerprint_mem !=
                    luma_fingerprint_display_m2;
            end
            else begin
                luma_fingerprint_raw_debug <=
                    second_field_raw_fingerprint_mem;
                luma_fingerprint_mismatch_debug <=
                    second_field_raw_fingerprint_mem !=
                    luma_fingerprint_display_m2;
            end
        end

        // Synchronize the one-bit line-consumed event.  The associated source
        // line number is generated locally below, eliminating the old binary
        // multi-bit CDC path.
        line_done_toggle_m1 <= line_done_toggle_rd;
        line_done_toggle_m2 <= line_done_toggle_m1;
        cache_scan_active_sync <=
            {cache_scan_active_sync[0], cache_scan_active_rd};
        cache_scan_y_bank_sync <=
            {cache_scan_y_bank_sync[0], cache_scan_y_bank_rd};
        cache_scan_c_bank_sync <=
            {cache_scan_c_bank_sync[0], cache_scan_c_bank_rd};

        // Passive deadline diagnostic. A cache bank contains exactly one
        // presentation line (or interlaced chroma pair), so a DDR return that
        // writes the bank currently being scanned can expose stale/new words
        // as short horizontal dashes. This does not alter refill control.
        if (ddram_dout_ready && cache_scan_active_sync[1] &&
            (((fetch_kind == FETCH_Y) &&
              (fetch_cache_bank == cache_scan_y_bank_sync[1])) ||
             ((fetch_kind != FETCH_Y) &&
              (fetch_cache_bank == cache_scan_c_bank_sync[1]))))
            bank_overlap_error <= 1'b1;

        if (line_done_toggle_m2 != line_done_toggle_seen) begin
            line_done_toggle_seen <= line_done_toggle_m2;

            if (!cache_ready) begin
                cache_error <= 1'b1;
            end
            else if (pending_event) begin
                // The DDR reader has fallen more than one displayed line behind.
                cache_error <= 1'b1;
            end
            else begin
                pending_event      <= 1'b1;
                pending_event_line <= line_done_sequence_mem;
            end

            // In native mode this is a 480-entry presentation-order sequence:
            // all lines of the authored first field, then all lines of the
            // other field. Progressive mode retains ordinary raster order.
            if (picture_height_mem == 11'd0)
                line_done_sequence_mem <= 11'd0;
            else if (native_interlaced_mem &&
                     (line_done_sequence_mem == 11'd479))
                line_done_sequence_mem <= 11'd0;
            else if (!native_interlaced_mem &&
                     (line_done_sequence_mem == (picture_height_mem - 11'd1)))
                line_done_sequence_mem <= 11'd0;
            else
                line_done_sequence_mem <= line_done_sequence_mem + 11'd1;
        end

        if (!picture_started && picture_complete) begin
            if ((horizontal_size == 14'd0) ||
                (vertical_size   == 14'd0) ||
                (horizontal_size > SRC_WIDTH) ||
                (vertical_size   > SRC_HEIGHT) ||
                // Phase 1Ob ping-pong wrap assumes an even number of luma
                // lines and an even number of 4:2:0 chroma lines.
                (vertical_size[1:0] != 2'b00)) begin
                cache_error <= 1'b1;
            end
            else begin
                picture_started       <= 1'b1;
                picture_width_mem     <= horizontal_size[11:0];
                picture_height_mem    <= vertical_size[10:0];
                chroma_height_mem     <= (vertical_size[10:0] + 11'd1) >> 1;
                native_interlaced_mem <= native_interlaced;
                first_field_mem       <= ~top_field_first;
                prefill_step          <= 3'd0;
                prefill_done          <= 1'b0;
                line_done_sequence_mem <= 11'd0;
            end
        end

        case (mem_state)
            MEM_ISSUE: begin
                // Hold address/count/read stable until the MiSTer DDR service
                // accepts the burst request.
                if (!ddram_busy) begin
                    recv_word_index <= 8'd0;
                    mem_state       <= MEM_RECV;
                end
            end

            MEM_RECV: begin
                if (ddram_dout_ready) begin
                    read_seen <= 1'b1;

                    if ((fetch_kind == FETCH_Y) && native_interlaced_mem) begin
                        if (fetch_line[0] == first_field_mem)
                            first_field_raw_fingerprint_mem <=
                                luma_fingerprint_word(
                                    first_field_raw_fingerprint_mem,
                                    ddram_dout);
                        else
                            second_field_raw_fingerprint_mem <=
                                luma_fingerprint_word(
                                    second_field_raw_fingerprint_mem,
                                    ddram_dout);
                    end

                    case (fetch_kind)
                        FETCH_Y: begin
                            y_cache_wr_addr <= y_fetch_cache_base +
                                               fetch_word_offset +
                                               recv_word_index[7:0];
                            y_cache_wr_data <= ddram_dout;
                            y_cache_wr_en   <= 1'b1;
                        end

                        FETCH_CB: begin
                            cb_cache_wr_addr <= c_fetch_cache_base +
                                                fetch_word_offset[6:0] +
                                                recv_word_index[6:0];
                            cb_cache_wr_data <= ddram_dout;
                            cb_cache_wr_en   <= 1'b1;
                        end

                        default: begin
                            cr_cache_wr_addr <= c_fetch_cache_base +
                                                fetch_word_offset[6:0] +
                                                recv_word_index[6:0];
                            cr_cache_wr_data <= ddram_dout;
                            cr_cache_wr_en   <= 1'b1;
                        end
                    endcase

                    if (recv_word_index == (fetch_segment_words - 8'd1)) begin
                        recv_word_index <= 8'd0;

                        if ((fetch_word_offset + fetch_segment_words) <
                            fetch_line_words) begin
                            // Continue the same logical line fetch with the
                            // remaining sequential words.
                            fetch_word_offset <=
                                fetch_word_offset + fetch_segment_words;
                            fetch_address <=
                                fetch_address + {21'd0, fetch_segment_words};

                            if ((fetch_line_words -
                                 (fetch_word_offset + fetch_segment_words)) >
                                8'd64)
                                fetch_segment_words <= 8'd64;
                            else
                                fetch_segment_words <=
                                    fetch_line_words -
                                    (fetch_word_offset + fetch_segment_words);

                            mem_state <= MEM_ISSUE;
                        end
                        else begin
                            // Complete logical line fetch.
                            mem_state <= MEM_IDLE;

                            if (!prefill_done) begin
                                if (prefill_step == 3'd5) begin
                                    prefill_done <= 1'b1;
                                    cache_ready  <= 1'b1;
                                end
                                else begin
                                    prefill_step <= prefill_step + 3'd1;
                                end
                            end
                            else if (refill_active) begin
                                if (refill_phase == 2'd0) begin
                                    if (refill_event_line[0]) begin
                                        refill_phase <= 2'd1;
                                    end
                                    else begin
                                        refill_active <= 1'b0;
                                    end
                                end
                                else if (refill_phase == 2'd1) begin
                                    refill_phase <= 2'd2;
                                end
                                else begin
                                    refill_active <= 1'b0;
                                end
                            end
                        end
                    end
                    else begin
                        recv_word_index <= recv_word_index + 8'd1;
                    end
                end
            end

            default: begin
                // MEM_IDLE scheduling.
                if (picture_started && !prefill_done) begin
                    case (prefill_step)
                        3'd0:
                            launch_fetch(FETCH_Y, prefill_y0, 1'b0);

                        3'd1:
                            if (picture_height_mem > 11'd1)
                                launch_fetch(FETCH_Y, prefill_y1, 1'b1);
                            else
                                prefill_step <= 3'd2;

                        3'd2:
                            launch_fetch(FETCH_CB, prefill_c0, 1'b0);

                        3'd3:
                            launch_fetch(FETCH_CR, prefill_c0, 1'b0);

                        3'd4:
                            if (chroma_height_mem > 11'd1)
                                launch_fetch(FETCH_CB, prefill_c1, 1'b1);
                            else
                                prefill_step <= 3'd5;

                        3'd5:
                            if (chroma_height_mem > 11'd1)
                                launch_fetch(FETCH_CR, prefill_c1, 1'b1);
                            else begin
                                prefill_done <= 1'b1;
                                cache_ready  <= 1'b1;
                            end

                        default:
                            cache_error <= 1'b1;
                    endcase
                end
                else if (prefill_done) begin
                    if (!refill_active && pending_event) begin
                        pending_event     <= 1'b0;
                        refill_active     <= 1'b1;
                        refill_phase      <= 2'd0;
                        refill_event_line <= pending_event_line;
                    end
                    else if (refill_active) begin
                        if (refill_phase == 2'd0) begin
                            launch_fetch(FETCH_Y, y_refill_line, y_refill_bank);
                        end
                        else if (refill_phase == 2'd1) begin
                            launch_fetch(FETCH_CB, c_refill_line, c_refill_bank);
                        end
                        else begin
                            launch_fetch(FETCH_CR, c_refill_line, c_refill_bank);
                        end
                    end
                end
            end
        endcase
    end
end

// -------------------------------------------------------------------------
// Small dual-clock ping-pong line caches.
// -------------------------------------------------------------------------

wire [7:0]  y_cache_rd_addr;
wire [6:0]  c_cache_rd_addr;
wire [63:0] y_cache_rd_word;
wire [63:0] cb_cache_rd_word;
wire [63:0] cr_cache_rd_word;

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (64),
    .widthad_a                      (8),
    .numwords_a                     (180),
    .width_b                        (64),
    .widthad_b                      (8),
    .numwords_b                     (180),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) y_line_cache (
    .clock0         (mem_clk),
    .clock1         (rd_clk),
    .address_a      (y_cache_wr_addr),
    .data_a         (y_cache_wr_data),
    .wren_a         (y_cache_wr_en),
    .address_b      (y_cache_rd_addr),
    .q_b            (y_cache_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (1'b1),
    .byteena_b      (1'b1),
    .data_b         (64'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (64),
    .widthad_a                      (7),
    .numwords_a                     (90),
    .width_b                        (64),
    .widthad_b                      (7),
    .numwords_b                     (90),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) cb_line_cache (
    .clock0         (mem_clk),
    .clock1         (rd_clk),
    .address_a      (cb_cache_wr_addr),
    .data_a         (cb_cache_wr_data),
    .wren_a         (cb_cache_wr_en),
    .address_b      (c_cache_rd_addr),
    .q_b            (cb_cache_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (1'b1),
    .byteena_b      (1'b1),
    .data_b         (64'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (64),
    .widthad_a                      (7),
    .numwords_a                     (90),
    .width_b                        (64),
    .widthad_b                      (7),
    .numwords_b                     (90),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) cr_line_cache (
    .clock0         (mem_clk),
    .clock1         (rd_clk),
    .address_a      (cr_cache_wr_addr),
    .data_a         (cr_cache_wr_data),
    .wren_a         (cr_cache_wr_en),
    .address_b      (c_cache_rd_addr),
    .q_b            (cr_cache_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (1'b1),
    .byteena_b      (1'b1),
    .data_b         (64'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

// -------------------------------------------------------------------------
// Video-side descriptor synchronization and line-consumed handshake.
// -------------------------------------------------------------------------

reg        cache_ready_r1;
reg        cache_ready_r2;
reg [11:0] picture_width_r1;
reg [11:0] picture_width_r2;
reg [10:0] picture_height_r1;
reg [10:0] picture_height_r2;
reg        native_interlaced_r1;
reg        native_interlaced_r2;
reg        first_field_r1;
reg        first_field_r2;
reg        picture_present_rd;
reg        prefill_deadline_missed_rd;
reg        line_done_pending_rd;

// Entry 516: the memory side advances a free-running 0..479 presentation
// sequence on exactly the line-consumed events generated below.  A replica in
// this domain therefore carries the same value without any clock crossing, and
// can be compared against the index implied by the raster position itself.  A
// disagreement means the sequence has lost phase with the field being scanned.
reg [8:0]  sequence_replica_rd;
reg        sequence_phase_error_rd;

assign picture_present_debug = picture_present_rd;
assign prefill_deadline_missed_debug = prefill_deadline_missed_rd;
assign first_field_fetch_toggle_debug  = first_field_fetch_toggle_mem;
assign second_field_fetch_toggle_debug = second_field_fetch_toggle_mem;
assign luma_return_valid_debug =
    ddram_dout_ready && (fetch_kind == FETCH_Y) && native_interlaced_mem;
assign luma_return_first_field_debug = (fetch_line[0] == first_field_mem);
assign luma_return_byte_debug        = ddram_dout[7:0];
assign sequence_phase_error_debug     = sequence_phase_error_rd;

// kate - Phase 1P: the module reset input is synchronized to mem_clk by the
// top level.  It still crosses into the independent 40 MHz rd_clk domain, so
// synchronize only its RELEASE again here.  Assertion remains asynchronous.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] rd_reset_sync;

always @(posedge rd_clk or posedge reset) begin
    if (reset)
        rd_reset_sync <= 3'b111;
    else
        rd_reset_sync <= {rd_reset_sync[1:0], 1'b0};
end

wire rd_reset = rd_reset_sync[2];
wire framebuffer_descriptor_valid =
    (picture_width_r2 != 12'd0) && (picture_height_r2 != 11'd0);
wire native_publish_origin =
    framebuffer_descriptor_valid && native_interlaced_r2 && pixel_en &&
    (h_pos == 12'd0) && (v_pos[8:1] == 8'd0) &&
    (v_pos[0] == first_field_r2);
wire progressive_publish_origin =
    framebuffer_descriptor_valid && !native_interlaced_r2 &&
    (h_pos == 12'd0) && (v_pos == 12'd0);

// Entry 516: field phase implied by the scanned raster line versus the field
// the presentation sequence believes it is in.  The 480-entry order places the
// authored first field at 0..239 and the other field at 240..479, so the
// replica's own position names its field directly.  Comparing only the two
// parities keeps this evidence to a single constant magnitude compare in the
// video domain rather than an adder and a nine-bit equality; a retained or
// misaligned field breaks the parity, which is the invariant that matters.
wire raster_first_field_rd   = (v_pos[0] == first_field_r2);
wire sequence_first_field_rd = (sequence_replica_rd < 9'd240);

always @(posedge rd_clk) begin
    if (rd_reset) begin
        cache_ready_r1       <= 1'b0;
        cache_ready_r2       <= 1'b0;
        picture_width_r1     <= 12'd0;
        picture_width_r2     <= 12'd0;
        picture_height_r1    <= 11'd0;
        picture_height_r2    <= 11'd0;
        native_interlaced_r1  <= 1'b0;
        native_interlaced_r2  <= 1'b0;
        first_field_r1        <= 1'b0;
        first_field_r2        <= 1'b0;
        picture_present_rd   <= 1'b0;
        prefill_deadline_missed_rd <= 1'b0;
        line_done_toggle_rd  <= 1'b0;
        line_done_pending_rd <= 1'b0;
        cache_scan_active_rd <= 1'b0;
        cache_scan_y_bank_rd <= 1'b0;
        cache_scan_c_bank_rd <= 1'b0;
        sequence_replica_rd  <= 9'd0;
        sequence_phase_error_rd <= 1'b0;
        luma_fingerprint_accumulator_rd <= 32'd0;
        luma_fingerprint_completed_rd   <= 32'd0;
        luma_fingerprint_first_field_rd <= 1'b0;
        luma_fingerprint_toggle_rd      <= 1'b0;
        luma_fingerprint_first_reported_rd <= 1'b0;
        luma_fingerprint_second_reported_rd <= 1'b0;
        source_x_d                      <= 12'd0;
        source_y_d                      <= 12'd0;
    end
    else begin
        cache_ready_r1    <= cache_ready;
        cache_ready_r2    <= cache_ready_r1;
        picture_width_r1  <= picture_width_mem;
        picture_width_r2  <= picture_width_r1;
        picture_height_r1 <= picture_height_mem;
        picture_height_r2 <= picture_height_r1;
        native_interlaced_r1 <= native_interlaced_mem;
        native_interlaced_r2 <= native_interlaced_r1;
        first_field_r1       <= first_field_mem;
        first_field_r2       <= first_field_r1;

        if (pixel_ce) begin
            source_x_d <= source_x;
            source_y_d <= source_y;
            cache_scan_active_rd <= decoded_picture_window;
            cache_scan_y_bank_rd <=
                native_interlaced_r2 ? source_y[1] : source_y[0];
            cache_scan_c_bank_rd <=
                native_interlaced_r2 ? source_y[2] : source_y[1];

            // Publish at the first active line of the authored first field, or
            // at the legacy progressive frame origin.
            if (!picture_present_rd && cache_ready_r2 &&
                (progressive_publish_origin || native_publish_origin))
                picture_present_rd <= 1'b1;

            // Entry 511: passive native publication deadline evidence.  A
            // descriptor is already live and the authored first-field origin
            // has arrived, but the six-line prefill has not crossed into the
            // video domain.  Retain one level for this framebuffer generation;
            // the external profiler counts its synchronized rising edge.
            if (!picture_present_rd && native_publish_origin &&
                !cache_ready_r2)
                prefill_deadline_missed_rd <= 1'b1;

            // The event is emitted on the logical sample after the last DDR
            // cache request for this displayed source line.
            if (line_done_pending_rd) begin
                line_done_pending_rd <= 1'b0;
                line_done_toggle_rd <= ~line_done_toggle_rd;
            end

            // Fold the exact luma byte selected from the cache for each
            // displayed pixel.  The delayed coordinates identify that byte,
            // matching the line-cache address/lane pipeline below.  At the
            // final pixel of either 240-line field, latch the completed value
            // and toggle the bundled-data handshake back to mem_clk.
            if (native_interlaced_r2 && decoded_picture_window_d) begin
                if ((source_x_d == 12'd719) &&
                    (source_y_d[8:1] == 8'd239)) begin
                    if ((source_y_d[0] == first_field_r2) &&
                        !luma_fingerprint_first_reported_rd) begin
                        luma_fingerprint_completed_rd <=
                            luma_fingerprint_byte(
                                luma_fingerprint_accumulator_rd,y_rd_data);
                        luma_fingerprint_first_field_rd <= 1'b1;
                        luma_fingerprint_toggle_rd <=
                            ~luma_fingerprint_toggle_rd;
                        luma_fingerprint_first_reported_rd <= 1'b1;
                    end
                    else if ((source_y_d[0] != first_field_r2) &&
                             !luma_fingerprint_second_reported_rd) begin
                        luma_fingerprint_completed_rd <=
                            luma_fingerprint_byte(
                                luma_fingerprint_accumulator_rd,y_rd_data);
                        luma_fingerprint_first_field_rd <= 1'b0;
                        luma_fingerprint_toggle_rd <=
                            ~luma_fingerprint_toggle_rd;
                        luma_fingerprint_second_reported_rd <= 1'b1;
                    end
                    luma_fingerprint_accumulator_rd <= 32'd0;
                end
                else begin
                    luma_fingerprint_accumulator_rd <=
                        luma_fingerprint_byte(
                            luma_fingerprint_accumulator_rd,y_rd_data);
                end
            end

            if (picture_present_rd &&
                ((native_interlaced_r2 && pixel_en &&
                  (h_pos == 12'd719)) ||
                 (!native_interlaced_r2 && pixel_en &&
                  (h_pos == 12'd759) &&
                  (v_pos >= 12'd60) &&
                  (v_pos < (12'd60 + {1'b0, picture_height_r2})))))
            begin
                line_done_pending_rd <= 1'b1;

                // Entry 516: this is the same event the memory side counts, so
                // compare the replica against the raster before advancing it
                // and toggle one evidence line per scanned field parity.
                if (native_interlaced_r2) begin
                    if (sequence_first_field_rd != raster_first_field_rd)
                        sequence_phase_error_rd <= 1'b1;

                    if (sequence_replica_rd == 9'd479)
                        sequence_replica_rd <= 9'd0;
                    else
                        sequence_replica_rd <= sequence_replica_rd + 9'd1;
                end
            end
        end
    end
end

// -------------------------------------------------------------------------
// Video-side cache addressing and full-precision 4:2:0 expansion.
// -------------------------------------------------------------------------

wire source_window = native_interlaced_r2 ?
    pixel_en :
    (pixel_en &&
     (h_pos >= 12'd40)  && (h_pos < 12'd760) &&
     (v_pos >= 12'd60)  && (v_pos < 12'd540));

wire [11:0] source_x = native_interlaced_r2 ? h_pos : (h_pos - 12'd40);
wire [11:0] source_y = native_interlaced_r2 ? v_pos : (v_pos - 12'd60);

wire decoded_picture_window =
    source_window &&
    picture_present_rd &&
    (source_x < picture_width_r2) &&
    (source_y < {1'b0, picture_height_r2});

wire [6:0] y_word_index = source_x[9:3];
wire [5:0] c_word_index = source_x[9:4];

assign y_cache_rd_addr =
    ((native_interlaced_r2 ? source_y[1] : source_y[0]) ?
        8'd90 : 8'd0) + {1'b0, y_word_index};

assign c_cache_rd_addr =
    ((native_interlaced_r2 ? source_y[2] : source_y[1]) ?
        7'd45 : 7'd0) + {1'b0, c_word_index};

wire [2:0] y_byte_lane = source_x[2:0];
wire [2:0] c_byte_lane = source_x[3:1];

reg [2:0] y_byte_lane_d;
reg [2:0] c_byte_lane_d;
reg       source_window_d;
reg       decoded_picture_window_d;

reg [7:0] y_rd_data;
reg [7:0] cb_rd_data;
reg [7:0] cr_rd_data;

always @* begin
    case (y_byte_lane_d)
        3'd0: y_rd_data = y_cache_rd_word[7:0];
        3'd1: y_rd_data = y_cache_rd_word[15:8];
        3'd2: y_rd_data = y_cache_rd_word[23:16];
        3'd3: y_rd_data = y_cache_rd_word[31:24];
        3'd4: y_rd_data = y_cache_rd_word[39:32];
        3'd5: y_rd_data = y_cache_rd_word[47:40];
        3'd6: y_rd_data = y_cache_rd_word[55:48];
        default: y_rd_data = y_cache_rd_word[63:56];
    endcase

    case (c_byte_lane_d)
        3'd0: begin
            cb_rd_data = cb_cache_rd_word[7:0];
            cr_rd_data = cr_cache_rd_word[7:0];
        end
        3'd1: begin
            cb_rd_data = cb_cache_rd_word[15:8];
            cr_rd_data = cr_cache_rd_word[15:8];
        end
        3'd2: begin
            cb_rd_data = cb_cache_rd_word[23:16];
            cr_rd_data = cr_cache_rd_word[23:16];
        end
        3'd3: begin
            cb_rd_data = cb_cache_rd_word[31:24];
            cr_rd_data = cr_cache_rd_word[31:24];
        end
        3'd4: begin
            cb_rd_data = cb_cache_rd_word[39:32];
            cr_rd_data = cr_cache_rd_word[39:32];
        end
        3'd5: begin
            cb_rd_data = cb_cache_rd_word[47:40];
            cr_rd_data = cr_cache_rd_word[47:40];
        end
        3'd6: begin
            cb_rd_data = cb_cache_rd_word[55:48];
            cr_rd_data = cr_cache_rd_word[55:48];
        end
        default: begin
            cb_rd_data = cb_cache_rd_word[63:56];
            cr_rd_data = cr_cache_rd_word[63:56];
        end
    endcase
end

wire [7:0] rgb_r;
wire [7:0] rgb_g;
wire [7:0] rgb_b;

mpeg2_ycbcr_to_rgb_bt601 mpeg2_ycbcr_to_rgb_bt601
(
    .y  (y_rd_data),
    .cb (cb_rd_data),
    .cr (cr_rd_data),
    .r  (rgb_r),
    .g  (rgb_g),
    .b  (rgb_b)
);

always @(posedge rd_clk) begin
    if (rd_reset) begin
        y_byte_lane_d             <= 3'd0;
        c_byte_lane_d             <= 3'd0;
        source_window_d           <= 1'b0;
        decoded_picture_window_d  <= 1'b0;
        video_r                   <= 8'd0;
        video_g                   <= 8'd0;
        video_b                   <= 8'd0;
        video_de                  <= 1'b0;
        video_hs                  <= 1'b0;
        video_vs                  <= 1'b0;
    end
    else if (pixel_ce) begin
        y_byte_lane_d            <= y_byte_lane;
        c_byte_lane_d            <= c_byte_lane;
        source_window_d          <= source_window;
        decoded_picture_window_d <= decoded_picture_window;

        video_de <= pixel_en;
        video_hs <= h_sync;
        video_vs <= v_sync;

        if (decoded_picture_window_d) begin
            video_r <= rgb_r;
            video_g <= rgb_g;
            video_b <= rgb_b;
        end
        else if (source_window_d) begin
            video_r <= 8'd24;
            video_g <= 8'd24;
            video_b <= 8'd24;
        end
        else begin
            video_r <= 8'd0;
            video_g <= 8'd0;
            video_b <= 8'd0;
        end
    end
end

endmodule
