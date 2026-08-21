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
    .previous_reference_frame_bank(mpeg2_new_previous_reference_frame_bank),
    .destination_frame_bank    (mpeg2_new_active_frame_bank),
    .b_scratch_frame_bank      (mpeg2_new_b_decode_scratch_bank),
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
    .row_persisted             (mpeg2_new_pred_row_persisted),
    .p_progress_stage          (mpeg2_new_pred_progress_stage),
    .probe_error               (mpeg2_new_pred_error),
    .probe_error_source        (mpeg2_new_pred_error_source),
    .probe_error_detail        (mpeg2_new_pred_error_detail)
);

wire [1:0] mpeg2_new_display_frame_bank;
wire      mpeg2_new_display_scratch;
wire      mpeg2_new_display_scratch_bank;
wire [2:0] mpeg2_new_framebuffer_swap_reset_count;
reg       mpeg2_new_swap_window_video;
wire      mpeg2_new_b_presentation_complete;
// Entry 282: scheduler observability taps consumed only by the cadence
// profiler's unconditional hold-attribution counters.
wire      mpeg2_new_b_scratch_available;
wire      mpeg2_new_b_promotion_active;
wire      mpeg2_new_b_presentation_error;
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

wire mpeg2_new_frame_waiting =
    mpeg2_new_picture_420_complete &&
    mpeg2_new_first_picture_420_parsed &&
