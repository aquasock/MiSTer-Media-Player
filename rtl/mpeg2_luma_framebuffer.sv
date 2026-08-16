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

    // Independent fixed video side - 40 MHz.
    input  wire        rd_clk,
    input  wire [11:0] h_pos,
    input  wire [11:0] v_pos,
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

// -------------------------------------------------------------------------
// Memory-side picture descriptor and line-fetch controller.
// -------------------------------------------------------------------------

reg        picture_started;
reg [10:0] picture_height_mem;
reg [10:0] chroma_height_mem;
reg [11:0] picture_width_mem;

reg [1:0]  mem_state;
reg [1:0]  fetch_kind;
reg [10:0] fetch_line;
reg [7:0]  fetch_line_words;
reg [7:0]  fetch_word_offset;
reg [7:0]  fetch_segment_words;
reg [7:0]  recv_word_index;
reg [28:0] fetch_address;

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
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg        line_done_toggle_m1;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg        line_done_toggle_m2;
reg        line_done_toggle_seen;
reg [10:0] line_done_sequence_mem;

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
    fetch_line[0] ? 8'd90 : 8'd0;
wire [6:0] c_fetch_cache_base =
    fetch_line[0] ? 7'd45 : 7'd0;

// A still picture is displayed repeatedly.  Refill targets therefore wrap at
// the bottom of the decoded picture so the next video frame finds Y0/Y1 and
// Cb/Cr0/1 back in their expected parity banks.
wire [11:0] y_refill_raw =
    {1'b0, refill_event_line} + 12'd2;
wire [10:0] y_refill_line =
    (y_refill_raw >= {1'b0, picture_height_mem}) ?
        (y_refill_raw - {1'b0, picture_height_mem}) :
        y_refill_raw[10:0];

wire [11:0] c_refill_raw =
    {2'b00, refill_event_line[10:1]} + 12'd2;
wire [10:0] c_refill_line =
    (c_refill_raw >= {1'b0, chroma_height_mem}) ?
        (c_refill_raw - {1'b0, chroma_height_mem}) :
        c_refill_raw[10:0];

task automatic launch_fetch;
    input [1:0]  kind;
    input [10:0] line_number;
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

        mem_state             <= MEM_IDLE;
        fetch_kind            <= FETCH_Y;
        fetch_line            <= 11'd0;
        fetch_line_words      <= 8'd0;
        fetch_word_offset     <= 8'd0;
        fetch_segment_words   <= 8'd0;
        recv_word_index       <= 8'd0;
        fetch_address         <= 29'd0;

        prefill_step          <= 3'd0;
        prefill_done          <= 1'b0;
        cache_ready           <= 1'b0;
        read_seen             <= 1'b0;
        cache_error           <= 1'b0;

        line_done_toggle_m1   <= 1'b0;
        line_done_toggle_m2   <= 1'b0;
        line_done_toggle_seen <= 1'b0;
        line_done_sequence_mem <= 11'd0;

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

        // Synchronize the one-bit line-consumed event.  The associated source
        // line number is generated locally below, eliminating the old binary
        // multi-bit CDC path.
        line_done_toggle_m1 <= line_done_toggle_rd;
        line_done_toggle_m2 <= line_done_toggle_m1;

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

            // Each synchronized toggle represents exactly one consumed source
            // line.  Wrap at the decoded picture height so repeated display
            // frames remain aligned to source line 0 without crossing a bus.
            if (picture_height_mem == 11'd0)
                line_done_sequence_mem <= 11'd0;
            else if (line_done_sequence_mem == (picture_height_mem - 11'd1))
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
                            launch_fetch(FETCH_Y, 11'd0);

                        3'd1:
                            if (picture_height_mem > 11'd1)
                                launch_fetch(FETCH_Y, 11'd1);
                            else
                                prefill_step <= 3'd2;

                        3'd2:
                            launch_fetch(FETCH_CB, 11'd0);

                        3'd3:
                            launch_fetch(FETCH_CR, 11'd0);

                        3'd4:
                            if (chroma_height_mem > 11'd1)
                                launch_fetch(FETCH_CB, 11'd1);
                            else
                                prefill_step <= 3'd5;

                        3'd5:
                            if (chroma_height_mem > 11'd1)
                                launch_fetch(FETCH_CR, 11'd1);
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
                            launch_fetch(FETCH_Y, y_refill_line);
                        end
                        else if (refill_phase == 2'd1) begin
                            launch_fetch(FETCH_CB, c_refill_line);
                        end
                        else begin
                            launch_fetch(FETCH_CR, c_refill_line);
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
reg        picture_present_rd;

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

always @(posedge rd_clk) begin
    if (rd_reset) begin
        cache_ready_r1       <= 1'b0;
        cache_ready_r2       <= 1'b0;
        picture_width_r1     <= 12'd0;
        picture_width_r2     <= 12'd0;
        picture_height_r1    <= 11'd0;
        picture_height_r2    <= 11'd0;
        picture_present_rd   <= 1'b0;
        line_done_toggle_rd  <= 1'b0;
    end
    else begin
        cache_ready_r1    <= cache_ready;
        cache_ready_r2    <= cache_ready_r1;
        picture_width_r1  <= picture_width_mem;
        picture_width_r2  <= picture_width_r1;
        picture_height_r1 <= picture_height_mem;
        picture_height_r2 <= picture_height_r1;

        // Publish only at a display-frame boundary after all initial line
        // caches are filled, so source line 0 always starts from a known bank.
        if (!picture_present_rd && cache_ready_r2 &&
            (h_pos == 12'd0) && (v_pos == 12'd0))
            picture_present_rd <= 1'b1;

        // Mark a source line free one pixel after its final cache read request.
        // Only the event toggle crosses to mem_clk; the memory-side sequence
        // counter supplies the source-line identity.
        if (picture_present_rd && pixel_en &&
            (h_pos == 12'd760) &&
            (v_pos >= 12'd60) &&
            (v_pos < (12'd60 + {1'b0, picture_height_r2}))) begin
            line_done_toggle_rd <= ~line_done_toggle_rd;
        end
    end
end

// -------------------------------------------------------------------------
// Video-side cache addressing and full-precision 4:2:0 expansion.
// -------------------------------------------------------------------------

wire source_window =
    pixel_en &&
    (h_pos >= 12'd40)  && (h_pos < 12'd760) &&
    (v_pos >= 12'd60)  && (v_pos < 12'd540);

wire [11:0] source_x = h_pos - 12'd40;
wire [11:0] source_y = v_pos - 12'd60;

wire decoded_picture_window =
    source_window &&
    picture_present_rd &&
    (source_x < picture_width_r2) &&
    (source_y < {1'b0, picture_height_r2});

wire [6:0] y_word_index = source_x[11:3];
wire [5:0] c_word_index = source_x[11:4];

assign y_cache_rd_addr =
    (source_y[0] ? 8'd90 : 8'd0) + {1'b0, y_word_index};

assign c_cache_rd_addr =
    (source_y[1] ? 7'd45 : 7'd0) + {1'b0, c_word_index};

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
    else begin
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
