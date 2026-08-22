`timescale 1ns/1ps

module tb_mpeg2_stream_word_unpacker;

reg         reset = 1'b1;
reg         wr_clk = 1'b0;
reg  [15:0] wr_data = 16'd0;
reg         wr_en = 1'b0;
wire        wr_full;
reg         rd_clk = 1'b0;
reg         rd_en = 1'b0;
wire  [7:0] rd_data;
wire        rd_empty;

reg [7:0] expected [0:5];
integer index;

always #5 wr_clk = ~wr_clk;
always #7 rd_clk = ~rd_clk;

mpeg2_stream_fifo dut
(
	.reset    (reset),
	.wr_clk   (wr_clk),
	.wr_data  (wr_data),
	.wr_en    (wr_en),
	.wr_full  (wr_full),
	.rd_clk   (rd_clk),
	.rd_en    (rd_en),
	.rd_data  (rd_data),
	.rd_empty (rd_empty)
);

task read_byte(input integer expected_index);
	begin
		wait (!rd_empty);
		@(negedge rd_clk);
		if (rd_data !== expected[expected_index]) begin
			$display("FAIL byte %0d got %02x expected %02x",
				expected_index, rd_data, expected[expected_index]);
			$fatal(1);
		end
		rd_en = 1'b1;
		@(negedge rd_clk);
		rd_en = 1'b0;
	end
endtask

initial begin
	expected[0] = 8'h11;
	expected[1] = 8'h22;
	expected[2] = 8'h33;
	expected[3] = 8'h44;
	expected[4] = 8'h55;
	expected[5] = 8'h66;

	repeat (3) @(negedge wr_clk);
	reset = 1'b0;
	repeat (6) @(negedge wr_clk);

	if (wr_full || !rd_empty) begin
		$display("FAIL FIFO reset state full=%0d empty=%0d", wr_full, rd_empty);
		$fatal(1);
	end

	// Three words are accepted on consecutive write clocks with no per-word
	// wait.  MiSTer WIDE file I/O places the lower-addressed byte in [7:0].
	wr_data = 16'h2211;
	wr_en = 1'b1;
	@(negedge wr_clk);
	if (wr_full) $fatal(1, "unexpected full after first word");
	wr_data = 16'h4433;
	@(negedge wr_clk);
	if (wr_full) $fatal(1, "unexpected full after second word");
	wr_data = 16'h6655;
	@(negedge wr_clk);
	wr_en = 1'b0;

	for (index = 0; index < 6; index = index + 1)
		read_byte(index);

	repeat (6) @(negedge rd_clk);
	if (!rd_empty) begin
		$display("FAIL FIFO did not return to empty");
		$fatal(1);
	end

	reset = 1'b1;
	#1;
	if (!rd_empty) begin
		$display("FAIL asynchronous reset did not assert empty");
		$fatal(1);
	end

	$display("PASS mixed-width MPEG-2 stream FIFO bytes=6");
	$finish;
end

endmodule
