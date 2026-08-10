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
	output reg debug_req_seen,
output reg debug_read_seen,
output reg debug_response_seen,
);

localparam [1:0]
	CMD_NOOP    = 2'b00,
	CMD_REFRESH = 2'b01,
	CMD_READ    = 2'b10,
	CMD_WRITE   = 2'b11;

localparam [28:0] DDR_BASE = 29'h04000000;

assign ddram_burstcnt = 8'd1;
assign ddram_be       = 8'hFF;


// -------------------------------------------------------------------------
// MPEG2FPGA request -> MiSTer DDRAM
//
// MPEG2FPGA was designed for a pipelined memory controller. Do not wait for
// a read response before accepting another request. DDRAM returns read data
// later through DDRAM_DOUT_READY, in request order.
// -------------------------------------------------------------------------

reg        pending;
reg [1:0]  pending_cmd;
reg [21:0] pending_addr;
reg [63:0] pending_dta;

always @(posedge clk) begin
	mem_req_en <= 1'b0;
	ddram_rd   <= 1'b0;
	ddram_we   <= 1'b0;

	if (reset) begin
	debug_req_seen      <= 1'b0;
	debug_read_seen     <= 1'b0;
	debug_response_seen <= 1'b0;

		pending      <= 1'b0;
		pending_cmd  <= CMD_NOOP;
		pending_addr <= 22'd0;
		pending_dta  <= 64'd0;

		ddram_addr   <= 29'd0;
		ddram_din    <= 64'd0;
	end
	else begin

		// Capture the current MPEG2FPGA request, but do not remove it
		// from its FIFO yet.
		if (!pending && mem_req_valid) begin
		debug_req_seen <= 1'b1;
			pending      <= 1'b1;
			pending_cmd  <= mem_req_cmd;
			pending_addr <= mem_req_addr;
			pending_dta  <= mem_req_dta;
		end

		if (pending) begin
			case (pending_cmd)

				CMD_NOOP: begin
					mem_req_en <= 1'b1;
					pending    <= 1'b0;
				end

				CMD_REFRESH: begin
					// MiSTer DDR3 handles refresh internally.
					mem_req_en <= 1'b1;
					pending    <= 1'b0;
				end

				CMD_WRITE: begin
					ddram_addr <= DDR_BASE +
					              {{7{1'b0}}, pending_addr};
					ddram_din  <= pending_dta;

					// Keep presenting the write until MiSTer can accept it.
					ddram_we <= 1'b1;

					if (!ddram_busy) begin
						mem_req_en <= 1'b1;
						pending    <= 1'b0;
					end
				end

				CMD_READ: begin
					ddram_addr <= DDR_BASE +
					              {{7{1'b0}}, pending_addr};

					if (!mem_res_almost_full) begin
						// Keep presenting the read until MiSTer accepts it.
						ddram_rd <= 1'b1;

						if (!ddram_busy) begin
						debug_read_seen <= 1'b1;

							mem_req_en <= 1'b1;
							pending    <= 1'b0;
						end
					end
				end

			endcase
		end
	end
end


// -------------------------------------------------------------------------
// MiSTer DDRAM -> MPEG2FPGA response FIFO
// -------------------------------------------------------------------------

always @(posedge clk) begin
	mem_res_en <= 1'b0;

	if (reset) begin
		mem_res_dta <= 64'd0;
	end
	else if (ddram_dout_ready) begin
	debug_response_seen <= 1'b1;
		mem_res_dta <= ddram_dout;
		mem_res_en  <= 1'b1;
	end
end

endmodule
