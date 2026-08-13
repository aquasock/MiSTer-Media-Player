//============================================================================
// MiSTer Media Player - Phase 1T-f/1T-g/1T-h/1T-i H.262 reference-picture probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 7.6.4.
//   Prediction samples are read from the reference frame offset by the motion
//   vector. Motion vectors are in half-sample units. The integer-vector part and
//   half-sample flags are derived from the reconstructed vector itself:
//
//       int_vec[t]  = vector[t] DIV 2
//       half_flag[t]= (vector[t] - 2*int_vec[t]) != 0
//
//   For horizontal half-sample prediction with no vertical half-sample component:
//
//       pel_pred = (pel_ref[x] + pel_ref[x+1]) // 2
//
//   where // is integer division rounded to the nearest integer. For unsigned
//   reference samples this implementation is equivalently (a + b + 1) >> 1.
//
// kate - Phase 1T-f performs one real luma DDR read from the current reference
// bank. Phase 1T-g requires the exact controlled integer sample x=9 == 162 for
// test_ip_motion_nores_end.m2v. Phase 1T-h proved the horizontal two-sample
// interpolation arithmetic on a real returned DDR word before an odd vector was
// allowed to select it.
//
// kate - Phase 1T-i consumes the actual verified explicit forward vector exported
// by the syntax probe. Two deliberately narrow diagnostic modes are supported:
//
//   integer mode: vector (4,0), f_code 1/1, destination (7,0)
//     -> int_vec=(2,0), no half flags, reference (9,0), exact sample 162.
//
//   horizontal-half mode: vector (3,0), f_code 2/2, destination (0,0)
//     -> int_vec=(1,0), half_flag=(1,0), base reference (1,0), interpolate
//        reference samples (1,0) and (2,0) from the same packed DDR word.
//
// These coordinates and exact integer-mode value are implementation regression
// restrictions, not H.262 validity rules. No residual addition, P-picture pixel
// reconstruction, frame persistence or reference promotion occurs here.
//============================================================================

module mpeg2_h262_reference_read_probe
(
    input  wire        clk,
    input  wire        reset,

    input  wire        p_vector_proof_seen,
    input  wire        p_forward_vector_valid,
    input  wire signed [12:0] p_forward_vector_x,
    input  wire signed [12:0] p_forward_vector_y,
    input  wire [3:0]  forward_f_code_horizontal,
    input  wire [3:0]  forward_f_code_vertical,

    input  wire        reference_frame_valid,
    input  wire        reference_frame_bank,

    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,

    output reg         read_seen,
    output reg  [7:0]  sample_value,
    output reg         sample_nonzero,
    output reg         half_sample_seen,
    output reg         probe_error
);

localparam [28:0] DDR_Y_BASE     = 29'h06000000;
localparam [28:0] DDR_BANK_WORDS = 29'h00010000;
localparam [7:0]  DIAG_EXPECTED_INTEGER_SAMPLE = 8'd162;

reg        trigger_seen;
reg        request_active;
reg        response_waiting;
reg [28:0] request_address;
reg [2:0]  request_lane;
reg        request_half_sample;
reg [15:0] proof_timeout;

function automatic [28:0] row_times_90;
    input [11:0] row;
    reg [28:0] r;
    begin
        r = {17'd0, row};
        row_times_90 = (r << 6) + (r << 4) + (r << 3) + (r << 1);
    end
endfunction

wire controlled_integer_mode =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd4) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd1) &&
    (forward_f_code_vertical   == 4'd1);

wire controlled_halfpel_mode =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd3) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd2) &&
    (forward_f_code_vertical   == 4'd2);

wire controlled_mode = controlled_integer_mode || controlled_halfpel_mode;

// H.262 7.6.4 vector decomposition. Arithmetic shift implements DIV 2 with
// floor behavior for two's-complement values; the subtraction then derives the
// half-sample flag directly from the reconstructed vector.
wire signed [12:0] int_vec_x = p_forward_vector_x >>> 1;
wire signed [12:0] int_vec_y = p_forward_vector_y >>> 1;
wire signed [12:0] twice_int_vec_x = int_vec_x + int_vec_x;
wire signed [12:0] twice_int_vec_y = int_vec_y + int_vec_y;
wire half_flag_x = (p_forward_vector_x - twice_int_vec_x) != 13'sd0;
wire half_flag_y = (p_forward_vector_y - twice_int_vec_y) != 13'sd0;

wire [11:0] diag_destination_x = controlled_halfpel_mode ? 12'd0 : 12'd7;
wire [11:0] diag_destination_y = 12'd0;
wire signed [13:0] reference_x_signed =
    $signed({1'b0, diag_destination_x}) + int_vec_x;
wire signed [13:0] reference_y_signed =
    $signed({1'b0, diag_destination_y}) + int_vec_y;
wire [11:0] reference_x = reference_x_signed[11:0];
wire [11:0] reference_y = reference_y_signed[11:0];

wire vector_decomposition_ok =
    controlled_integer_mode ?
        ((int_vec_x == 13'sd2) && (int_vec_y == 13'sd0) &&
         !half_flag_x && !half_flag_y &&
         (reference_x_signed == 14'sd9) &&
         (reference_y_signed == 14'sd0)) :
    controlled_halfpel_mode ?
        ((int_vec_x == 13'sd1) && (int_vec_y == 13'sd0) &&
         half_flag_x && !half_flag_y &&
         (reference_x_signed == 14'sd1) &&
         (reference_y_signed == 14'sd0)) :
        1'b0;

wire [28:0] reference_bank_offset =
    reference_frame_bank ? DDR_BANK_WORDS : 29'd0;
wire [28:0] calculated_address =
    DDR_Y_BASE + reference_bank_offset +
    row_times_90(reference_y) +
    {20'd0, reference_x[11:3]};

wire [7:0] returned_sample =
    (request_lane == 3'd0) ? ddram_dout[7:0]   :
    (request_lane == 3'd1) ? ddram_dout[15:8]  :
    (request_lane == 3'd2) ? ddram_dout[23:16] :
    (request_lane == 3'd3) ? ddram_dout[31:24] :
    (request_lane == 3'd4) ? ddram_dout[39:32] :
    (request_lane == 3'd5) ? ddram_dout[47:40] :
    (request_lane == 3'd6) ? ddram_dout[55:48] :
                             ddram_dout[63:56];

wire [2:0] right_lane = request_lane + 3'd1;
wire [7:0] right_sample =
    (right_lane == 3'd0) ? ddram_dout[7:0]   :
    (right_lane == 3'd1) ? ddram_dout[15:8]  :
    (right_lane == 3'd2) ? ddram_dout[23:16] :
    (right_lane == 3'd3) ? ddram_dout[31:24] :
    (right_lane == 3'd4) ? ddram_dout[39:32] :
    (right_lane == 3'd5) ? ddram_dout[47:40] :
    (right_lane == 3'd6) ? ddram_dout[55:48] :
                           ddram_dout[63:56];

wire [8:0] halfpel_sum =
    {1'b0, returned_sample} + {1'b0, right_sample};
wire [8:0] halfpel_rounded_sum = halfpel_sum + 9'd1;
wire [7:0] halfpel_filtered_sample = halfpel_rounded_sum[8:1];
wire [8:0] halfpel_filtered_twice =
    {halfpel_filtered_sample, 1'b0};
wire halfpel_relation_ok =
    halfpel_sum[0] ?
        (halfpel_filtered_twice == (halfpel_sum + 9'd1)) :
        (halfpel_filtered_twice == halfpel_sum);
wire [7:0] halfpel_min =
    (returned_sample < right_sample) ? returned_sample : right_sample;
wire [7:0] halfpel_max =
    (returned_sample > right_sample) ? returned_sample : right_sample;
wire halfpel_nontrivial =
    (returned_sample != right_sample) &&
    (halfpel_filtered_sample > halfpel_min) &&
    (halfpel_filtered_sample < halfpel_max);

assign ddram_burstcnt = request_active ? 8'd1 : 8'd0;
assign ddram_addr     = request_active ? request_address : 29'd0;
assign ddram_rd       = request_active;

always @(posedge clk) begin
    if (reset) begin
        trigger_seen       <= 1'b0;
        request_active     <= 1'b0;
        response_waiting   <= 1'b0;
        request_address    <= 29'd0;
        request_lane       <= 3'd0;
        request_half_sample<= 1'b0;
        proof_timeout      <= 16'd0;
        read_seen          <= 1'b0;
        sample_value       <= 8'd0;
        sample_nonzero     <= 1'b0;
        half_sample_seen   <= 1'b0;
        probe_error        <= 1'b0;
    end
    else begin
        // Only the two controlled explicit-vector modes consume the diagnostic
        // DDR reader. Other P syntax regressions remain syntax-only.
        if (p_vector_proof_seen && controlled_mode && !trigger_seen) begin
            trigger_seen  <= 1'b1;
            proof_timeout <= 16'hFFFF;

            if (!reference_frame_valid || !vector_decomposition_ok ||
                (controlled_halfpel_mode && (reference_x[2:0] == 3'd7))) begin
                probe_error <= 1'b1;
            end
            else begin
                request_address     <= calculated_address;
                request_lane        <= reference_x[2:0];
                request_half_sample <= controlled_halfpel_mode;
                request_active      <= 1'b1;
            end
        end

        // A controlled prediction proof must produce its one-word response in a
        // bounded interval. At 54 MHz this is about 1.2 ms.
        if (trigger_seen && !read_seen && (proof_timeout != 16'd0)) begin
            proof_timeout <= proof_timeout - 16'd1;
            if (proof_timeout == 16'd1)
                probe_error <= 1'b1;
        end

        if (request_active && !ddram_busy) begin
            request_active   <= 1'b0;
            response_waiting <= 1'b1;
        end

        if (ddram_dout_ready) begin
            if (!response_waiting) begin
                probe_error <= 1'b1;
            end
            else begin
                response_waiting <= 1'b0;
                proof_timeout    <= 16'd0;
                read_seen        <= 1'b1;

                if (request_half_sample) begin
                    // Phase 1T-i: the odd vector itself selected this branch.
                    sample_value     <= halfpel_filtered_sample;
                    sample_nonzero   <= (halfpel_filtered_sample != 8'd0);
                    half_sample_seen <= 1'b1;

                    if (!halfpel_relation_ok ||
                        !halfpel_nontrivial ||
                        (halfpel_filtered_sample == 8'd0))
                        probe_error <= 1'b1;
                end
                else begin
                    // Preserve the Phase 1T-g exact integer-reference proof.
                    sample_value   <= returned_sample;
                    sample_nonzero <= (returned_sample != 8'd0);

                    if (returned_sample != DIAG_EXPECTED_INTEGER_SAMPLE)
                        probe_error <= 1'b1;
                end
            end
        end
    end
end

endmodule
