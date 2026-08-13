// kate - Phase 1T-r keeps the public reference-probe interface unchanged and
// adds a third serialized client for the controlled explicit (0,0) two-
// macroblock copy proof. Existing implicit residual and explicit 4/3-vector
// diagnostics retain their accepted paths.
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

wire copy_sel = p_forward_vector_valid &&
                (p_forward_vector_x == 13'sd0) &&
                (p_forward_vector_y == 13'sd0) &&
                !p_implicit_reconstruct_request;
wire implicit_sel = p_implicit_reconstruct_request;
wire explicit_sel = !copy_sel && !implicit_sel;

wire [7:0] ebc, ibc, cbc;
wire [28:0] ea, ia, ca;
wire erd, ird, crd;
wire eread,enon,ehalf,eerr,eactive;
wire iread,inon,iseen,ipseen,ierr;
wire cread,cnon,cseen,cpseen,cerr;
wire [7:0] esample,isample,csample;
wire [7:0] irecon,ipersist,crecon,cpersist;

wire istore_select;
wire [7:0] istore_value;
wire [11:0] istore_x,istore_y;
wire istore_valid,istore_start,istore_complete;

wire cstore_select;
wire [7:0] cstore_value;
wire [11:0] cstore_x,cstore_y;
wire cstore_valid,cstore_start,cstore_complete;

mpeg2_h262_p_explicit_reference_probe explicit_probe(
 .clk(clk),.reset(reset),.proof_seen(p_vector_proof_seen),.p_forward_vector_valid(p_forward_vector_valid),
 .p_forward_vector_x(p_forward_vector_x),.p_forward_vector_y(p_forward_vector_y),
 .f_code_x(forward_f_code_horizontal),.f_code_y(forward_f_code_vertical),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),
 .ddram_busy(ddram_busy),.ddram_dout(ddram_dout),.ddram_dout_ready(ddram_dout_ready&&explicit_sel),
 .active(eactive),.ddram_burstcnt(ebc),.ddram_addr(ea),.ddram_rd(erd),
 .read_seen(eread),.sample_value(esample),.sample_nonzero(enon),.half_sample_seen(ehalf),.error(eerr));

mpeg2_h262_p_luma_macroblock_engine implicit_probe(
 .clk(clk),.reset(reset),.request(p_implicit_reconstruct_request),
 .residual_valid(p_residual_sample_valid),.residual_index(p_residual_sample_index),.residual_value(p_residual_sample_value),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),.destination_bank(destination_frame_bank),
 .store_block_stored(p_store_block_stored),.ddram_busy(ddram_busy),.ddram_dout(ddram_dout),
 .ddram_dout_ready(ddram_dout_ready&&implicit_sel),.ddram_burstcnt(ibc),.ddram_addr(ia),.ddram_rd(ird),
 .store_select(istore_select),.store_pixel_value(istore_value),.store_pixel_x(istore_x),
 .store_pixel_y(istore_y),.store_pixel_valid(istore_valid),.store_block_start(istore_start),
 .store_block_complete(istore_complete),.read_seen(iread),.sample_value(isample),.sample_nonzero(inon),
 .reconstructed_seen(iseen),.reconstructed_value(irecon),.persisted_seen(ipseen),.persisted_value(ipersist),.error(ierr));

mpeg2_h262_p_two_mb_copy_engine copy_probe(
 .clk(clk),.reset(reset),.request(copy_sel),
 .reference_valid(reference_frame_valid),.reference_bank(reference_frame_bank),.destination_bank(destination_frame_bank),
 .store_block_stored(p_store_block_stored),.ddram_busy(ddram_busy),.ddram_dout(ddram_dout),
 .ddram_dout_ready(ddram_dout_ready&&copy_sel),.ddram_burstcnt(cbc),.ddram_addr(ca),.ddram_rd(crd),
 .store_select(cstore_select),.store_pixel_value(cstore_value),.store_pixel_x(cstore_x),
 .store_pixel_y(cstore_y),.store_pixel_valid(cstore_valid),.store_block_start(cstore_start),
 .store_block_complete(cstore_complete),.read_seen(cread),.sample_value(csample),.sample_nonzero(cnon),
 .reconstructed_seen(cseen),.reconstructed_value(crecon),.persisted_seen(cpseen),.persisted_value(cpersist),.error(cerr));

assign ddram_burstcnt = copy_sel ? cbc : implicit_sel ? ibc : ebc;
assign ddram_addr     = copy_sel ? ca  : implicit_sel ? ia  : ea;
assign ddram_rd       = copy_sel ? crd : implicit_sel ? ird : erd;

assign p_store_select         = copy_sel ? cstore_select   : istore_select;
assign p_store_pixel_value    = copy_sel ? cstore_value    : istore_value;
assign p_store_pixel_x        = copy_sel ? cstore_x        : istore_x;
assign p_store_pixel_y        = copy_sel ? cstore_y        : istore_y;
assign p_store_pixel_valid    = copy_sel ? cstore_valid    : istore_valid;
assign p_store_block_start    = copy_sel ? cstore_start    : istore_start;
assign p_store_block_complete = copy_sel ? cstore_complete : istore_complete;

assign read_seen       = copy_sel ? cread   : implicit_sel ? iread   : eread;
assign sample_value    = copy_sel ? csample : implicit_sel ? isample : esample;
assign sample_nonzero  = copy_sel ? cnon    : implicit_sel ? inon    : enon;
assign half_sample_seen = explicit_sel ? ehalf : 1'b0;
assign reconstructed_seen  = copy_sel ? cseen    : iseen;
assign reconstructed_value = copy_sel ? crecon   : irecon;
assign persisted_seen      = copy_sel ? cpseen   : ipseen;
assign persisted_value     = copy_sel ? cpersist : ipersist;
assign probe_error = eerr | ierr | cerr;
wire unused = eactive;
endmodule
