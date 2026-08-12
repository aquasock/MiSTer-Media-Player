// kate - Clock-domain crossing FIFO for HPS -> MPEG2 elementary stream.

module mpeg2_stream_fifo
(
	input  wire       reset,

	input  wire       wr_clk,
	input  wire [7:0] wr_data,
	input  wire       wr_en,
	output wire       wr_full,

	input  wire       rd_clk,
	input  wire       rd_en,
	output wire [7:0] rd_data,
	output wire       rd_empty
);

dcfifo #(
	.lpm_numwords         (256),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo"),
	.lpm_width            (8),
	.lpm_widthu           (8),
	.overflow_checking    ("ON"),
	.underflow_checking   ("ON"),
	.use_eab              ("ON"),
	.rdsync_delaypipe     (4),
	.wrsync_delaypipe     (4),

	// kate - Phase 1P: synchronize asynchronous-clear RELEASE independently
	// to both FIFO clocks.  Intel recommends both circuits for DCFIFO ACLR.
	.write_aclr_synch     ("ON"),
	.read_aclr_synch      ("ON")
) stream_fifo
(
	.aclr    (reset),

	.data    (wr_data),
	.wrclk   (wr_clk),
	.wrreq   (wr_en),
	.wrfull  (wr_full),

	.q       (rd_data),
	.rdclk   (rd_clk),
	.rdreq   (rd_en),
	.rdempty (rd_empty)
);

endmodule
