//============================================================================
// MiSTer Media Player - reference publication shell with controlled B support
//
// The accepted I/P publication path remains unchanged. Commit 128 adds one
// progressive B-picture core proof. B reconstruction completion is consumed as
// a non-reference event: neither retained I/P bank is promoted or overwritten.
//============================================================================
module mpeg2_h262_two_picture_probe
(
    input wire clk,input wire reset,input wire[7:0] stream_data,input wire stream_valid,output wire stream_ready,
    input wire phase1_supported,input wire[13:0] vertical_size,input wire[1:0] intra_dc_precision,input wire intra_vlc_format,
    input wire pipeline_block_done,input wire recon_block_complete,input wire p_persistence_complete,
    output wire slice_header_seen,output wire macroblock_address_seen,output wire first_i_macroblock_seen,
    output wire first_luma_dc_seen,output wire first_luma_block_complete,output wire first_picture_420_parsed,
    output wire second_picture_420_parsed,output wire picture_420_complete,output wire active_frame_bank,
    output wire completed_frame_bank,output wire[7:0] picture_count,output wire reference_frame_valid,
    output wire reference_frame_bank,output wire[7:0] reference_promotion_count,
    output wire p_macroblock_type_seen,output wire p_forward_vector_valid,output wire signed[12:0] p_forward_vector_x,
    output wire signed[12:0] p_forward_vector_y,output wire p_residual_required,output wire p_residual_success,
    output wire p_first_residual_sample_valid,output wire signed[15:0] p_first_residual_sample_value,
    output wire p_residual_sample_valid,output wire[5:0] p_residual_sample_index,output wire signed[15:0] p_residual_sample_value,
    output wire probe_error,output wire[4:0] quantiser_scale_code,output wire[11:0] macroblock_address_increment,
    output wire macroblock_quant,output wire[4:0] macroblock_quantiser_scale_code,output wire[7:0] slice_vertical_position,
    output wire[2:0] slice_vertical_position_extension,output wire[3:0] first_luma_dc_size,
    output wire signed[12:0] first_luma_dc_differential,output wire[10:0] first_luma_dc_coefficient,
    output wire[6:0] first_luma_ac_nonzero_count,output wire[5:0] first_luma_last_coeff_index,
    output wire signed[11:0] first_luma_last_ac_level,output wire slice_start,output wire luma_macroblock_start,
    output wire[2:0] qfs_block_index,output wire qfs_block_start,output wire qfs_write_en,
    output wire[5:0] qfs_write_index,output wire signed[12:0] qfs_write_value,output wire qfs_block_end
);

wire parser_ready,p_picture_expected,bookkeeper_error,p_hold_raw,p_error_raw;
wire base_picture_420_complete,base_active_frame_bank,base_completed_frame_bank;
wire[7:0] base_picture_count;wire base_reference_frame_valid,base_reference_frame_bank;wire[7:0] base_reference_promotion_count;

mpeg2_h262_picture_bookkeeper bookkeeper(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.parser_stream_ready(parser_ready),
 .phase1_supported(phase1_supported),.vertical_size(vertical_size),.intra_dc_precision(intra_dc_precision),.intra_vlc_format(intra_vlc_format),
 .pipeline_block_done(pipeline_block_done),.recon_block_complete(recon_block_complete),.p_picture_expected(p_picture_expected),
 .slice_header_seen(slice_header_seen),.macroblock_address_seen(macroblock_address_seen),.first_i_macroblock_seen(first_i_macroblock_seen),
 .first_luma_dc_seen(first_luma_dc_seen),.first_luma_block_complete(first_luma_block_complete),.first_picture_420_parsed(first_picture_420_parsed),
 .second_picture_420_parsed(second_picture_420_parsed),.picture_420_complete(base_picture_420_complete),.active_frame_bank(base_active_frame_bank),
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

reg p_persistence_d;reg[1:0] p_publication_count;reg publication_error;reg picture_complete_pulse;
reg active_frame_bank_reg,completed_frame_bank_reg;reg[7:0] picture_count_reg;reg reference_frame_valid_reg,reference_frame_bank_reg;reg[7:0] reference_promotion_count_reg;

reg[31:0] picture_window;wire[31:0] picture_window_next={picture_window[23:0],stream_data};
wire picture_start_now=(picture_window_next==32'h00000100);reg picture_header_capture,picture_header_second_byte;
reg[1:0] p_header_count;reg consecutive_candidate_seen;reg b_picture_observed,b_picture_inflight,b_persistence_verified;
wire b_header_now=stream_valid&&picture_header_capture&&picture_header_second_byte&&(stream_data[5:3]==3'b011);
wire persistence_edge=p_persistence_complete&&!p_persistence_d;
wire p_persisted_now=persistence_edge&&!b_picture_inflight;
wire b_persisted_now=persistence_edge&&b_picture_inflight;

wire reference_progress_error=(picture_count_reg>=8'd2)&&(p_publication_count!=0)&&
 (!reference_frame_valid_reg||(reference_promotion_count_reg<picture_count_reg)||
  (reference_frame_bank_reg!=completed_frame_bank_reg)||(reference_frame_bank_reg==active_frame_bank_reg));
assign picture_420_complete=picture_complete_pulse;assign active_frame_bank=active_frame_bank_reg;assign completed_frame_bank=completed_frame_bank_reg;
assign picture_count=picture_count_reg;assign reference_frame_valid=reference_frame_valid_reg;assign reference_frame_bank=reference_frame_bank_reg;
assign reference_promotion_count=reference_promotion_count_reg;

always @(posedge clk)begin
 if(reset)begin
  p_persistence_d<=0;p_publication_count<=0;publication_error<=0;picture_complete_pulse<=0;active_frame_bank_reg<=0;completed_frame_bank_reg<=0;
  picture_count_reg<=0;reference_frame_valid_reg<=0;reference_frame_bank_reg<=0;reference_promotion_count_reg<=0;
  picture_window<=0;picture_header_capture<=0;picture_header_second_byte<=0;p_header_count<=0;consecutive_candidate_seen<=0;
  b_picture_observed<=0;b_picture_inflight<=0;b_persistence_verified<=0;
 end else begin
  p_persistence_d<=p_persistence_complete;picture_complete_pulse<=0;

  if(stream_valid)begin
   picture_window<=picture_window_next;
   if(picture_start_now)begin picture_header_capture<=1;picture_header_second_byte<=0;end
   else if(picture_header_capture)begin
    if(!picture_header_second_byte)picture_header_second_byte<=1;
    else begin
     picture_header_capture<=0;picture_header_second_byte<=0;
     if(stream_data[5:3]==3'b010)begin
      if(p_header_count!=3)p_header_count<=p_header_count+1'b1;
      if(p_header_count>=1)consecutive_candidate_seen<=1;
     end else if(stream_data[5:3]==3'b011)begin
      b_picture_observed<=1;b_picture_inflight<=1;b_persistence_verified<=0;
     end else if((stream_data[5:3]==3'b001)&&consecutive_candidate_seen&&(p_publication_count<2))publication_error<=1;
    end
   end
  end

  if(base_picture_420_complete&&!b_picture_inflight)begin
   picture_complete_pulse<=1;completed_frame_bank_reg<=active_frame_bank_reg;active_frame_bank_reg<=~active_frame_bank_reg;
   if(picture_count_reg!=8'hff)picture_count_reg<=picture_count_reg+1'b1;
   if(reference_frame_valid_reg&&(active_frame_bank_reg==reference_frame_bank_reg))publication_error<=1;
   reference_frame_valid_reg<=1;reference_frame_bank_reg<=active_frame_bank_reg;
   if(reference_promotion_count_reg!=8'hff)reference_promotion_count_reg<=reference_promotion_count_reg+1'b1;
  end else if(p_persisted_now)begin
   if(!reference_frame_valid_reg||(active_frame_bank_reg==reference_frame_bank_reg))publication_error<=1;
   else begin
    if(p_publication_count!=3)p_publication_count<=p_publication_count+1'b1;
    picture_complete_pulse<=1;completed_frame_bank_reg<=active_frame_bank_reg;active_frame_bank_reg<=~active_frame_bank_reg;
    if(picture_count_reg!=8'hff)picture_count_reg<=picture_count_reg+1'b1;
    reference_frame_valid_reg<=1;reference_frame_bank_reg<=active_frame_bank_reg;
    if(reference_promotion_count_reg!=8'hff)reference_promotion_count_reg<=reference_promotion_count_reg+1'b1;
   end
  end else if(b_persisted_now)begin
   b_persistence_verified<=1;b_picture_inflight<=0;
  end
 end
end

wire p_macroblock_type_seen_raw,p_forward_vector_valid_raw;wire signed[12:0] p_forward_vector_x_raw,p_forward_vector_y_raw;
wire p_residual_required_raw,p_residual_success_raw,p_first_residual_sample_valid_raw,p_residual_sample_valid_raw;
wire signed[15:0] p_first_residual_sample_value_raw,p_residual_sample_value_raw;wire[5:0] p_residual_sample_index_raw;
mpeg2_h262_p_diagnostic_controller p_controller(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),
 .p_persistence_complete(p_persistence_complete),.stream_hold(p_hold_raw),.p_macroblock_type_seen(p_macroblock_type_seen_raw),
 .p_forward_vector_valid(p_forward_vector_valid_raw),.p_forward_vector_x(p_forward_vector_x_raw),.p_forward_vector_y(p_forward_vector_y_raw),
 .p_residual_required(p_residual_required_raw),.p_residual_success(p_residual_success_raw),
 .p_first_residual_sample_valid(p_first_residual_sample_valid_raw),.p_first_residual_sample_value(p_first_residual_sample_value_raw),
 .p_residual_sample_valid(p_residual_sample_valid_raw),.p_residual_sample_index(p_residual_sample_index_raw),
 .p_residual_sample_value(p_residual_sample_value_raw),.probe_error(p_error_raw));

wire b_candidate,b_seen,b_complete_now,b_parse_hold,b_replay_active,b_sideband_valid,b_first_valid,b_error;
wire[5:0] b_sideband_index;wire signed[15:0] b_sideband_value,b_first_value;
mpeg2_h262_b_core_probe b_controller(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.b_candidate(b_candidate),.b_seen(b_seen),
 .b_complete_now(b_complete_now),.parse_hold(b_parse_hold),.replay_active(b_replay_active),.sideband_valid(b_sideband_valid),
 .sideband_index(b_sideband_index),.sideband_value(b_sideband_value),.first_sample_valid(b_first_valid),
 .first_sample_value(b_first_value),.probe_error(b_error));

wire b_final_success=b_seen&&b_persistence_verified;
wire b_transport=b_replay_active||b_sideband_valid;
assign p_macroblock_type_seen=b_final_success?1'b1:p_macroblock_type_seen_raw;
assign p_forward_vector_valid=b_transport?1'b1:p_forward_vector_valid_raw;
assign p_forward_vector_x=b_transport?13'sd2047:p_forward_vector_x_raw;
assign p_forward_vector_y=b_transport?-13'sd2048:p_forward_vector_y_raw;
assign p_residual_required=b_transport?b_first_valid:p_residual_required_raw;
assign p_residual_success=b_transport?1'b1:p_residual_success_raw;
assign p_first_residual_sample_valid=b_transport?b_first_valid:p_first_residual_sample_valid_raw;
assign p_first_residual_sample_value=b_transport?b_first_value:p_first_residual_sample_value_raw;
assign p_residual_sample_valid=b_transport?b_sideband_valid:p_residual_sample_valid_raw;
assign p_residual_sample_index=b_transport?b_sideband_index:p_residual_sample_index_raw;
assign p_residual_sample_value=b_transport?b_sideband_value:p_residual_sample_value_raw;

wire p_hold_effective=p_hold_raw&&!b_picture_inflight&&!b_candidate&&!b_transport;
assign stream_ready=(b_picture_inflight?1'b1:parser_ready)&&!p_hold_effective&&!b_parse_hold;
assign probe_error=(b_picture_observed?1'b0:bookkeeper_error)||(b_picture_observed?1'b0:p_error_raw)||b_error||publication_error||reference_progress_error;

wire unused_base_state=&{1'b0,base_active_frame_bank,base_completed_frame_bank,base_picture_count,
 base_reference_frame_valid,base_reference_frame_bank,base_reference_promotion_count,b_complete_now,b_candidate,b_header_now};
endmodule
