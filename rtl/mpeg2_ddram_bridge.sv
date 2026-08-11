module mpeg2_ddram_bridge
(
	input  wire        clk,
	input  wire        reset,

	// MPEG2FPGA memory request FIFO
	input  wire [1:0]  mem_req_cmd,
	input  wire [21:0] mem_req_addr,
	input  wire [63:0] mem_req_dta,
	input  wire        mem_req_valid,
	input  wire        mem_req_empty,
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
	output reg         ddram_we,

	// Sticky diagnostic flags
	output reg         debug_req_seen,
	output reg         debug_read_seen,
	output reg         debug_write_seen,
	output reg         debug_response_seen
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
reg        fetch_wait;
reg [1:0]  pending_cmd;
reg [21:0] pending_addr;
reg [63:0] pending_dta;
reg       read_accepted;
reg       read_returned;
reg [7:0] outstanding_reads;

always @(posedge clk) begin
	read_accepted <= 1'b0;
	mem_req_en <= 1'b0;
	ddram_rd   <= 1'b0;
	ddram_we   <= 1'b0;

	if (reset) begin
	debug_req_seen      <= 1'b0;
	debug_read_seen     <= 1'b0;
	debug_write_seen    <= 1'b0;

	read_accepted   <= 1'b0;

		pending      <= 1'b0;
		fetch_wait   <= 1'b0;
		pending_cmd  <= CMD_NOOP;
		pending_addr <= 22'd0;
		pending_dta  <= 64'd0;

		ddram_addr   <= 29'd0;
		ddram_din    <= 64'd0;
	end
	else begin

		// Capture the current MPEG2FPGA request, but do not remove it
		// from its FIFO yet.
		// fifo_dc "valid" is a read acknowledge, not an empty/not-empty flag.
// Request a FIFO read first, then capture the request when valid
// is asserted on the following cycle.
if (!pending) begin
	if (!fetch_wait && !mem_req_empty) begin
		mem_req_en <= 1'b1;
		fetch_wait <= 1'b1;
	end
	else if (fetch_wait && mem_req_valid) begin
		debug_req_seen <= 1'b1;

		pending      <= 1'b1;
		pending_cmd  <= mem_req_cmd;
		pending_addr <= mem_req_addr;
		pending_dta  <= mem_req_dta;

		fetch_wait <= 1'b0;
	end
end

		if (pending) begin
			case (pending_cmd)

				CMD_NOOP: begin
	pending <= 1'b0;
end

				CMD_REFRESH: begin
	// MiSTer DDR3 handles refresh internally.
	pending <= 1'b0;
end

				CMD_WRITE: begin
					ddram_addr <= DDR_BASE +
					              {{7{1'b0}}, pending_addr};
					ddram_din <= {
    pending_dta[7:0],
    pending_dta[15:8],
    pending_dta[23:16],
    pending_dta[31:24],
    pending_dta[39:32],
    pending_dta[47:40],
    pending_dta[55:48],
    pending_dta[63:56]
}; // kate - test MPEG2FPGA/MiSTer DDR byte order

					// Keep presenting the write until MiSTer can accept it.
					ddram_we <= 1'b1;

					if (!ddram_busy) begin
					debug_write_seen <= 1'b1;
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

						read_accepted   <= 1'b1;

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
	mem_res_en    <= 1'b0;
	read_returned <= 1'b0;

	if (reset) begin
		mem_res_dta         <= 64'd0;
		debug_response_seen <= 1'b0;
		read_returned       <= 1'b0;
	end
	else if (ddram_dout_ready && (outstanding_reads != 0)) begin
		mem_res_dta <= {
    ddram_dout[7:0],
    ddram_dout[15:8],
    ddram_dout[23:16],
    ddram_dout[31:24],
    ddram_dout[39:32],
    ddram_dout[47:40],
    ddram_dout[55:48],
    ddram_dout[63:56]
}; // kate - restore MPEG2FPGA byte order on reads
		mem_res_en          <= 1'b1;
		debug_response_seen <= 1'b1;
		read_returned       <= 1'b1;
	end
end

always @(posedge clk) begin
	if (reset) begin
		outstanding_reads <= 8'd0;
	end
	else begin
		case ({read_accepted, read_returned})

			2'b10:
				outstanding_reads <= outstanding_reads + 8'd1;

			2'b01:
				if (outstanding_reads != 0)
					outstanding_reads <= outstanding_reads - 8'd1;

			default:
				outstanding_reads <= outstanding_reads;

		endcase
	end
end

endmodule
