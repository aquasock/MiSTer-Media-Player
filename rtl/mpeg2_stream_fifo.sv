// kate - Clock-domain crossing FIFO for HPS -> MPEG2 elementary stream.

module mpeg2_stream_fifo
(
	input  wire       reset,

	input  wire       wr_clk,
	input  wire [15:0] wr_data,
	input  wire       wr_en,
	output wire       wr_full,
	input  wire       wr_attempt,
	output wire [14:0] burst_credit,
	output wire       burst_ready,
	output reg        burst_fault,
	output reg [31:0] burst_words,
	output reg [15:0] burst_digest,

	input  wire       rd_clk,
	input  wire       rd_en,
	output wire [7:0] rd_data,
	output wire       rd_empty
);

// Write-domain used count includes synchronized read progress. Reserve 32 words
// for count latency and the short HPS/FIO write pipeline; never advertise full
// capacity. A status snapshot grants at most 8 KiB until the next verification.
wire [13:0] wr_used;
wire wr_empty;
// The 14-bit count wraps at 16384. A partial-byte read may release full
// before that wrapped count changes; only trust zero when wrempty agrees.
wire wrapped_used = (wr_used == 0) && !wr_empty;
wire [14:0] free_words = 15'd16384 - {1'b0, wr_used};
reg [5:0] settle_count;
assign burst_ready = settle_count[5] && !reset;
assign burst_credit = !burst_ready || wr_full || wrapped_used || free_words <= 15'd32 ? 15'd0 :
                      free_words > 15'd4128 ? 15'd4096 : free_words - 15'd32;

always @(posedge wr_clk or posedge reset) begin
	if (reset) begin
		settle_count <= 0;
		burst_fault <= 0;
		burst_words <= 0;
		burst_digest <= 0;
	end else begin
		if (!settle_count[5]) settle_count <= settle_count + 1'b1;
		if (wr_attempt && wr_full) burst_fault <= 1;
		if (wr_en && !wr_full) begin
			burst_words <= burst_words + 1'b1;
			burst_digest <= {burst_digest[14:0], burst_digest[15]} ^ wr_data;
		end
	end
end

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
	.wrusedw (wr_used),
	.wrempty (wr_empty),

	.q       (rd_data),
	.rdclk   (rd_clk),
	.rdreq   (rd_en),
	.rdempty (rd_empty)
);

endmodule
