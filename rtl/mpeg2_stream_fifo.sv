// kate - Clock-domain crossing FIFO for HPS -> MPEG2 elementary stream.

module mpeg2_stream_fifo
(
	input  wire       reset,

	input  wire       wr_clk,
	input  wire [15:0] wr_data,
	input  wire       wr_en,
	output wire       wr_full,

	input  wire       rd_clk,
	input  wire       rd_en,
	output wire [7:0] rd_data,
	output wire       rd_empty
);

dcfifo_mixed_widths #(
	// Entry 324: a 256-byte reservoir made MiSTer's ioctl_wait stop/restart
	// latency visible whenever dense pictures drained the FIFO in one burst.
	// Entry 329: accept complete 16-bit MiSTer WIDE transfers without asserting
	// host wait between their two constituent bytes.  The read port remains the
	// decoder's original byte stream, and total storage remains exactly 32 KiB.
	.lpm_numwords         (16384),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo_mixed_widths"),
	.lpm_width            (16),
	.lpm_width_r          (8),
	.lpm_widthu           (14),
	.lpm_widthu_r         (15),
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
