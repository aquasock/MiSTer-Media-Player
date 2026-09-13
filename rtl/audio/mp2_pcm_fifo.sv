module mp2_pcm_fifo (
    input wire reset,wr_clk,rd_clk,
    input wire [66:0] wr_data,
    input wire wr_en,rd_en,
    output wire wr_full,rd_empty,
    output wire [66:0] rd_data
);
dcfifo #(
    .lpm_numwords(4096),.lpm_showahead("ON"),.lpm_type("dcfifo"),
    .lpm_width(67),.lpm_widthu(12),.overflow_checking("ON"),
    .underflow_checking("ON"),.use_eab("ON"),.rdsync_delaypipe(4),
    .wrsync_delaypipe(4),.write_aclr_synch("ON"),.read_aclr_synch("ON")
) fifo (.aclr(reset),.data(wr_data),.wrclk(wr_clk),.wrreq(wr_en),
    .wrfull(wr_full),.q(rd_data),.rdclk(rd_clk),.rdreq(rd_en),.rdempty(rd_empty));
endmodule
