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
    .stream_data(mpeg2_stream_data),
    .stream_valid(mpeg2_new_decode_stream_valid),
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
	.dct_type                           (mpeg2_new_dct_type),
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

wire mpeg2_new_luma_writer_word;
wire [2:0] mpeg2_new_luma_writer_region;
wire mpeg2_new_luma_writer_row_parity;
wire mpeg2_new_luma_writer_picture_start;
wire mpeg2_new_luma_writer_picture_complete;
wire [31:0] mpeg2_new_luma_writer_position_fingerprint;

mpeg2_h262_ddram_store mpeg2_h262_ddram_store
(
	.clk             (clk_mpeg2),
	.reset           (reset_mpeg2),
	.frame_bank      (mpeg2_new_active_frame_bank),
	// Entry 650: only the reconstruction path carries field-DCT blocks;
	// the P store path is frame-ordered.
	.field_dct       (!mpeg2_new_p_store_select && mpeg2_new_dct_type),
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
