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
	// Entry 324: a 256-byte reservoir made MiSTer's ioctl_wait stop/restart
	// latency visible whenever dense pictures drained the FIFO in one burst.
	// Keep the same CDC primitive but use 32 KiB so normal decoder stalls can
	// prefetch enough compressed data to bridge those transfer turnarounds.
	.lpm_numwords         (32768),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo"),
	.lpm_width            (8),
	.lpm_widthu           (15),
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
