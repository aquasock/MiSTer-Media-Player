//============================================================================
// MiSTer Media Player - reference publication shell with mixed I/P/B support
//
// The accepted I/P publication path remains unchanged. B reconstruction is a
// non-reference event: neither retained I/P bank is promoted or overwritten.
// Phase 1V mixed-GOP work re-arms repeated B transactions and holds the byte
// stream after B sideband completion until scratch persistence is complete, so
// a following reference picture cannot outrun the shared P/B execution client.
//============================================================================
module mpeg2_h262_two_picture_probe
(
    input wire clk,input wire reset,input wire[7:0] stream_data,input wire stream_valid,output wire stream_ready,
    input wire phase1_supported,input wire[13:0] vertical_size,input wire[1:0] intra_dc_precision,input wire intra_vlc_format,input wire frame_pred_frame_dct,
    input wire pipeline_block_done,input wire recon_block_complete,input wire p_persistence_complete,
    input wire p_row_persistence_complete,
    output wire slice_header_seen,output wire macroblock_address_seen,output wire first_i_macroblock_seen,
    output wire first_luma_dc_seen,output wire first_luma_block_complete,output wire first_picture_420_parsed,
    output wire second_picture_420_parsed,output wire picture_420_complete,output wire[1:0] active_frame_bank,
    output wire[1:0] completed_frame_bank,output wire[7:0] picture_count,output wire reference_frame_valid,
    output wire[1:0] reference_frame_bank,output wire[1:0] previous_reference_frame_bank,
    output wire[7:0] reference_promotion_count,
    output wire dct_type,
    output wire p_macroblock_type_seen,output wire p_forward_vector_valid,output wire signed[12:0] p_forward_vector_x,
    output wire signed[12:0] p_forward_vector_y,output wire p_residual_required,output wire p_residual_success,
    output wire p_first_residual_sample_valid,output wire signed[15:0] p_first_residual_sample_value,
    output wire p_residual_sample_valid,output wire[5:0] p_residual_sample_index,output wire signed[15:0] p_residual_sample_value,
    output wire b_motion_transport,
    output wire probe_error,
    // kate - Commit 179 observability only.  Names which of the five terms in
    // the probe_error OR below fired.  probe_error itself is unchanged.
    output wire[3:0] probe_error_source,
    // kate - Commit 180 observability only.  Deeper split of source 2
    // (p_error_raw) plus the progress_error conjunct detail.
    output wire[3:0] p_probe_error_source,
    output wire[3:0] p_progress_detail,
    output wire[2:0] publication_error_detail,
    output wire[4:0] p_wide_probe_error_detail,
    output wire b_user_success,output wire[4:0] quantiser_scale_code,output wire[11:0] macroblock_address_increment,
    output wire macroblock_quant,output wire[4:0] macroblock_quantiser_scale_code,output wire[7:0] slice_vertical_position,
    output wire[2:0] slice_vertical_position_extension,output wire[3:0] first_luma_dc_size,
    output wire signed[12:0] first_luma_dc_differential,output wire[10:0] first_luma_dc_coefficient,
    output wire[6:0] first_luma_ac_nonzero_count,output wire[5:0] first_luma_last_coeff_index,
    output wire signed[11:0] first_luma_last_ac_level,output wire slice_start,output wire luma_macroblock_start,
    output wire[2:0] qfs_block_index,output wire qfs_block_start,output wire qfs_write_en,
    output wire[5:0] qfs_write_index,output wire signed[12:0] qfs_write_value,output wire qfs_block_end
);

wire parser_ready,p_picture_expected,bookkeeper_error,p_hold_raw,p_error_raw;
wire p_unsupported_raw;
wire base_second_picture_420_parsed,base_picture_420_complete,base_active_frame_bank,base_completed_frame_bank;
wire[7:0] base_picture_count;wire base_reference_frame_valid,base_reference_frame_bank;wire[7:0] base_reference_promotion_count;

mpeg2_h262_picture_bookkeeper bookkeeper(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.parser_stream_ready(parser_ready),
 .phase1_supported(phase1_supported),.vertical_size(vertical_size),.intra_dc_precision(intra_dc_precision),.intra_vlc_format(intra_vlc_format),.frame_pred_frame_dct(frame_pred_frame_dct),.dct_type(dct_type),
 .pipeline_block_done(pipeline_block_done),.recon_block_complete(recon_block_complete),.p_picture_expected(p_picture_expected),
 .slice_header_seen(slice_header_seen),.macroblock_address_seen(macroblock_address_seen),.first_i_macroblock_seen(first_i_macroblock_seen),
 .first_luma_dc_seen(first_luma_dc_seen),.first_luma_block_complete(first_luma_block_complete),.first_picture_420_parsed(first_picture_420_parsed),
 .second_picture_420_parsed(base_second_picture_420_parsed),.picture_420_complete(base_picture_420_complete),.active_frame_bank(base_active_frame_bank),
 .completed_frame_bank(base_completed_frame_bank),.picture_count(base_picture_count),.reference_frame_valid(base_reference_frame_valid),
 .reference_frame_bank(base_reference_frame_bank),.reference_promotion_count(base_reference_promotion_count),.probe_error(bookkeeper_error),
 .quantiser_scale_code(quantiser_scale_code),.macroblock_address_increment(macroblock_address_increment),.macroblock_quant(macroblock_quant),
 .macroblock_quantiser_scale_code(macroblock_quantiser_scale_code),.slice_vertical_position(slice_vertical_position),
 .slice_vertical_position_extension(slice_vertical_position_extension),.first_luma_dc_size(first_luma_dc_size),
 .first_luma_dc_differential(first_luma_dc_differential),.first_luma_dc_coefficient(first_luma_dc_coefficient),
 .first_luma_ac_nonzero_count(first_luma_ac_nonzero_count),.first_luma_last_coeff_index(first_luma_last_coeff_index),
 .first_luma_last_ac_level(first_luma_last_ac_level),.slice_start(slice_start),.luma_macroblock_start(luma_macroblock_start),
 .qfs_block_index(qfs_block_index),.qfs_block_start(qfs_block_start),.qfs_write_en(qfs_write_en),
 .qfs_write_index(qfs_write_index),.qfs_write_value(qfs_write_value),.qfs_block_end(qfs_block_end));

// Entry 285: Entry 227 lets a B header be accepted before its future
// reference publishes, binding the publication into the open transaction
// later.  Checking publication at header time therefore rejects a legal
// ordering.  Track the wait instead and enforce the real invariant, which is
// that a B must not COMPLETE against an unpublished reference.
reg b_reference_publication_pending;reg p_persistence_d;reg[7:0] p_publication_count;reg p_reconstruction_inflight;reg p_overlap_pending,p_overlap_hold;reg publication_error;reg[2:0] publication_error_detail_reg;reg picture_complete_pulse;
reg[1:0] active_frame_bank_reg,completed_frame_bank_reg;reg[7:0] picture_count_reg;
reg reference_frame_valid_reg;reg[1:0] reference_frame_bank_reg,previous_reference_frame_bank_reg;
reg[7:0] reference_promotion_count_reg;

reg[31:0] picture_window;wire[31:0] picture_window_next={picture_window[23:0],stream_data};
wire picture_start_now=(picture_window_next==32'h00000100);reg picture_header_capture,picture_header_second_byte;
wire extension_start_now=(picture_window_next==32'h000001b5);
reg p_overlap_extension_capture;reg[2:0] p_overlap_extension_count;
// Entry 215: these are transaction proofs, not small diagnostic categories.
// Preserve every P/B header and persistence event through the complete stream;
// saturation at 3/7 made the first B of the second GOP indistinguishable from
// the already-settled first-GOP state.
reg[7:0] p_header_count;reg consecutive_candidate_seen;reg b_picture_observed,b_picture_inflight,b_persistence_verified;
reg[7:0] b_header_count,b_persist_count;
wire b_header_now=stream_valid&&picture_header_capture&&picture_header_second_byte&&(stream_data[5:3]==3'b011);
wire persistence_edge=p_persistence_complete&&!p_persistence_d;
wire p_persisted_now=persistence_edge&&!b_picture_inflight;
wire b_persisted_now=persistence_edge&&b_picture_inflight;

wire reference_progress_error=(picture_count_reg>=8'd2)&&(p_publication_count!=0)&&
 (!reference_frame_valid_reg||(reference_promotion_count_reg<picture_count_reg)||
  (reference_frame_bank_reg!=completed_frame_bank_reg)||(reference_frame_bank_reg==active_frame_bank_reg));
assign picture_420_complete=picture_complete_pulse;assign active_frame_bank=active_frame_bank_reg;assign completed_frame_bank=completed_frame_bank_reg;
assign picture_count=picture_count_reg;assign reference_frame_valid=reference_frame_valid_reg;assign reference_frame_bank=reference_frame_bank_reg;
assign previous_reference_frame_bank=previous_reference_frame_bank_reg;
assign reference_promotion_count=reference_promotion_count_reg;
assign publication_error_detail=publication_error_detail_reg;
// Commit 192: the legacy bookkeeper only counts I pictures.  A generalized P
// persistence event also publishes a reference picture through this shell, so
// the exported second-reference prerequisite must follow the combined I/P
// publication count as well as the legacy result.
assign second_picture_420_parsed=base_second_picture_420_parsed||(picture_count_reg>=8'd2);

always @(posedge clk)begin
 if(reset)begin
  b_reference_publication_pending<=0;p_persistence_d<=0;p_publication_count<=0;p_reconstruction_inflight<=0;p_overlap_pending<=0;p_overlap_hold<=0;publication_error<=0;publication_error_detail_reg<=0;picture_complete_pulse<=0;active_frame_bank_reg<=0;completed_frame_bank_reg<=0;
  picture_count_reg<=0;reference_frame_valid_reg<=0;reference_frame_bank_reg<=0;previous_reference_frame_bank_reg<=0;reference_promotion_count_reg<=0;
  picture_window<=0;picture_header_capture<=0;picture_header_second_byte<=0;p_overlap_extension_capture<=0;p_overlap_extension_count<=0;p_header_count<=0;consecutive_candidate_seen<=0;
  b_picture_observed<=0;b_picture_inflight<=0;b_persistence_verified<=0;b_header_count<=0;b_persist_count<=0;
 end else begin
  p_persistence_d<=p_persistence_complete;picture_complete_pulse<=0;
  if(p_persisted_now)begin
   p_reconstruction_inflight<=0;
   p_overlap_pending<=0;
   p_overlap_hold<=0;
  end
  if(p_residual_sample_valid_raw&&
     ((p_residual_sample_index_raw==6'h3e)||
      (p_residual_sample_index_raw==6'h3b)))
   p_reconstruction_inflight<=1;

  if(stream_valid)begin
   picture_window<=picture_window_next;
   if(extension_start_now)begin
    p_overlap_extension_capture<=1;
    p_overlap_extension_count<=0;
   end else if(p_overlap_extension_capture)begin
    if((p_overlap_extension_count==0)&&(stream_data[7:4]!=4'h8))begin
     p_overlap_extension_capture<=0;
     p_overlap_extension_count<=0;
    end else if(p_overlap_extension_count==4)begin
     p_overlap_extension_capture<=0;
     p_overlap_extension_count<=0;
     // The wide parser restores candidate ownership on this same accepted
     // byte.  Waiting here keeps its delayed prior-row replay visible while
     // preventing the following picture's first slice from emitting motion.
     if(p_overlap_pending&&p_reconstruction_inflight&&!p_persisted_now)
      p_overlap_hold<=1;
    end else p_overlap_extension_count<=p_overlap_extension_count+1'b1;
   end
   if(picture_start_now)begin picture_header_capture<=1;picture_header_second_byte<=0;end
   else if(picture_header_capture)begin
    if(!picture_header_second_byte)picture_header_second_byte<=1;
    else begin
     picture_header_capture<=0;picture_header_second_byte<=0;
     if(stream_data[5:3]==3'b010)begin
      // Entry 710: classify the next P header, then wait until its coding
      // extension has restored wide-parser ownership before applying the
      // overlap hold.  Holding at the header itself hides the preceding row's
      // delayed residual terminator and deadlocks persistence.
      // Header/publication counts cannot prove that ownership: the accepted
      // GOP bookkeeping intentionally leaves them offset on some legal coded
      // orders.  The first live P motion record starts ownership and the
      // matching persistence pulse releases it.
      if(p_reconstruction_inflight&&!p_persisted_now)
       p_overlap_pending<=1;
      if(p_header_count!=8'hff)p_header_count<=p_header_count+1'b1;
      if(p_header_count>=1)consecutive_candidate_seen<=1;
     end else if(stream_data[5:3]==3'b011)begin
      b_picture_observed<=1;b_picture_inflight<=1;b_persistence_verified<=0;
      if(b_header_count!=8'hff)b_header_count<=b_header_count+1'b1;
      // In coded order the future reference P precedes each B.  Do not accept
      // a B transaction if an observed P header has not actually persisted.
      if(p_publication_count<p_header_count)
       b_reference_publication_pending<=1;
     end else if((stream_data[5:3]==3'b001)&&consecutive_candidate_seen&&(p_publication_count<2))begin
      publication_error<=1;
      if(!publication_error)publication_error_detail_reg<=3'd2;
     end
    end
   end
  end

  if(base_picture_420_complete&&!b_picture_inflight)begin
   picture_complete_pulse<=1;completed_frame_bank_reg<=active_frame_bank_reg;
   active_frame_bank_reg<=(active_frame_bank_reg==2'd2)?2'd0:(active_frame_bank_reg+1'b1);
   if(picture_count_reg!=8'hff)picture_count_reg<=picture_count_reg+1'b1;
   if(reference_frame_valid_reg&&(active_frame_bank_reg==reference_frame_bank_reg))begin
    publication_error<=1;
    if(!publication_error)publication_error_detail_reg<=3'd3;
   end
   previous_reference_frame_bank_reg<=reference_frame_valid_reg?reference_frame_bank_reg:active_frame_bank_reg;
   reference_frame_valid_reg<=1;reference_frame_bank_reg<=active_frame_bank_reg;
   if(reference_promotion_count_reg!=8'hff)reference_promotion_count_reg<=reference_promotion_count_reg+1'b1;
  end else if(p_persisted_now)begin
   if(!reference_frame_valid_reg)begin
    publication_error<=1;
    if(!publication_error)publication_error_detail_reg<=3'd4;
   end
   else if(active_frame_bank_reg==reference_frame_bank_reg)begin
    publication_error<=1;
    if(!publication_error)publication_error_detail_reg<=3'd5;
   end
   else begin
    if(p_publication_count!=8'hff)p_publication_count<=p_publication_count+1'b1;
    b_reference_publication_pending<=0;
    picture_complete_pulse<=1;completed_frame_bank_reg<=active_frame_bank_reg;
    active_frame_bank_reg<=(active_frame_bank_reg==2'd2)?2'd0:(active_frame_bank_reg+1'b1);
    if(picture_count_reg!=8'hff)picture_count_reg<=picture_count_reg+1'b1;
    previous_reference_frame_bank_reg<=reference_frame_bank_reg;
    reference_frame_valid_reg<=1;reference_frame_bank_reg<=active_frame_bank_reg;
    if(reference_promotion_count_reg!=8'hff)reference_promotion_count_reg<=reference_promotion_count_reg+1'b1;
   end
  end else if(b_persisted_now)begin
   b_persistence_verified<=1;b_picture_inflight<=0;
   // The deferred binding never arrived before this B completed.
   if(b_reference_publication_pending)begin
    publication_error<=1;
    if(!publication_error)publication_error_detail_reg<=3'd1;
   end
   if(b_persist_count!=8'hff)b_persist_count<=b_persist_count+1'b1;
  end

  // Entry 205: a failed B parser/replay transaction must never retain
  // ownership of the compressed-stream path.  b_error is intentionally
  // sticky for the settled diagnostic report; only the live transaction and
  // its persistence prerequisite are aborted here.  Subsequent bytes can
  // therefore drain through ioctl even when this stream is not accepted.
  if(b_picture_inflight&&b_error)begin
   b_picture_inflight<=0;
   b_persistence_verified<=0;
  end
 end
end

wire p_macroblock_type_seen_raw,p_forward_vector_valid_raw;wire signed[12:0] p_forward_vector_x_raw,p_forward_vector_y_raw;
wire p_residual_required_raw,p_residual_success_raw,p_first_residual_sample_valid_raw,p_residual_sample_valid_raw;
wire signed[15:0] p_first_residual_sample_value_raw,p_residual_sample_value_raw;wire[5:0] p_residual_sample_index_raw;
mpeg2_h262_p_diagnostic_controller p_controller(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),
 .p_persistence_complete(p_persistence_complete),.p_row_persistence_complete(p_row_persistence_complete),
 .intra_dc_precision(intra_dc_precision),
 .stream_hold(p_hold_raw),.p_unsupported(p_unsupported_raw),
 .p_macroblock_type_seen(p_macroblock_type_seen_raw),
 .p_forward_vector_valid(p_forward_vector_valid_raw),.p_forward_vector_x(p_forward_vector_x_raw),.p_forward_vector_y(p_forward_vector_y_raw),
 .p_residual_required(p_residual_required_raw),.p_residual_success(p_residual_success_raw),
 .p_first_residual_sample_valid(p_first_residual_sample_valid_raw),.p_first_residual_sample_value(p_first_residual_sample_value_raw),
 .p_residual_sample_valid(p_residual_sample_valid_raw),.p_residual_sample_index(p_residual_sample_index_raw),
 .p_residual_sample_value(p_residual_sample_value_raw),.probe_error(p_error_raw),
 .probe_error_source(p_probe_error_source),.progress_detail(p_progress_detail),
 .wide_probe_error_detail(p_wide_probe_error_detail));

wire b_candidate,b_seen,b_complete_now,b_parse_hold,b_replay_active,b_sideband_valid,b_first_valid,b_error;
wire[5:0] b_sideband_index;wire signed[15:0] b_sideband_value,b_first_value;
wire signed[9:0] b_motion_vector_x,b_motion_vector_y;
mpeg2_h262_b_core_probe b_controller(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.row_retired(p_row_persistence_complete),.b_candidate(b_candidate),.b_seen(b_seen),
 .b_complete_now(b_complete_now),.parse_hold(b_parse_hold),.replay_active(b_replay_active),.sideband_valid(b_sideband_valid),
 .sideband_index(b_sideband_index),.sideband_value(b_sideband_value),
 .motion_vector_x(b_motion_vector_x),.motion_vector_y(b_motion_vector_y),.first_sample_valid(b_first_valid),
 .first_sample_value(b_first_value),.probe_error(b_error));

wire b_all_observed_persisted=(b_header_count!=0)&&(b_persist_count==b_header_count);
wire b_final_success=b_seen&&b_persistence_verified&&b_all_observed_persisted;
wire b_transport=b_replay_active||b_sideband_valid;
assign b_motion_transport=b_transport;
assign p_macroblock_type_seen=b_final_success?1'b1:p_macroblock_type_seen_raw;
assign p_forward_vector_valid=b_transport?1'b1:p_forward_vector_valid_raw;
assign p_forward_vector_x=b_transport?{{3{b_motion_vector_x[9]}},b_motion_vector_x}:p_forward_vector_x_raw;
assign p_forward_vector_y=b_transport?{{3{b_motion_vector_y[9]}},b_motion_vector_y}:p_forward_vector_y_raw;
assign p_residual_required=b_transport?b_first_valid:p_residual_required_raw;
assign p_residual_success=b_transport?1'b1:p_residual_success_raw;
assign p_first_residual_sample_valid=b_transport?b_first_valid:p_first_residual_sample_valid_raw;
assign p_first_residual_sample_value=b_transport?b_first_value:p_first_residual_sample_value_raw;
assign p_residual_sample_valid=b_transport?b_sideband_valid:p_residual_sample_valid_raw;
assign p_residual_sample_index=b_transport?b_sideband_index:p_residual_sample_index_raw;
assign p_residual_sample_value=b_transport?b_sideband_value:p_residual_sample_value_raw;

wire p_hold_effective=p_hold_raw&&!b_picture_inflight&&!b_candidate&&!b_transport;
// The final B slice is delimited by the following start code, so that start
// code may already be consumed when replay completes.  Hold immediately after
// b_seen until scratch persistence finishes; the following picture header body
// then resumes with the shared P/B execution client free.
wire b_persistence_wait=b_picture_inflight&&b_seen&&!b_persistence_verified&&!b_error;
assign stream_ready=(b_picture_inflight?1'b1:parser_ready)&&!p_hold_effective&&!b_parse_hold&&!b_persistence_wait&&!p_overlap_hold;
wire b_accept_error=b_error||publication_error||reference_progress_error;
assign b_user_success=b_final_success&&!b_accept_error;
// Entry 289: p_error_raw is gated by b_picture_observed because a controlled
// pattern observer's subset rejection may still be owned by another observer.
// p_unsupported_raw is not such a rejection: it means no engine claimed the
// picture, so it must reach acceptance ungated or the stream hangs instead of
// reporting.
assign probe_error=(b_picture_observed?1'b0:bookkeeper_error)||
                   (b_picture_observed?1'b0:p_error_raw)||
                   p_unsupported_raw||
                   b_error||publication_error||reference_progress_error;

// kate - Commit 179 observability only.  Priority order matches the OR above.
wire bookkeeper_error_gated=b_picture_observed?1'b0:bookkeeper_error;
wire p_error_gated=b_picture_observed?1'b0:p_error_raw;
assign probe_error_source=
    p_unsupported_raw         ? 4'd10 :
    bookkeeper_error_gated    ? 4'd1 :
    p_error_gated             ? 4'd2 :
    b_error                   ? 4'd3 :
    publication_error         ? 4'd4 :
    reference_progress_error  ? 4'd5 : 4'd0;

wire unused_base_state=&{1'b0,base_active_frame_bank,base_completed_frame_bank,base_picture_count,
 base_reference_frame_valid,base_reference_frame_bank,base_reference_promotion_count,b_complete_now,b_header_now,b_final_success,b_first_value};
endmodule
