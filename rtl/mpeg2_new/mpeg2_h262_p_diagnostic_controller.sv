//============================================================================
// MiSTer Media Player - Phase 1T-r P diagnostic controller
// kate - Keeps all accepted P syntax/residual/hold behavior, adding an exact
// 32x16 two-macroblock zero-vector signature whose public success is withheld
// until full DDR persistence completes.
//============================================================================
module mpeg2_h262_p_diagnostic_controller(
 input wire clk,input wire reset,input wire [7:0] stream_data,input wire stream_valid,
 input wire p_picture_expected,input wire p_persistence_complete,
 output wire stream_hold,output wire p_macroblock_type_seen,output wire p_forward_vector_valid,
 output wire signed [12:0] p_forward_vector_x,output wire signed [12:0] p_forward_vector_y,
 output wire p_residual_required,output wire p_residual_success,output wire p_first_residual_sample_valid,
 output wire signed [15:0] p_first_residual_sample_value,output wire p_residual_sample_valid,
 output wire [5:0] p_residual_sample_index,output wire signed [15:0] p_residual_sample_value,
 output wire probe_error);
wire syntax_error_raw,mb_seen_raw,vector_valid_raw;wire signed [12:0] vector_x_raw,vector_y_raw;
wire two_mb_seen,two_mb_error;wire residual_decision,residual_required_raw,residual_success_raw,first_valid_raw;
wire signed [15:0] first_value_raw;wire residual_valid_raw;wire [5:0] residual_index_raw;wire signed [15:0] residual_value_raw;
wire residual_error,hold_seen,hold_error;
assign p_forward_vector_valid=two_mb_seen?1'b1:vector_valid_raw;
assign p_forward_vector_x=two_mb_seen?13'sd0:vector_x_raw;assign p_forward_vector_y=two_mb_seen?13'sd0:vector_y_raw;
assign p_residual_required=residual_required_raw;assign p_residual_success=residual_success_raw;
assign p_first_residual_sample_valid=first_valid_raw;assign p_first_residual_sample_value=first_value_raw;
assign p_residual_sample_valid=residual_valid_raw;assign p_residual_sample_index=residual_index_raw;assign p_residual_sample_value=residual_value_raw;
wire mb_seen_combined=mb_seen_raw||two_mb_seen;
wire mb_seen_decoded=mb_seen_combined&&(!p_picture_expected||(residual_decision&&(!residual_required_raw||residual_success_raw)));
wire two_mb_wait=two_mb_seen&&!p_persistence_complete;wire mb_seen_for_hold=mb_seen_decoded&&!two_mb_wait;
assign p_macroblock_type_seen=mb_seen_decoded&&(!p_picture_expected||(hold_seen&&!two_mb_wait));
wire syntax_error=syntax_error_raw&&!two_mb_seen;wire progress_error=p_picture_expected&&!p_macroblock_type_seen;
assign probe_error=syntax_error|two_mb_error|residual_error|hold_error|progress_error;
mpeg2_h262_p_syntax_probe syntax_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_expected(p_picture_expected),.p_macroblock_type_seen(mb_seen_raw),.p_forward_vector_valid(vector_valid_raw),
 .p_forward_vector_x(vector_x_raw),.p_forward_vector_y(vector_y_raw),.probe_error(syntax_error_raw));
mpeg2_h262_p_two_mb_syntax_probe two_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_expected(p_picture_expected),.two_mb_seen(two_mb_seen),.probe_error(two_mb_error));
mpeg2_h262_p_residual_probe residual_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_expected(p_picture_expected),.decision_complete(residual_decision),.residual_required(residual_required_raw),
 .residual_success(residual_success_raw),.first_sample_valid(first_valid_raw),.first_sample_value(first_value_raw),
 .residual_sample_valid(residual_valid_raw),.residual_sample_index(residual_index_raw),.residual_sample_value(residual_value_raw),
 .probe_error(residual_error));
mpeg2_h262_p_stream_hold hold_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_active(p_picture_expected),.p_macroblock_type_seen(mb_seen_for_hold),.p_residual_required(residual_required_raw),
 .p_persistence_complete(p_persistence_complete),.stream_hold(stream_hold),.hold_seen(hold_seen),.hold_error(hold_error));
endmodule
