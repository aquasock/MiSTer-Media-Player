// kate - Clock-domain crossing FIFO for HPS -> MPEG2 elementary stream.

module mpeg2_stream_word_unpacker
(
	input  wire        reset,
	input  wire        clk,
	input  wire [15:0] word_data,
	input  wire        word_valid,
	output wire        word_wait,
	input  wire        byte_full,
	output reg   [7:0] byte_data,
	output reg         byte_write
);

reg [7:0] high_byte;
reg       high_pending;

// MiSTer WIDE file I/O supplies the lower-addressed byte in [7:0].  Stop the
// host for one clock while [15:8] is committed so words cannot overlap.
assign word_wait = high_pending || byte_full;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		high_byte    <= 8'd0;
		high_pending <= 1'b0;
		byte_data    <= 8'd0;
		byte_write   <= 1'b0;
	end
	else begin
		byte_write <= 1'b0;

		if (high_pending) begin
			if (!byte_full) begin
				byte_data    <= high_byte;
				byte_write   <= 1'b1;
				high_pending <= 1'b0;
			end
		end
		else if (word_valid && !byte_full) begin
			byte_data    <= word_data[7:0];
			byte_write   <= 1'b1;
			high_byte    <= word_data[15:8];
			high_pending <= 1'b1;
		end
	end
end

endmodule

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

wire       fifo_wr_full;
wire [7:0] fifo_wr_data;
wire       fifo_wr_en;

mpeg2_stream_word_unpacker word_unpacker
(
	.reset      (reset),
	.clk        (wr_clk),
	.word_data  (wr_data),
	.word_valid (wr_en),
	.word_wait  (wr_full),
	.byte_full  (fifo_wr_full),
	.byte_data  (fifo_wr_data),
	.byte_write (fifo_wr_en)
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

	.data    (fifo_wr_data),
	.wrclk   (wr_clk),
	.wrreq   (fifo_wr_en),
	.wrfull  (fifo_wr_full),

	.q       (rd_data),
	.rdclk   (rd_clk),
	.rdreq   (rd_en),
	.rdempty (rd_empty)
);

endmodule
