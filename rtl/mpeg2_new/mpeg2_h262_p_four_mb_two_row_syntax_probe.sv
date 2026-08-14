//============================================================================
// MiSTer Media Player - controlled four-macroblock/two-row H.262 P observer
//
// Standards authority: core-standards.md, source_id H262.
// Relevant established records:
//   H262-007 macroblock width
//   H262-008 slice vertical position identifies the macroblock row
//   H262-009 macroblock address progression restarts from the slice basis
//   H262-011 P-picture motion-forward-only macroblock_type code 001
//   H262-012 motion_code 0 code 1
//   H262-013 macroblock_address_increment 1 code 1
//
// kate - Phase 1T-s recognizes one deliberately narrow 32x32 progressive P
// diagnostic.  It requires two P slices, vertical positions 1 and 2.  Each
// slice contains exactly two adjacent motion-forward-only macroblocks with
// macroblock_address_increment=1, motion_code=(0,0), and forward f_code=(2,2).
// Each controlled slice therefore has the semantic payload 0x12 0x79 0xC0.
//
// This is a controlled diagnostic recognizer, not a general P-picture parser.
//============================================================================

module mpeg2_h262_p_four_mb_two_row_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,

    output reg        four_mb_candidate,
    output reg        four_mb_seen,
    output wire       four_mb_complete_now,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);
// kate - Phase 1T-t: a following I picture may be preceded by a new sequence
// header.  Both start codes are valid boundaries for the completed P picture.
wire        post_p_boundary_now =
    (start_code_value == PICTURE_START_CODE) ||
    (start_code_value == SEQUENCE_HEADER_CODE);

// sequence_header() first 24 payload bits are horizontal_size_value followed
// by vertical_size_value.
reg        sequence_capture;
reg [1:0]  sequence_count;
reg [23:0] sequence_shift;
wire [23:0] sequence_next = {sequence_shift[15:0], stream_data};
reg        geometry_32x32;

// picture_header() first 16 payload bits contain temporal_reference[9:0],
// picture_coding_type[2:0], then the first three vbv_delay bits.
reg        picture_capture;
reg        picture_count;
reg [15:0] picture_shift;
wire [15:0] picture_next = {picture_shift[7:0], stream_data};
reg        current_picture_is_p;

// Capture the first 40 bits of picture_coding_extension().
reg        pce_capture;
reg [2:0]  pce_count;
reg [39:0] pce_shift;
wire [39:0] pce_next = {pce_shift[31:0], stream_data};

// Capture two controlled P slices.  As with the accepted Phase 1T-r observer,
// slice_count==6 at the following start-code byte means exactly three payload
// bytes preceded the 00 00 01 prefix of that next start code.
reg        slice_capture;
reg        second_slice;
reg [3:0]  slice_count;
reg [23:0] first_three_bytes;
reg        first_three_complete;
reg        proof_done;

wire controlled_payload_ok =
    // quantiser_scale_code = 2
    (first_three_bytes[23:19] == 5'd2) &&
    // extra_bit_slice terminator = 0
    (first_three_bytes[18] == 1'b0) &&
    // macroblock 0: MBA increment 1, P type 001, mv=(0,0)
    (first_three_bytes[17]    == 1'b1) &&
    (first_three_bytes[16:14] == 3'b001) &&
    (first_three_bytes[13]    == 1'b1) &&
    (first_three_bytes[12]    == 1'b1) &&
    // macroblock 1: same syntax, therefore adjacent within the slice row
    (first_three_bytes[11]    == 1'b1) &&
    (first_three_bytes[10:8]  == 3'b001) &&
    (first_three_bytes[7]     == 1'b1) &&
    (first_three_bytes[6]     == 1'b1) &&
    // stuffing to the byte boundary
    (first_three_bytes[5:0]   == 6'b000000);

// Assert on the exact accepted boundary after the second controlled slice.
// The controlled stream may begin the next I picture directly or may emit a
// sequence header first.  This combinational pulse lets the controller stop the
// compressed stream on that boundary cycle, before its payload is consumed.
assign four_mb_complete_now =
    stream_valid &&
    slice_capture &&
    second_slice &&
    start_code_now &&
    post_p_boundary_now &&
    (slice_count == 4'd6) &&
    first_three_complete &&
    controlled_payload_ok;

always @(posedge clk) begin
    if (reset) begin
        byte_window          <= 32'd0;
        sequence_capture     <= 1'b0;
        sequence_count       <= 2'd0;
        sequence_shift       <= 24'd0;
        geometry_32x32       <= 1'b0;
        picture_capture      <= 1'b0;
        picture_count        <= 1'b0;
        picture_shift        <= 16'd0;
        current_picture_is_p <= 1'b0;
        pce_capture          <= 1'b0;
        pce_count            <= 3'd0;
        pce_shift            <= 40'd0;
        four_mb_candidate    <= 1'b0;
        slice_capture        <= 1'b0;
        second_slice         <= 1'b0;
        slice_count          <= 4'd0;
        first_three_bytes    <= 24'd0;
        first_three_complete <= 1'b0;
        proof_done           <= 1'b0;
        four_mb_seen         <= 1'b0;
        probe_error          <= 1'b0;
    end
    else if (stream_valid) begin
        byte_window <= byte_window_next;

        if (sequence_capture) begin
            sequence_shift <= sequence_next;
            if (sequence_count == 2'd2) begin
                sequence_capture <= 1'b0;
                sequence_count   <= 2'd0;
                geometry_32x32   <= (sequence_next == 24'h020020);
            end
            else begin
                sequence_count <= sequence_count + 2'd1;
            end
        end
        else if (start_code_now &&
                 (start_code_value == SEQUENCE_HEADER_CODE)) begin
            sequence_capture <= 1'b1;
            sequence_count   <= 2'd0;
            sequence_shift   <= 24'd0;
        end

        if (picture_capture) begin
            picture_shift <= picture_next;
            if (picture_count) begin
                picture_capture      <= 1'b0;
                picture_count        <= 1'b0;
                current_picture_is_p <= (picture_next[5:3] == 3'd2);
                four_mb_candidate    <= 1'b0;
            end
            else begin
                picture_count <= 1'b1;
            end
        end
        else if (start_code_now &&
                 (start_code_value == PICTURE_START_CODE)) begin
            picture_capture <= 1'b1;
            picture_count   <= 1'b0;
            picture_shift   <= 16'd0;
        end

        if (pce_capture) begin
            pce_shift <= pce_next;
            if (pce_count == 3'd4) begin
                pce_capture <= 1'b0;
                pce_count   <= 3'd0;

                // Controlled progressive frame-P boundary.  Forward horizontal
                // and vertical f_code are both 2.  motion_code=0 still yields
                // an exact zero vector with no residual motion bits.
                four_mb_candidate <=
                    geometry_32x32 &&
                    current_picture_is_p &&
                    (pce_next[39:36] == 4'h8) &&
                    (pce_next[35:32] == 4'd2) &&
                    (pce_next[31:28] == 4'd2) &&
                    (pce_next[17:16] == 2'b11) &&
                    (pce_next[14]    == 1'b1) &&
                    (pce_next[13]    == 1'b0) &&
                    (pce_next[12]    == 1'b0) &&
                    (pce_next[10]    == 1'b0);
            end
            else begin
                pce_count <= pce_count + 3'd1;
            end
        end
        else if (current_picture_is_p && start_code_now &&
                 (start_code_value == EXTENSION_START_CODE)) begin
            pce_capture <= 1'b1;
            pce_count   <= 3'd0;
            pce_shift   <= 40'd0;
        end

        if (!proof_done && slice_capture) begin
            if (start_code_now) begin
                if ((slice_count != 4'd6) ||
                    !first_three_complete ||
                    !controlled_payload_ok) begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;
                    probe_error   <= 1'b1;
                end
                else if (!second_slice) begin
                    // H262-008: the second slice start code selects row 1 of
                    // this 32x32 picture.  H262-009 then restarts the MBA basis.
                    if (start_code_value == 8'h02) begin
                        slice_capture        <= 1'b1;
                        second_slice         <= 1'b1;
                        slice_count          <= 4'd0;
                        first_three_bytes    <= 24'd0;
                        first_three_complete <= 1'b0;
                    end
                    else begin
                        slice_capture <= 1'b0;
                        proof_done    <= 1'b1;
                        probe_error   <= 1'b1;
                    end
                end
                else begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;

                    if (post_p_boundary_now)
                        four_mb_seen <= 1'b1;
                    else
                        probe_error <= 1'b1;
                end
            end
            else begin
                if (slice_count < 4'd3) begin
                    first_three_bytes <=
                        {first_three_bytes[15:0], stream_data};
                    if (slice_count == 4'd2)
                        first_three_complete <= 1'b1;
                end

                if (slice_count != 4'hF)
                    slice_count <= slice_count + 4'd1;
            end
        end
        else if (!proof_done && four_mb_candidate && slice_start_now) begin
            if (start_code_value == 8'h01) begin
                slice_capture        <= 1'b1;
                second_slice         <= 1'b0;
                slice_count          <= 4'd0;
                first_three_bytes    <= 24'd0;
                first_three_complete <= 1'b0;
            end
            else begin
                proof_done  <= 1'b1;
                probe_error <= 1'b1;
            end
        end
    end
end

endmodule
