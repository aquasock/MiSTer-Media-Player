//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign DDRAM_CLK = clk_mpeg2;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = ioctl_download;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"MediaPlayer;;",
	"F1,M2V,Open MPEG-2 Video;",
	"-;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,2;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

// ARM -> FPGA MPEG-2 elementary-stream transfer.
wire        ioctl_download;
wire [15:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        mpeg2_stream_full;
wire        mpeg2_stream_empty;
wire [7:0]  mpeg2_stream_data;
wire        mpeg2_stream_rd;
wire        mpeg2_stream_wr;
wire [2:0] mpeg2_debug_picture_coding_type;
wire [1:0] mpeg2_debug_picture_structure;
wire       mpeg2_debug_progressive_sequence;
wire       mpeg2_debug_progressive_frame;


hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(0),
	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ioctl_wait(ioctl_download && mpeg2_stream_full)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire clk_video;
wire clk_mpeg2;
wire clk_mpeg2_mem;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_video),
	.outclk_2(clk_mpeg2),
	.outclk_3(clk_mpeg2_mem)
);

assign mpeg2_stream_wr =
	ioctl_download &&
	ioctl_wr &&
	(ioctl_index[5:0] == 6'd1) &&
	!mpeg2_stream_full;

assign mpeg2_stream_rd =
	!mpeg2_stream_empty &&
	!mpeg2_busy;

mpeg2_stream_fifo mpeg2_stream_fifo
(
	.reset    (reset),

	.wr_clk   (clk_sys),
	.wr_data  (ioctl_dout),
	.wr_en    (mpeg2_stream_wr),
	.wr_full  (mpeg2_stream_full),

	.rd_clk   (clk_mpeg2),
	.rd_en    (mpeg2_stream_rd),
	.rd_data  (mpeg2_stream_data),
	.rd_empty (mpeg2_stream_empty)
);


wire reset = RESET | status[0] | buttons[1];


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

wire        mpeg2_busy;
wire        mpeg2_error;

wire [7:0]  mpeg2_r;
wire [7:0]  mpeg2_g;
wire [7:0]  mpeg2_b;

wire        mpeg2_pixel_en;
wire        mpeg2_h_sync;
wire        mpeg2_v_sync;

wire [1:0]  mpeg2_mem_req_rd_cmd;
wire [21:0] mpeg2_mem_req_rd_addr;
wire [63:0] mpeg2_mem_req_rd_dta;
wire        mpeg2_mem_req_rd_valid;
wire        mpeg2_mem_req_rd_empty;

wire        mpeg2_mem_res_wr_almost_full;

wire        mpeg2_mem_req_rd_en;

wire [63:0] mpeg2_mem_res_wr_dta;
wire        mpeg2_mem_res_wr_en;

wire [33:0] mpeg2_debug_testpoint;
wire mpeg2_debug_mem_req_wr_en;
wire mpeg2_debug_vbr_wr_en;
wire mpeg2_debug_getbits_valid;
wire mpeg2_debug_update_picture_buffers;
wire mpeg2_debug_macroblock_seen;
wire mpeg2_debug_sequence_header_seen;
wire mpeg2_debug_pixel_underflow;
wire mpeg2_debug_picture_coding_type;
wire mpeg2_debug_picture_structure;
wire mpeg2_debug_progressive_sequence;
wire mpeg2_debug_progressive_frame;

wire mpeg2_debug_req_seen;
wire mpeg2_debug_read_seen;
wire mpeg2_debug_write_seen;
wire mpeg2_debug_response_seen;
reg mpeg2_debug_mem_req_wr_seen = 1'b0;
reg mpeg2_debug_vbr_wr_seen = 1'b0;
reg mpeg2_debug_getbits_valid_seen = 1'b0;
reg mpeg2_debug_update_picture_seen = 1'b0;
reg mpeg2_debug_macroblock_seen_latched = 1'b0;
reg mpeg2_debug_pixel_underflow_seen = 1'b0;

always @(posedge clk_sys) begin
	if (reset)
		mpeg2_debug_mem_req_wr_seen <= 1'b0;
	else if (mpeg2_debug_mem_req_wr_en)
		mpeg2_debug_mem_req_wr_seen <= 1'b1;
end
always @(posedge clk_sys) begin
	if (reset)
		mpeg2_debug_vbr_wr_seen <= 1'b0;
	else if (mpeg2_debug_vbr_wr_en)
		mpeg2_debug_vbr_wr_seen <= 1'b1;
end
always @(posedge clk_sys) begin
	if (reset)
		mpeg2_debug_getbits_valid_seen <= 1'b0;
	else if (mpeg2_debug_getbits_valid)
		mpeg2_debug_getbits_valid_seen <= 1'b1;
end
always @(posedge clk_sys) begin
	if (reset)
		mpeg2_debug_update_picture_seen <= 1'b0;
	else if (mpeg2_debug_update_picture_buffers)
		mpeg2_debug_update_picture_seen <= 1'b1;
end
always @(posedge clk_sys) begin
	if (reset)
		mpeg2_debug_macroblock_seen_latched <= 1'b0;
	else if (mpeg2_debug_macroblock_seen)
		mpeg2_debug_macroblock_seen_latched <= 1'b1;
end
always @(posedge clk_video) begin
	if (reset)
		mpeg2_debug_pixel_underflow_seen <= 1'b0;
	else if (mpeg2_debug_pixel_underflow)
		mpeg2_debug_pixel_underflow_seen <= 1'b1;
end
reg mpeg2_debug_bad_header_seen = 1'b0;

always @(posedge clk_mpeg2) begin
	if (reset)
		mpeg2_debug_bad_header_seen <= 1'b0;
	else if ((mpeg2_debug_picture_coding_type > 3) ||
	         ((mpeg2_debug_picture_coding_type != 0) &&
	          (mpeg2_debug_picture_structure != 2'b11)))
		mpeg2_debug_bad_header_seen <= 1'b1;
end

media_player media_player
(
	.clk     (clk_sys),
	.reset   (reset),

	.ce_pix(ce_pix),

	.HBlank(HBlank),
	.HSync(HSync),
	.VBlank(VBlank),
	.VSync(VSync),

	.video(video)
);

mpeg2_decoder mpeg2_decoder
(
	.clk                    (clk_mpeg2),
	.mem_clk                (clk_mpeg2),
	.dot_clk(clk_video),
	.reset(reset),

	.stream_data  (mpeg2_stream_data),
	.stream_valid (mpeg2_stream_rd),

	.mem_res_wr_dta (mpeg2_mem_res_wr_dta),
	.mem_res_wr_en  (mpeg2_mem_res_wr_en),
	.mem_req_rd_en  (mpeg2_mem_req_rd_en),

	.busy                   (mpeg2_busy),
	.error                  (mpeg2_error),

	.r                      (mpeg2_r),
	.g                      (mpeg2_g),
	.b                      (mpeg2_b),

	.pixel_en               (mpeg2_pixel_en),
	.h_sync                 (mpeg2_h_sync),
	.v_sync                 (mpeg2_v_sync),

	.mem_req_rd_cmd         (mpeg2_mem_req_rd_cmd),
	.mem_req_rd_addr        (mpeg2_mem_req_rd_addr),
	.mem_req_rd_dta         (mpeg2_mem_req_rd_dta),
	.mem_req_rd_valid       (mpeg2_mem_req_rd_valid),
	.mem_req_rd_empty       (mpeg2_mem_req_rd_empty),

	.mem_res_wr_almost_full (mpeg2_mem_res_wr_almost_full),

	.debug_testpoint        (mpeg2_debug_testpoint),
	.debug_mem_req_wr_en    (mpeg2_debug_mem_req_wr_en),
	.debug_vbr_wr_en        (mpeg2_debug_vbr_wr_en),
	.debug_getbits_valid    (mpeg2_debug_getbits_valid),
	.debug_update_picture_buffers (mpeg2_debug_update_picture_buffers),
	.debug_macroblock_seen        (mpeg2_debug_macroblock_seen),
	.debug_sequence_header_seen (mpeg2_debug_sequence_header_seen),
	.debug_pixel_underflow       (mpeg2_debug_pixel_underflow)
);

mpeg2_ddram_bridge mpeg2_ddram_bridge
(
	.clk                    (clk_mpeg2),
	.reset               (reset),

	.mem_req_cmd         (mpeg2_mem_req_rd_cmd),
	.mem_req_addr        (mpeg2_mem_req_rd_addr),
	.mem_req_dta         (mpeg2_mem_req_rd_dta),
	.mem_req_valid       (mpeg2_mem_req_rd_valid),
	.mem_req_empty       (mpeg2_mem_req_rd_empty),
	.mem_req_en          (mpeg2_mem_req_rd_en),

	.mem_res_dta         (mpeg2_mem_res_wr_dta),
	.mem_res_en          (mpeg2_mem_res_wr_en),
	.mem_res_almost_full (mpeg2_mem_res_wr_almost_full),

	.ddram_busy          (DDRAM_BUSY),
	.ddram_burstcnt      (DDRAM_BURSTCNT),
	.ddram_addr          (DDRAM_ADDR),
	.ddram_dout          (DDRAM_DOUT),
	.ddram_dout_ready    (DDRAM_DOUT_READY),
	.ddram_rd            (DDRAM_RD),
	.ddram_din           (DDRAM_DIN),
	.ddram_be            (DDRAM_BE),
	.ddram_we            (DDRAM_WE),

	.debug_req_seen      (mpeg2_debug_req_seen),
	.debug_read_seen     (mpeg2_debug_read_seen),
	.debug_write_seen    (mpeg2_debug_write_seen),
	.debug_response_seen (mpeg2_debug_response_seen)
);

assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = 1'b1;

assign VGA_DE = mpeg2_pixel_en;
assign VGA_HS = mpeg2_h_sync;
assign VGA_VS = mpeg2_v_sync;
assign VGA_R = mpeg2_r;
assign VGA_G = mpeg2_g;
assign VGA_B = mpeg2_b;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER =
	mpeg2_debug_pixel_underflow_seen |
	mpeg2_debug_bad_header_seen;

endmodule
