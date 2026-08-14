//============================================================================
// MiSTer Media Player - P diagnostic controller
//
// Phase 1U-o preserves all accepted P clients and adds one controlled
// motion+residual raster.  Its six-block residual is buffered and replayed only
// after the exact picture syntax has been verified, so the legacy aligned-plan
// transport remains unchanged for already-accepted streams.
//============================================================================
module mpeg2_h262_p_diagnostic_controller
(
 input wire clk,input wire reset,input wire [7:0] stream_data,input wire stream_valid,
 input wire p_picture_expected,input wire p_persistence_complete,
 output wire stream_hold,output wire p_macroblock_type_seen,output wire p_forward_vector_valid,
 output wire signed [12:0] p_forward_vector_x,output wire signed [12:0] p_forward_vector_y,
 output wire p_residual_required,output wire p_residual_success,
 output wire p_first_residual_sample_valid,output wire signed [15:0] p_first_residual_sample_value,
 output wire p_residual_sample_valid,output wire [5:0] p_residual_sample_index,
 output wire signed [15:0] p_residual_sample_value,output wire probe_error
);
wire syntax_error_raw,mb_seen_raw,vector_valid_raw;wire signed[12:0] vector_x_raw,vector_y_raw;
wire two_mb_seen,two_mb_error;
wire four_mb_candidate,four_mb_seen,four_mb_complete_now,four_mb_parse_hold,four_mb_error;
wire aligned_candidate,aligned_seen,aligned_complete_now;wire[47:0] aligned_shift_right_map;wire aligned_error;
wire mixed_candidate,mixed_seen,mixed_complete_now,mixed_first_slice_complete;wire[47:0] mixed_shift_right_map;wire mixed_error;
wire residual_decision,residual_required_raw,residual_success_raw,first_valid_raw,residual_valid_raw,residual_error_raw,mixed_replay_active;
wire signed[15:0] first_value_raw,residual_value_raw;wire[5:0] residual_index_raw;
wire hold_seen,hold_error,old_stream_hold;
wire use_mixed=mixed_candidate||mixed_seen;
wire raster_candidate=four_mb_candidate||aligned_candidate||mixed_candidate;
wire raster_seen=four_mb_seen||aligned_seen||mixed_seen;
wire raster_complete_now=four_mb_complete_now||aligned_complete_now||mixed_complete_now;

// Accepted Phase 1U-l aligned-plan serialization remains intact for old streams.
reg aligned_plan_sending,aligned_plan_done;reg[5:0] aligned_plan_index;
always @(posedge clk)begin
 if(reset)begin aligned_plan_sending<=0;aligned_plan_done<=0;aligned_plan_index<=0;end
 else begin
  if(!aligned_seen&&aligned_candidate&&aligned_plan_done)begin aligned_plan_sending<=0;aligned_plan_done<=0;aligned_plan_index<=0;end
  else if(aligned_seen&&!aligned_plan_sending&&!aligned_plan_done)begin aligned_plan_sending<=1;aligned_plan_index<=0;end
  else if(aligned_plan_sending)begin if(aligned_plan_index==47)begin aligned_plan_sending<=0;aligned_plan_done<=1;end else aligned_plan_index<=aligned_plan_index+1'b1;end
 end
end

assign p_forward_vector_valid=mixed_seen?residual_valid_raw:aligned_seen?aligned_plan_done:four_mb_seen?1'b1:two_mb_seen?1'b1:raster_candidate?1'b0:vector_valid_raw;
assign p_forward_vector_x=mixed_seen?13'sd32:aligned_seen?13'sd32:(four_mb_seen||two_mb_seen)?13'sd0:vector_x_raw;
assign p_forward_vector_y=(raster_seen||two_mb_seen)?13'sd0:vector_y_raw;
assign p_residual_required=residual_required_raw;
assign p_residual_success=residual_success_raw;
assign p_first_residual_sample_valid=first_valid_raw;
assign p_first_residual_sample_value=first_value_raw;
assign p_residual_sample_valid=use_mixed?residual_valid_raw:(aligned_plan_sending?1'b1:residual_valid_raw);
assign p_residual_sample_index=use_mixed?residual_index_raw:(aligned_plan_sending?aligned_plan_index:residual_index_raw);
assign p_residual_sample_value=use_mixed?residual_value_raw:(aligned_plan_sending?$signed({15'd0,aligned_shift_right_map[aligned_plan_index]}):residual_value_raw);

wire mb_seen_combined=raster_candidate?raster_seen:(mb_seen_raw||two_mb_seen||raster_seen);
wire mb_seen_decoded=mb_seen_combined&&(!p_picture_expected||(residual_decision&&(!residual_required_raw||residual_success_raw)));
wire two_mb_wait=two_mb_seen&&!p_persistence_complete;wire raster_wait=raster_seen&&!p_persistence_complete;
wire mb_seen_for_hold=mb_seen_decoded&&!two_mb_wait&&!raster_wait;
reg raster_hold_active,raster_hold_seen,raster_hold_ready,raster_hold_error;reg[19:0] raster_hold_timeout;
always @(posedge clk)begin
 if(reset)begin raster_hold_active<=0;raster_hold_seen<=0;raster_hold_ready<=1;raster_hold_error<=0;raster_hold_timeout<=0;end
 else begin
  if(raster_complete_now&&raster_hold_ready)begin raster_hold_active<=1;raster_hold_seen<=1;raster_hold_ready<=0;raster_hold_timeout<=20'hfffff;end
  if(raster_hold_active)begin if(p_persistence_complete)begin raster_hold_active<=0;raster_hold_ready<=1;raster_hold_timeout<=0;end else if(raster_hold_timeout==1)begin raster_hold_active<=0;raster_hold_timeout<=0;raster_hold_error<=1;end else if(raster_hold_timeout!=0)raster_hold_timeout<=raster_hold_timeout-1'b1;end
 end
end
wire hold_seen_combined=raster_seen?raster_hold_seen:hold_seen;
assign p_macroblock_type_seen=mb_seen_decoded&&(!p_picture_expected||(hold_seen_combined&&!two_mb_wait&&!raster_wait));
assign stream_hold=four_mb_parse_hold||raster_hold_active||(!raster_candidate&&old_stream_hold);
wire syntax_error=syntax_error_raw&&!two_mb_seen&&!four_mb_seen&&!aligned_candidate&&!aligned_seen&&!mixed_candidate&&!mixed_seen;
wire progress_error=p_picture_expected&&!p_macroblock_type_seen;
assign probe_error=syntax_error|two_mb_error|four_mb_error|((aligned_error)&&!use_mixed)|mixed_error|residual_error_raw|hold_error|raster_hold_error|progress_error;

mpeg2_h262_p_syntax_probe syntax_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),.p_macroblock_type_seen(mb_seen_raw),.p_forward_vector_valid(vector_valid_raw),.p_forward_vector_x(vector_x_raw),.p_forward_vector_y(vector_y_raw),.probe_error(syntax_error_raw));
mpeg2_h262_p_two_mb_syntax_probe two_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.two_mb_seen(two_mb_seen),.probe_error(two_mb_error));
mpeg2_h262_p_four_mb_two_row_syntax_probe four_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.four_mb_candidate(four_mb_candidate),.four_mb_seen(four_mb_seen),.four_mb_complete_now(four_mb_complete_now),.parse_hold(four_mb_parse_hold),.probe_error(four_mb_error));
mpeg2_h262_p_aligned_motion_syntax_probe aligned_motion_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.aligned_candidate(aligned_candidate),.aligned_seen(aligned_seen),.aligned_complete_now(aligned_complete_now),.aligned_shift_right_map(aligned_shift_right_map),.probe_error(aligned_error));
mpeg2_h262_p_motion_residual_syntax_probe mixed_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.mixed_candidate(mixed_candidate),.mixed_seen(mixed_seen),.mixed_complete_now(mixed_complete_now),.first_slice_complete(mixed_first_slice_complete),.shift_right_map(mixed_shift_right_map),.probe_error(mixed_error));
mpeg2_h262_p_residual_probe residual_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),.mixed_mode(use_mixed),.mixed_first_slice_complete(mixed_first_slice_complete),.mixed_release(mixed_seen),.decision_complete(residual_decision),.residual_required(residual_required_raw),.residual_success(residual_success_raw),.mixed_replay_active(mixed_replay_active),.first_sample_valid(first_valid_raw),.first_sample_value(first_value_raw),.residual_sample_valid(residual_valid_raw),.residual_sample_index(residual_index_raw),.residual_sample_value(residual_value_raw),.probe_error(residual_error_raw));
mpeg2_h262_p_stream_hold hold_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_active(p_picture_expected&&!raster_candidate),.p_macroblock_type_seen(mb_seen_for_hold),.p_residual_required(residual_required_raw),.p_persistence_complete(p_persistence_complete),.stream_hold(old_stream_hold),.hold_seen(hold_seen),.hold_error(hold_error));
wire unused_mixed_map=&{1'b0,mixed_shift_right_map};
endmodule
