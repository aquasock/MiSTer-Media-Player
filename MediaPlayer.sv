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
wire        mpeg2_new_stream_ready;

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

// kate - Phase 1P CDC/reset closure.
//
// RESET, status[0], and buttons[1] originate outside the MPEG/video clock
// domains.  Treat their OR as an asynchronous reset request, then synchronize
// reset RELEASE independently into each destination domain.  Assertion is
// asynchronous into these small synchronizer chains, so even a short request
// is stretched until the destination clock has observed it.
//
// This is an implementation/timing-safety change, not an H.262 requirement.
wire reset_request = RESET | status[0] | buttons[1];

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_mpeg2_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_video_sync;

always @(posedge clk_mpeg2 or posedge reset_request) begin
	if (reset_request)
		reset_mpeg2_sync <= 3'b111;
	else
		reset_mpeg2_sync <= {reset_mpeg2_sync[1:0], 1'b0};
end

always @(posedge clk_video or posedge reset_request) begin
	if (reset_request)
		reset_video_sync <= 3'b111;
	else
		reset_video_sync <= {reset_video_sync[1:0], 1'b0};
end

wire reset_mpeg2 = reset_mpeg2_sync[2];
wire reset_video = reset_video_sync[2];

// kate - Phase 1Ob: the streaming H.262 bitreader continues to own input
// backpressure while picture_data() advances across every slice of the first
// supported I-picture.  Slice boundaries remain inside the bitreader so no
// alignment or payload bytes are discarded.
// Before the first slice is selected, bytes flow continuously for start-code/header
// parsing.  During slice parsing the bitreader stalls this FIFO whenever its
// current payload byte has not been fully consumed, including IQ/IDCT waits.
assign mpeg2_stream_wr =
	ioctl_download &&
	ioctl_wr &&
	(ioctl_index[5:0] == 6'd1) &&
	!mpeg2_stream_full;

assign mpeg2_stream_rd =
	!mpeg2_stream_empty &&
	mpeg2_new_stream_ready;

mpeg2_stream_fifo mpeg2_stream_fifo
(
	// kate - DCFIFO owns reset-release synchronization for wr_clk and rd_clk.
	.reset    (reset_request),

	.wr_clk   (clk_sys),
	.wr_data  (mpeg2_stream_wr ? ioctl_dout : 8'd0),
	.wr_en    (mpeg2_stream_wr),
	.wr_full  (mpeg2_stream_full),

	.rd_clk   (clk_mpeg2),
	.rd_en    (mpeg2_stream_rd),
	.rd_data  (mpeg2_stream_data),
	.rd_empty (mpeg2_stream_empty)
);

// The DDR service and Phase 1S/1T clients run in the decoder clock domain.
assign DDRAM_CLK = clk_mpeg2;

///////////////////////   VIDEO TIMING   /////////////////////////

wire [11:0] display_h_pos;
wire [11:0] display_v_pos;
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;

wire [7:0]  fb_video_r;
wire [7:0]  fb_video_g;
wire [7:0]  fb_video_b;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;

mpeg2_video_svga_800x600 mpeg2_video_svga_800x600
(
	.clk      (clk_video),
	.reset    (reset_video),
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
wire [3:0]  mpeg2_new_forward_f_code_horizontal;
wire [3:0]  mpeg2_new_forward_f_code_vertical;
wire [3:0]  mpeg2_new_backward_f_code_horizontal;
wire [3:0]  mpeg2_new_backward_f_code_vertical;
wire        mpeg2_new_motion_f_code_seen;
wire        mpeg2_new_intra_quant_matrix_default;

wire        mpeg2_new_slice_header_seen;
wire        mpeg2_new_macroblock_address_seen;
wire        mpeg2_new_first_i_macroblock_seen;
wire        mpeg2_new_first_luma_dc_seen;
wire        mpeg2_new_first_luma_block_complete;
wire        mpeg2_new_first_picture_420_parsed;
wire        mpeg2_new_second_picture_420_parsed;
wire        mpeg2_new_picture_420_complete;
wire        mpeg2_new_active_frame_bank;
wire        mpeg2_new_completed_frame_bank;
wire [7:0]  mpeg2_new_picture_count;
wire        mpeg2_new_reference_frame_valid;
wire        mpeg2_new_reference_frame_bank;
wire [7:0]  mpeg2_new_reference_promotion_count;
wire        mpeg2_new_p_macroblock_type_seen;
wire        mpeg2_new_p_forward_vector_valid;
wire signed [12:0] mpeg2_new_p_forward_vector_x;
wire signed [12:0] mpeg2_new_p_forward_vector_y;
wire        mpeg2_new_p_residual_required;
wire        mpeg2_new_p_residual_success;
wire        mpeg2_new_p_first_residual_sample_valid;
wire signed [15:0] mpeg2_new_p_first_residual_sample_value;
wire        mpeg2_new_p_residual_sample_valid;
wire [5:0]  mpeg2_new_p_residual_sample_index;
wire signed [15:0] mpeg2_new_p_residual_sample_value;
wire        mpeg2_new_slice_start;
wire        mpeg2_new_luma_macroblock_start;
wire        mpeg2_new_phase1_probe_error;
wire        mpeg2_new_b_user_success;
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
wire [2:0]  mpeg2_new_qfs_block_index;
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
wire [1:0]  mpeg2_new_recon_pixel_component;
wire [11:0] mpeg2_new_recon_pixel_x;
wire [11:0] mpeg2_new_recon_pixel_y;
wire [7:0]  mpeg2_new_recon_pixel_value;
wire        mpeg2_new_recon_block_start;
wire        mpeg2_new_recon_block_complete;
wire        mpeg2_new_recon_macroblock_420_complete;
wire        mpeg2_new_recon_error;
wire [11:0] mpeg2_new_recon_block_origin_x;
wire [11:0] mpeg2_new_recon_block_origin_y;

wire        mpeg2_new_ddr_block_stored;
wire        mpeg2_new_ddr_write_seen;
wire        mpeg2_new_ddr_store_error;

wire [7:0]  mpeg2_new_ddr_wr_burstcnt;
wire [28:0] mpeg2_new_ddr_wr_addr;
wire        mpeg2_new_ddr_wr_rd;
wire [63:0] mpeg2_new_ddr_wr_din;
wire [7:0]  mpeg2_new_ddr_wr_be;
wire        mpeg2_new_ddr_wr_we;
wire        mpeg2_new_ddr_writer_busy;

wire [7:0]  mpeg2_new_ddr_rd_burstcnt;
wire [28:0] mpeg2_new_ddr_rd_addr;
wire [28:0] mpeg2_new_ddr_rd_banked_addr;
wire        mpeg2_new_ddr_rd;
wire        mpeg2_new_ddr_reader_busy;
wire        mpeg2_new_ddr_reader_dout_ready;

wire [7:0]  mpeg2_new_pred_burstcnt;
wire [28:0] mpeg2_new_pred_addr;
wire        mpeg2_new_pred_rd;
wire        mpeg2_new_pred_busy;
wire        mpeg2_new_pred_dout_ready;
wire        mpeg2_new_pred_read_seen;
wire [7:0]  mpeg2_new_pred_sample_value;
wire        mpeg2_new_pred_sample_nonzero;
wire        mpeg2_new_pred_half_sample_seen;
wire        mpeg2_new_pred_reconstructed_seen;
wire [7:0]  mpeg2_new_pred_reconstructed_value;
wire        mpeg2_new_pred_persisted_seen;
wire        mpeg2_new_pred_error;

wire        mpeg2_new_p_store_select;
wire [7:0]  mpeg2_new_p_store_pixel_value;
wire [11:0] mpeg2_new_p_store_pixel_x;
wire [11:0] mpeg2_new_p_store_pixel_y;
wire        mpeg2_new_p_store_pixel_valid;
wire        mpeg2_new_p_store_block_start;
wire        mpeg2_new_p_store_block_complete;

wire        mpeg2_new_ddr_cache_ready;
wire        mpeg2_new_ddr_read_seen;
wire        mpeg2_new_ddr_cache_error;

wire [4:0] mpeg2_new_effective_quantiser_scale_code =
	mpeg2_new_macroblock_quant ?
		mpeg2_new_macroblock_quantiser_scale_code :
		mpeg2_new_slice_quantiser_scale_code;

wire mpeg2_new_phase1n_frame_geometry_supported =
	(mpeg2_new_horizontal_size != 14'd0) &&
	(mpeg2_new_vertical_size   != 14'd0) &&
	(mpeg2_new_horizontal_size <= 14'd720) &&
	(mpeg2_new_vertical_size   <= 14'd480);

mpeg2_h262_frontend mpeg2_h262_frontend
(
	.clk                              (clk_mpeg2),
	.reset                            (reset_mpeg2),
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
	.forward_f_code_horizontal        (mpeg2_new_forward_f_code_horizontal),
	.forward_f_code_vertical          (mpeg2_new_forward_f_code_vertical),
	.backward_f_code_horizontal       (mpeg2_new_backward_f_code_horizontal),
	.backward_f_code_vertical         (mpeg2_new_backward_f_code_vertical),
	.motion_f_code_seen               (mpeg2_new_motion_f_code_seen),
	.intra_quant_matrix_default       (mpeg2_new_intra_quant_matrix_default)
);

mpeg2_h262_two_picture_probe mpeg2_h262_two_picture_probe
(
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
	.stream_data                 (mpeg2_stream_data),
	.stream_valid                (mpeg2_stream_rd),
	.stream_ready                (mpeg2_new_stream_ready),
	.phase1_supported            (mpeg2_new_phase1_supported),
	.vertical_size               (mpeg2_new_vertical_size),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.intra_vlc_format            (mpeg2_new_intra_vlc_format),
	.pipeline_block_done         (mpeg2_new_ddr_block_stored),
	.recon_block_complete        (mpeg2_new_recon_block_complete),
	.p_persistence_complete      (mpeg2_new_pred_persisted_seen),
	.slice_header_seen           (mpeg2_new_slice_header_seen),
	.macroblock_address_seen     (mpeg2_new_macroblock_address_seen),
	.first_i_macroblock_seen     (mpeg2_new_first_i_macroblock_seen),
	.first_luma_dc_seen          (mpeg2_new_first_luma_dc_seen),
	.first_luma_block_complete   (mpeg2_new_first_luma_block_complete),
	.first_picture_420_parsed    (mpeg2_new_first_picture_420_parsed),
	.second_picture_420_parsed   (mpeg2_new_second_picture_420_parsed),
	.picture_420_complete        (mpeg2_new_picture_420_complete),
	.active_frame_bank           (mpeg2_new_active_frame_bank),
	.completed_frame_bank        (mpeg2_new_completed_frame_bank),
	.picture_count               (mpeg2_new_picture_count),
	.reference_frame_valid       (mpeg2_new_reference_frame_valid),
	.reference_frame_bank        (mpeg2_new_reference_frame_bank),
	.reference_promotion_count   (mpeg2_new_reference_promotion_count),
	.p_macroblock_type_seen      (mpeg2_new_p_macroblock_type_seen),
	.p_forward_vector_valid      (mpeg2_new_p_forward_vector_valid),
	.p_forward_vector_x          (mpeg2_new_p_forward_vector_x),
	.p_forward_vector_y          (mpeg2_new_p_forward_vector_y),
	.p_residual_required         (mpeg2_new_p_residual_required),
	.p_residual_success          (mpeg2_new_p_residual_success),
	.p_first_residual_sample_valid(mpeg2_new_p_first_residual_sample_valid),
	.p_first_residual_sample_value(mpeg2_new_p_first_residual_sample_value),
	.p_residual_sample_valid     (mpeg2_new_p_residual_sample_valid),
	.p_residual_sample_index     (mpeg2_new_p_residual_sample_index),
	.p_residual_sample_value     (mpeg2_new_p_residual_sample_value),
	.probe_error                 (mpeg2_new_phase1_probe_error),
	.b_user_success              (mpeg2_new_b_user_success),
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
	.slice_start                 (mpeg2_new_slice_start),
	.luma_macroblock_start       (mpeg2_new_luma_macroblock_start),
	.qfs_block_index             (mpeg2_new_qfs_block_index),
	.qfs_block_start             (mpeg2_new_qfs_block_start),
	.qfs_write_en                (mpeg2_new_qfs_write_en),
	.qfs_write_index             (mpeg2_new_qfs_write_index),
	.qfs_write_value             (mpeg2_new_qfs_write_value),
	.qfs_block_end               (mpeg2_new_qfs_block_end)
);

mpeg2_h262_inverse_quant mpeg2_h262_inverse_quant
(
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
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

mpeg2_h262_idct mpeg2_h262_idct
(
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
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

mpeg2_h262_intra_recon mpeg2_h262_intra_recon
(
	.clk                                (clk_mpeg2),
	.reset                              (reset_mpeg2),
	.horizontal_size                    (mpeg2_new_horizontal_size),
	.vertical_size                      (mpeg2_new_vertical_size),
	.slice_vertical_position            (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension  (mpeg2_new_slice_vertical_position_extension),
	.macroblock_address_increment       (mpeg2_new_macroblock_address_increment),
	.slice_start                        (mpeg2_new_slice_start),
	.macroblock_start                   (mpeg2_new_luma_macroblock_start),
	.block_index                        (mpeg2_new_qfs_block_index),
	.sample_valid                       (mpeg2_new_idct_sample_valid),
	.sample_index                       (mpeg2_new_idct_sample_index),
	.sample_value                       (mpeg2_new_idct_sample_value),
	.idct_block_complete                (mpeg2_new_idct_complete),
	.pixel_valid                        (mpeg2_new_recon_pixel_valid),
	.pixel_component                    (mpeg2_new_recon_pixel_component),
	.pixel_x                            (mpeg2_new_recon_pixel_x),
	.pixel_y                            (mpeg2_new_recon_pixel_y),
	.pixel_value                        (mpeg2_new_recon_pixel_value),
	.block_start                        (mpeg2_new_recon_block_start),
	.block_complete                     (mpeg2_new_recon_block_complete),
	.macroblock_420_complete            (mpeg2_new_recon_macroblock_420_complete),
	.recon_error                        (mpeg2_new_recon_error),
	.block_origin_x                     (mpeg2_new_recon_block_origin_x),
	.block_origin_y                     (mpeg2_new_recon_block_origin_y)
);

mpeg2_h262_ddram_store mpeg2_h262_ddram_store
(
	.clk             (clk_mpeg2),
	.reset           (reset_mpeg2),
	.frame_bank      (mpeg2_new_active_frame_bank),
	.pixel_value     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_value :
	                  mpeg2_new_recon_pixel_value),
	.pixel_component (mpeg2_new_p_store_select ?
	                  2'd0 :
	                  mpeg2_new_recon_pixel_component),
	.pixel_x         (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_x :
	                  mpeg2_new_recon_pixel_x),
	.pixel_y         (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_y :
	                  mpeg2_new_recon_pixel_y),
	.pixel_valid     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_valid :
	                  mpeg2_new_recon_pixel_valid),
	.block_start     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_block_start :
	                  mpeg2_new_recon_block_start),
	.block_complete  (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_block_complete :
	                  mpeg2_new_recon_block_complete),
	.block_stored    (mpeg2_new_ddr_block_stored),
	.write_seen      (mpeg2_new_ddr_write_seen),
	.store_error     (mpeg2_new_ddr_store_error),
	.ddram_busy      (mpeg2_new_ddr_writer_busy),
	.ddram_burstcnt  (mpeg2_new_ddr_wr_burstcnt),
	.ddram_addr      (mpeg2_new_ddr_wr_addr),
	.ddram_rd        (mpeg2_new_ddr_wr_rd),
	.ddram_din       (mpeg2_new_ddr_wr_din),
	.ddram_be        (mpeg2_new_ddr_wr_be),
	.ddram_we        (mpeg2_new_ddr_wr_we)
);

// kate - Phase 1T-o: the controlled pattern-only P macroblock has no explicit
// forward vector. Once its complete first-Y0 transform is available, the
// prediction client reconstructs the full 8x8 luma block from real reference
// rows plus the 64 live residual samples, emits it through the ordinary DDR
// block writer, and verifies all eight destination row words by readback.
wire mpeg2_new_phase1t_implicit_reconstruct_required =
    mpeg2_new_p_residual_required &&
    mpeg2_new_p_residual_success &&
    mpeg2_new_p_first_residual_sample_valid &&
    !mpeg2_new_p_forward_vector_valid;

mpeg2_h262_reference_read_probe mpeg2_h262_reference_read_probe
(
    .clk                       (clk_mpeg2),
    .reset                     (reset_mpeg2),
    // kate - Phase 1T-y: connect live coded horizontal geometry at top level.
    .horizontal_size           (mpeg2_new_horizontal_size),
    // kate - Phase 1U-c: connect live coded vertical geometry at top level.
    .vertical_size             (mpeg2_new_vertical_size),
    .p_vector_proof_seen       (mpeg2_new_p_macroblock_type_seen),
    .p_forward_vector_valid    (mpeg2_new_p_forward_vector_valid),
    .p_forward_vector_x        (mpeg2_new_p_forward_vector_x),
    .p_forward_vector_y        (mpeg2_new_p_forward_vector_y),
    .forward_f_code_horizontal (mpeg2_new_forward_f_code_horizontal),
    .forward_f_code_vertical   (mpeg2_new_forward_f_code_vertical),
    .p_implicit_reconstruct_request(mpeg2_new_phase1t_implicit_reconstruct_required),
    .p_residual_sample_valid   (mpeg2_new_p_residual_sample_valid),
    .p_residual_sample_index   (mpeg2_new_p_residual_sample_index),
    .p_residual_sample_value   (mpeg2_new_p_residual_sample_value),
    .reference_frame_valid     (mpeg2_new_reference_frame_valid),
    .reference_frame_bank      (mpeg2_new_reference_frame_bank),
    .destination_frame_bank    (mpeg2_new_active_frame_bank),
    .p_store_block_stored      (mpeg2_new_ddr_block_stored),
    .ddram_busy                (mpeg2_new_pred_busy),
    .ddram_dout                (DDRAM_DOUT),
    .ddram_dout_ready          (mpeg2_new_pred_dout_ready),
    .ddram_burstcnt            (mpeg2_new_pred_burstcnt),
    .ddram_addr                (mpeg2_new_pred_addr),
    .ddram_rd                  (mpeg2_new_pred_rd),
    .p_store_select            (mpeg2_new_p_store_select),
    .p_store_pixel_value       (mpeg2_new_p_store_pixel_value),
    .p_store_pixel_x           (mpeg2_new_p_store_pixel_x),
    .p_store_pixel_y           (mpeg2_new_p_store_pixel_y),
    .p_store_pixel_valid       (mpeg2_new_p_store_pixel_valid),
    .p_store_block_start       (mpeg2_new_p_store_block_start),
    .p_store_block_complete    (mpeg2_new_p_store_block_complete),
    .read_seen                 (mpeg2_new_pred_read_seen),
    .sample_value              (mpeg2_new_pred_sample_value),
    .sample_nonzero            (mpeg2_new_pred_sample_nonzero),
    .half_sample_seen          (mpeg2_new_pred_half_sample_seen),
    .reconstructed_seen        (mpeg2_new_pred_reconstructed_seen),
    .reconstructed_value       (mpeg2_new_pred_reconstructed_value),
    .persisted_seen            (mpeg2_new_pred_persisted_seen),
    .probe_error               (mpeg2_new_pred_error)
);

reg       mpeg2_new_display_frame_bank;
reg       mpeg2_new_display_scratch;
reg [2:0] mpeg2_new_framebuffer_swap_reset_count;
reg       mpeg2_new_pending_frame_valid;
reg       mpeg2_new_pending_frame_bank;
reg       mpeg2_new_swap_window_video;
reg       mpeg2_new_b_user_success_d;
reg       mpeg2_new_b_picture_frontend_d;
reg       mpeg2_new_b_reorder_active;
reg       mpeg2_new_b_scratch_pending;
reg       mpeg2_new_b_future_frame_pending;
reg       mpeg2_new_b_future_frame_bank;
reg       mpeg2_new_b_scratch_presented;
reg       mpeg2_new_b_presentation_complete;
reg       mpeg2_new_b_presentation_error;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_swap_window_sync;

always @(posedge clk_video) begin
    if (reset_video)
        mpeg2_new_swap_window_video <= 1'b0;
    else
        mpeg2_new_swap_window_video <= (display_v_pos >= 12'd600);
end

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2)
        mpeg2_new_swap_window_sync <= 3'b000;
    else
        mpeg2_new_swap_window_sync <=
            {mpeg2_new_swap_window_sync[1:0], mpeg2_new_swap_window_video};
end

wire mpeg2_new_swap_window_pulse =
    mpeg2_new_swap_window_sync[1] && !mpeg2_new_swap_window_sync[2];

wire mpeg2_new_b_user_success_edge =
    mpeg2_new_b_user_success && !mpeg2_new_b_user_success_d;
wire mpeg2_new_b_picture_frontend_active =
    mpeg2_new_picture_seen && (mpeg2_new_picture_coding_type == 3'b011);
wire mpeg2_new_b_picture_start_edge =
    mpeg2_new_b_picture_frontend_active && !mpeg2_new_b_picture_frontend_d;
wire mpeg2_new_b_future_waiting =
    mpeg2_new_b_future_frame_pending && mpeg2_new_b_scratch_presented;

wire mpeg2_new_frame_waiting =
    mpeg2_new_picture_420_complete &&
    mpeg2_new_first_picture_420_parsed &&
    (mpeg2_new_display_scratch ||
     (mpeg2_new_completed_frame_bank != mpeg2_new_display_frame_bank));

// Commit 139 adds one non-reference presentation slot.  The controlled stream
// is coded I / future-P / B.  Bank 0 already displays the first I picture; the
// completed future P remains pending while B reconstructs into fixed scratch
// storage.  Once B persistence is proven, scratch gets the next swap and the
// retained future-P bank gets the following swap.  B never becomes a reference.
wire mpeg2_new_b_scratch_waiting =
    mpeg2_new_b_scratch_pending || mpeg2_new_b_user_success_edge;
wire mpeg2_new_scheduled_frame_valid =
    mpeg2_new_b_scratch_waiting ||
    mpeg2_new_b_future_waiting ||
    (!mpeg2_new_b_reorder_active &&
     !mpeg2_new_b_picture_start_edge &&
     (mpeg2_new_frame_waiting || mpeg2_new_pending_frame_valid));
wire mpeg2_new_scheduled_frame_scratch = mpeg2_new_b_scratch_waiting;
wire mpeg2_new_scheduled_frame_bank =
    mpeg2_new_b_future_waiting ?
        mpeg2_new_b_future_frame_bank :
    mpeg2_new_frame_waiting ?
        mpeg2_new_completed_frame_bank :
        mpeg2_new_pending_frame_bank;
wire mpeg2_new_scheduled_frame_differs =
    mpeg2_new_scheduled_frame_scratch ?
        !mpeg2_new_display_scratch :
        (mpeg2_new_display_scratch ||
         (mpeg2_new_scheduled_frame_bank != mpeg2_new_display_frame_bank));

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_display_frame_bank            <= 1'b0;
        mpeg2_new_display_scratch               <= 1'b0;
        mpeg2_new_framebuffer_swap_reset_count  <= 3'd0;
        mpeg2_new_pending_frame_valid           <= 1'b0;
        mpeg2_new_pending_frame_bank            <= 1'b0;
        mpeg2_new_b_user_success_d              <= 1'b0;
        mpeg2_new_b_picture_frontend_d          <= 1'b0;
        mpeg2_new_b_reorder_active              <= 1'b0;
        mpeg2_new_b_scratch_pending             <= 1'b0;
        mpeg2_new_b_future_frame_pending        <= 1'b0;
        mpeg2_new_b_future_frame_bank           <= 1'b0;
        mpeg2_new_b_scratch_presented           <= 1'b0;
        mpeg2_new_b_presentation_complete       <= 1'b0;
        mpeg2_new_b_presentation_error          <= 1'b0;
    end
    else begin
        mpeg2_new_b_user_success_d     <= mpeg2_new_b_user_success;
        mpeg2_new_b_picture_frontend_d <= mpeg2_new_b_picture_frontend_active;

        if (mpeg2_new_frame_waiting &&
            !mpeg2_new_b_reorder_active &&
            !mpeg2_new_b_picture_start_edge &&
            !mpeg2_new_b_user_success_edge) begin
            mpeg2_new_pending_frame_valid <= 1'b1;
            mpeg2_new_pending_frame_bank  <= mpeg2_new_completed_frame_bank;
        end

        if (mpeg2_new_b_picture_start_edge) begin
            mpeg2_new_b_reorder_active       <= 1'b1;
            mpeg2_new_b_scratch_pending      <= 1'b0;
            mpeg2_new_b_future_frame_pending <= 1'b1;
            mpeg2_new_b_future_frame_bank    <= mpeg2_new_reference_frame_bank;
            mpeg2_new_b_scratch_presented    <= 1'b0;
            mpeg2_new_b_presentation_complete<= 1'b0;
            mpeg2_new_pending_frame_valid    <= 1'b0;
            if (mpeg2_new_display_scratch ||
                (mpeg2_new_display_frame_bank == mpeg2_new_reference_frame_bank))
                mpeg2_new_b_presentation_error <= 1'b1;
        end

        if (mpeg2_new_b_user_success_edge) begin
            if (!mpeg2_new_b_reorder_active)
                mpeg2_new_b_presentation_error <= 1'b1;
            mpeg2_new_b_scratch_pending <= 1'b1;
        end

        if (mpeg2_new_swap_window_pulse &&
            mpeg2_new_scheduled_frame_valid &&
            mpeg2_new_scheduled_frame_differs) begin
            mpeg2_new_display_scratch <= mpeg2_new_scheduled_frame_scratch;
            if (!mpeg2_new_scheduled_frame_scratch)
                mpeg2_new_display_frame_bank <= mpeg2_new_scheduled_frame_bank;
            mpeg2_new_framebuffer_swap_reset_count <= 3'd4;

            if (mpeg2_new_b_scratch_waiting) begin
                mpeg2_new_b_scratch_pending   <= 1'b0;
                mpeg2_new_b_scratch_presented <= 1'b1;
            end
            else if (mpeg2_new_b_future_waiting) begin
                mpeg2_new_b_future_frame_pending <= 1'b0;
                mpeg2_new_b_reorder_active       <= 1'b0;
                mpeg2_new_pending_frame_valid    <= 1'b0;
                if (mpeg2_new_b_scratch_presented &&
                    !mpeg2_new_b_presentation_error)
                    mpeg2_new_b_presentation_complete <= 1'b1;
                else
                    mpeg2_new_b_presentation_error <= 1'b1;
            end
            else begin
                mpeg2_new_pending_frame_valid <= 1'b0;
            end
        end
        else if (mpeg2_new_framebuffer_swap_reset_count != 3'd0) begin
            mpeg2_new_framebuffer_swap_reset_count <=
                mpeg2_new_framebuffer_swap_reset_count - 3'd1;
        end
    end
end

wire mpeg2_new_framebuffer_reset =
    reset_mpeg2 || (mpeg2_new_framebuffer_swap_reset_count != 3'd0);

localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK_WORDS    = 29'h00010000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH_WORDS = 29'h00020000;
wire [28:0] mpeg2_new_display_frame_offset =
    mpeg2_new_display_scratch ? MPEG2_NEW_DDR_FRAME_SCRATCH_WORDS :
    mpeg2_new_display_frame_bank ? MPEG2_NEW_DDR_FRAME_BANK_WORDS : 29'd0;
assign mpeg2_new_ddr_rd_banked_addr =
    mpeg2_new_ddr_rd_addr + mpeg2_new_display_frame_offset;


mpeg2_luma_framebuffer mpeg2_luma_framebuffer
(
    .reset          (mpeg2_new_framebuffer_reset),
    .mem_clk        (clk_mpeg2),
    .picture_complete(mpeg2_new_first_picture_420_parsed),
    .horizontal_size(mpeg2_new_horizontal_size),
    .vertical_size  (mpeg2_new_vertical_size),
    .ddram_busy     (mpeg2_new_ddr_reader_busy),
    .ddram_dout     (DDRAM_DOUT),
    .ddram_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .ddram_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .ddram_addr     (mpeg2_new_ddr_rd_addr),
    .ddram_rd       (mpeg2_new_ddr_rd),
    .cache_ready    (mpeg2_new_ddr_cache_ready),
    .read_seen      (mpeg2_new_ddr_read_seen),
    .cache_error    (mpeg2_new_ddr_cache_error),
    .rd_clk         (clk_video),
    .h_pos          (display_h_pos),
    .v_pos          (display_v_pos),
    .pixel_en       (display_pixel_en),
    .h_sync         (display_h_sync),
    .v_sync         (display_v_sync),
    .video_r        (fb_video_r),
    .video_g        (fb_video_g),
    .video_b        (fb_video_b),
    .video_de       (fb_video_de),
    .video_hs       (fb_video_hs),
    .video_vs       (fb_video_vs)
);

mpeg2_h262_ddram_arbiter mpeg2_h262_ddram_arbiter
(
    .clk             (clk_mpeg2),
    .reset           (reset_mpeg2),
    .writer_burstcnt (mpeg2_new_ddr_wr_burstcnt),
    .writer_addr     (mpeg2_new_ddr_wr_addr),
    .writer_rd       (mpeg2_new_ddr_wr_rd),
    .writer_din      (mpeg2_new_ddr_wr_din),
    .writer_be       (mpeg2_new_ddr_wr_be),
    .writer_we       (mpeg2_new_ddr_wr_we),
    .writer_busy     (mpeg2_new_ddr_writer_busy),
    .reader_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .reader_addr     (mpeg2_new_ddr_rd_banked_addr),
    .reader_rd       (mpeg2_new_ddr_rd),
    .reader_busy     (mpeg2_new_ddr_reader_busy),
    .reader_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .prediction_burstcnt (mpeg2_new_pred_burstcnt),
    .prediction_addr     (mpeg2_new_pred_addr),
    .prediction_rd       (mpeg2_new_pred_rd),
    .prediction_busy     (mpeg2_new_pred_busy),
    .prediction_dout_ready(mpeg2_new_pred_dout_ready),
    .ddram_busy      (DDRAM_BUSY),
    .ddram_dout_ready(DDRAM_DOUT_READY),
    .ddram_burstcnt  (DDRAM_BURSTCNT),
    .ddram_addr      (DDRAM_ADDR),
    .ddram_rd        (DDRAM_RD),
    .ddram_din       (DDRAM_DIN),
    .ddram_be        (DDRAM_BE),
    .ddram_we        (DDRAM_WE)
);

assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = 1'b1;
assign VGA_DE = fb_video_de;
assign VGA_HS = fb_video_hs;
assign VGA_VS = fb_video_vs;
assign VGA_R = fb_video_r;
assign VGA_G = fb_video_g;
assign VGA_B = fb_video_b;

wire mpeg2_new_phase1s_all_i_user_success =
    mpeg2_new_first_picture_420_parsed &&
    mpeg2_new_second_picture_420_parsed &&
    (mpeg2_new_picture_count >= 8'd3) &&
    (mpeg2_new_completed_frame_bank == mpeg2_new_display_frame_bank);

wire mpeg2_new_phase1t_integer_read_required =
    mpeg2_new_p_forward_vector_valid &&
    (mpeg2_new_p_forward_vector_x == 13'sd4) &&
    (mpeg2_new_p_forward_vector_y == 13'sd0) &&
    (mpeg2_new_forward_f_code_horizontal == 4'd1) &&
    (mpeg2_new_forward_f_code_vertical   == 4'd1);

wire mpeg2_new_phase1t_halfpel_read_required =
    mpeg2_new_p_forward_vector_valid &&
    (mpeg2_new_p_forward_vector_x == 13'sd3) &&
    (mpeg2_new_p_forward_vector_y == 13'sd0) &&
    (mpeg2_new_forward_f_code_horizontal == 4'd2) &&
    (mpeg2_new_forward_f_code_vertical   == 4'd2);

wire mpeg2_new_phase1t_reference_read_required =
    mpeg2_new_phase1t_integer_read_required ||
    mpeg2_new_phase1t_halfpel_read_required;

wire mpeg2_new_phase1t_reference_read_ok =
    !mpeg2_new_phase1t_reference_read_required ||
    (mpeg2_new_pred_read_seen &&
     mpeg2_new_pred_sample_nonzero &&
     (!mpeg2_new_phase1t_halfpel_read_required ||
      mpeg2_new_pred_half_sample_seen));

// kate - Phase 1T-l requires the implicit pattern-only path to complete the
// real prediction + residual + clipping proof. No fixed expected pel value is
// invented; the prediction and residual are both live data from this stream.
wire mpeg2_new_phase1t_implicit_reconstruct_ok =
    !mpeg2_new_phase1t_implicit_reconstruct_required ||
    mpeg2_new_pred_reconstructed_seen;

wire mpeg2_new_phase1t_p_syntax_user_success =
    mpeg2_new_p_macroblock_type_seen &&
    mpeg2_new_first_picture_420_parsed &&
    mpeg2_new_second_picture_420_parsed &&
    (mpeg2_new_picture_count >= 8'd2) &&
    (mpeg2_new_completed_frame_bank == mpeg2_new_display_frame_bank) &&
    mpeg2_new_phase1t_reference_read_ok &&
    mpeg2_new_phase1t_implicit_reconstruct_ok;

wire unused_phase1t_reconstructed_value = &{1'b0, mpeg2_new_pred_reconstructed_value};

// Commit 138 retires the temporary B pulse diagnostics.  B acceptance is
// now a first-class success result exported by the publication shell after the
// real B core has completed and the non-reference scratch frame has persisted.
// The accepted all-I and P success branches remain unchanged.
wire mpeg2_new_b_presentation_user_success =
    mpeg2_new_b_user_success &&
    mpeg2_new_b_presentation_complete &&
    !mpeg2_new_b_presentation_error;

wire mpeg2_new_normal_user_led =
    (mpeg2_new_phase1s_all_i_user_success ||
     mpeg2_new_phase1t_p_syntax_user_success ||
     mpeg2_new_b_presentation_user_success) &&

    mpeg2_new_recon_macroblock_420_complete &&
    mpeg2_new_phase1n_frame_geometry_supported &&
    !mpeg2_new_syntax_error &&
    !mpeg2_new_phase1_probe_error &&
    !mpeg2_new_pred_error &&
    !mpeg2_new_inverse_quant_error &&
    !mpeg2_new_inverse_quant_unsupported_matrix &&
    !mpeg2_new_idct_error &&
    !mpeg2_new_recon_error &&
    mpeg2_new_ddr_write_seen &&
    !mpeg2_new_ddr_store_error &&
    mpeg2_new_ddr_cache_ready &&
    mpeg2_new_ddr_read_seen &&
    !mpeg2_new_ddr_cache_error;

assign LED_USER = mpeg2_new_normal_user_led;

endmodule
