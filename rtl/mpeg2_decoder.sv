module mpeg2_decoder
(
	input  wire        clk,
	input  wire        mem_clk,
	input  wire        dot_clk,
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
	output wire        mem_req_rd_empty,

	output wire        mem_res_wr_almost_full,

	output wire [33:0] debug_testpoint,
	output wire        debug_mem_req_wr_en,
	output wire        debug_vbr_wr_en,
	output wire        debug_getbits_valid,
	output wire        debug_update_picture_buffers,
	output wire        debug_macroblock_seen,
	output wire        debug_sequence_header_seen,
	output wire        debug_pixel_underflow,
	output wire        debug_progressive_sequence,
	output wire        debug_progressive_frame,
	output wire        debug_picture_coding_type,
	output wire        debug_picture_structure,
	output wire [7:0]  debug_resample_y,
output wire [2:0]  debug_resample_position,
output wire [1:0]  debug_resample_image,
output wire [11:0] debug_resample_x,
output wire [11:0] debug_resample_y_pos,
output wire        debug_resample_wr_en,

output wire [11:0] debug_video_h_pos,
output wire [11:0] debug_video_v_pos,
output wire        debug_video_pixel_en,
output wire        debug_video_h_sync,
output wire        debug_video_v_sync,
	output wire debug_fwd_addr_error
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
// We deliberately retain MPEG2FPGA as a reference decoder during Phase 1G,
// but it no longer owns or influences the raster used by our framebuffer.
// Its RGB/sync outputs below are legacy/reference outputs only.

mpeg2video decoder
(
	.clk     (clk),
	.mem_clk (mem_clk),
	.dot_clk (dot_clk),

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
	.mem_req_rd_empty       (mem_req_rd_empty),

	.mem_res_wr_dta         (mem_res_wr_dta),
	.mem_res_wr_en          (mem_res_wr_en),
	.mem_res_wr_almost_full (mem_res_wr_almost_full),

	.testpoint_dip    (4'h9),
.testpoint_dip_en (1'b1),
	.testpoint              (testpoint),
	.debug_mem_req_wr_en    (debug_mem_req_wr_en),
	.debug_vbr_wr_en        (debug_vbr_wr_en),
	.debug_getbits_valid    (debug_getbits_valid),
	.debug_update_picture_buffers (debug_update_picture_buffers),
	.debug_macroblock_seen        (debug_macroblock_seen),
	.debug_sequence_header_seen (debug_sequence_header_seen),
	.debug_pixel_underflow       (debug_pixel_underflow),
	.debug_fwd_addr_error(debug_fwd_addr_error),
	.debug_resample_y        (debug_resample_y),
.debug_resample_position (debug_resample_position),
.debug_resample_image    (debug_resample_image),
.debug_resample_x        (debug_resample_x),
.debug_resample_y_pos    (debug_resample_y_pos),
.debug_resample_wr_en    (debug_resample_wr_en),

// Legacy MPEG2FPGA timing is intentionally disconnected. This wrapper is not
// part of the active Quartus source set; keep its old debug raster outputs
// inert now that the Phase 1G development generator has been retired.
.debug_video_h_pos       (),
.debug_video_v_pos       (),
.debug_video_pixel_en    (),
.debug_video_h_sync      (),
.debug_video_v_sync      ()
);

assign debug_video_h_pos    = 12'd0;
assign debug_video_v_pos    = 12'd0;
assign debug_video_pixel_en = 1'b0;
assign debug_video_h_sync   = 1'b0;
assign debug_video_v_sync   = 1'b0;

endmodule
