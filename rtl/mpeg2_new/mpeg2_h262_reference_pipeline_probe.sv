module mpeg2_h262_reference_read_probe(
 input wire clk,input wire reset,input wire p_vector_proof_seen,input wire p_forward_vector_valid,
 input wire signed [12:0] p_forward_vector_x,input wire signed [12:0] p_forward_vector_y,
 input wire [3:0] forward_f_code_horizontal,input wire [3:0] forward_f_code_vertical,
 input wire p_implicit_reconstruct_request,input wire p_residual_sample_valid,input wire [5:0] p_residual_sample_index,
 input wire signed [15:0] p_residual_sample_value,input wire reference_frame_valid,input wire reference_frame_bank,
 input wire destination_frame_bank,input wire p_store_block_stored,input wire ddram_busy,input wire [63:0] ddram_dout,
 input wire ddram_dout_ready,output wire [7:0] ddram_burstcnt,output wire [28:0] ddram_addr,output wire ddram_rd,
 output wire p_store_select,output wire [7:0] p_store_pixel_value,output wire [11:0] p_store_pixel_x,
 output wire [11:0] p_store_pixel_y,output wire p_store_pixel_valid,output wire p_store_block_start,
 output wire p_store_block_complete,output wire read_seen,output wire [7:0] sample_value,output wire sample_nonzero,
 output wire half_sample_seen,output wire reconstructed_seen,output wire [7:0] reconstructed_value,
 output wire persisted_seen,output wire [7:0] persisted_value,output wire probe_error);
wire sel=p_implicit_reconstruct_request;
wire [7:0] ebc,mbc,esample,msample,mrecon,mpersist;
wire [28:0] ea,ma;
wire erd,mrd,eread,enon,ehalf,eerr,mread,mnon,mseen,mpseen,merr,eactive;
mpeg2_h262_p_explicit_reference_probe e(
 .clk(clk),.reset(reset),.proof_seen(p_vector_proof_seen),.p_forward_vector_valid(p_forward_vector_valid),
 .p_forward_vector_x(p_forward_vector_x),.p_forward_vector_y(p_forward_vector_y),
 .f_code_x(forward_f_code_horizontal),.f_code_y(forward_f_code_vertical),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),
 .ddram_busy(ddram_busy),.ddram_dout(ddram_dout),.ddram_dout_ready(ddram_dout_ready&&!sel),
 .active(eactive),.ddram_burstcnt(ebc),.ddram_addr(ea),.ddram_rd(erd),
 .read_seen(eread),.sample_value(esample),.sample_nonzero(enon),.half_sample_seen(ehalf),.error(eerr));
mpeg2_h262_p_luma_macroblock_engine m(
 .clk(clk),.reset(reset),.request(p_implicit_reconstruct_request),
 .residual_valid(p_residual_sample_valid),.residual_index(p_residual_sample_index),.residual_value(p_residual_sample_value),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),.destination_bank(destination_frame_bank),
 .store_block_stored(p_store_block_stored),.ddram_busy(ddram_busy),.ddram_dout(ddram_dout),
 .ddram_dout_ready(ddram_dout_ready&&sel),.ddram_burstcnt(mbc),.ddram_addr(ma),.ddram_rd(mrd),
 .store_select(p_store_select),.store_pixel_value(p_store_pixel_value),.store_pixel_x(p_store_pixel_x),
 .store_pixel_y(p_store_pixel_y),.store_pixel_valid(p_store_pixel_valid),.store_block_start(p_store_block_start),
 .store_block_complete(p_store_block_complete),.read_seen(mread),.sample_value(msample),.sample_nonzero(mnon),
 .reconstructed_seen(mseen),.reconstructed_value(mrecon),.persisted_seen(mpseen),.persisted_value(mpersist),.error(merr));
assign ddram_burstcnt=sel?mbc:ebc;
assign ddram_addr=sel?ma:ea;
assign ddram_rd=sel?mrd:erd;
assign read_seen=sel?mread:eread;
assign sample_value=sel?msample:esample;
assign sample_nonzero=sel?mnon:enon;
assign half_sample_seen=sel?1'b0:ehalf;
assign reconstructed_seen=mseen;
assign reconstructed_value=mrecon;
assign persisted_seen=mpseen;
assign persisted_value=mpersist;
assign probe_error=eerr|merr;
wire unused=eactive;
endmodule
