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
wire [4:0]  mpeg2_new_syntax_error_source;
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
wire        mpeg2_new_chroma_420_type;
// Entry 365: extracted for interlaced operation and 3:2 pulldown; carried
// into the cadence snapshot only, not yet consumed by presentation.
wire        mpeg2_new_top_field_first;
// Entry 369: picture metadata supplied by the HPS in band with the
// elementary stream.  Distinct from the frontend's parsed fields above:
// these come from the container, those from the bitstream.
wire [32:0] mpeg2_new_inband_pts_90k;
wire [1:0]  mpeg2_new_inband_picture_structure;
wire        mpeg2_new_inband_top_field_first;
wire        mpeg2_new_inband_repeat_first_field;
wire        mpeg2_new_inband_progressive_frame;
wire        mpeg2_new_inband_valid;
wire [7:0]  mpeg2_new_inband_count;
// Entry 372: timestamps carried through frame ownership to the displayed frame.
wire [32:0] mpeg2_new_display_pts;
wire        mpeg2_new_display_pts_valid;
wire [7:0]  mpeg2_new_associated_count;
// Entry 389: timestamp-driven candidate presentation.  The scheduler exports
// only its already-stable next identity; timestamp ownership supplies the
// matching bank value and the local 90 kHz timeline decides when it is due.
wire        mpeg2_new_candidate_frame_valid;
wire        mpeg2_new_candidate_frame_scratch;
wire        mpeg2_new_candidate_scratch_bank;
wire [1:0]  mpeg2_new_candidate_frame_bank;
wire [32:0] mpeg2_new_candidate_pts;
wire        mpeg2_new_candidate_pts_valid;
wire        mpeg2_new_timestamp_candidate_active;
wire        mpeg2_new_timestamp_candidate_due;
wire        mpeg2_new_pts_timeline_anchored;
wire [32:0] mpeg2_new_pts_timeline_stc;
wire        mpeg2_new_repeat_first_field;
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
wire [1:0]  mpeg2_new_active_frame_bank;
wire [1:0]  mpeg2_new_completed_frame_bank;
wire [7:0]  mpeg2_new_picture_count;
wire        mpeg2_new_reference_frame_valid;
wire [1:0]  mpeg2_new_reference_frame_bank;
wire [1:0]  mpeg2_new_previous_reference_frame_bank;
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
wire        mpeg2_new_b_motion_transport;
wire        mpeg2_new_slice_start;
wire        mpeg2_new_luma_macroblock_start;
wire        mpeg2_new_phase1_probe_error;
wire [3:0]  mpeg2_new_phase1_probe_error_source;
// kate - Commit 180 observability only.
wire [3:0]  mpeg2_new_p_probe_error_source;
wire [3:0]  mpeg2_new_p_progress_detail;
wire [2:0]  mpeg2_new_publication_error_detail;
wire [4:0]  mpeg2_new_p_wide_probe_error_detail;
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
