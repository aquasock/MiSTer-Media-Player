wire        mpeg2_new_pred_sample_nonzero;
wire        mpeg2_new_pred_half_sample_seen;
wire        mpeg2_new_pred_reconstructed_seen;
wire [7:0]  mpeg2_new_pred_reconstructed_value;
wire        mpeg2_new_pred_persisted_seen;
wire [3:0]  mpeg2_new_pred_progress_stage;
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
	.stream_ready                (mpeg2_new_decoder_stream_ready),
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
	.probe_error_source          (mpeg2_new_phase1_probe_error_source),
	.p_probe_error_source        (mpeg2_new_p_probe_error_source),
	.p_progress_detail           (mpeg2_new_p_progress_detail),
