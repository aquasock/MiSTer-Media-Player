//============================================================================
// MiSTer Media Player - controlled two-macroblock H.262 P syntax observer
//
// Standards authority: core-standards.md, source_id H262.
// Relevant established records:
//   H262-007 macroblock width
//   H262-008 slice vertical position
//   H262-009 macroblock address progression
//
// kate - Phase 1T-r recognizes one deliberately narrow 32x16 P-picture test
// without relying on historical stream bytes.  The first P slice must contain
// exactly two adjacent motion-forward-only macroblocks.  Each has
// macroblock_address_increment=1 and motion_code=(0,0), with f_code=1 for both
// forward components.  The remaining six bits of the third payload byte are
// slice stuffing and must be zero.
//
// This is a controlled diagnostic recognizer, not a general P-picture parser.
//============================================================================

module mpeg2_h262_p_two_mb_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,

    output reg        two_mb_seen,
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

// sequence_header() first 24 payload bits are horizontal_size_value followed
// by vertical_size_value.
reg        sequence_capture;
reg [1:0]  sequence_count;
reg [23:0] sequence_shift;
wire [23:0] sequence_next = {sequence_shift[15:0], stream_data};
reg        geometry_32x16;

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
reg        p_controls_ok;

// Capture the controlled first P slice until the following start code.  The
// three payload bytes are followed by 00 00 01 before the next start-code byte,
// so slice_count==6 proves exactly three payload bytes were present.
reg        slice_capture;
reg [3:0]  slice_count;
reg [23:0] first_three_bytes;
reg        first_three_complete;
reg        proof_done;

wire controlled_payload_ok =
    // quantiser_scale_code = 2
    (first_three_bytes[23:19] == 5'd2) &&
    // extra_bit_slice terminator = 0
    (first_three_bytes[18] == 1'b0) &&
    // macroblock 0: MBA increment 1, P type 001 motion_forward only,
    // horizontal motion_code 0, vertical motion_code 0.
    (first_three_bytes[17]    == 1'b1) &&
    (first_three_bytes[16:14] == 3'b001) &&
    (first_three_bytes[13]    == 1'b1) &&
    (first_three_bytes[12]    == 1'b1) &&
    // macroblock 1: same syntax; H262-009 therefore advances to x=16.
    (first_three_bytes[11]    == 1'b1) &&
    (first_three_bytes[10:8]  == 3'b001) &&
    (first_three_bytes[7]     == 1'b1) &&
    (first_three_bytes[6]     == 1'b1) &&
    // Slice stuffing to the byte boundary.
    (first_three_bytes[5:0]   == 6'b000000);

always @(posedge clk) begin
    if (reset) begin
        byte_window            <= 32'd0;
        sequence_capture       <= 1'b0;
        sequence_count         <= 2'd0;
        sequence_shift         <= 24'd0;
        geometry_32x16         <= 1'b0;
        picture_capture        <= 1'b0;
        picture_count          <= 1'b0;
        picture_shift          <= 16'd0;
        current_picture_is_p   <= 1'b0;
        pce_capture            <= 1'b0;
        pce_count              <= 3'd0;
        pce_shift              <= 40'd0;
        p_controls_ok          <= 1'b0;
        slice_capture          <= 1'b0;
        slice_count            <= 4'd0;
        first_three_bytes      <= 24'd0;
        first_three_complete   <= 1'b0;
        proof_done             <= 1'b0;
        two_mb_seen            <= 1'b0;
        probe_error            <= 1'b0;
    end
    else if (stream_valid) begin
        byte_window <= byte_window_next;

        if (sequence_capture) begin
            sequence_shift <= sequence_next;
            if (sequence_count == 2'd2) begin
                sequence_capture <= 1'b0;
                sequence_count   <= 2'd0;
                geometry_32x16   <= (sequence_next == 24'h020010);
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
                p_controls_ok        <= 1'b0;
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

                // Controlled progressive frame-P boundary.  The first two
                // forward f_code values are 1, frame picture is selected,
                // frame_pred_frame_dct is set, and the controlled stream uses
                // linear qscale with no concealment vectors or alternate scan.
                p_controls_ok <=
                    (pce_next[39:36] == 4'h8) &&
                    (pce_next[35:32] == 4'd1) &&
                    (pce_next[31:28] == 4'd1) &&
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
                slice_capture <= 1'b0;
                proof_done    <= 1'b1;

                if ((slice_count == 4'd6) &&
                    first_three_complete &&
                    controlled_payload_ok) begin
                    two_mb_seen <= 1'b1;
                end
                else begin
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
        else if (!proof_done && current_picture_is_p && geometry_32x16 &&
                 p_controls_ok && slice_start_now) begin
            if (start_code_value == 8'h01) begin
                slice_capture        <= 1'b1;
                slice_count          <= 4'd0;
                first_three_bytes    <= 24'd0;
                first_three_complete <= 1'b0;
            end
            else begin
                // A 16-line controlled picture must begin on its only row.
                proof_done  <= 1'b1;
                probe_error <= 1'b1;
            end
        end
    end
end

endmodule
