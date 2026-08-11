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

wire reset = RESET | status[0] | buttons[1];

// kate - Phase 1H: MPEG2FPGA no longer exists in the active design.
// The new H.262 front end owns the FIFO read side directly.  Both current
// standards-driven parsers are byte-stream consumers and accept arbitrary
// gaps, so data is consumed whenever the asynchronous FIFO is non-empty.
assign mpeg2_stream_wr =
	ioctl_download &&
	ioctl_wr &&
	(ioctl_index[5:0] == 6'd1) &&
	!mpeg2_stream_full;

assign mpeg2_stream_rd =
	!mpeg2_stream_empty;

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

// kate - Phase 1H: the legacy MPEG2FPGA DDR frame-store path is gone.
// The present Phase-1J luma-strip proof uses only the on-chip M10K framebuffer.
// Keep the MiSTer DDR service interface completely idle until our own explicit
// frame-store layer is introduced in a later decoder phase.
assign DDRAM_CLK      = clk_mpeg2;
assign DDRAM_BURSTCNT = 8'd0;
assign DDRAM_ADDR     = 29'd0;
assign DDRAM_RD       = 1'b0;
assign DDRAM_DIN      = 64'd0;
assign DDRAM_BE       = 8'd0;
assign DDRAM_WE       = 1'b0;

///////////////////////   VIDEO TIMING   /////////////////////////

wire [11:0] display_h_pos;
wire [11:0] display_v_pos;
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;

wire [7:0]  fb_video_y;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;

// kate - Fixed presentation timing is now instantiated directly by the core.
// There is no MPEG2FPGA wrapper or legacy sync generator between this counter
// and the MiSTer framebuffer/display path.
mpeg2_video_svga_800x600 mpeg2_video_svga_800x600
(
	.clk      (clk_video),
	.reset    (reset),

	.h_pos    (display_h_pos),
	.v_pos    (display_v_pos),
	.pixel_en (display_pixel_en),
	.h_sync   (display_h_sync),
	.v_sync   (display_v_sync)
);

///////////////////////   NEW H.262 DECODER   ////////////////////

wire        mpeg2_new_frontend_ready;
wire        mpeg2_new_phase1_supported;
wire        mpeg2_new_syntax_error;
wire        mpeg2_new_sequence_seen;
wire        mpeg2_new_sequence_extension_seen;
wire        mpeg2_new_sequence_scalable_extension_seen;
wire        mpeg2_new_picture_seen;
wire        mpeg2_new_picture_coding_extension_seen;
wire        mpeg2_new_slice_seen;
wire        mpeg2_new_sequence_end_seen;
wire [13:0] mpeg2_new_horizontal_size;
wire [13:0] mpeg2_new_vertical_size;
wire [3:0]  mpeg2_new_aspect_ratio_information;
wire [3:0]  mpeg2_new_frame_rate_code;
wire [7:0]  mpeg2_new_profile_and_level_indication;
wire        mpeg2_new_progressive_sequence;
wire [1:0]  mpeg2_new_chroma_format;
wire [9:0]  mpeg2_new_temporal_reference;
wire [2:0]  mpeg2_new_picture_coding_type;
wire [1:0]  mpeg2_new_intra_dc_precision;
wire [1:0]  mpeg2_new_picture_structure;
wire        mpeg2_new_frame_pred_frame_dct;
wire        mpeg2_new_concealment_motion_vectors;
wire        mpeg2_new_q_scale_type;
wire        mpeg2_new_intra_vlc_format;
wire        mpeg2_new_alternate_scan;
wire        mpeg2_new_progressive_frame;
wire        mpeg2_new_intra_quant_matrix_default;

wire        mpeg2_new_slice_header_seen;
wire        mpeg2_new_macroblock_address_seen;
wire        mpeg2_new_first_i_macroblock_seen;
wire        mpeg2_new_first_luma_dc_seen;
wire        mpeg2_new_first_luma_block_complete;
wire        mpeg2_new_first_macroblock_luma_parsed;
wire        mpeg2_new_luma_macroblock_start;
wire        mpeg2_new_phase1_probe_error;
wire [4:0]  mpeg2_new_slice_quantiser_scale_code;
wire [11:0] mpeg2_new_macroblock_address_increment;
wire        mpeg2_new_macroblock_quant;
wire [4:0]  mpeg2_new_macroblock_quantiser_scale_code;
wire [7:0]  mpeg2_new_slice_vertical_position;
wire [2:0]  mpeg2_new_slice_vertical_position_extension;
wire [3:0]  mpeg2_new_first_luma_dc_size;
wire signed [12:0] mpeg2_new_first_luma_dc_differential;
wire [10:0] mpeg2_new_first_luma_dc_coefficient;
wire [6:0]  mpeg2_new_first_luma_ac_nonzero_count;
wire [5:0]  mpeg2_new_first_luma_last_coeff_index;
wire signed [11:0] mpeg2_new_first_luma_last_ac_level;
wire        mpeg2_new_qfs_block_start;
wire        mpeg2_new_qfs_write_en;
wire [5:0]  mpeg2_new_qfs_write_index;
wire signed [12:0] mpeg2_new_qfs_write_value;
wire        mpeg2_new_qfs_block_end;

wire        mpeg2_new_inverse_quant_complete;
wire        mpeg2_new_inverse_quant_error;
wire        mpeg2_new_inverse_quant_unsupported_matrix;
wire signed [11:0] mpeg2_new_first_luma_f00;
wire signed [11:0] mpeg2_new_first_luma_f77;
wire        mpeg2_new_iq_coeff_block_start;
wire        mpeg2_new_iq_coeff_valid;
wire [5:0]  mpeg2_new_iq_coeff_index;
wire signed [11:0] mpeg2_new_iq_coeff_value;
wire        mpeg2_new_iq_coeff_block_end;

wire        mpeg2_new_idct_complete;
wire        mpeg2_new_idct_error;
wire        mpeg2_new_idct_sample_valid;
wire [5:0]  mpeg2_new_idct_sample_index;
wire signed [15:0] mpeg2_new_idct_sample_value;
wire signed [15:0] mpeg2_new_first_luma_sample00;
wire signed [15:0] mpeg2_new_first_luma_sample77;

wire        mpeg2_new_recon_pixel_valid;
wire [11:0] mpeg2_new_recon_pixel_x;
wire [11:0] mpeg2_new_recon_pixel_y;
wire [7:0]  mpeg2_new_recon_pixel_luma;
wire        mpeg2_new_recon_block_start;
wire        mpeg2_new_recon_block_complete;
wire        mpeg2_new_recon_macroblock_luma_complete;
wire        mpeg2_new_recon_error;
wire [11:0] mpeg2_new_recon_block_origin_x;
wire [11:0] mpeg2_new_recon_block_origin_y;

wire [4:0] mpeg2_new_effective_quantiser_scale_code =
	mpeg2_new_macroblock_quant ?
		mpeg2_new_macroblock_quantiser_scale_code :
		mpeg2_new_slice_quantiser_scale_code;

// kate - Standards-driven H.262 header parser.  Phase 1H is the first build in
// which this parser is not sharing its compressed input with MPEG2FPGA.
mpeg2_h262_frontend mpeg2_h262_frontend
(
	.clk                              (clk_mpeg2),
	.reset                            (reset),
	.stream_data                      (mpeg2_stream_data),
	.stream_valid                     (mpeg2_stream_rd),

	.frontend_ready                   (mpeg2_new_frontend_ready),
	.phase1_supported                 (mpeg2_new_phase1_supported),
	.syntax_error                     (mpeg2_new_syntax_error),

	.sequence_seen                    (mpeg2_new_sequence_seen),
	.sequence_extension_seen          (mpeg2_new_sequence_extension_seen),
	.sequence_scalable_extension_seen (mpeg2_new_sequence_scalable_extension_seen),
	.picture_seen                     (mpeg2_new_picture_seen),
	.picture_coding_extension_seen    (mpeg2_new_picture_coding_extension_seen),
	.slice_seen                       (mpeg2_new_slice_seen),
	.sequence_end_seen                (mpeg2_new_sequence_end_seen),

	.horizontal_size                  (mpeg2_new_horizontal_size),
	.vertical_size                    (mpeg2_new_vertical_size),
	.aspect_ratio_information         (mpeg2_new_aspect_ratio_information),
	.frame_rate_code                  (mpeg2_new_frame_rate_code),
	.profile_and_level_indication     (mpeg2_new_profile_and_level_indication),
	.progressive_sequence             (mpeg2_new_progressive_sequence),
	.chroma_format                    (mpeg2_new_chroma_format),

	.temporal_reference               (mpeg2_new_temporal_reference),
	.picture_coding_type              (mpeg2_new_picture_coding_type),
	.intra_dc_precision               (mpeg2_new_intra_dc_precision),
	.picture_structure                (mpeg2_new_picture_structure),
	.frame_pred_frame_dct             (mpeg2_new_frame_pred_frame_dct),
	.concealment_motion_vectors       (mpeg2_new_concealment_motion_vectors),
	.q_scale_type                     (mpeg2_new_q_scale_type),
	.intra_vlc_format                 (mpeg2_new_intra_vlc_format),
	.alternate_scan                   (mpeg2_new_alternate_scan),
	.progressive_frame                (mpeg2_new_progressive_frame),
	.intra_quant_matrix_default       (mpeg2_new_intra_quant_matrix_default)
);

// kate - Phase 1J first-slice progression.  The probe reconstructs Y blocks
// 0..3 for the first four macroblocks, consumes Cb/Cr block syntax to reach the
// following macroblock, and waits for the one-block pipeline between Y blocks.
mpeg2_h262_luma4_probe mpeg2_h262_luma4_probe
(
	.clk                         (clk_mpeg2),
	.reset                       (reset),
	.stream_data                 (mpeg2_stream_data),
	.stream_valid                (mpeg2_stream_rd),
	.phase1_supported            (mpeg2_new_phase1_supported),
	.vertical_size               (mpeg2_new_vertical_size),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.intra_vlc_format            (mpeg2_new_intra_vlc_format),
	.pipeline_block_done         (mpeg2_new_recon_block_complete),

	.slice_header_seen           (mpeg2_new_slice_header_seen),
	.macroblock_address_seen     (mpeg2_new_macroblock_address_seen),
	.first_i_macroblock_seen     (mpeg2_new_first_i_macroblock_seen),
	.first_luma_dc_seen          (mpeg2_new_first_luma_dc_seen),
	.first_luma_block_complete   (mpeg2_new_first_luma_block_complete),
	.first_macroblock_luma_parsed(mpeg2_new_first_macroblock_luma_parsed),
	.probe_error                 (mpeg2_new_phase1_probe_error),
	.quantiser_scale_code        (mpeg2_new_slice_quantiser_scale_code),
	.macroblock_address_increment(mpeg2_new_macroblock_address_increment),
	.macroblock_quant            (mpeg2_new_macroblock_quant),
	.macroblock_quantiser_scale_code(mpeg2_new_macroblock_quantiser_scale_code),
	.slice_vertical_position     (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension(mpeg2_new_slice_vertical_position_extension),
	.first_luma_dc_size          (mpeg2_new_first_luma_dc_size),
	.first_luma_dc_differential  (mpeg2_new_first_luma_dc_differential),
	.first_luma_dc_coefficient   (mpeg2_new_first_luma_dc_coefficient),
	.first_luma_ac_nonzero_count (mpeg2_new_first_luma_ac_nonzero_count),
	.first_luma_last_coeff_index (mpeg2_new_first_luma_last_coeff_index),
	.first_luma_last_ac_level    (mpeg2_new_first_luma_last_ac_level),
	.luma_macroblock_start       (mpeg2_new_luma_macroblock_start),

	.qfs_block_start             (mpeg2_new_qfs_block_start),
	.qfs_write_en                (mpeg2_new_qfs_write_en),
	.qfs_write_index             (mpeg2_new_qfs_write_index),
	.qfs_write_value             (mpeg2_new_qfs_write_value),
	.qfs_block_end               (mpeg2_new_qfs_block_end)
);

// kate - H.262 inverse scan, inverse quantisation, saturation and mismatch
// control for each submitted luminance block.
mpeg2_h262_inverse_quant mpeg2_h262_inverse_quant
(
	.clk                         (clk_mpeg2),
	.reset                       (reset),

	.block_start                 (mpeg2_new_qfs_block_start),
	.coeff_write_en              (mpeg2_new_qfs_write_en),
	.coeff_write_index           (mpeg2_new_qfs_write_index),
	.coeff_write_value           (mpeg2_new_qfs_write_value),
	.block_end                   (mpeg2_new_qfs_block_end),

	.intra_quant_matrix_default  (mpeg2_new_intra_quant_matrix_default),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.quantiser_scale_code        (mpeg2_new_effective_quantiser_scale_code),
	.q_scale_type                (mpeg2_new_q_scale_type),
	.alternate_scan              (mpeg2_new_alternate_scan),

	.block_complete              (mpeg2_new_inverse_quant_complete),
	.iq_error                    (mpeg2_new_inverse_quant_error),
	.unsupported_matrix          (mpeg2_new_inverse_quant_unsupported_matrix),
	.first_luma_f00              (mpeg2_new_first_luma_f00),
	.first_luma_f77              (mpeg2_new_first_luma_f77),

	.coeff_out_block_start       (mpeg2_new_iq_coeff_block_start),
	.coeff_out_valid             (mpeg2_new_iq_coeff_valid),
	.coeff_out_index             (mpeg2_new_iq_coeff_index),
	.coeff_out_value             (mpeg2_new_iq_coeff_value),
	.coeff_out_block_end         (mpeg2_new_iq_coeff_block_end)
);

// kate - H.262 inverse DCT.
mpeg2_h262_idct mpeg2_h262_idct
(
	.clk                         (clk_mpeg2),
	.reset                       (reset),

	.coeff_block_start           (mpeg2_new_iq_coeff_block_start),
	.coeff_valid                 (mpeg2_new_iq_coeff_valid),
	.coeff_index                 (mpeg2_new_iq_coeff_index),
	.coeff_value                 (mpeg2_new_iq_coeff_value),
	.coeff_block_end             (mpeg2_new_iq_coeff_block_end),

	.block_complete              (mpeg2_new_idct_complete),
	.idct_error                  (mpeg2_new_idct_error),
	.sample_valid                (mpeg2_new_idct_sample_valid),
	.sample_index                (mpeg2_new_idct_sample_index),
	.sample_value                (mpeg2_new_idct_sample_value),
	.first_luma_sample00         (mpeg2_new_first_luma_sample00),
	.first_luma_sample77         (mpeg2_new_first_luma_sample77)
);

// kate - H.262 intra reconstruction and explicit picture coordinates.
mpeg2_h262_intra_recon mpeg2_h262_intra_recon
(
	.clk                                (clk_mpeg2),
	.reset                              (reset),

	.horizontal_size                    (mpeg2_new_horizontal_size),
	.vertical_size                      (mpeg2_new_vertical_size),
	.slice_vertical_position            (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension  (mpeg2_new_slice_vertical_position_extension),
	.macroblock_address_increment       (mpeg2_new_macroblock_address_increment),
	.macroblock_start                   (mpeg2_new_luma_macroblock_start),

	.sample_valid                       (mpeg2_new_idct_sample_valid),
	.sample_index                       (mpeg2_new_idct_sample_index),
	.sample_value                       (mpeg2_new_idct_sample_value),
	.idct_block_complete                (mpeg2_new_idct_complete),

	.pixel_valid                        (mpeg2_new_recon_pixel_valid),
	.pixel_x                            (mpeg2_new_recon_pixel_x),
	.pixel_y                            (mpeg2_new_recon_pixel_y),
	.pixel_luma                         (mpeg2_new_recon_pixel_luma),
	.block_start                        (mpeg2_new_recon_block_start),
	.block_complete                     (mpeg2_new_recon_block_complete),
	.macroblock_luma_complete           (mpeg2_new_recon_macroblock_luma_complete),
	.recon_error                        (mpeg2_new_recon_error),
	.block_origin_x                     (mpeg2_new_recon_block_origin_x),
	.block_origin_y                     (mpeg2_new_recon_block_origin_y)
);

///////////////////////   LUMA FRAMEBUFFER   //////////////////////

// kate - New-decoder pixels write at 54 MHz; the fixed 800x600 raster reads at
// 40 MHz.  MPEG2FPGA is not present on either side of this memory.
mpeg2_luma_framebuffer mpeg2_luma_framebuffer
(
	.reset       (reset),

	.wr_clk      (clk_mpeg2),
	.wr_y        (mpeg2_new_recon_pixel_luma),
	.wr_x_pos    (mpeg2_new_recon_pixel_x),
	.wr_y_pos    (mpeg2_new_recon_pixel_y),
	.wr_en       (mpeg2_new_recon_pixel_valid),
	.wr_macroblock_start (mpeg2_new_luma_macroblock_start),
	.wr_block_start    (mpeg2_new_recon_block_start),
	.wr_block_complete (mpeg2_new_recon_block_complete),

	.rd_clk      (clk_video),
	.h_pos       (display_h_pos),
	.v_pos       (display_v_pos),
	.pixel_en    (display_pixel_en),
	.h_sync      (display_h_sync),
	.v_sync      (display_v_sync),

	.video_y     (fb_video_y),
	.video_de    (fb_video_de),
	.video_hs    (fb_video_hs),
	.video_vs    (fb_video_vs)
);

assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = 1'b1;

assign VGA_DE = fb_video_de;
assign VGA_HS = fb_video_hs;
assign VGA_VS = fb_video_vs;

assign VGA_R = fb_video_y;
assign VGA_G = fb_video_y;
assign VGA_B = fb_video_y;

// kate - Phase 1J positive diagnostic.
// OFF: the first four intra macroblocks have not completed the luma path, or an
// earlier decoder stage reported an error.
// ON: sixteen Y blocks (1024 reconstructed luma samples) reached our framebuffer.
assign LED_USER =
	mpeg2_new_first_macroblock_luma_parsed &&
	mpeg2_new_recon_macroblock_luma_complete &&
	!mpeg2_new_syntax_error &&
	!mpeg2_new_phase1_probe_error &&
	!mpeg2_new_inverse_quant_error &&
	!mpeg2_new_inverse_quant_unsupported_matrix &&
	!mpeg2_new_idct_error &&
	!mpeg2_new_recon_error;

endmodule
