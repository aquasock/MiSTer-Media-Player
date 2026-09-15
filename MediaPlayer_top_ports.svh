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
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
        SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
        SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

// Movie PCM is signed stereo, scheduled in the CLK_AUDIO domain by the MP2
// sink and passed through the normal MiSTer audio output/filter path.
wire [15:0] audio_pcm_output_l;
wire [15:0] audio_pcm_output_r;
assign AUDIO_S = 1'b1;
assign AUDIO_L = audio_pcm_output_l;
assign AUDIO_R = audio_pcm_output_r;
assign AUDIO_MIX = 2'd0;

assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

// The OSD alone selects display shape; sequence metadata never overrides it.
wire ar;
video_config_cdc #(.WIDTH(1)) aspect_config (
 .src_clk(clk_sys), .dst_clk(clk_video),
 .src_data(status[121]), .dst_data(ar)
);
assign VIDEO_ARX = ar ? 13'd16 : 13'd4;
assign VIDEO_ARY = ar ? 13'd9 : 13'd3;

`include "build_id.v"
// Status bits 3:1 remain reserved after removal of Audio test.
localparam CONF_STR = {
	"MediaPlayer;;",
	"S0,MPGFL*,Load media;",
`include "MediaPlayer_subtitle_menu.svh"
	"h0P4,Visualizers:;",
	"h0P4O[123:122],Type,Waveforms,FFT,O-Scope;",
	"-;",
	"-;",
	"O[121],Aspect ratio,4:3,16:9;",
	"D0O[6],Refresh rate,59.94 Hz,50 Hz;",
	"D0O[5:4],Color matrix,Auto,BT.601,BT.709;",

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

