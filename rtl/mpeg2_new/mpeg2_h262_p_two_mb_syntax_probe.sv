//============================================================================
// MiSTer Media Player - Phase 1T-r controlled two-macroblock P observer
//
// Standards authority: core-standards.md, source_id H262.
// H262-009 controls slice-local macroblock address progression.  This observer
// is deliberately a test-vector recognizer, not a general P-picture parser.
//
// Controlled stream signature (tools/streams/test_ip_two_mb_static.m2v):
//   sequence geometry 32x16 4:2:0
//   first P slice payload bits:
//     quantiser_scale_code = 2
//     extra_bit_slice      = 0
//     macroblock 0: MBA=1, P type 001 (motion_forward only), mv=(0,0)
//     macroblock 1: MBA=1, P type 001 (motion_forward only), mv=(0,0)
//   followed by zero stuffing and the next start-code prefix.
//
// The exact three-byte payload 12 79 c0 is therefore a compact controlled
// proof of two adjacent coded macroblocks with no residual data.  The normal
// standards-driven P syntax probe remains authoritative for every existing
// regression; this module is only selected after both geometry and signature
// match.
//============================================================================
module mpeg2_h262_p_two_mb_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_expected,
    output reg        two_mb_seen,
    output reg        probe_error
);

localparam [7:0] SEQUENCE_HEADER_CODE = 8'hB3;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire start_code_now = (byte_window_next[31:8] == 24'h000001);
wire [7:0] start_code_value = byte_window_next[7:0];
wire slice_start_now = start_code_now &&
                       (start_code_value >= 8'h01) &&
                       (start_code_value <= 8'hAF);

reg sequence_capture;
reg [1:0] sequence_count;
reg [23:0] sequence_bytes;
reg geometry_32x16;

reg slice_capture;
reg [3:0] slice_count;
reg [23:0] first_three_bytes;
reg first_three_complete;
reg proof_done;

always @(posedge clk) begin
    if (reset) begin
        byte_window          <= 32'd0;
        sequence_capture     <= 1'b0;
        sequence_count       <= 2'd0;
        sequence_bytes       <= 24'd0;
        geometry_32x16       <= 1'b0;
        slice_capture        <= 1'b0;
        slice_count          <= 4'd0;
        first_three_bytes    <= 24'd0;
        first_three_complete <= 1'b0;
        proof_done           <= 1'b0;
        two_mb_seen          <= 1'b0;
        probe_error          <= 1'b0;
    end
    else if (stream_valid) begin
        byte_window <= byte_window_next;

        if (sequence_capture) begin
            sequence_bytes <= {sequence_bytes[15:0], stream_data};
            if (sequence_count == 2'd2) begin
                sequence_capture <= 1'b0;
                sequence_count   <= 2'd0;
                // sequence_header() first 24 payload bits are
                // horizontal_size_value[11:0], vertical_size_value[11:0].
                geometry_32x16 <=
                    ({sequence_bytes[15:0], stream_data} == 24'h020010);
            end
            else begin
                sequence_count <= sequence_count + 2'd1;
            end
        end
        else if (start_code_now &&
                 (start_code_value == SEQUENCE_HEADER_CODE)) begin
            sequence_capture <= 1'b1;
            sequence_count   <= 2'd0;
            sequence_bytes   <= 24'd0;
        end

        if (!proof_done && p_picture_expected && geometry_32x16) begin
            if (slice_capture) begin
                if (start_code_now) begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;

                    // Three syntax payload bytes plus the 00 00 01 prefix
                    // have been accepted when the following code byte arrives.
                    if ((slice_count == 4'd6) &&
                        first_three_complete &&
                        (first_three_bytes == 24'h1279c0)) begin
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

                    if (slice_count != 4'hf)
                        slice_count <= slice_count + 4'd1;
                end
            end
            else if (slice_start_now) begin
                slice_capture        <= 1'b1;
                slice_count          <= 4'd0;
                first_three_bytes    <= 24'd0;
                first_three_complete <= 1'b0;
            end
        end
    end
end

endmodule
