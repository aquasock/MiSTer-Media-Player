// Ordered byte/EOF reservoir. Each word is {EOF, byte}; sector padding never
// enters the decoder. DCFIFO synchronizes reset release in both clock domains.
module mpeg2_stream_fifo(
 input wire reset,wr_clk,
 input wire [8:0] wr_data,
 input wire wr_en,
 output wire wr_full,
 output wire [14:0] wr_used,
 input wire rd_clk,rd_en,
 output wire [8:0] rd_data,
 output wire rd_empty
);
dcfifo #(
 .lpm_numwords(32768),.lpm_showahead("ON"),.lpm_type("dcfifo"),
 .lpm_width(9),.lpm_widthu(15),
 .overflow_checking("ON"),.underflow_checking("ON"),.use_eab("ON"),
 .rdsync_delaypipe(4),.wrsync_delaypipe(4),
 .write_aclr_synch("ON"),.read_aclr_synch("ON")
) stream_fifo (
 .aclr(reset),.data(wr_data),.wrclk(wr_clk),.wrreq(wr_en),
 .wrfull(wr_full),.wrusedw(wr_used),
 .q(rd_data),.rdclk(rd_clk),.rdreq(rd_en),.rdempty(rd_empty)
);
endmodule
