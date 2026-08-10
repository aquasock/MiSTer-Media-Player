module mpeg2_ddram_bridge
(
	input  wire        clk,
	input  wire        reset,

	// MPEG2FPGA memory request FIFO
	input  wire [1:0]  mem_req_cmd,
	input  wire [21:0] mem_req_addr,
	input  wire [63:0] mem_req_dta,
	input  wire        mem_req_valid,
	output reg         mem_req_en,

	// MPEG2FPGA memory response FIFO
	output reg  [63:0] mem_res_dta,
	output reg         mem_res_en,
	input  wire        mem_res_almost_full,

	// MiSTer DDR3 interface
	input  wire        ddram_busy,
	output wire [7:0]  ddram_burstcnt,
	output reg  [28:0] ddram_addr,
	input  wire [63:0] ddram_dout,
	input  wire        ddram_dout_ready,
	output reg         ddram_rd,
	output reg  [63:0] ddram_din,
	output wire [7:0]  ddram_be,
	output reg         ddram_we
);

localparam [1:0]
	CMD_NOOP    = 2'b00,
	CMD_REFRESH = 2'b01,
	CMD_READ    = 2'b10,
	CMD_WRITE   = 2'b11;

// MiSTer FPGA-accessible DDR region starts at byte address 0x20000000.
// DDRAM_ADDR is a 64-bit-word address, therefore:
//
//     0x20000000 / 8 = 0x04000000
//
localparam [28:0] DDR_BASE = 29'h04000000;

assign ddram_burstcnt = 8'd1;
assign ddram_be       = 8'hFF;

localparam STATE_IDLE      = 1'b0;
localparam STATE_READ_WAIT = 1'b1;

reg state;

always @(posedge clk) begin
	mem_req_en <= 1'b0;
	mem_res_en <= 1'b0;
	ddram_rd   <= 1'b0;
	ddram_we   <= 1'b0;

	if (reset) begin
		state       <= STATE_IDLE;
		ddram_addr  <= 29'd0;
		ddram_din   <= 64'd0;
		mem_res_dta <= 64'd0;
	end
	else begin
		case (state)

			STATE_IDLE: begin
				if (mem_req_valid) begin
					case (mem_req_cmd)

						CMD_NOOP: begin
							// Consume the MPEG2FPGA request.
							mem_req_en <= 1'b1;
						end

						CMD_REFRESH: begin
							// MiSTer's DDR3 controller performs its own refresh.
							// Consume the legacy MPEG2FPGA refresh request.
							mem_req_en <= 1'b1;
						end

						CMD_WRITE: begin
							if (!ddram_busy) begin
								ddram_addr <= DDR_BASE +
								              {{7{1'b0}}, mem_req_addr};

								ddram_din <= mem_req_dta;
								ddram_we  <= 1'b1;

								// Request has now been accepted.
								mem_req_en <= 1'b1;
							end
						end

						CMD_READ: begin
							if (!ddram_busy && !mem_res_almost_full) begin
								ddram_addr <= DDR_BASE +
								              {{7{1'b0}}, mem_req_addr};

								ddram_rd <= 1'b1;

								// Remove this request from MPEG2FPGA's request FIFO.
								mem_req_en <= 1'b1;

								// Wait for MiSTer DDRAM read response.
								state <= STATE_READ_WAIT;
							end
						end

					endcase
				end
			end

			STATE_READ_WAIT: begin
				if (ddram_dout_ready) begin
					mem_res_dta <= ddram_dout;
					mem_res_en  <= 1'b1;
					state       <= STATE_IDLE;
				end
			end

		endcase
	end
end

endmodule
