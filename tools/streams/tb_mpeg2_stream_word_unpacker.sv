`timescale 1ns/1ps

module tb_mpeg2_stream_word_unpacker;

reg         reset = 1'b1;
reg         clk = 1'b0;
reg  [15:0] word_data = 16'd0;
reg         word_valid = 1'b0;
wire        word_wait;
reg         byte_full = 1'b0;
wire  [7:0] byte_data;
wire        byte_write;

reg [7:0] expected [0:5];
integer observed = 0;

always #5 clk = ~clk;

mpeg2_stream_word_unpacker dut
(
	.reset      (reset),
	.clk        (clk),
	.word_data  (word_data),
	.word_valid (word_valid),
	.word_wait  (word_wait),
	.byte_full  (byte_full),
	.byte_data  (byte_data),
	.byte_write (byte_write)
);

always @(negedge clk) begin
	if (byte_write) begin
		if (observed > 5 || byte_data !== expected[observed]) begin
			$display("FAIL byte %0d got %02x expected %02x",
				observed, byte_data, expected[observed]);
			$fatal(1);
		end
		observed = observed + 1;
	end
end

task send_word(input [15:0] value);
	begin
		@(negedge clk);
		if (word_wait) begin
			$display("FAIL attempted word %04x while wait asserted", value);
			$fatal(1);
		end
		word_data = value;
		word_valid = 1'b1;
		@(negedge clk);
		word_valid = 1'b0;
	end
endtask

initial begin
	expected[0] = 8'h11;
	expected[1] = 8'h22;
	expected[2] = 8'h33;
	expected[3] = 8'h44;
	expected[4] = 8'h77;
	expected[5] = 8'h88;

	repeat (2) @(negedge clk);
	reset = 1'b0;

	send_word(16'h2211);
	wait (!word_wait);

	send_word(16'h4433);
	byte_full = 1'b1;
	repeat (3) begin
		@(negedge clk);
		if (!word_wait) begin
			$display("FAIL wait dropped while high byte was stalled");
			$fatal(1);
		end
	end
	byte_full = 1'b0;
	wait (!word_wait);
	@(negedge clk);

	reset = 1'b1;
	#1;
	if (word_wait || byte_write) begin
		$display("FAIL reset did not clear unpacker state");
		$fatal(1);
	end
	@(negedge clk);
	reset = 1'b0;

	send_word(16'h8877);
	wait (!word_wait);
	@(negedge clk);
	#1;

	if (observed != 6) begin
		$display("FAIL observed %0d bytes expected 6", observed);
		$fatal(1);
	end

	$display("PASS mpeg2 stream word unpacker bytes=%0d", observed);
	$finish;
end

endmodule
