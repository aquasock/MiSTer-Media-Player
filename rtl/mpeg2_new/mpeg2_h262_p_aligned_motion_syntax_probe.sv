//============================================================================
// MiSTer Media Player - controlled aligned non-zero H.262 P motion observer
//
// Standards authority: core-standards.md, source_id H262.
// Relevant records:
//   H262-003 prediction samples derive from reference samples and motion vectors
//   H262-008 slice vertical position identifies the macroblock row
//   H262-009 slice-local macroblock address progression
//   H262-011 P motion-forward-only macroblock_type code 001
//   H262-014 Table B.1 macroblock_address_increment VLCs
//   H262-015 skipped P-frame macroblocks reset prediction to zero motion
//   H262-016 controlled f_code=3 motion_code +8/residual 3 reconstructs +32
//   H262-017 4:2:0 chroma vector is derived by halving the luma vector
//
// Phase 1U-l preserves the accepted Phase 1U-k repeated-column proof and adds
// a second controlled syntax shape whose +32 motion macroblock moves one column
// to the right on each successive slice row.  The following macroblock is
// skipped in every row to reset PMV, and all remaining coded macroblocks use
// zero motion.  Once all six rows are verified, a 48-bit shift-right execution
// map is exported to the controller for serialized delivery to the reference
// pipeline.  This remains a controlled semantic proof, not a general P parser.
//============================================================================

module mpeg2_h262_p_aligned_motion_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,

    output reg        aligned_candidate,
    output reg        aligned_seen,
    output wire       aligned_complete_now,
    output reg [47:0] aligned_shift_right_map,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5;

localparam [4:0] EXPECTED_SLICE_COUNT = 5'd11; // 8 payload + 000001 prefix
localparam [47:0] LEGACY_SHIFT_MAP   = 48'h010101010101;
localparam [47:0] DISPATCH_SHIFT_MAP = 48'h201008040201;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);
wire post_p_boundary_now =
    (start_code_value == PICTURE_START_CODE) ||
    (start_code_value == SEQUENCE_HEADER_CODE);

reg        sequence_capture;
reg [1:0]  sequence_count;
reg [23:0] sequence_shift;
wire [23:0] sequence_next = {sequence_shift[15:0], stream_data};
reg        geometry_128x96;

reg        picture_capture;
reg        picture_count;
reg [15:0] picture_shift;
wire [15:0] picture_next = {picture_shift[7:0], stream_data};
reg        current_picture_is_p;

reg        pce_capture;
reg [2:0]  pce_count;
reg [39:0] pce_shift;
wire [39:0] pce_next = {pce_shift[31:0], stream_data};

reg        slice_capture;
reg [3:0]  slice_row_number;
reg [4:0]  slice_count;
reg        legacy_possible;
reg        dispatch_possible;
reg        proof_done;

function automatic [7:0] payload_byte;
    input [63:0] payload;
    input [4:0]  index;
    begin
        case (index)
            5'd0: payload_byte = payload[63:56];
            5'd1: payload_byte = payload[55:48];
            5'd2: payload_byte = payload[47:40];
            5'd3: payload_byte = payload[39:32];
            5'd4: payload_byte = payload[31:24];
            5'd5: payload_byte = payload[23:16];
            5'd6: payload_byte = payload[15:8];
            5'd7: payload_byte = payload[7:0];
            default: payload_byte = 8'h00;
        endcase
    end
endfunction

function automatic [63:0] dispatch_payload;
    input [3:0] row_number;
    begin
        case (row_number)
            4'd1: dispatch_payload = 64'h12416ECF3CF3CF38;
            4'd2: dispatch_payload = 64'h127905BB3CF3CF38;
            4'd3: dispatch_payload = 64'h1279E416ECF3CF38;
            4'd4: dispatch_payload = 64'h1279E7905BB3CF38;
            4'd5: dispatch_payload = 64'h1279E79E416ECF38;
            4'd6: dispatch_payload = 64'h1279E79E7905BB38;
            default: dispatch_payload = 64'd0;
        endcase
    end
endfunction

wire [7:0] legacy_expected_byte =
    payload_byte(64'h12416ECF3CF3CF38, slice_count);
wire [7:0] dispatch_expected_byte =
    payload_byte(dispatch_payload(slice_row_number), slice_count);
wire any_pattern_possible = legacy_possible || dispatch_possible;

assign aligned_complete_now =
    stream_valid &&
    slice_capture &&
    start_code_now &&
    post_p_boundary_now &&
    (slice_row_number == 4'd6) &&
    (slice_count == EXPECTED_SLICE_COUNT) &&
    any_pattern_possible;

always @(posedge clk) begin
    if (reset) begin
        byte_window               <= 32'd0;
        sequence_capture          <= 1'b0;
        sequence_count            <= 2'd0;
        sequence_shift            <= 24'd0;
        geometry_128x96           <= 1'b0;
        picture_capture           <= 1'b0;
        picture_count             <= 1'b0;
        picture_shift             <= 16'd0;
        current_picture_is_p      <= 1'b0;
        pce_capture               <= 1'b0;
        pce_count                 <= 3'd0;
        pce_shift                 <= 40'd0;
        aligned_candidate         <= 1'b0;
        aligned_seen              <= 1'b0;
        aligned_shift_right_map   <= 48'd0;
        slice_capture             <= 1'b0;
        slice_row_number          <= 4'd0;
        slice_count               <= 5'd0;
        legacy_possible           <= 1'b0;
        dispatch_possible         <= 1'b0;
        proof_done                <= 1'b0;
        probe_error               <= 1'b0;
    end
    else if (stream_valid) begin
        byte_window <= byte_window_next;

        if (sequence_capture) begin
            sequence_shift <= sequence_next;
            if (sequence_count == 2'd2) begin
                sequence_capture <= 1'b0;
                sequence_count   <= 2'd0;
                geometry_128x96  <=
                    (sequence_next[23:12] == 12'd128) &&
                    (sequence_next[11:0]  == 12'd96);
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
                aligned_candidate    <= 1'b0;
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
                aligned_candidate <=
                    geometry_128x96 &&
                    current_picture_is_p &&
                    (pce_next[39:36] == 4'h8) &&
                    (pce_next[35:32] == 4'd3) &&
                    (pce_next[31:28] == 4'd3) &&
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
                if ((slice_count != EXPECTED_SLICE_COUNT) ||
                    !any_pattern_possible) begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;
                    probe_error   <= 1'b1;
                end
                else if (slice_row_number < 4'd6) begin
                    if (start_code_value == {4'd0, slice_row_number} + 8'd1) begin
                        slice_row_number <= slice_row_number + 4'd1;
                        slice_count      <= 5'd0;
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
                    if (post_p_boundary_now) begin
                        aligned_seen <= 1'b1;
                        if (dispatch_possible)
                            aligned_shift_right_map <= DISPATCH_SHIFT_MAP;
                        else
                            aligned_shift_right_map <= LEGACY_SHIFT_MAP;
                    end
                    else begin
                        probe_error <= 1'b1;
                    end
                end
            end
            else begin
                if (slice_count < 5'd8) begin
                    if (stream_data != legacy_expected_byte)
                        legacy_possible <= 1'b0;
                    if (stream_data != dispatch_expected_byte)
                        dispatch_possible <= 1'b0;
                end
                if (slice_count != 5'h1F)
                    slice_count <= slice_count + 5'd1;
            end
        end
        else if (!proof_done && aligned_candidate && slice_start_now) begin
            if (start_code_value == 8'h01) begin
                slice_capture           <= 1'b1;
                slice_row_number        <= 4'd1;
                slice_count             <= 5'd0;
                legacy_possible         <= 1'b1;
                dispatch_possible       <= 1'b1;
                aligned_shift_right_map <= 48'd0;
            end
            else begin
                proof_done  <= 1'b1;
                probe_error <= 1'b1;
            end
        end
    end
end

endmodule
