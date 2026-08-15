//============================================================================
// MiSTer Media Player - re-arm wrapper for accepted P reference pipeline
//
// The accepted motion-plan base remains intact.  Residual-bearing generalized
// raster pictures are identified when the verified (+32,0), f_code=(3,3)
// representative vector coincides with residual-sideband replay.  That replay
// now carries the decoded 48-bit motion map plus sparse residual block metadata,
// so the mixed raster no longer uses a picture-wide hard-coded execution map.
//============================================================================
`include "rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_plan.sv"
module mpeg2_h262_reference_read_probe
(
 input wire clk,input wire reset,input wire[13:0] horizontal_size,input wire[13:0] vertical_size,
 input wire p_vector_proof_seen,input wire p_forward_vector_valid,input wire signed[12:0] p_forward_vector_x,input wire signed[12:0] p_forward_vector_y,
 input wire[3:0] forward_f_code_horizontal,input wire[3:0] forward_f_code_vertical,input wire p_implicit_reconstruct_request,
 input wire p_residual_sample_valid,input wire[5:0] p_residual_sample_index,input wire signed[15:0] p_residual_sample_value,
 input wire reference_frame_valid,input wire reference_frame_bank,input wire destination_frame_bank,input wire p_store_block_stored,
 input wire ddram_busy,input wire[63:0] ddram_dout,input wire ddram_dout_ready,
 output wire[7:0] ddram_burstcnt,output wire[28:0] ddram_addr,output wire ddram_rd,
 output wire p_store_select,output wire[7:0] p_store_pixel_value,output wire[11:0] p_store_pixel_x,output wire[11:0] p_store_pixel_y,
 output wire p_store_pixel_valid,output wire p_store_block_start,output wire p_store_block_complete,
 output wire read_seen,output wire[7:0] sample_value,output wire sample_nonzero,output wire half_sample_seen,
 output wire reconstructed_seen,output wire[7:0] reconstructed_value,output wire persisted_seen,output wire[7:0] persisted_value,output wire probe_error
);
wire mixed_detect_now=p_residual_sample_valid&&p_forward_vector_valid&&(p_forward_vector_x==13'sd32)&&(p_forward_vector_y==13'sd0)&&
 (forward_f_code_horizontal==4'd3)&&(forward_f_code_vertical==4'd3)&&(horizontal_size==14'd128)&&(vertical_size==14'd96)&&!p_implicit_reconstruct_request;
reg mixed_mode;wire mixed_active,mixed_persisted_seen,mixed_error;wire mixed_select=mixed_mode||mixed_detect_now||mixed_active;
always @(posedge clk)begin if(reset)mixed_mode<=0;else if(mixed_persisted_seen)mixed_mode<=0;else if(mixed_detect_now)mixed_mode<=1;end
wire base_persisted_seen,base_probe_error;reg p_forward_vector_valid_d;
wire plan_rearm_now=base_persisted_seen&&p_forward_vector_valid_d&&!p_forward_vector_valid;
wire base_reset=reset||plan_rearm_now||mixed_select;
always @(posedge clk)begin if(reset)p_forward_vector_valid_d<=0;else p_forward_vector_valid_d<=p_forward_vector_valid&&!mixed_select;end
wire[7:0] base_bc;wire[28:0] base_addr;wire base_rd,base_store_sel;wire[7:0] base_store_val;wire[11:0] base_store_x,base_store_y;wire base_store_valid,base_store_start,base_store_complete;
wire base_read;wire[7:0] base_sample;wire base_nonzero,base_half,base_recon;wire[7:0] base_recon_val,base_persist_val;
wire base_vector_valid=p_forward_vector_valid&&!mixed_select;wire base_residual_valid=p_residual_sample_valid&&!mixed_select;
mpeg2_h262_reference_read_probe_base base_probe(
 .reset(base_reset),.p_forward_vector_valid(base_vector_valid),.p_residual_sample_valid(base_residual_valid),
 .ddram_burstcnt(base_bc),.ddram_addr(base_addr),.ddram_rd(base_rd),.p_store_select(base_store_sel),.p_store_pixel_value(base_store_val),
 .p_store_pixel_x(base_store_x),.p_store_pixel_y(base_store_y),.p_store_pixel_valid(base_store_valid),.p_store_block_start(base_store_start),.p_store_block_complete(base_store_complete),
 .read_seen(base_read),.sample_value(base_sample),.sample_nonzero(base_nonzero),.half_sample_seen(base_half),.reconstructed_seen(base_recon),
 .reconstructed_value(base_recon_val),.persisted_seen(base_persisted_seen),.persisted_value(base_persist_val),.probe_error(base_probe_error),.*);
wire[7:0] mix_bc;wire[28:0] mix_addr;wire mix_rd,mix_store_sel;wire[7:0] mix_store_val;wire[11:0] mix_store_x,mix_store_y;wire mix_store_valid,mix_store_start,mix_store_complete;
wire mix_read;wire[7:0] mix_sample;wire mix_nonzero,mix_recon;wire[7:0] mix_recon_val,mix_persist_val;
mpeg2_h262_p_motion_residual_raster_engine mixed_probe(
 .clk(clk),.reset(reset),.capture_enable(mixed_select),.request(mixed_select),.shift_right_map(48'd0),
 .residual_valid(p_residual_sample_valid&&mixed_select),.residual_index(p_residual_sample_index),.residual_value(p_residual_sample_value),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),.destination_bank(destination_frame_bank),.store_block_stored(p_store_block_stored),
 .ddram_busy(ddram_busy),.ddram_dout(ddram_dout),.ddram_dout_ready(ddram_dout_ready&&mixed_select),.ddram_burstcnt(mix_bc),.ddram_addr(mix_addr),.ddram_rd(mix_rd),
 .store_select(mix_store_sel),.store_pixel_value(mix_store_val),.store_pixel_x(mix_store_x),.store_pixel_y(mix_store_y),.store_pixel_valid(mix_store_valid),
 .store_block_start(mix_store_start),.store_block_complete(mix_store_complete),.active(mixed_active),.read_seen(mix_read),.sample_value(mix_sample),.sample_nonzero(mix_nonzero),
 .reconstructed_seen(mix_recon),.reconstructed_value(mix_recon_val),.persisted_seen(mixed_persisted_seen),.persisted_value(mix_persist_val),.error(mixed_error));
assign ddram_burstcnt=mixed_select?mix_bc:base_bc;assign ddram_addr=mixed_select?mix_addr:base_addr;assign ddram_rd=mixed_select?mix_rd:base_rd;
assign p_store_select=mixed_select?mix_store_sel:base_store_sel;assign p_store_pixel_value=mixed_select?mix_store_val:base_store_val;assign p_store_pixel_x=mixed_select?mix_store_x:base_store_x;assign p_store_pixel_y=mixed_select?mix_store_y:base_store_y;assign p_store_pixel_valid=mixed_select?mix_store_valid:base_store_valid;assign p_store_block_start=mixed_select?mix_store_start:base_store_start;assign p_store_block_complete=mixed_select?mix_store_complete:base_store_complete;
assign read_seen=mixed_select?mix_read:base_read;assign sample_value=mixed_select?mix_sample:base_sample;assign sample_nonzero=mixed_select?mix_nonzero:base_nonzero;assign half_sample_seen=mixed_select?1'b0:base_half;assign reconstructed_seen=mixed_select?mix_recon:base_recon;assign reconstructed_value=mixed_select?mix_recon_val:base_recon_val;assign persisted_seen=mixed_select?mixed_persisted_seen:base_persisted_seen;assign persisted_value=mixed_select?mix_persist_val:base_persist_val;assign probe_error=mixed_error||(!mixed_select&&base_probe_error);
endmodule
