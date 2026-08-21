//============================================================================
// MiSTer Media Player - development hardware cadence profiler
//
// Entry 245: count only registered, externally visible decoder boundaries and
// freeze a stable, checksummed snapshot after the terminal presentation drains.
// The snapshot crosses to the video clock through two data synchronizer stages
// and a trailing ready synchronizer.  It is observational only: no profiler
// output feeds decoder, DDR, publication, or presentation control.
//============================================================================

module mpeg2_h262_hardware_cadence_profiler
(
    input  wire        clk_mpeg2,
    input  wire        reset_mpeg2,
    input  wire        clk_video,
    input  wire        reset_video,

    input  wire        fifo_pending,
    input  wire        decoder_ready,
    input  wire        presentation_hold,
    input  wire        destination_hold,
    // Entry 282: scheduler observability taps, used only by the unconditional
    // hold-attribution counters below.
    input  wire        scratch_available,
    input  wire        promotion_active,
    input  wire        decoder_byte_accepted,
    input  wire [2:0]  picture_coding_type,
    input  wire [9:0]  temporal_reference,
    input  wire [3:0]  frame_rate_code,
    input  wire [7:0]  picture_count,
    input  wire        reference_picture_complete,
    input  wire        b_picture_complete,

    input  wire        prediction_read,
    input  wire        prediction_busy,
    input  wire        prediction_data_ready,
    input  wire        writer_write,
    input  wire        writer_busy,

    input  wire [1:0]  display_frame_bank,
    input  wire        display_scratch,
    input  wire        display_scratch_bank,
    input  wire        sequence_end_seen,
    input  wire        session_quiet,
    input  wire [15:0] error_flags,

    input  wire [11:0] h_pos,
    input  wire [11:0] v_pos,
    input  wire [7:0]  base_r,
    input  wire [7:0]  base_g,
    input  wire [7:0]  base_b,
    input  wire        base_de,
    output reg  [7:0]  video_r,
    output reg  [7:0]  video_g,
    output reg  [7:0]  video_b,
    output wire        snapshot_ready
);

localparam integer SNAPSHOT_WORDS = 26;
localparam integer SNAPSHOT_BITS  = SNAPSHOT_WORDS * 32;
localparam [31:0] SNAPSHOT_MAGIC  = 32'h4d4d5031; // "MMP1"
localparam [31:0] SNAPSHOT_FORMAT = {8'd2, 8'd26, 16'd54000};
localparam [11:0] OVERLAY_X       = 12'd8;
localparam [11:0] OVERLAY_Y       = 12'd492;
localparam [11:0] OVERLAY_WIDTH   = 12'd168;
localparam [11:0] OVERLAY_HEIGHT  = 12'd104;

reg session_active;
reg fifo_pending_q;
reg decoder_ready_q;
reg presentation_hold_q;
reg destination_hold_q;
reg decoder_byte_accepted_q;
reg [2:0] picture_coding_type_q;
reg [9:0] temporal_reference_q;
reg [3:0] frame_rate_code_q;
reg [7:0] picture_count_q;
reg reference_picture_complete_q;
reg b_picture_complete_q;
reg prediction_read_q;
reg prediction_busy_q;
reg prediction_data_ready_q;
reg writer_write_q;
reg writer_busy_q;
reg [1:0] display_frame_bank_q;
reg display_scratch_q;
reg display_scratch_bank_q;
reg sequence_end_seen_q;
reg session_quiet_q;
reg [15:0] error_flags_q;
reg [31:0] session_cycles;
reg [31:0] accepted_bytes;
reg [31:0] first_present_cycle;
reg [31:0] last_present_cycle;
reg        first_present_valid;
reg [31:0] decoder_stall_cycles;
reg [31:0] presentation_stall_cycles;
reg [31:0] destination_stall_cycles;
// Entry 282: unconditional hold attribution.  Unlike the three stall counters
// above, which are a mutually exclusive priority chain, each of these counts
// every cycle its own condition is true.  Their sums may therefore overlap one
// another and the stall counters, which is precisely what makes the overlap
// measurable.
reg [31:0] presentation_hold_total_cycles;
reg [31:0] destination_hold_total_cycles;
reg [31:0] hold_overlap_cycles;
reg [31:0] hold_scratch_available_cycles;
reg [31:0] hold_promotion_pending_cycles;
reg scratch_available_q;
reg promotion_active_q;
reg [31:0] i_stall_cycles;
reg [31:0] p_stall_cycles;
reg [31:0] b_stall_cycles;
reg [31:0] prediction_requests;
reg [31:0] prediction_request_wait_cycles;
reg [31:0] prediction_response_cycles;
reg        prediction_outstanding;
reg [31:0] writer_wait_cycles;
reg [7:0]  reference_picture_count;
reg [7:0]  b_picture_count;
reg [7:0]  display_picture_count;
reg [7:0]  display_swap_count;
reg        b_picture_complete_d;
reg [1:0] display_frame_bank_d;
reg        display_scratch_d;
reg        display_scratch_bank_d;
reg [9:0]  quiet_count;
reg [SNAPSHOT_BITS-1:0] snapshot_mpeg2;
reg snapshot_ready_mpeg2;

wire b_picture_complete_edge =
    b_picture_complete_q && !b_picture_complete_d;
wire display_swap_now = first_present_valid &&
    ((display_frame_bank_q != display_frame_bank_d) ||
     (display_scratch_q != display_scratch_d) ||
     (display_scratch_q &&
      (display_scratch_bank_q != display_scratch_bank_d)));
wire prediction_request_accepted = prediction_read_q && !prediction_busy_q;

wire [31:0] snapshot_word_00 = SNAPSHOT_MAGIC;
wire [31:0] snapshot_word_01 = SNAPSHOT_FORMAT;
wire [31:0] snapshot_word_02 = accepted_bytes;
wire [31:0] snapshot_word_03 = session_cycles;
wire [31:0] snapshot_word_04 = first_present_cycle;
wire [31:0] snapshot_word_05 = last_present_cycle;
wire [31:0] snapshot_word_06 = last_present_cycle-first_present_cycle;
wire [31:0] snapshot_word_07 = decoder_stall_cycles;
wire [31:0] snapshot_word_08 = presentation_stall_cycles;
wire [31:0] snapshot_word_09 = destination_stall_cycles;
wire [31:0] snapshot_word_10 = i_stall_cycles;
wire [31:0] snapshot_word_11 = p_stall_cycles;
wire [31:0] snapshot_word_12 = b_stall_cycles;
wire [31:0] snapshot_word_13 = prediction_requests;
wire [31:0] snapshot_word_14 = prediction_request_wait_cycles;
wire [31:0] snapshot_word_15 = prediction_response_cycles;
wire [31:0] snapshot_word_16 = writer_wait_cycles;
wire [31:0] snapshot_word_17 =
    {reference_picture_count, b_picture_count,
     display_picture_count, display_swap_count};
wire [31:0] snapshot_word_18 =
    {frame_rate_code_q, picture_coding_type_q, temporal_reference_q,
     picture_count_q, 7'd0};
wire [31:0] snapshot_word_19 = {error_flags_q, 16'd0};
wire [31:0] snapshot_word_20 = presentation_hold_total_cycles;
wire [31:0] snapshot_word_21 = destination_hold_total_cycles;
wire [31:0] snapshot_word_22 = hold_overlap_cycles;
wire [31:0] snapshot_word_23 = hold_scratch_available_cycles;
wire [31:0] snapshot_word_24 = hold_promotion_pending_cycles;
wire [31:0] snapshot_word_25 =
    snapshot_word_00 ^ snapshot_word_01 ^ snapshot_word_02 ^
    snapshot_word_03 ^ snapshot_word_04 ^ snapshot_word_05 ^
    snapshot_word_06 ^ snapshot_word_07 ^ snapshot_word_08 ^
    snapshot_word_09 ^ snapshot_word_10 ^ snapshot_word_11 ^
    snapshot_word_12 ^ snapshot_word_13 ^ snapshot_word_14 ^
    snapshot_word_15 ^ snapshot_word_16 ^ snapshot_word_17 ^
    snapshot_word_18 ^ snapshot_word_19 ^ snapshot_word_20 ^
    snapshot_word_21 ^ snapshot_word_22 ^ snapshot_word_23 ^
    snapshot_word_24;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        session_active                 <= 1'b0;
        fifo_pending_q                 <= 1'b0;
        decoder_ready_q                <= 1'b0;
        presentation_hold_q            <= 1'b0;
        destination_hold_q             <= 1'b0;
        scratch_available_q            <= 1'b0;
        promotion_active_q             <= 1'b0;
        decoder_byte_accepted_q        <= 1'b0;
        picture_coding_type_q          <= 3'd0;
        temporal_reference_q           <= 10'd0;
        frame_rate_code_q              <= 4'd0;
        picture_count_q                <= 8'd0;
        reference_picture_complete_q   <= 1'b0;
        b_picture_complete_q           <= 1'b0;
        prediction_read_q              <= 1'b0;
        prediction_busy_q              <= 1'b0;
        prediction_data_ready_q        <= 1'b0;
        writer_write_q                 <= 1'b0;
        writer_busy_q                  <= 1'b0;
        display_frame_bank_q           <= 1'b0;
        display_scratch_q              <= 1'b0;
        display_scratch_bank_q         <= 1'b0;
        sequence_end_seen_q            <= 1'b0;
        session_quiet_q                <= 1'b0;
        error_flags_q                  <= 16'd0;
        session_cycles                 <= 32'd0;
        accepted_bytes                 <= 32'd0;
        first_present_cycle            <= 32'd0;
        last_present_cycle             <= 32'd0;
        first_present_valid            <= 1'b0;
        decoder_stall_cycles           <= 32'd0;
        presentation_stall_cycles      <= 32'd0;
        destination_stall_cycles       <= 32'd0;
        presentation_hold_total_cycles <= 32'd0;
        destination_hold_total_cycles  <= 32'd0;
        hold_overlap_cycles            <= 32'd0;
        hold_scratch_available_cycles  <= 32'd0;
        hold_promotion_pending_cycles  <= 32'd0;
        i_stall_cycles                 <= 32'd0;
        p_stall_cycles                 <= 32'd0;
        b_stall_cycles                 <= 32'd0;
        prediction_requests            <= 32'd0;
        prediction_request_wait_cycles <= 32'd0;
        prediction_response_cycles     <= 32'd0;
        prediction_outstanding         <= 1'b0;
        writer_wait_cycles             <= 32'd0;
        reference_picture_count        <= 8'd0;
        b_picture_count                <= 8'd0;
        display_picture_count          <= 8'd0;
        display_swap_count             <= 8'd0;
        b_picture_complete_d           <= 1'b0;
        display_frame_bank_d           <= 1'b0;
        display_scratch_d              <= 1'b0;
        display_scratch_bank_d         <= 1'b0;
        quiet_count                    <= 10'd0;
        snapshot_mpeg2                 <= {SNAPSHOT_BITS{1'b0}};
        snapshot_ready_mpeg2           <= 1'b0;
    end
    else begin
        // One diagnostic register per observed boundary keeps all counter and
        // checksum logic off the live decoder and presentation cones.
        fifo_pending_q               <= fifo_pending;
        decoder_ready_q              <= decoder_ready;
        presentation_hold_q          <= presentation_hold;
        scratch_available_q          <= scratch_available;
        promotion_active_q           <= promotion_active;
        destination_hold_q           <= destination_hold;
        decoder_byte_accepted_q      <= decoder_byte_accepted;
        picture_coding_type_q        <= picture_coding_type;
        temporal_reference_q         <= temporal_reference;
        frame_rate_code_q            <= frame_rate_code;
        picture_count_q              <= picture_count;
        reference_picture_complete_q <= reference_picture_complete;
        b_picture_complete_q         <= b_picture_complete;
        prediction_read_q            <= prediction_read;
        prediction_busy_q            <= prediction_busy;
        prediction_data_ready_q      <= prediction_data_ready;
        writer_write_q               <= writer_write;
        writer_busy_q                <= writer_busy;
        display_frame_bank_q         <= display_frame_bank;
        display_scratch_q            <= display_scratch;
        display_scratch_bank_q       <= display_scratch_bank;
        sequence_end_seen_q          <= sequence_end_seen;
        session_quiet_q              <= session_quiet;
        error_flags_q                <= error_flags;

        b_picture_complete_d   <= b_picture_complete_q;
        display_frame_bank_d   <= display_frame_bank_q;
        display_scratch_d      <= display_scratch_q;
        display_scratch_bank_d <= display_scratch_bank_q;

        if (decoder_byte_accepted_q)
            session_active <= 1'b1;

        if (!snapshot_ready_mpeg2 &&
            (session_active || decoder_byte_accepted_q)) begin
            session_cycles <= session_cycles + 1'b1;

            if (decoder_byte_accepted_q)
                accepted_bytes <= accepted_bytes + 1'b1;

            if (fifo_pending_q) begin
                if (!decoder_ready_q) begin
                    decoder_stall_cycles <= decoder_stall_cycles + 1'b1;
                    case (picture_coding_type_q)
                        3'b001: i_stall_cycles <= i_stall_cycles + 1'b1;
                        3'b010: p_stall_cycles <= p_stall_cycles + 1'b1;
                        3'b011: b_stall_cycles <= b_stall_cycles + 1'b1;
                        default: ;
                    endcase
                end
                else if (presentation_hold_q)
                    presentation_stall_cycles <=
                        presentation_stall_cycles + 1'b1;
                else if (destination_hold_q)
                    destination_stall_cycles <=
                        destination_stall_cycles + 1'b1;
            end

            // Entry 282: attribution independent of the priority chain above
            // and of fifo_pending, so overlapping holds are visible instead of
            // being masked by whichever cause happens to rank first.
            if (presentation_hold_q)
                presentation_hold_total_cycles <=
                    presentation_hold_total_cycles + 1'b1;
            if (destination_hold_q)
                destination_hold_total_cycles <=
                    destination_hold_total_cycles + 1'b1;
            if (presentation_hold_q && destination_hold_q)
                hold_overlap_cycles <= hold_overlap_cycles + 1'b1;
            if (presentation_hold_q && scratch_available_q)
                hold_scratch_available_cycles <=
                    hold_scratch_available_cycles + 1'b1;
            if (presentation_hold_q && promotion_active_q)
                hold_promotion_pending_cycles <=
                    hold_promotion_pending_cycles + 1'b1;

            if (prediction_request_accepted)
                prediction_requests <= prediction_requests + 1'b1;
            if (prediction_read_q && prediction_busy_q)
                prediction_request_wait_cycles <=
                    prediction_request_wait_cycles + 1'b1;
            if (prediction_outstanding)
                prediction_response_cycles <=
                    prediction_response_cycles + 1'b1;
            if (writer_write_q && writer_busy_q)
                writer_wait_cycles <= writer_wait_cycles + 1'b1;

            case ({prediction_request_accepted, prediction_data_ready_q})
                2'b10: prediction_outstanding <= 1'b1;
                2'b01: prediction_outstanding <= 1'b0;
                2'b11: prediction_outstanding <= 1'b1;
                default: ;
            endcase

            if (reference_picture_complete_q) begin
                reference_picture_count <= reference_picture_count + 1'b1;
                if (!first_present_valid) begin
                    first_present_valid   <= 1'b1;
                    first_present_cycle   <= session_cycles;
                    last_present_cycle    <= session_cycles;
                    display_picture_count <= 8'd1;
                end
            end

            if (b_picture_complete_edge)
                b_picture_count <= b_picture_count + 1'b1;

            if (display_swap_now) begin
                last_present_cycle    <= session_cycles;
                display_swap_count    <= display_swap_count + 1'b1;
                display_picture_count <= display_picture_count + 1'b1;
            end
        end

        if (!snapshot_ready_mpeg2 && session_active &&
            sequence_end_seen_q && session_quiet_q) begin
            if (quiet_count == 10'd1023) begin
                snapshot_mpeg2 <= {
                    snapshot_word_25, snapshot_word_24,
                    snapshot_word_23, snapshot_word_22,
                    snapshot_word_21, snapshot_word_20,
                    snapshot_word_19,
                    snapshot_word_18, snapshot_word_17,
                    snapshot_word_16, snapshot_word_15,
                    snapshot_word_14, snapshot_word_13,
                    snapshot_word_12, snapshot_word_11,
                    snapshot_word_10, snapshot_word_09,
                    snapshot_word_08, snapshot_word_07,
                    snapshot_word_06, snapshot_word_05,
                    snapshot_word_04, snapshot_word_03,
                    snapshot_word_02, snapshot_word_01,
                    snapshot_word_00
                };
                snapshot_ready_mpeg2 <= 1'b1;
            end
            else
                quiet_count <= quiet_count + 1'b1;
        end
        else
            quiet_count <= 10'd0;
    end
end

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [SNAPSHOT_BITS-1:0] snapshot_sync_1;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [SNAPSHOT_BITS-1:0] snapshot_sync_2;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] snapshot_ready_sync;

always @(posedge clk_video) begin
    if (reset_video) begin
        snapshot_sync_1     <= {SNAPSHOT_BITS{1'b0}};
        snapshot_sync_2     <= {SNAPSHOT_BITS{1'b0}};
        snapshot_ready_sync <= 3'b000;
    end
    else begin
        snapshot_sync_1     <= snapshot_mpeg2;
        snapshot_sync_2     <= snapshot_sync_1;
        snapshot_ready_sync <=
            {snapshot_ready_sync[1:0], snapshot_ready_mpeg2};
    end
end

assign snapshot_ready = snapshot_ready_sync[2];

reg [41:0] overlay_shift;
reg [31:0] overlay_row_word;
wire [4:0] overlay_row_index = (v_pos-OVERLAY_Y) >> 2;

always @* begin
    case (overlay_row_index)
        5'd0:  overlay_row_word = snapshot_sync_2[31:0];
        5'd1:  overlay_row_word = snapshot_sync_2[63:32];
        5'd2:  overlay_row_word = snapshot_sync_2[95:64];
        5'd3:  overlay_row_word = snapshot_sync_2[127:96];
        5'd4:  overlay_row_word = snapshot_sync_2[159:128];
        5'd5:  overlay_row_word = snapshot_sync_2[191:160];
        5'd6:  overlay_row_word = snapshot_sync_2[223:192];
        5'd7:  overlay_row_word = snapshot_sync_2[255:224];
        5'd8:  overlay_row_word = snapshot_sync_2[287:256];
        5'd9:  overlay_row_word = snapshot_sync_2[319:288];
        5'd10: overlay_row_word = snapshot_sync_2[351:320];
        5'd11: overlay_row_word = snapshot_sync_2[383:352];
        5'd12: overlay_row_word = snapshot_sync_2[415:384];
        5'd13: overlay_row_word = snapshot_sync_2[447:416];
        5'd14: overlay_row_word = snapshot_sync_2[479:448];
        5'd15: overlay_row_word = snapshot_sync_2[511:480];
        5'd16: overlay_row_word = snapshot_sync_2[543:512];
        5'd17: overlay_row_word = snapshot_sync_2[575:544];
        5'd18: overlay_row_word = snapshot_sync_2[607:576];
        5'd19: overlay_row_word = snapshot_sync_2[639:608];
        5'd20: overlay_row_word = snapshot_sync_2[671:640];
        5'd21: overlay_row_word = snapshot_sync_2[703:672];
        5'd22: overlay_row_word = snapshot_sync_2[735:704];
        5'd23: overlay_row_word = snapshot_sync_2[767:736];
        5'd24: overlay_row_word = snapshot_sync_2[799:768];
        5'd25: overlay_row_word = snapshot_sync_2[831:800];
        default: overlay_row_word = 32'd0;
    endcase
end

always @(posedge clk_video) begin
    if (reset_video)
        overlay_shift <= 42'd0;
    else if (h_pos == 12'd0) begin
        if (snapshot_ready &&
            (v_pos >= OVERLAY_Y) && (v_pos < OVERLAY_Y+OVERLAY_HEIGHT))
            overlay_shift <= {
                4'b1010, overlay_row_index,
                overlay_row_word, ^overlay_row_word
            };
        else
            overlay_shift <= 42'd0;
    end
    else if ((h_pos >= OVERLAY_X) &&
             (h_pos < OVERLAY_X+OVERLAY_WIDTH) &&
             (h_pos[1:0] == 2'b11))
        overlay_shift <= {overlay_shift[40:0], 1'b0};
end

always @* begin
    video_r = base_r;
    video_g = base_g;
    video_b = base_b;
    if (snapshot_ready && base_de &&
        (h_pos >= OVERLAY_X) && (h_pos < OVERLAY_X+OVERLAY_WIDTH) &&
        (v_pos >= OVERLAY_Y) && (v_pos < OVERLAY_Y+OVERLAY_HEIGHT)) begin
        video_r = overlay_shift[41] ? 8'hff : 8'h00;
        video_g = overlay_shift[41] ? 8'hff : 8'h00;
        video_b = overlay_shift[41] ? 8'hff : 8'h00;
    end
end

endmodule
