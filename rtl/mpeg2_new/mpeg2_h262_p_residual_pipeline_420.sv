//============================================================================
// MiSTer Media Player - shared six-block H.262 P residual pipeline
//
// Phase 1U-o retains the accepted first-macroblock residual parser and adds a
// controlled MC+Coded +7/EOB source for the mixed raster.  Both feed the same serialized
// non-intra IQ/IDCT transform.  Mixed residual samples are buffered and replayed
// only after the exact raster syntax has been verified at the picture boundary.
//============================================================================
module mpeg2_h262_p_residual_probe(
 input wire clk,input wire reset,input wire [7:0] stream_data,input wire stream_valid,input wire p_picture_expected,
 input wire mixed_mode,input wire mixed_first_slice_complete,input wire mixed_release,
 output wire decision_complete,output wire residual_required,output wire residual_success,output wire mixed_replay_active,
 output wire first_sample_valid,output wire signed [15:0] first_sample_value,
 output wire residual_sample_valid,output wire [5:0] residual_sample_index,output wire signed [15:0] residual_sample_value,
 output wire probe_error);

wire old_decision,old_required,old_success,old_parser_error;wire[4:0] old_qscale;wire old_qtype,old_alt;
wire[2:0] old_block;wire old_start,old_we,old_end;wire[5:0] old_widx;wire signed[12:0] old_wval;
wire transform_done;
mpeg2_h262_p_residual_parser_420 parser(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),
 .transform_block_done(transform_done&&!mixed_mode),.decision_complete(old_decision),.residual_required(old_required),
 .residual_success(old_success),.quantiser_scale_code(old_qscale),.q_scale_type(old_qtype),.alternate_scan(old_alt),
 .qfs_block_index(old_block),.qfs_block_start(old_start),.qfs_write_en(old_we),.qfs_write_index(old_widx),
 .qfs_write_value(old_wval),.qfs_block_end(old_end),.probe_error(old_parser_error));

localparam M_IDLE=3'd0,M_START=3'd1,M_WRITE=3'd2,M_END=3'd3,M_WAIT=3'd4;
reg[2:0] mstate,mblock;reg mixed_decision,mixed_success,mixed_error;
reg mstart,mwe,mend;
always @(posedge clk)begin
 if(reset)begin mstate<=M_IDLE;mblock<=0;mixed_decision<=0;mixed_success<=0;mixed_error<=0;mstart<=0;mwe<=0;mend<=0;end
 else begin
  mstart<=0;mwe<=0;mend<=0;
  case(mstate)
   M_IDLE:if(mixed_first_slice_complete)begin mixed_decision<=1;mblock<=0;mstate<=M_START;end
   M_START:begin mstart<=1;mstate<=M_WRITE;end
   M_WRITE:begin mwe<=1;mstate<=M_END;end
   M_END:begin mend<=1;mstate<=M_WAIT;end
   M_WAIT:if(transform_done&&mixed_mode)begin if(mblock==5)begin mixed_success<=1;mstate<=M_IDLE;end else begin mblock<=mblock+1'b1;mstate<=M_START;end end
   default:begin mixed_error<=1;mstate<=M_IDLE;end
  endcase
 end
end

wire[2:0] qblock=mixed_mode?mblock:old_block;
wire qstart=mixed_mode?mstart:old_start;wire qwe=mixed_mode?mwe:old_we;wire qend=mixed_mode?mend:old_end;
wire[5:0] qwidx=mixed_mode?6'd0:old_widx;wire signed[12:0] qwval=mixed_mode?13'sd7:old_wval;
wire[4:0] qscale=mixed_mode?5'd2:old_qscale;wire qtype=mixed_mode?1'b0:old_qtype;wire alt=mixed_mode?1'b0:old_alt;
wire[1:0] tblock=(qblock==0)?2'd0:2'd1;
wire tfvalid,tvalid,terr;wire signed[15:0] tfvalue,tvalue;wire[1:0] unused_block;wire[5:0] tidx;
mpeg2_h262_p_non_intra_transform transform(
 .clk(clk),.reset(reset),.qfs_block_index(tblock),.qfs_block_start(qstart),.qfs_write_en(qwe),.qfs_write_index(qwidx),.qfs_write_value(qwval),
 .qfs_block_end(qend),.quantiser_scale_code(qscale),.q_scale_type(qtype),.alternate_scan(alt),.block_done(transform_done),
 .first_sample_valid(tfvalid),.first_sample_value(tfvalue),.residual_sample_valid(tvalid),.residual_sample_block_index(unused_block),
 .residual_sample_index(tidx),.residual_sample_value(tvalue),.probe_error(terr));

reg signed[15:0] mixed_mem[0:383];reg[8:0] cap_count,replay_count;reg replay_active,replay_done;reg replay_valid,first_valid_reg;reg[5:0] replay_index;reg signed[15:0] replay_value,first_value_reg;reg buffer_error;
always @(posedge clk)begin
 if(reset)begin cap_count<=0;replay_count<=0;replay_active<=0;replay_done<=0;replay_valid<=0;first_valid_reg<=0;replay_index<=0;replay_value<=0;first_value_reg<=0;buffer_error<=0;end
 else begin
  replay_valid<=0;first_valid_reg<=0;
  if(mixed_mode&&tvalid)begin if(cap_count>=384||tidx!=cap_count[5:0])buffer_error<=1;else begin mixed_mem[cap_count]<=tvalue;cap_count<=cap_count+1'b1;end end
  if(mixed_release&&mixed_success&&!replay_active&&!replay_done)begin if(cap_count!=384)buffer_error<=1;else begin replay_active<=1;replay_count<=0;end end
  if(replay_active)begin replay_valid<=1;replay_index<=replay_count[5:0];replay_value<=mixed_mem[replay_count];if(replay_count==0)begin first_valid_reg<=1;first_value_reg<=mixed_mem[0];end if(replay_count==383)begin replay_active<=0;replay_done<=1;end else replay_count<=replay_count+1'b1;end
 end
end
assign decision_complete=mixed_mode?mixed_decision:old_decision;
assign residual_required=mixed_mode?1'b1:old_required;
assign residual_success=mixed_mode?mixed_success:old_success;
assign mixed_replay_active=replay_active;
assign first_sample_valid=mixed_mode?first_valid_reg:tfvalid;
assign first_sample_value=mixed_mode?first_value_reg:tfvalue;
assign residual_sample_valid=mixed_mode?replay_valid:tvalid;
assign residual_sample_index=mixed_mode?replay_index:tidx;
assign residual_sample_value=mixed_mode?replay_value:tvalue;
assign probe_error=terr|mixed_error|buffer_error|(!mixed_mode&&old_parser_error);
endmodule
