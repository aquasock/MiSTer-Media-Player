assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = 1'b1;
assign VGA_DE = fb_video_de;
assign VGA_HS = fb_video_hs;
assign VGA_VS = fb_video_vs;
assign VGA_R = cadence_video_r;
assign VGA_G = cadence_video_g;
assign VGA_B = cadence_video_b;

// Entry 245: development-only hardware cadence snapshot. Every input is an
// already registered top-level boundary. The profiler has no control output,
// and its overlay appears after either a quiet drain or the bounded terminal
// diagnostic timeout.
wire mpeg2_new_cadence_session_quiet =
    mpeg2_new_sequence_end_seen &&
    mpeg2_new_b_presentation_complete &&
    !mpeg2_new_b_scheduler_debug_state[26] &&
    mpeg2_stream_empty &&
    !mpeg2_new_decode_stream_valid &&
    !mpeg2_new_frame_waiting &&
    !mpeg2_new_b_presentation_hold &&
    !mpeg2_new_p_destination_ownership_hold &&
    !mpeg2_new_pred_rd &&
    !mpeg2_new_ddr_wr_we &&
    (!av_is_ps || mp2_finished_sync[2]);

wire [15:0] mpeg2_new_cadence_error_flags = {
    1'b0,(|media_telemetry[227:224]),
    mp2_timestamp_error_sync[2],
    mp2_underrun_sync[2],
    mp2_error,
    mpeg2_demux_error,
    mpeg2_new_b_presentation_error,
    mpeg2_new_ddr_cache_error,
    mpeg2_new_ddr_store_error,
    mpeg2_new_recon_error,
    mpeg2_new_idct_error,
    mpeg2_new_inverse_quant_unsupported_matrix,
    mpeg2_new_inverse_quant_error,
    mpeg2_new_pred_error,
    mpeg2_new_phase1_probe_error,
    mpeg2_new_syntax_error
};

reg [11:0] telemetry_h_d,telemetry_h,telemetry_v_d,telemetry_v;
always @(posedge clk_video) begin
    telemetry_h_d <= display_h_pos; telemetry_h <= telemetry_h_d;
    telemetry_v_d <= display_v_pos; telemetry_v <= telemetry_v_d;
end

mpeg2_h262_hardware_cadence_profiler #(
`ifdef MMP_DETAILED_TELEMETRY
    .DETAILED_TELEMETRY(1)
`else
    .DETAILED_TELEMETRY(0)
`endif
) mpeg2_h262_hardware_cadence_profiler
(
    .transport_status(media_telemetry),
    .audio_frames(mp2_frames_decoded),.audio_samples(mp2_samples_count),
    .audio_status({25'd0,mp2_timestamp_error_sync[2],mp2_underrun_sync[2],mp2_error,
        mp2_finished_sync[2],mp2_eof_queued,mp2_idle,av_is_ps}),
    .clk_mpeg2                 (clk_mpeg2),
    .reset_mpeg2               (reset_mpeg2),
    .clk_video                 (clk_video),
    .reset_video               (reset_video),
    .fifo_pending              (!mpeg2_stream_empty),
    .decoder_ready             (mpeg2_new_decoder_stream_ready),
    .presentation_hold         (mpeg2_new_b_presentation_hold),
    .destination_hold          (mpeg2_new_p_destination_ownership_hold),
    .scratch_available         (mpeg2_new_b_scratch_available),
    .promotion_active          (mpeg2_new_b_promotion_active),
    .frame_waiting             (mpeg2_new_frame_waiting),
    .completed_frame_bank      (mpeg2_new_completed_frame_bank),
    .presentation_complete     (mpeg2_new_b_presentation_complete),
    .presentation_error        (mpeg2_new_b_presentation_error),
    .scheduler_debug_state     (mpeg2_new_b_scheduler_debug_state),
    .decoder_byte_accepted     (mpeg2_new_decode_stream_valid),
    .stc_seconds               (mpeg2_new_stc_seconds),
    .associated_count          (mpeg2_new_associated_count),
    .display_pts               (mpeg2_new_display_pts),
    .top_field_first           (mpeg2_new_top_field_first),
    .repeat_first_field        (mpeg2_new_repeat_first_field),
    .picture_coding_type       (mpeg2_new_picture_coding_type),
    .temporal_reference        (mpeg2_new_temporal_reference),
    .frame_rate_code           (mpeg2_new_frame_rate_code),
    .picture_count             (mpeg2_new_picture_count),
    .reference_picture_complete(mpeg2_new_picture_420_complete),
    .b_picture_complete        (mpeg2_new_b_user_success),
    .prediction_read           (mpeg2_new_pred_rd),
    .prediction_busy           (mpeg2_new_pred_busy),
    .prediction_data_ready     (mpeg2_new_pred_dout_ready),
    .writer_write              (mpeg2_new_ddr_wr_we),
    .writer_busy               (mpeg2_new_ddr_writer_busy),
    .display_frame_bank        (mpeg2_new_display_frame_bank),
    .display_scratch           (mpeg2_new_display_scratch),
    .display_scratch_bank      (mpeg2_new_display_scratch_bank),
    .sequence_end_seen         (mpeg2_new_sequence_end_seen),
    .session_quiet             (mpeg2_new_cadence_session_quiet),
    .error_flags               (mpeg2_new_cadence_error_flags),
    .h_pos                     (telemetry_h),
    .v_pos                     (telemetry_v),
    .base_r                    (fb_video_r),
    .base_g                    (fb_video_g),
    .base_b                    (fb_video_b),
    .base_de                   (fb_video_de),
    .video_r                   (cadence_video_r),
    .video_g                   (cadence_video_g),
    .video_b                   (cadence_video_b),
    .snapshot_ready            (cadence_snapshot_ready)
);

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

// Normal B acceptance requires the clean B decode/persistence result plus the
// proven Commit-139 scratch-then-future-P presentation transaction.
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

// Remove the legacy blink-code diagnostics; screen telemetry retains the
// playback counters and error snapshot. Return LEDs to platform defaults.
assign LED_USER = 1'b0;
assign LED_POWER = 2'b00;
assign LED_DISK = 2'b00;

endmodule
