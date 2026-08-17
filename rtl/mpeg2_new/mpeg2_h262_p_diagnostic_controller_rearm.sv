//============================================================================
// MiSTer Media Player - P diagnostic controller
//
// Commit 123 retains the accepted generalized 128x96 packed-plan parser.
// kate - Commit 166 adds a wide progressive parser whose motion metadata is
// streamed directly to the shared raster engine while the existing transform
// pipeline handles sparse residual blocks. Legacy proof clients remain intact.
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
 output wire signed [15:0] p_residual_sample_value,output wire probe_error,
 // kate - Commit 180 observability only.  probe_error_source names which of the
 // nine terms ORed into probe_error fired; progress_detail names which conjunct
 // of p_macroblock_type_seen is false when progress_error is the winning term.
 // Neither changes probe_error or any decode behavior.
 output wire [3:0] probe_error_source,
 output wire [3:0] progress_detail
);

wire syntax_error_raw,mb_seen_raw,vector_valid_raw;
wire signed[12:0] vector_x_raw,vector_y_raw;
wire two_mb_seen,two_mb_error;
wire four_mb_candidate,four_mb_seen,four_mb_complete_now,four_mb_parse_hold,four_mb_error;

// Historical 128x96 generalized parser.
wire legacy_candidate,legacy_seen,legacy_complete_now,legacy_parse_hold,legacy_error,legacy_residual_present;
wire[47:0] legacy_shift_right_map;
wire[383:0] legacy_motion_x_plan,legacy_motion_y_plan;
wire[287:0] legacy_residual_block_plan;
wire[4:0] legacy_residual_block_count;
wire[383:0] legacy_coeff_index_plan;
wire[831:0] legacy_coeff_value_plan;
wire[63:0] legacy_coeff_last_plan;
wire[6:0] legacy_coeff_count;
wire[79:0] legacy_qscale_plan;
wire legacy_qtype,legacy_alt;

// Commit-166 wide parser.
wire wide_candidate,wide_seen,wide_complete_now,wide_parse_hold,wide_error;
wire wide_motion_valid;
wire[10:0] wide_motion_index;
wire signed[7:0] wide_motion_x,wide_motion_y;
wire[5:0] wide_mb_width,wide_mb_height;
wire[10:0] wide_mb_count;
wire[351:0] wide_residual_mb_plan;
wire[95:0] wide_residual_block_index_plan;
wire[5:0] wide_residual_block_count;
wire wide_residual_present;
wire[383:0] wide_coeff_index_plan;
wire[831:0] wide_coeff_value_plan;
wire[63:0] wide_coeff_last_plan;
wire[6:0] wide_coeff_count;
wire[159:0] wide_qscale_plan;
wire wide_qtype,wide_alt;

wire residual_decision,residual_required_raw,residual_success_raw;
wire first_valid_raw,residual_valid_raw,residual_error_raw,mixed_replay_active;
wire signed[15:0] first_value_raw,residual_value_raw;
wire[5:0] residual_index_raw;
wire hold_seen,hold_error,old_stream_hold;

wire legacy_mode=legacy_candidate||legacy_seen;
wire wide_mode=wide_candidate||wide_seen;
wire general_mode=legacy_mode||wide_mode;
wire use_general=legacy_seen||wide_seen;
wire raster_candidate=four_mb_candidate||legacy_candidate||wide_candidate;
wire raster_seen=four_mb_seen||legacy_seen||wide_seen;
wire raster_complete_now=four_mb_complete_now||legacy_complete_now||wide_complete_now;

// Wide motion events are already in macroblock order and are forwarded to the
// same sideband consumed by the shared P raster engine. Residual replay follows
// after the complete picture has been parsed and transformed.
wire wide_sideband_valid = wide_motion_valid || residual_valid_raw;
wire [5:0] wide_sideband_index =
    wide_motion_valid ? 6'h3e : residual_index_raw;
wire signed [15:0] wide_sideband_value =
    wide_motion_valid ? $signed({wide_motion_x,wide_motion_y}) :
                        residual_value_raw;

wire signed [7:0] legacy_mvx0=$signed(legacy_motion_x_plan[7:0]);
wire signed [7:0] legacy_mvy0=$signed(legacy_motion_y_plan[7:0]);

assign p_forward_vector_valid =
    wide_mode ? wide_sideband_valid :
    legacy_seen ? residual_valid_raw :
    four_mb_seen ? 1'b1 :
    two_mb_seen ? 1'b1 :
    raster_candidate ? 1'b0 :
    vector_valid_raw;

assign p_forward_vector_x =
    wide_mode ?
        (wide_motion_valid ? {{5{wide_motion_x[7]}},wide_motion_x} : 13'sd0) :
    legacy_seen ? {{5{legacy_mvx0[7]}},legacy_mvx0} :
    (four_mb_seen||two_mb_seen) ? 13'sd0 : vector_x_raw;

assign p_forward_vector_y =
    wide_mode ?
        (wide_motion_valid ? {{5{wide_motion_y[7]}},wide_motion_y} : 13'sd0) :
    legacy_seen ? {{5{legacy_mvy0[7]}},legacy_mvy0} :
    (four_mb_seen||two_mb_seen) ? 13'sd0 : vector_y_raw;

assign p_residual_required=residual_required_raw;
assign p_residual_success=residual_success_raw;
assign p_first_residual_sample_valid=first_valid_raw;
assign p_first_residual_sample_value=first_value_raw;
assign p_residual_sample_valid =
    wide_mode ? wide_sideband_valid : residual_valid_raw;
assign p_residual_sample_index =
    wide_mode ? wide_sideband_index : residual_index_raw;
assign p_residual_sample_value =
    wide_mode ? wide_sideband_value : residual_value_raw;

// A generalized transaction must begin before a persistence indication is
// accepted. This prevents sticky persistence from the previous consecutive P
// frame from retiring newly parsed metadata.
// kate - Commit 168: streamed motion can finish before wide_complete_now. Keep
// that observed transaction live across wide completion so motion-only P can
// accept its own persistence pulse; clear it when generalized mode drops while
// the following generalized P picture rearms.
reg general_replay_seen,general_persistence_seen;
always @(posedge clk)begin
 if(reset)begin
  general_replay_seen<=0;
  general_persistence_seen<=0;
 end
 else if(raster_complete_now)begin
  if(!wide_complete_now)general_replay_seen<=0;
  general_persistence_seen<=0;
 end
 else if(!general_mode)begin
  general_replay_seen<=0;
  general_persistence_seen<=0;
 end
 else begin
  if(wide_mode&&wide_motion_valid)general_replay_seen<=1;
  if(legacy_mode&&mixed_replay_active&&residual_valid_raw)general_replay_seen<=1;
  if(wide_mode&&mixed_replay_active&&residual_valid_raw)general_replay_seen<=1;
  if(general_mode&&general_replay_seen&&p_persistence_complete)
   general_persistence_seen<=1;
 end
end

wire raster_persistence_complete =
    general_mode ?
        (general_replay_seen&&
         (p_persistence_complete||general_persistence_seen)) :
        p_persistence_complete;
wire general_final_proof=use_general&&general_persistence_seen;
wire legacy_hold_owner=p_picture_expected&&!raster_candidate&&!raster_seen;

wire mb_seen_combined =
    raster_candidate ? raster_seen :
    (mb_seen_raw||two_mb_seen||raster_seen);
wire mb_seen_decoded =
    mb_seen_combined &&
    (!p_picture_expected ||
     (residual_decision &&
      (!residual_required_raw||residual_success_raw)));
wire two_mb_wait=two_mb_seen&&!p_persistence_complete;
wire raster_wait=raster_seen&&!raster_persistence_complete;
wire mb_seen_for_hold=mb_seen_decoded&&!two_mb_wait&&!raster_wait;

reg raster_hold_active,raster_hold_seen,raster_hold_ready,raster_hold_error;
reg[23:0] raster_hold_timeout;
always @(posedge clk)begin
 if(reset)begin
  raster_hold_active<=0;
  raster_hold_seen<=0;
  raster_hold_ready<=1;
  raster_hold_error<=0;
  raster_hold_timeout<=0;
 end
 else begin
  if(raster_complete_now&&raster_hold_ready)begin
   raster_hold_active<=1;
   raster_hold_seen<=1;
   raster_hold_ready<=0;
   raster_hold_timeout<=24'hffffff;
  end
  if(raster_hold_active)begin
   if(raster_persistence_complete)begin
    raster_hold_active<=0;
    raster_hold_ready<=1;
    raster_hold_timeout<=0;
   end
   else if(raster_hold_timeout==1)begin
    raster_hold_active<=0;
    raster_hold_timeout<=0;
    raster_hold_error<=1;
   end
   else if(raster_hold_timeout!=0)
    raster_hold_timeout<=raster_hold_timeout-1'b1;
  end
 end
end

wire hold_seen_combined=raster_seen?raster_hold_seen:hold_seen;
wire p_macroblock_type_seen_normal=
    mb_seen_decoded &&
    (!p_picture_expected ||
     (hold_seen_combined&&!two_mb_wait&&!raster_wait));
assign p_macroblock_type_seen=
    general_final_proof?1'b1:p_macroblock_type_seen_normal;

assign stream_hold =
    four_mb_parse_hold ||
    legacy_parse_hold ||
    wide_parse_hold ||
    raster_hold_active ||
    (!raster_candidate&&!raster_seen&&old_stream_hold);

wire syntax_error=
    syntax_error_raw &&
    !two_mb_seen &&
    !four_mb_seen &&
    !legacy_candidate &&
    !legacy_seen &&
    !wide_candidate &&
    !wide_seen;
wire progress_error=p_picture_expected&&!p_macroblock_type_seen;
// kate - Commit 181.  A controlled observer must not gate acceptance on a
// stream it has disclaimed.  Each observer admits only its own documented
// subset -- the four-MB raster observer claims picture_coding_extension
// f_code 2, the Commit-166 wide parser claims f_code 3 -- so on any stream
// outside that subset the observer never asserts its candidate/seen claim.
// Its probe_error could still latch from an internal scope check and then
// permanently fail acceptance for a stream it was never proving.  That is the
// Commit-180 hardware result: the Commit-175 generators emit f_code 3, so
// four_mb_candidate is false by construction on all six streams, yet
// four_mb_error latched on test_consecutive_chain and read out as POWER 3.
//
// Qualify every observer error by that observer's own claim.  syntax_error
// already carries the equivalent qualification and is unchanged.  probe_error
// keeps all its terms; only unowned contributions are dropped.
// kate - Commit 184.  These five parser probes are historical controlled-
// pattern observers, not the generalized decoder that owns current f_code-3
// streams.  Their documented subset rejections must not fail acceptance.
// Keep every functional completion/replay/hold error below; only retire the
// controlled parser observer group from the acceptance error output.
assign probe_error=
    progress_error|residual_error_raw|
    hold_error|raster_hold_error;

// Preserve the established numeric codes for the remaining functional terms.
assign probe_error_source=
    progress_error    ? 4'd6 :
    residual_error_raw? 4'd7 :
    hold_error        ? 4'd8 :
    raster_hold_error ? 4'd9 : 4'd0;

// kate - Commit 180 observability only.  progress_error is a symptom: it is
// p_picture_expected && !p_macroblock_type_seen, and p_macroblock_type_seen is
// general_final_proof OR a deep conjunction.  Name the first false conjunct in
// the order the expression evaluates.  Only meaningful while progress_error is
// the winning source.
assign progress_detail=
    general_final_proof                             ? 4'd0 :
    !mb_seen_combined                               ? 4'd1 :
    !residual_decision                              ? 4'd2 :
    (residual_required_raw&&!residual_success_raw)  ? 4'd3 :
    !hold_seen_combined                             ? 4'd4 :
    two_mb_wait                                     ? 4'd5 :
    raster_wait                                     ? 4'd6 : 4'd0;

mpeg2_h262_p_syntax_probe syntax_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_expected(p_picture_expected),
 .p_macroblock_type_seen(mb_seen_raw),
 .p_forward_vector_valid(vector_valid_raw),
 .p_forward_vector_x(vector_x_raw),
 .p_forward_vector_y(vector_y_raw),
 .probe_error(syntax_error_raw)
);

mpeg2_h262_p_two_mb_syntax_probe two_mb_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .two_mb_seen(two_mb_seen),.probe_error(two_mb_error)
);

mpeg2_h262_p_four_mb_two_row_syntax_probe four_mb_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .four_mb_candidate(four_mb_candidate),.four_mb_seen(four_mb_seen),
 .four_mb_complete_now(four_mb_complete_now),
 .parse_hold(four_mb_parse_hold),.probe_error(four_mb_error)
);

mpeg2_h262_p_aligned_motion_syntax_probe legacy_general_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .aligned_candidate(legacy_candidate),.aligned_seen(legacy_seen),
 .aligned_complete_now(legacy_complete_now),
 .aligned_shift_right_map(legacy_shift_right_map),
 .motion_x_plan(legacy_motion_x_plan),.motion_y_plan(legacy_motion_y_plan),
 .residual_block_plan(legacy_residual_block_plan),
 .residual_block_count(legacy_residual_block_count),
 .residual_present(legacy_residual_present),
 .residual_coeff_index_plan(legacy_coeff_index_plan),
 .residual_coeff_value_plan(legacy_coeff_value_plan),
 .residual_coeff_last_plan(legacy_coeff_last_plan),
 .residual_coeff_count(legacy_coeff_count),
 .residual_qscale_plan(legacy_qscale_plan),
 .q_scale_type(legacy_qtype),.alternate_scan(legacy_alt),
 .parse_hold(legacy_parse_hold),.probe_error(legacy_error)
);

mpeg2_h262_p_wide_motion_syntax_probe wide_general_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .wide_candidate(wide_candidate),.wide_seen(wide_seen),
 .wide_complete_now(wide_complete_now),
 .motion_event_valid(wide_motion_valid),
 .motion_event_index(wide_motion_index),
 .motion_event_x(wide_motion_x),.motion_event_y(wide_motion_y),
 .picture_mb_width(wide_mb_width),.picture_mb_height(wide_mb_height),
 .picture_mb_count(wide_mb_count),
 .residual_mb_plan(wide_residual_mb_plan),
 .residual_block_index_plan(wide_residual_block_index_plan),
 .residual_block_count(wide_residual_block_count),
 .residual_present(wide_residual_present),
 .residual_coeff_index_plan(wide_coeff_index_plan),
 .residual_coeff_value_plan(wide_coeff_value_plan),
 .residual_coeff_last_plan(wide_coeff_last_plan),
 .residual_coeff_count(wide_coeff_count),
 .residual_qscale_plan(wide_qscale_plan),
 .q_scale_type(wide_qtype),.alternate_scan(wide_alt),
 .parse_hold(wide_parse_hold),.probe_error(wide_error)
);

mpeg2_h262_p_residual_probe residual_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_expected(p_picture_expected),

 .general_mode(legacy_mode),
 .general_picture_complete(legacy_complete_now),
 .general_motion_x_plan(legacy_motion_x_plan),
 .general_motion_y_plan(legacy_motion_y_plan),
 .general_residual_block_plan(legacy_residual_block_plan),
 .general_residual_block_count(legacy_residual_block_count),
 .general_coeff_index_plan(legacy_coeff_index_plan),
 .general_coeff_value_plan(legacy_coeff_value_plan),
 .general_coeff_last_plan(legacy_coeff_last_plan),
 .general_coeff_count(legacy_coeff_count),
 .general_qscale_plan(legacy_qscale_plan),
 .general_q_scale_type(legacy_qtype),
 .general_alternate_scan(legacy_alt),

 .wide_mode(wide_mode),
 .wide_picture_complete(wide_complete_now),
 .wide_residual_mb_plan(wide_residual_mb_plan),
 .wide_residual_block_index_plan(wide_residual_block_index_plan),
 .wide_residual_block_count(wide_residual_block_count),
 .wide_coeff_index_plan(wide_coeff_index_plan),
 .wide_coeff_value_plan(wide_coeff_value_plan),
 .wide_coeff_last_plan(wide_coeff_last_plan),
 .wide_coeff_count(wide_coeff_count),
 .wide_qscale_plan(wide_qscale_plan),
 .wide_q_scale_type(wide_qtype),
 .wide_alternate_scan(wide_alt),

 .decision_complete(residual_decision),
 .residual_required(residual_required_raw),
 .residual_success(residual_success_raw),
 .mixed_replay_active(mixed_replay_active),
 .first_sample_valid(first_valid_raw),
 .first_sample_value(first_value_raw),
 .residual_sample_valid(residual_valid_raw),
 .residual_sample_index(residual_index_raw),
 .residual_sample_value(residual_value_raw),
 .probe_error(residual_error_raw)
);

mpeg2_h262_p_stream_hold hold_probe
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_active(legacy_hold_owner),
 .p_macroblock_type_seen(mb_seen_for_hold),
 .p_residual_required(residual_required_raw),
 .p_persistence_complete(raster_persistence_complete),
 .stream_hold(old_stream_hold),
 .hold_seen(hold_seen),
 .hold_error(hold_error)
);

wire unused_general=&{
 1'b0,
 legacy_shift_right_map[0],
 legacy_residual_present,
 wide_residual_present,
 wide_motion_index,
 wide_mb_width,
 wide_mb_height,
 wide_mb_count
};

endmodule
