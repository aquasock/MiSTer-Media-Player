//============================================================================
// MiSTer Media Player - P diagnostic controller
//
// Generalized 128x96 f_code=(3,3) raster syntax is now owned by one sequential
// parser that derives both the 48-position aligned-motion map and a sparse 48x6
// residual-block plan.  Motion-only pictures retain the accepted 48-bit plan
// transport.  Residual-bearing pictures reuse the shared transform and transport
// motion/residual metadata over the existing residual sideband.
//
// The Phase 1U-x legacy stream-hold ownership/completion correction is retained:
// once a raster client is accepted the legacy hold cannot reclaim the transaction,
// and remembered raster persistence retires any already-active legacy hold.
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
wire general_candidate,general_seen,general_complete_now,general_parse_hold,general_error,general_residual_present;
wire[47:0] general_shift_right_map;wire[287:0] general_residual_block_plan;wire[4:0] general_residual_block_count;
wire residual_decision,residual_required_raw,residual_success_raw,first_valid_raw,residual_valid_raw,residual_error_raw,mixed_replay_active;
wire signed[15:0] first_value_raw,residual_value_raw;wire[5:0] residual_index_raw;
wire hold_seen,hold_error,old_stream_hold;
wire general_mode=general_candidate||general_seen;
wire use_mixed=general_seen&&general_residual_present;
wire raster_candidate=four_mb_candidate||general_candidate;
wire raster_seen=four_mb_seen||general_seen;
wire raster_complete_now=four_mb_complete_now||general_complete_now;

reg general_plan_sending,general_plan_done;reg[5:0] general_plan_index;
always @(posedge clk)begin
 if(reset)begin general_plan_sending<=0;general_plan_done<=0;general_plan_index<=0;end
 else begin
  if(!general_seen&&general_candidate&&general_plan_done)begin general_plan_sending<=0;general_plan_done<=0;general_plan_index<=0;end
  else if(general_seen&&!general_residual_present&&!general_plan_sending&&!general_plan_done)begin general_plan_sending<=1;general_plan_index<=0;end
  else if(general_plan_sending)begin if(general_plan_index==47)begin general_plan_sending<=0;general_plan_done<=1;end else general_plan_index<=general_plan_index+1'b1;end
 end
end

assign p_forward_vector_valid=use_mixed?residual_valid_raw:general_seen?general_plan_done:four_mb_seen?1'b1:two_mb_seen?1'b1:raster_candidate?1'b0:vector_valid_raw;
assign p_forward_vector_x=use_mixed?13'sd32:general_seen?13'sd32:(four_mb_seen||two_mb_seen)?13'sd0:vector_x_raw;
assign p_forward_vector_y=(raster_seen||two_mb_seen)?13'sd0:vector_y_raw;
assign p_residual_required=residual_required_raw;assign p_residual_success=residual_success_raw;
assign p_first_residual_sample_valid=first_valid_raw;assign p_first_residual_sample_value=first_value_raw;
assign p_residual_sample_valid=use_mixed?residual_valid_raw:(general_plan_sending?1'b1:residual_valid_raw);
assign p_residual_sample_index=use_mixed?residual_index_raw:(general_plan_sending?general_plan_index:residual_index_raw);
assign p_residual_sample_value=use_mixed?residual_value_raw:(general_plan_sending?$signed({15'd0,general_shift_right_map[general_plan_index]}):residual_value_raw);

reg mixed_persistence_seen;
always @(posedge clk)begin
 if(reset)mixed_persistence_seen<=0;
 else if(general_complete_now&&general_residual_present)mixed_persistence_seen<=0;
 else if(use_mixed&&p_persistence_complete)mixed_persistence_seen<=1;
end
wire raster_persistence_complete=use_mixed?(p_persistence_complete||mixed_persistence_seen):p_persistence_complete;
wire mixed_final_proof=use_mixed&&mixed_persistence_seen;
wire legacy_hold_owner=p_picture_expected&&!raster_candidate&&!raster_seen;

wire mb_seen_combined=raster_candidate?raster_seen:(mb_seen_raw||two_mb_seen||raster_seen);
wire mb_seen_decoded=mb_seen_combined&&(!p_picture_expected||(residual_decision&&(!residual_required_raw||residual_success_raw)));
wire two_mb_wait=two_mb_seen&&!p_persistence_complete;wire raster_wait=raster_seen&&!raster_persistence_complete;
wire mb_seen_for_hold=mb_seen_decoded&&!two_mb_wait&&!raster_wait;
reg raster_hold_active,raster_hold_seen,raster_hold_ready,raster_hold_error;reg[19:0] raster_hold_timeout;
always @(posedge clk)begin
 if(reset)begin raster_hold_active<=0;raster_hold_seen<=0;raster_hold_ready<=1;raster_hold_error<=0;raster_hold_timeout<=0;end
 else begin
  if(raster_complete_now&&raster_hold_ready)begin raster_hold_active<=1;raster_hold_seen<=1;raster_hold_ready<=0;raster_hold_timeout<=20'hfffff;end
  if(raster_hold_active)begin if(p_persistence_complete)begin raster_hold_active<=0;raster_hold_ready<=1;raster_hold_timeout<=0;end
   else if(raster_hold_timeout==1)begin raster_hold_active<=0;raster_hold_timeout<=0;raster_hold_error<=1;end else if(raster_hold_timeout!=0)raster_hold_timeout<=raster_hold_timeout-1'b1;end
 end
end
wire hold_seen_combined=raster_seen?raster_hold_seen:hold_seen;
wire p_macroblock_type_seen_normal=mb_seen_decoded&&(!p_picture_expected||(hold_seen_combined&&!two_mb_wait&&!raster_wait));
assign p_macroblock_type_seen=mixed_final_proof?1'b1:p_macroblock_type_seen_normal;
assign stream_hold=four_mb_parse_hold||general_parse_hold||raster_hold_active||(!raster_candidate&&!raster_seen&&old_stream_hold);
wire syntax_error=syntax_error_raw&&!two_mb_seen&&!four_mb_seen&&!general_candidate&&!general_seen;
wire progress_error=p_picture_expected&&!p_macroblock_type_seen;
wire parser_error_group=syntax_error|two_mb_error|four_mb_error|general_error;
assign probe_error=parser_error_group|progress_error|residual_error_raw|hold_error|raster_hold_error;

mpeg2_h262_p_syntax_probe syntax_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),.p_macroblock_type_seen(mb_seen_raw),.p_forward_vector_valid(vector_valid_raw),.p_forward_vector_x(vector_x_raw),.p_forward_vector_y(vector_y_raw),.probe_error(syntax_error_raw));
mpeg2_h262_p_two_mb_syntax_probe two_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.two_mb_seen(two_mb_seen),.probe_error(two_mb_error));
mpeg2_h262_p_four_mb_two_row_syntax_probe four_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.four_mb_candidate(four_mb_candidate),.four_mb_seen(four_mb_seen),.four_mb_complete_now(four_mb_complete_now),.parse_hold(four_mb_parse_hold),.probe_error(four_mb_error));
mpeg2_h262_p_aligned_motion_syntax_probe general_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.aligned_candidate(general_candidate),.aligned_seen(general_seen),.aligned_complete_now(general_complete_now),.aligned_shift_right_map(general_shift_right_map),.residual_block_plan(general_residual_block_plan),.residual_block_count(general_residual_block_count),.residual_present(general_residual_present),.parse_hold(general_parse_hold),.probe_error(general_error));
mpeg2_h262_p_residual_probe residual_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),.general_mode(general_mode),.general_picture_complete(general_complete_now),.general_shift_right_map(general_shift_right_map),.general_residual_block_plan(general_residual_block_plan),.general_residual_block_count(general_residual_block_count),.decision_complete(residual_decision),.residual_required(residual_required_raw),.residual_success(residual_success_raw),.mixed_replay_active(mixed_replay_active),.first_sample_valid(first_valid_raw),.first_sample_value(first_value_raw),.residual_sample_valid(residual_valid_raw),.residual_sample_index(residual_index_raw),.residual_sample_value(residual_value_raw),.probe_error(residual_error_raw));
mpeg2_h262_p_stream_hold hold_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_active(legacy_hold_owner),.p_macroblock_type_seen(mb_seen_for_hold),.p_residual_required(residual_required_raw),.p_persistence_complete(raster_persistence_complete),.stream_hold(old_stream_hold),.hold_seen(hold_seen),.hold_error(hold_error));
wire unused_mixed_replay=&{1'b0,mixed_replay_active};
endmodule
