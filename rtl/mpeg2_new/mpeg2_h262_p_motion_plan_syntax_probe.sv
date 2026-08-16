//============================================================================
// MiSTer Media Player - retired legacy generalized-P syntax compatibility shell
//
// kate - Commit 167: the Commit-166 streamed parser now owns both the accepted
// 128x96 generalized-P regression geometry and the wider <=720x480 envelope.
// Keep the historical module interface constant-zero so the existing controller
// wiring remains source-stable while Quartus can prune the duplicate packed-plan
// parser and every legacy-only downstream branch.
//============================================================================
module mpeg2_h262_p_aligned_motion_syntax_probe
(
    input  wire          clk,
    input  wire          reset,
    input  wire [7:0]    stream_data,
    input  wire          stream_valid,

    output wire          aligned_candidate,
    output wire          aligned_seen,
    output wire          aligned_complete_now,
    output wire [47:0]   aligned_shift_right_map,
    output wire [383:0]  motion_x_plan,
    output wire [383:0]  motion_y_plan,
    output wire [287:0]  residual_block_plan,
    output wire [4:0]    residual_block_count,
    output wire          residual_present,
    output wire [383:0]  residual_coeff_index_plan,
    output wire [831:0]  residual_coeff_value_plan,
    output wire [63:0]   residual_coeff_last_plan,
    output wire [6:0]    residual_coeff_count,
    output wire [79:0]   residual_qscale_plan,
    output wire          q_scale_type,
    output wire          alternate_scan,
    output wire          parse_hold,
    output wire          probe_error
);

assign aligned_candidate          = 1'b0;
assign aligned_seen               = 1'b0;
assign aligned_complete_now       = 1'b0;
assign aligned_shift_right_map    = 48'd0;
assign motion_x_plan              = 384'd0;
assign motion_y_plan              = 384'd0;
assign residual_block_plan        = 288'd0;
assign residual_block_count       = 5'd0;
assign residual_present           = 1'b0;
assign residual_coeff_index_plan  = 384'd0;
assign residual_coeff_value_plan  = 832'd0;
assign residual_coeff_last_plan   = 64'd0;
assign residual_coeff_count       = 7'd0;
assign residual_qscale_plan       = 80'd0;
assign q_scale_type               = 1'b0;
assign alternate_scan             = 1'b0;
assign parse_hold                 = 1'b0;
assign probe_error                = 1'b0;

// Inputs intentionally remain unused. The shell exists only to preserve the
// historical controller port shape while synthesis removes the retired path.
endmodule
