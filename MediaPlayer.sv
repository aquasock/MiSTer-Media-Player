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
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

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

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"MediaPlayer;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,1;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

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
	
	.ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys)
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

wire        mpeg2_mem_res_wr_almost_full;

media_player media_player
(
	.clk(clk_sys),
	.reset(reset),

	.ce_pix(ce_pix),

	.HBlank(HBlank),
	.HSync(HSync),
	.VBlank(VBlank),
	.VSync(VSync),

	.video(video)
);

mpeg2_decoder mpeg2_decoder
(
	.clk                    (clk_sys),
	.reset                  (reset),

	.stream_data            (status[15:8]),
	.stream_valid           (status[16]),

	.mem_res_wr_dta         ({8{status[24:17]}}),
	.mem_res_wr_en          (status[25]),
	.mem_req_rd_en          (status[26]),

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

	.mem_res_wr_almost_full (mpeg2_mem_res_wr_almost_full)
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;
assign VGA_R = video;
assign VGA_G = video;
assign VGA_B = video;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER = ~(mpeg2_busy | mpeg2_error);

endmodule
