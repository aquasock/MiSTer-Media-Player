//============================================================================
// MiSTer Media Player - consolidated re-arm wrapper for P reference pipeline
//
// Generalized P raster replay is identified by ordered motion metadata at
// sideband index 0x3e.  The historical 128x96 +32/0 motion-plan transport is
// captured here and translated into the same generalized metadata protocol,
// eliminating its duplicate raster execution engine.
//
// The generalized raster DDR request remains registered at this wrapper
// boundary.  The raster engine sees a synthetic busy handshake that completes
// only when the registered external request is accepted; read data is delayed
// one cycle so a zero-latency response cannot race the engine wait-response
// transition.
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

// ---------------------------------------------------------------------------
// Generalized sideband selection.
// ---------------------------------------------------------------------------
wire general_detect_now=p_residual_sample_valid&&(p_residual_sample_index==6'h3e)&&
 (forward_f_code_horizontal==4'd3)&&(forward_f_code_vertical==4'd3)&&
 (horizontal_size==14'd128)&&(vertical_size==14'd96)&&!p_implicit_reconstruct_request;
reg general_mixed_mode;
wire mixed_active,mixed_persisted_seen,mixed_error,mixed_half;
always @(posedge clk)begin
 if(reset)general_mixed_mode<=0;
 else if(general_detect_now)general_mixed_mode<=1;
 else if(mixed_persisted_seen)general_mixed_mode<=0;
end

// ---------------------------------------------------------------------------
// Historical motion-plan compatibility adapter.
//
// The old transport supplied 48 ordered sideband bits at indexes 0..47, then
// published representative vector (+32,0).  Convert those bits to 48 ordinary
// generalized motion metadata words: bit 0 -> (0,0), bit 1 -> (+32,0), followed
// by the normal A2FF metadata terminator.  The generalized raster engine then
// performs the exact same 8x6 prediction/store work used by the v0.4.0 path.
// ---------------------------------------------------------------------------
wire plan_capture_window=
 !p_forward_vector_valid&&!p_implicit_reconstruct_request&&
 (forward_f_code_horizontal==4'd3)&&(forward_f_code_vertical==4'd3)&&
 (horizontal_size==14'd128)&&(vertical_size==14'd96)&&!general_mixed_mode;
wire plan_first_now=plan_capture_window&&p_residual_sample_valid&&
 (p_residual_sample_index==6'd0)&&(p_residual_sample_value[15:1]==15'd0);

reg[47:0] plan_shift_right_map;
reg[5:0] plan_capture_count,plan_emit_count;
reg plan_capture_active,plan_ready,plan_started,plan_replay_active,plan_replay_seen,plan_error;

wire plan_request_now=plan_ready&&p_forward_vector_valid&&
 (p_forward_vector_x==13'sd32)&&(p_forward_vector_y==13'sd0)&&
 (forward_f_code_horizontal==4'd3)&&(forward_f_code_vertical==4'd3)&&
 (horizontal_size==14'd128)&&(vertical_size==14'd96)&&!p_implicit_reconstruct_request;

always @(posedge clk)begin
 if(reset)begin
  plan_shift_right_map<=0;plan_capture_count<=0;plan_emit_count<=0;
  plan_capture_active<=0;plan_ready<=0;plan_started<=0;plan_replay_active<=0;plan_replay_seen<=0;plan_error<=0;
 end else begin
  if(plan_first_now&&!plan_capture_active&&!plan_ready&&!plan_started)begin
   plan_shift_right_map<=0;plan_shift_right_map[0]<=p_residual_sample_value[0];
   plan_capture_count<=6'd1;plan_capture_active<=1;plan_replay_seen<=0;plan_error<=0;
  end else if(plan_capture_active&&p_residual_sample_valid)begin
   if((p_residual_sample_index!=plan_capture_count)||(p_residual_sample_index>=6'd48)||
      (p_residual_sample_value[15:1]!=15'd0))plan_error<=1;
   else begin
    plan_shift_right_map[p_residual_sample_index]<=p_residual_sample_value[0];
    if(p_residual_sample_index==6'd47)begin plan_capture_active<=0;plan_ready<=1;end
    else plan_capture_count<=plan_capture_count+1'b1;
   end
  end

  if(plan_request_now&&!plan_started)begin
   plan_started<=1;plan_replay_active<=1;plan_emit_count<=0;
  end else if(plan_replay_active)begin
   if(plan_emit_count==6'd0)plan_replay_seen<=1;
   if(plan_emit_count==6'd48)plan_replay_active<=0;
   else plan_emit_count<=plan_emit_count+1'b1;
  end

  // Retire adapter state only after the translated raster has actually
  // persisted.  plan_replay_active protects against a stale persisted_seen
  // from the preceding generalized P picture until the first synthesized
  // metadata word re-arms the raster engine.
  if(plan_started&&plan_replay_seen&&!plan_replay_active&&!mixed_active&&mixed_persisted_seen)begin
   plan_capture_count<=0;plan_emit_count<=0;plan_capture_active<=0;
   plan_ready<=0;plan_started<=0;plan_replay_seen<=0;plan_shift_right_map<=0;
  end
 end
end

wire[5:0] plan_map_index=(plan_emit_count<6'd48)?plan_emit_count:6'd0;
wire signed[7:0] plan_emit_mvx=plan_shift_right_map[plan_map_index]?8'sd32:8'sd0;
wire plan_adapter_valid=plan_replay_active;
wire[5:0] plan_adapter_index=(plan_emit_count<6'd48)?6'h3e:6'h3f;
wire signed[15:0] plan_adapter_value=(plan_emit_count<6'd48)?
 {plan_emit_mvx,8'sd0}:16'shA2FF;

wire plan_select=plan_first_now||plan_capture_active||plan_ready||plan_started||plan_replay_active;
wire general_input_select=general_mixed_mode||general_detect_now;
wire mixed_select=general_input_select||plan_select||mixed_active;
wire mix_residual_valid=plan_adapter_valid?1'b1:(p_residual_sample_valid&&general_input_select);
wire[5:0] mix_residual_index=plan_adapter_valid?plan_adapter_index:p_residual_sample_index;
wire signed[15:0] mix_residual_value=plan_adapter_valid?plan_adapter_value:p_residual_sample_value;

// ---------------------------------------------------------------------------
// Legacy client shell.  It now contains only explicit-reference,
// implicit-residual and one shared zero-motion raster-copy engine.
// ---------------------------------------------------------------------------
wire base_persisted_seen,base_probe_error;reg p_forward_vector_valid_d;
wire base_rearm_now=base_persisted_seen&&p_forward_vector_valid_d&&!p_forward_vector_valid;
wire base_reset=reset||base_rearm_now||mixed_select;
always @(posedge clk)begin
 if(reset)p_forward_vector_valid_d<=0;
 else p_forward_vector_valid_d<=p_forward_vector_valid&&!mixed_select;
end
wire[7:0] base_bc;wire[28:0] base_addr;wire base_rd,base_store_sel;wire[7:0] base_store_val;wire[11:0] base_store_x,base_store_y;wire base_store_valid,base_store_start,base_store_complete;
wire base_read;wire[7:0] base_sample;wire base_nonzero,base_half,base_recon;wire[7:0] base_recon_val,base_persist_val;
wire base_vector_valid=p_forward_vector_valid&&!mixed_select;
wire base_residual_valid=p_residual_sample_valid&&!mixed_select;

mpeg2_h262_reference_read_probe_base base_probe(
 .reset(base_reset),.p_forward_vector_valid(base_vector_valid),.p_residual_sample_valid(base_residual_valid),
 .ddram_burstcnt(base_bc),.ddram_addr(base_addr),.ddram_rd(base_rd),.p_store_select(base_store_sel),.p_store_pixel_value(base_store_val),
 .p_store_pixel_x(base_store_x),.p_store_pixel_y(base_store_y),.p_store_pixel_valid(base_store_valid),.p_store_block_start(base_store_start),.p_store_block_complete(base_store_complete),
 .read_seen(base_read),.sample_value(base_sample),.sample_nonzero(base_nonzero),.half_sample_seen(base_half),.reconstructed_seen(base_recon),
 .reconstructed_value(base_recon_val),.persisted_seen(base_persisted_seen),.persisted_value(base_persist_val),.probe_error(base_probe_error),.*);

// ---------------------------------------------------------------------------
// Registered generalized-raster DDR request adapter.
// ---------------------------------------------------------------------------
wire[7:0] mix_bc_raw;wire[28:0] mix_addr_raw;wire mix_rd_raw;
reg mix_req_active,mix_response_pending;reg[7:0] mix_bc_reg;reg[28:0] mix_addr_reg;
reg[63:0] mix_dout_reg;reg mix_dout_ready_reg;
wire mix_engine_busy=!(mix_req_active&&!ddram_busy);

always @(posedge clk)begin
 if(reset)begin
  mix_req_active<=0;mix_response_pending<=0;mix_bc_reg<=0;mix_addr_reg<=0;mix_dout_reg<=0;mix_dout_ready_reg<=0;
 end else begin
  mix_dout_ready_reg<=0;
  if(!mixed_select)begin
   mix_req_active<=0;mix_response_pending<=0;
  end else begin
   if(!mix_req_active&&mix_rd_raw)begin
    mix_req_active<=1;mix_bc_reg<=mix_bc_raw;mix_addr_reg<=mix_addr_raw;
   end else if(mix_req_active&&!ddram_busy)begin
    mix_req_active<=0;mix_response_pending<=1;
   end
   if(ddram_dout_ready&&(mix_response_pending||(mix_req_active&&!ddram_busy)))begin
    mix_dout_reg<=ddram_dout;mix_dout_ready_reg<=1;mix_response_pending<=0;
   end
  end
 end
end

wire mix_store_sel;wire[7:0] mix_store_val;wire[11:0] mix_store_x,mix_store_y;wire mix_store_valid,mix_store_start,mix_store_complete;
wire mix_read;wire[7:0] mix_sample;wire mix_nonzero,mix_recon;wire[7:0] mix_recon_val,mix_persist_val;
mpeg2_h262_p_motion_residual_raster_engine mixed_probe(
 .clk(clk),.reset(reset),.capture_enable(mixed_select),.request(mixed_select),.shift_right_map(48'd0),
 .residual_valid(mix_residual_valid),.residual_index(mix_residual_index),.residual_value(mix_residual_value),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),.destination_bank(destination_frame_bank),.store_block_stored(p_store_block_stored),
 .ddram_busy(mix_engine_busy),.ddram_dout(mix_dout_reg),.ddram_dout_ready(mix_dout_ready_reg),.ddram_burstcnt(mix_bc_raw),.ddram_addr(mix_addr_raw),.ddram_rd(mix_rd_raw),
 .store_select(mix_store_sel),.store_pixel_value(mix_store_val),.store_pixel_x(mix_store_x),.store_pixel_y(mix_store_y),.store_pixel_valid(mix_store_valid),
 .store_block_start(mix_store_start),.store_block_complete(mix_store_complete),.active(mixed_active),.read_seen(mix_read),.sample_value(mix_sample),.sample_nonzero(mix_nonzero),
 .half_sample_seen(mixed_half),.reconstructed_seen(mix_recon),.reconstructed_value(mix_recon_val),.persisted_seen(mixed_persisted_seen),.persisted_value(mix_persist_val),.error(mixed_error));

assign ddram_burstcnt=mixed_select?(mix_req_active?mix_bc_reg:8'd0):base_bc;
assign ddram_addr=mixed_select?(mix_req_active?mix_addr_reg:29'd0):base_addr;
assign ddram_rd=mixed_select?mix_req_active:base_rd;
assign p_store_select=mixed_select?mix_store_sel:base_store_sel;
assign p_store_pixel_value=mixed_select?mix_store_val:base_store_val;
assign p_store_pixel_x=mixed_select?mix_store_x:base_store_x;
assign p_store_pixel_y=mixed_select?mix_store_y:base_store_y;
assign p_store_pixel_valid=mixed_select?mix_store_valid:base_store_valid;
assign p_store_block_start=mixed_select?mix_store_start:base_store_start;
assign p_store_block_complete=mixed_select?mix_store_complete:base_store_complete;
wire mixed_seen_enable=!plan_select||plan_replay_seen;
assign read_seen=mixed_select?(mixed_seen_enable&&mix_read):base_read;
assign sample_value=mixed_select?mix_sample:base_sample;
assign sample_nonzero=mixed_select?(mixed_seen_enable&&mix_nonzero):base_nonzero;
assign half_sample_seen=mixed_select?(mixed_seen_enable&&mixed_half):base_half;
assign reconstructed_seen=mixed_select?(mixed_seen_enable&&mix_recon):base_recon;
assign reconstructed_value=mixed_select?mix_recon_val:base_recon_val;
assign persisted_seen=mixed_select?(mixed_seen_enable&&mixed_persisted_seen):base_persisted_seen;
assign persisted_value=mixed_select?mix_persist_val:base_persist_val;
assign probe_error=plan_error||mixed_error||(!mixed_select&&base_probe_error);
endmodule
