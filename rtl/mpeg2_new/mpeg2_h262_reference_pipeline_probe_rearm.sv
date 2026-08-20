//============================================================================
// MiSTer Media Player - consolidated re-arm wrapper for P/B reference pipeline
//
// Generalized P raster replay is identified by ordered motion metadata at
// sideband index 0x3e; intra macroblocks use index 0x3b. B uses an internal
// sentinel vector plus B direction metadata.
// P and B share the registered DDR request adapter and response-owner gating.
// Phase 1V mixed-GOP work adds a one-cycle B-engine re-arm after each fully
// persisted B picture so a later B transaction can reuse the same raster engine.
//============================================================================
`include "rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_plan.sv"
module mpeg2_h262_reference_read_probe
(
 input wire clk,input wire reset,input wire[13:0] horizontal_size,input wire[13:0] vertical_size,
 input wire p_vector_proof_seen,input wire p_forward_vector_valid,input wire signed[12:0] p_forward_vector_x,input wire signed[12:0] p_forward_vector_y,
 input wire[3:0] forward_f_code_horizontal,input wire[3:0] forward_f_code_vertical,input wire p_implicit_reconstruct_request,
 input wire p_residual_sample_valid,input wire[5:0] p_residual_sample_index,input wire signed[15:0] p_residual_sample_value,
 input wire reference_frame_valid,input wire[1:0] reference_frame_bank,input wire[1:0] previous_reference_frame_bank,
 input wire[1:0] destination_frame_bank,input wire b_scratch_frame_bank,input wire p_store_block_stored,
 input wire ddram_busy,input wire[63:0] ddram_dout,input wire ddram_dout_ready,
 output wire[7:0] ddram_burstcnt,output wire[28:0] ddram_addr,output wire ddram_rd,
 output wire p_store_select,output wire[7:0] p_store_pixel_value,output wire[11:0] p_store_pixel_x,output wire[11:0] p_store_pixel_y,
 output wire p_store_pixel_valid,output wire p_store_block_start,output wire p_store_block_complete,
 output wire read_seen,output wire[7:0] sample_value,output wire sample_nonzero,output wire half_sample_seen,
 output wire reconstructed_seen,output wire[7:0] reconstructed_value,output wire persisted_seen,output wire row_persisted,output wire[7:0] persisted_value,
 output wire[3:0] p_progress_stage,output wire probe_error,
 output wire[2:0] probe_error_source,output wire[4:0] probe_error_detail
);

// kate - Commit 169: both generalized P and controlled B sidebands are valid
// throughout the established progressive 4:2:0 frame envelope. The historical
// aligned-plan P adapter remains exact-128x96-only.
wire general_geometry_supported=
 (horizontal_size!=14'd0)&&(vertical_size!=14'd0)&&
 (horizontal_size<=14'd720)&&(vertical_size<=14'd480);
wire general_p_f_code_supported=
 (forward_f_code_horizontal>=4'd1)&&(forward_f_code_horizontal<=4'd4)&&
 (forward_f_code_vertical>=4'd1)&&(forward_f_code_vertical<=4'd4);
wire general_detect_now=p_residual_sample_valid&&(p_residual_sample_index==6'h3e)&&
 general_p_f_code_supported&&
 general_geometry_supported&&!p_implicit_reconstruct_request;
reg general_mixed_mode;
wire mixed_active,mixed_persisted_seen,mixed_error,mixed_half;
reg mixed_persisted_seen_d;
always @(posedge clk)begin
 if(reset)begin general_mixed_mode<=0;mixed_persisted_seen_d<=0;end
 else begin
  mixed_persisted_seen_d<=mixed_persisted_seen;
  if(general_detect_now)general_mixed_mode<=1;
  else if(mixed_persisted_seen)general_mixed_mode<=0;
 end
end

wire b_direction_word=(p_residual_sample_index==6'h38)||(p_residual_sample_index==6'h39)||(p_residual_sample_index==6'h3a);
wire b_detect_now=p_residual_sample_valid&&b_direction_word&&p_forward_vector_valid&&
 (p_forward_vector_x==13'sd2047)&&(p_forward_vector_y==-13'sd2048)&&
 general_p_f_code_supported&&
 general_geometry_supported&&!p_implicit_reconstruct_request;
reg b_mode;
reg b_persisted_seen_d;
wire b_active,b_persisted_seen,b_row_persisted,b_error,b_half,b_recon,b_read,b_nonzero;
wire[4:0] b_error_source;
wire [7:0] b_sample,b_recon_value,b_persist_value;
reg b_history_error;
reg[4:0] b_history_error_source;
wire b_rearm_now=b_mode&&b_persisted_seen&&!b_active;
wire b_reset=reset||b_rearm_now;
always @(posedge clk)begin
 if(reset)begin b_mode<=0;b_persisted_seen_d<=0;b_history_error<=0;b_history_error_source<=0;end
 else begin
  b_persisted_seen_d<=b_persisted_seen;
  if(b_error)b_history_error<=1;
  if(b_error&&(b_history_error_source==0))b_history_error_source<=b_error_source;
  if(b_detect_now)b_mode<=1;
  else if(b_persisted_seen&&!b_active)b_mode<=0;
 end
end
wire b_select=b_mode||b_detect_now||b_active;
// Entry 240 timing closure: b_detect_now is required combinationally only to
// capture the first B metadata word.  The raster/cache path cannot issue a
// request until the following cycle, when b_mode is registered, so keep the
// geometry-qualified detector out of the shared address/response cone.
wire b_engine_select=b_mode||b_active;

// Commit 201 capacity closure: the streamed generalized P protocol supersedes
// the historical 128x96 plan adapter and base reference engine.  Current P
// pictures identify themselves with ordered 0x3e/0x3b metadata and always use
// mixed_probe; B continues to use b_probe.
wire plan_capture_window=1'b0;
wire plan_first_now=1'b0;

reg[47:0] plan_shift_right_map;
reg[5:0] plan_capture_count,plan_emit_count;
reg plan_capture_active,plan_ready,plan_started,plan_replay_active,plan_replay_seen,plan_error;

wire plan_request_now=1'b0;

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

  if(plan_request_now&&!plan_started)begin plan_started<=1;plan_replay_active<=1;plan_emit_count<=0;end
  else if(plan_replay_active)begin
   if(plan_emit_count==6'd0)plan_replay_seen<=1;
   if(plan_emit_count==6'd48)plan_replay_active<=0;else plan_emit_count<=plan_emit_count+1'b1;
  end

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
wire signed[15:0] plan_adapter_value=(plan_emit_count<6'd48)?{plan_emit_mvx,8'sd0}:16'shA2FF;

wire plan_select=plan_first_now||plan_capture_active||plan_ready||plan_started||plan_replay_active;
wire general_input_select=(general_mixed_mode||general_detect_now)&&!b_select;
wire mixed_select=general_input_select||plan_select||mixed_active;
// Entry 240 timing closure: B selection must retain priority on the shared
// cache/DDR muxes, but it need not enter the P engine's internal address cone.
// P mode remains latched from its first metadata word through persistence, and
// mix_residual_valid below still rejects every B sideband.
wire mixed_engine_select=general_mixed_mode||general_detect_now||
    plan_select||mixed_active;
wire mix_residual_valid=plan_adapter_valid?1'b1:(p_residual_sample_valid&&general_input_select);
wire[5:0] mix_residual_index=plan_adapter_valid?plan_adapter_index:p_residual_sample_index;
wire signed[15:0] mix_residual_value=plan_adapter_valid?plan_adapter_value:p_residual_sample_value;

wire base_persisted_seen,base_probe_error;reg p_forward_vector_valid_d;
wire base_rearm_now=base_persisted_seen&&p_forward_vector_valid_d&&!p_forward_vector_valid;
wire base_reset=reset||base_rearm_now||mixed_select||b_select;
always @(posedge clk)begin
 if(reset)p_forward_vector_valid_d<=0;
 else p_forward_vector_valid_d<=p_forward_vector_valid&&!mixed_select&&!b_select;
end
wire[7:0] base_bc;wire[28:0] base_addr;wire base_rd,base_store_sel;wire[7:0] base_store_val;wire[11:0] base_store_x,base_store_y;wire base_store_valid,base_store_start,base_store_complete;
wire base_read;wire[7:0] base_sample;wire base_nonzero,base_half,base_recon;wire[7:0] base_recon_val,base_persist_val;
wire base_vector_valid=p_forward_vector_valid&&!mixed_select&&!b_select;
wire base_residual_valid=p_residual_sample_valid&&!mixed_select&&!b_select;

assign base_bc=8'd0;
assign base_addr=29'd0;
assign base_rd=1'b0;
assign base_store_sel=1'b0;
assign base_store_val=8'd0;
assign base_store_x=12'd0;
assign base_store_y=12'd0;
assign base_store_valid=1'b0;
assign base_store_start=1'b0;
assign base_store_complete=1'b0;
assign base_read=1'b0;
assign base_sample=8'd0;
assign base_nonzero=1'b0;
assign base_half=1'b0;
assign base_recon=1'b0;
assign base_recon_val=8'd0;
assign base_persisted_seen=1'b0;
assign base_persist_val=8'd0;
assign base_probe_error=1'b0;

wire[7:0] mix_bc_raw;wire[28:0] mix_addr_raw;wire mix_rd_raw,mix_cacheable_raw,mix_lookup_request,mix_lookup_consume;
wire mix_store_sel;wire[7:0] mix_store_val;wire[11:0] mix_store_x,mix_store_y;wire mix_store_valid,mix_store_start,mix_store_complete;
wire mix_read;wire[7:0] mix_sample;wire mix_nonzero,mix_recon,mix_row_persisted;wire[7:0] mix_recon_val,mix_persist_val;wire[3:0] mix_progress_stage;
wire[4:0] mixed_error_source;

wire[7:0] b_bc_raw;wire[28:0] b_addr_raw;wire b_rd_raw,b_cacheable_raw,b_lookup_request,b_lookup_consume;
wire b_store_sel;wire[7:0] b_store_val;wire[11:0] b_store_x,b_store_y;wire b_store_valid,b_store_start,b_store_complete;

// Commit 203: P and B parsing/reconstruction are mutually exclusive, so both
// raster engines reuse one 2048-block sparse residual store.  Port A accepts
// transformed samples during metadata capture; port B serves synchronous
// reconstruction reads from whichever engine owns the shared DDR path.
wire mix_residual_store_write,b_residual_store_write;
wire [16:0] mix_residual_store_write_address;
wire [16:0] b_residual_store_write_address;
wire signed [15:0] mix_residual_store_write_data;
wire signed [15:0] b_residual_store_write_data;
wire [16:0] mix_residual_store_read_address;
wire [16:0] b_residual_store_read_address;
reg signed [15:0] shared_residual_store_read_data;
(* ramstyle = "M10K" *) reg signed [15:0]
    shared_residual_store [0:131071];

always @(posedge clk) begin
 if(mix_residual_store_write)
  shared_residual_store[mix_residual_store_write_address]
   <=mix_residual_store_write_data;
 else if(b_residual_store_write)
  shared_residual_store[b_residual_store_write_address]
   <=b_residual_store_write_data;
 shared_residual_store_read_data<=shared_residual_store[
  b_engine_select?b_residual_store_read_address:
           mix_residual_store_read_address];
end

wire shared_select=mixed_select||b_engine_select;
wire[7:0] shared_bc_raw=b_engine_select?b_bc_raw:mix_bc_raw;
wire[28:0] shared_addr_raw=b_engine_select?b_addr_raw:mix_addr_raw;
wire shared_rd_raw=b_engine_select?b_rd_raw:mix_rd_raw;
wire shared_cacheable_raw=b_engine_select?b_cacheable_raw:mix_cacheable_raw;
wire shared_engine_active=mixed_active||b_active;
wire shared_engine_busy;
wire[63:0] shared_engine_dout;
wire shared_engine_dout_ready;
wire[7:0] shared_cached_bc;
wire[28:0] shared_cached_addr;
wire shared_cached_rd;
wire[31:0] shared_cache_hits,shared_cache_misses,shared_uncached_reads;
wire shared_lookup_ready,shared_lookup_hit;
wire[63:0] shared_lookup_data;
wire shared_lookup_request=b_engine_select?b_lookup_request:mix_lookup_request;
wire shared_lookup_consume=b_engine_select?b_lookup_consume:mix_lookup_consume;
wire mix_dout_ready_owned=shared_engine_dout_ready&&mixed_select&&!b_engine_select;
wire b_dout_ready_owned=shared_engine_dout_ready&&b_engine_select;

mpeg2_h262_reference_word_cache reference_cache(
 .clk(clk),.reset(reset),.active(shared_engine_active),
 .request_burstcnt(shared_bc_raw),.request_addr(shared_addr_raw),
 .request_read(shared_rd_raw),.request_cacheable(shared_cacheable_raw),
 .lookup_request(shared_lookup_request),.lookup_consume(shared_lookup_consume),
 .lookup_ready(shared_lookup_ready),.lookup_hit(shared_lookup_hit),
 .lookup_data(shared_lookup_data),
 .request_busy(shared_engine_busy),.request_dout(shared_engine_dout),
 .request_dout_ready(shared_engine_dout_ready),
 .downstream_busy(ddram_busy),.downstream_dout(ddram_dout),
 .downstream_dout_ready(ddram_dout_ready),
 .downstream_burstcnt(shared_cached_bc),
 .downstream_addr(shared_cached_addr),.downstream_read(shared_cached_rd),
 .cache_hit_count(shared_cache_hits),.cache_miss_count(shared_cache_misses),
 .uncached_count(shared_uncached_reads));

mpeg2_h262_p_motion_residual_raster_engine mixed_probe(
 .clk(clk),.reset(reset),.capture_enable(mixed_engine_select),
 .request(mixed_engine_select),
 .horizontal_size(horizontal_size),.vertical_size(vertical_size),
 .shift_right_map(48'd0),
 .residual_valid(mix_residual_valid),.residual_index(mix_residual_index),.residual_value(mix_residual_value),
 .residual_store_write(mix_residual_store_write),
 .residual_store_write_address(mix_residual_store_write_address),
 .residual_store_write_data(mix_residual_store_write_data),
 .residual_store_read_address(mix_residual_store_read_address),
 .residual_store_read_data(shared_residual_store_read_data),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),.destination_bank(destination_frame_bank),.store_block_stored(p_store_block_stored),
 .ddram_busy(shared_engine_busy),.ddram_dout(shared_engine_dout),.ddram_dout_ready(mix_dout_ready_owned),
 .ddram_lookup_ready(shared_lookup_ready),.ddram_lookup_hit(shared_lookup_hit),
 .ddram_lookup_data(shared_lookup_data),
 .ddram_burstcnt(mix_bc_raw),.ddram_addr(mix_addr_raw),.ddram_rd(mix_rd_raw),
 .ddram_cacheable(mix_cacheable_raw),.ddram_lookup_request(mix_lookup_request),
 .ddram_lookup_consume(mix_lookup_consume),
 .store_select(mix_store_sel),.store_pixel_value(mix_store_val),.store_pixel_x(mix_store_x),.store_pixel_y(mix_store_y),.store_pixel_valid(mix_store_valid),
 .store_block_start(mix_store_start),.store_block_complete(mix_store_complete),.active(mixed_active),.read_seen(mix_read),.sample_value(mix_sample),.sample_nonzero(mix_nonzero),
 .half_sample_seen(mixed_half),.reconstructed_seen(mix_recon),.reconstructed_value(mix_recon_val),.persisted_seen(mixed_persisted_seen),.row_persisted(mix_row_persisted),.persisted_value(mix_persist_val),
 .progress_stage(mix_progress_stage),.error(mixed_error),.error_source(mixed_error_source));

mpeg2_h262_b_bidirectional_raster_engine b_probe(
 .clk(clk),.reset(b_reset),.capture_enable(b_select),.request(b_select),
 .sideband_valid(p_residual_sample_valid&&b_select),.sideband_index(p_residual_sample_index),.sideband_value(p_residual_sample_value),
 .residual_store_write(b_residual_store_write),
 .residual_store_write_address(b_residual_store_write_address),
 .residual_store_write_data(b_residual_store_write_data),
 .residual_store_read_address(b_residual_store_read_address),
 .residual_store_read_data(shared_residual_store_read_data),
 .reference_valid(reference_frame_valid),.past_reference_bank(previous_reference_frame_bank),
 .future_reference_bank(reference_frame_bank),.scratch_frame_bank(b_scratch_frame_bank),.store_block_stored(p_store_block_stored),
 .ddram_busy(shared_engine_busy),.ddram_dout(shared_engine_dout),.ddram_dout_ready(b_dout_ready_owned),
 .ddram_lookup_ready(shared_lookup_ready),.ddram_lookup_hit(shared_lookup_hit),
 .ddram_lookup_data(shared_lookup_data),
 .ddram_burstcnt(b_bc_raw),.ddram_addr(b_addr_raw),.ddram_rd(b_rd_raw),
 .ddram_cacheable(b_cacheable_raw),.ddram_lookup_request(b_lookup_request),
 .ddram_lookup_consume(b_lookup_consume),
 .store_select(b_store_sel),.store_pixel_value(b_store_val),.store_pixel_x(b_store_x),.store_pixel_y(b_store_y),
 .store_pixel_valid(b_store_valid),.store_block_start(b_store_start),.store_block_complete(b_store_complete),
 .active(b_active),.read_seen(b_read),.sample_nonzero(b_nonzero),.half_sample_seen(b_half),
 .reconstructed_seen(b_recon),.persisted_seen(b_persisted_seen),.row_persisted(b_row_persisted),.error(b_error),.error_source(b_error_source));
assign b_sample=8'd0;assign b_recon_value=8'd0;assign b_persist_value=8'd0;

assign ddram_burstcnt=shared_select?shared_cached_bc:base_bc;
assign ddram_addr=shared_select?shared_cached_addr:base_addr;
assign ddram_rd=shared_select?shared_cached_rd:base_rd;
assign p_store_select=b_select?b_store_sel:mixed_select?mix_store_sel:base_store_sel;
assign p_store_pixel_value=b_select?b_store_val:mixed_select?mix_store_val:base_store_val;
assign p_store_pixel_x=b_select?b_store_x:mixed_select?mix_store_x:base_store_x;
assign p_store_pixel_y=b_select?b_store_y:mixed_select?mix_store_y:base_store_y;
assign p_store_pixel_valid=b_select?b_store_valid:mixed_select?mix_store_valid:base_store_valid;
assign p_store_block_start=b_select?b_store_start:mixed_select?mix_store_start:base_store_start;
assign p_store_block_complete=b_select?b_store_complete:mixed_select?mix_store_complete:base_store_complete;
wire mixed_seen_enable=!plan_select||plan_replay_seen;
assign read_seen=b_select?b_read:mixed_select?(mixed_seen_enable&&mix_read):base_read;
assign sample_value=b_select?b_sample:mixed_select?mix_sample:base_sample;
assign sample_nonzero=b_select?b_nonzero:mixed_select?(mixed_seen_enable&&mix_nonzero):base_nonzero;
assign half_sample_seen=b_select?b_half:mixed_select?(mixed_seen_enable&&mixed_half):base_half;
assign reconstructed_seen=b_select?b_recon:mixed_select?(mixed_seen_enable&&mix_recon):base_recon;
assign reconstructed_value=b_select?b_recon_value:mixed_select?mix_recon_val:base_recon_val;
// Entry 221: the engines expose sticky completion levels while their selection
// is transient.  Export one edge per engine transaction so returning from B to
// a still-settled P engine cannot republish the preceding P reference.
wire mixed_persisted_edge=mixed_persisted_seen&&!mixed_persisted_seen_d;
wire b_persisted_edge=b_persisted_seen&&!b_persisted_seen_d;
assign persisted_seen=b_select?b_persisted_edge:
 mixed_select?(mixed_seen_enable&&mixed_persisted_edge):base_persisted_seen;
assign row_persisted=b_select?b_row_persisted:(mixed_select&&mix_row_persisted);
assign persisted_value=b_select?b_persist_value:mixed_select?mix_persist_val:base_persist_val;
assign p_progress_stage=mix_progress_stage;
assign probe_error=plan_error||b_history_error||(b_select?b_error:(mixed_select?mixed_error:base_probe_error));
// Commit 199 diagnostics: preserve the parent USER=3 error while naming the
// responsible engine on POWER and its first assertion on DISK.  These outputs
// are observational only and do not feed selection, DDR, or reconstruction.
assign probe_error_source=plan_error?3'd1:
 b_history_error?3'd3:
 (b_select&&b_error)?3'd3:
 (mixed_select&&mixed_error)?3'd2:
 base_probe_error?3'd4:3'd0;
assign probe_error_detail=(probe_error_source==3'd2)?mixed_error_source:
 (probe_error_source==3'd3)?
  ((b_history_error_source!=0)?b_history_error_source:b_error_source):5'd0;
wire unused_b=&{1'b0,b_sample,b_recon_value,b_persist_value,
 shared_cache_hits,shared_cache_misses,shared_uncached_reads};
endmodule
