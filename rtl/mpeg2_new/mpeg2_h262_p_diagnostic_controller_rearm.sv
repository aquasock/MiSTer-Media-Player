//============================================================================
// MiSTer Media Player - P diagnostic controller
//
// Commit 123 routes every accepted generalized 128x96 P picture through one
// syntax-derived raster replay.  The replay carries 48 signed motion vectors
// plus optional transformed residual blocks.  Legacy two/four-macroblock proof
// clients and the Phase 1U-x stream-hold ownership rules remain intact.
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
wire[47:0] general_shift_right_map;
wire[383:0] general_motion_x_plan,general_motion_y_plan;
wire[287:0] general_residual_block_plan;wire[4:0] general_residual_block_count;
wire[383:0] general_coeff_index_plan;wire[831:0] general_coeff_value_plan;wire[63:0] general_coeff_last_plan;
wire[6:0] general_coeff_count;wire[79:0] general_qscale_plan;wire general_qtype,general_alt;
wire residual_decision,residual_required_raw,residual_success_raw,first_valid_raw,residual_valid_raw,residual_error_raw,mixed_replay_active;
wire signed[15:0] first_value_raw,residual_value_raw;wire[5:0] residual_index_raw;
wire hold_seen,hold_error,old_stream_hold;

wire general_mode=general_candidate||general_seen;
wire use_general=general_seen;
wire raster_candidate=four_mb_candidate||general_candidate;
wire raster_seen=four_mb_seen||general_seen;
wire raster_complete_now=four_mb_complete_now||general_complete_now;

wire signed [7:0] general_mvx0=$signed(general_motion_x_plan[7:0]);
wire signed [7:0] general_mvy0=$signed(general_motion_y_plan[7:0]);
assign p_forward_vector_valid=use_general?residual_valid_raw:four_mb_seen?1'b1:two_mb_seen?1'b1:raster_candidate?1'b0:vector_valid_raw;
assign p_forward_vector_x=use_general?{{5{general_mvx0[7]}},general_mvx0}:(four_mb_seen||two_mb_seen)?13'sd0:vector_x_raw;
assign p_forward_vector_y=use_general?{{5{general_mvy0[7]}},general_mvy0}:(four_mb_seen||two_mb_seen)?13'sd0:vector_y_raw;
assign p_residual_required=residual_required_raw;
assign p_residual_success=residual_success_raw;
assign p_first_residual_sample_valid=first_valid_raw;
assign p_first_residual_sample_value=first_value_raw;
assign p_residual_sample_valid=residual_valid_raw;
assign p_residual_sample_index=residual_index_raw;
assign p_residual_sample_value=residual_value_raw;

// A generalized replay must begin before a persistence indication is accepted.
// This prevents the sticky persisted_seen from the previous consecutive P frame
// from retiring a newly parsed transaction before its first motion metadata word.
reg general_replay_seen,general_persistence_seen;
always @(posedge clk)begin
 if(reset)begin general_replay_seen<=0;general_persistence_seen<=0;end
 else if(general_complete_now)begin general_replay_seen<=0;general_persistence_seen<=0;end
 else begin
  if(use_general&&mixed_replay_active&&residual_valid_raw)general_replay_seen<=1;
  if(use_general&&general_replay_seen&&p_persistence_complete)general_persistence_seen<=1;
 end
end
wire raster_persistence_complete=use_general?(general_replay_seen&&(p_persistence_complete||general_persistence_seen)):p_persistence_complete;
wire general_final_proof=use_general&&general_persistence_seen;
wire legacy_hold_owner=p_picture_expected&&!raster_candidate&&!raster_seen;

wire mb_seen_combined=raster_candidate?raster_seen:(mb_seen_raw||two_mb_seen||raster_seen);
wire mb_seen_decoded=mb_seen_combined&&(!p_picture_expected||(residual_decision&&(!residual_required_raw||residual_success_raw)));
wire two_mb_wait=two_mb_seen&&!p_persistence_complete;
wire raster_wait=raster_seen&&!raster_persistence_complete;
wire mb_seen_for_hold=mb_seen_decoded&&!two_mb_wait&&!raster_wait;

reg raster_hold_active,raster_hold_seen,raster_hold_ready,raster_hold_error;reg[23:0] raster_hold_timeout;
always @(posedge clk)begin
 if(reset)begin raster_hold_active<=0;raster_hold_seen<=0;raster_hold_ready<=1;raster_hold_error<=0;raster_hold_timeout<=0;end
 else begin
  if(raster_complete_now&&raster_hold_ready)begin raster_hold_active<=1;raster_hold_seen<=1;raster_hold_ready<=0;raster_hold_timeout<=24'hffffff;end
  if(raster_hold_active)begin
   if(raster_persistence_complete)begin raster_hold_active<=0;raster_hold_ready<=1;raster_hold_timeout<=0;end
   else if(raster_hold_timeout==1)begin raster_hold_active<=0;raster_hold_timeout<=0;raster_hold_error<=1;end
   else if(raster_hold_timeout!=0)raster_hold_timeout<=raster_hold_timeout-1'b1;
  end
 end
end
wire hold_seen_combined=raster_seen?raster_hold_seen:hold_seen;
wire p_macroblock_type_seen_normal=mb_seen_decoded&&(!p_picture_expected||(hold_seen_combined&&!two_mb_wait&&!raster_wait));
assign p_macroblock_type_seen=general_final_proof?1'b1:p_macroblock_type_seen_normal;
assign stream_hold=four_mb_parse_hold||general_parse_hold||raster_hold_active||(!raster_candidate&&!raster_seen&&old_stream_hold);
wire syntax_error=syntax_error_raw&&!two_mb_seen&&!four_mb_seen&&!general_candidate&&!general_seen;
wire progress_error=p_picture_expected&&!p_macroblock_type_seen;
wire parser_error_group=syntax_error|two_mb_error|four_mb_error|general_error;
assign probe_error=parser_error_group|progress_error|residual_error_raw|hold_error|raster_hold_error;

mpeg2_h262_p_syntax_probe syntax_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),.p_macroblock_type_seen(mb_seen_raw),.p_forward_vector_valid(vector_valid_raw),.p_forward_vector_x(vector_x_raw),.p_forward_vector_y(vector_y_raw),.probe_error(syntax_error_raw));
mpeg2_h262_p_two_mb_syntax_probe two_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.two_mb_seen(two_mb_seen),.probe_error(two_mb_error));
mpeg2_h262_p_four_mb_two_row_syntax_probe four_mb_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.four_mb_candidate(four_mb_candidate),.four_mb_seen(four_mb_seen),.four_mb_complete_now(four_mb_complete_now),.parse_hold(four_mb_parse_hold),.probe_error(four_mb_error));

mpeg2_h262_p_aligned_motion_syntax_probe general_probe(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .aligned_candidate(general_candidate),.aligned_seen(general_seen),.aligned_complete_now(general_complete_now),
 .aligned_shift_right_map(general_shift_right_map),.motion_x_plan(general_motion_x_plan),.motion_y_plan(general_motion_y_plan),
 .residual_block_plan(general_residual_block_plan),.residual_block_count(general_residual_block_count),.residual_present(general_residual_present),
 .residual_coeff_index_plan(general_coeff_index_plan),.residual_coeff_value_plan(general_coeff_value_plan),
 .residual_coeff_last_plan(general_coeff_last_plan),.residual_coeff_count(general_coeff_count),.residual_qscale_plan(general_qscale_plan),
 .q_scale_type(general_qtype),.alternate_scan(general_alt),.parse_hold(general_parse_hold),.probe_error(general_error));

mpeg2_h262_p_residual_probe residual_probe(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),
 .general_mode(general_mode),.general_picture_complete(general_complete_now),
 .general_motion_x_plan(general_motion_x_plan),.general_motion_y_plan(general_motion_y_plan),
 .general_residual_block_plan(general_residual_block_plan),.general_residual_block_count(general_residual_block_count),
 .general_coeff_index_plan(general_coeff_index_plan),.general_coeff_value_plan(general_coeff_value_plan),
 .general_coeff_last_plan(general_coeff_last_plan),.general_coeff_count(general_coeff_count),.general_qscale_plan(general_qscale_plan),
 .general_q_scale_type(general_qtype),.general_alternate_scan(general_alt),
 .decision_complete(residual_decision),.residual_required(residual_required_raw),.residual_success(residual_success_raw),
 .mixed_replay_active(mixed_replay_active),.first_sample_valid(first_valid_raw),.first_sample_value(first_value_raw),
 .residual_sample_valid(residual_valid_raw),.residual_sample_index(residual_index_raw),.residual_sample_value(residual_value_raw),
 .probe_error(residual_error_raw));

mpeg2_h262_p_stream_hold hold_probe(.clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_active(legacy_hold_owner),.p_macroblock_type_seen(mb_seen_for_hold),.p_residual_required(residual_required_raw),.p_persistence_complete(raster_persistence_complete),.stream_hold(old_stream_hold),.hold_seen(hold_seen),.hold_error(hold_error));
wire unused_general=&{1'b0,general_shift_right_map[0],general_residual_present};
endmodule
