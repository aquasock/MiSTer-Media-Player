module mpeg2_decoder
(
	input  wire        clk,
	input  wire        mem_clk,
	input  wire        reset,

	input  wire [7:0]  stream_data,
	input  wire        stream_valid,

	input  wire [63:0] mem_res_wr_dta,
	input  wire        mem_res_wr_en,
	input  wire        mem_req_rd_en,

	output wire        busy,
	output wire        error,

	output wire [7:0]  r,
	output wire [7:0]  g,
	output wire [7:0]  b,

	output wire        pixel_en,
	output wire        h_sync,
	output wire        v_sync,

	output wire [1:0]  mem_req_rd_cmd,
	output wire [21:0] mem_req_rd_addr,
	output wire [63:0] mem_req_rd_dta,
	output wire        mem_req_rd_valid,

	output wire        mem_res_wr_almost_full,

	output wire [33:0] debug_testpoint
);

wire [7:0] y;
wire [7:0] u;
wire [7:0] v;

wire c_sync;
wire interrupt;
wire watchdog_rst;

wire [31:0] reg_dta_out;
wire [33:0] testpoint;
assign debug_testpoint = testpoint;


// MPEG2FPGA uses an active-low reset.
//
// We deliberately run all three decoder clock domains from clk_sys for this
// first MiSTer integration experiment. This is NOT the final clocking scheme.

mpeg2video decoder
(
	.clk     (clk),
	.mem_clk (mem_clk),
	.dot_clk (clk),

	.rst                    (~reset),

	.stream_data            (stream_data),
	.stream_valid           (stream_valid),

	.reg_addr               (4'h0),
	.reg_wr_en              (1'b0),
	.reg_dta_in             (32'h00000000),
	.reg_rd_en              (1'b0),
	.reg_dta_out            (reg_dta_out),

	.busy                   (busy),
	.error                  (error),
	.interrupt              (interrupt),
	.watchdog_rst           (watchdog_rst),

	.r                      (r),
	.g                      (g),
	.b                      (b),

	.y                      (y),
	.u                      (u),
	.v                      (v),

	.pixel_en               (pixel_en),
	.h_sync                 (h_sync),
	.v_sync                 (v_sync),
	.c_sync                 (c_sync),

	.mem_req_rd_cmd         (mem_req_rd_cmd),
	.mem_req_rd_addr        (mem_req_rd_addr),
	.mem_req_rd_dta         (mem_req_rd_dta),
	.mem_req_rd_en          (mem_req_rd_en),
	.mem_req_rd_valid       (mem_req_rd_valid),

	.mem_res_wr_dta         (mem_res_wr_dta),
	.mem_res_wr_en          (mem_res_wr_en),
	.mem_res_wr_almost_full (mem_res_wr_almost_full),

	.testpoint_dip    (4'h9),
.testpoint_dip_en (1'b1),
	.testpoint              (testpoint)
);

endmodule
