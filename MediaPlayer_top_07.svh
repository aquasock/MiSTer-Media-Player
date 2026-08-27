assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = display_pixel_ce;
assign VGA_F1 = display_field;
assign VGA_DE = presentation_base_de;
assign VGA_HS = presentation_base_hs;
assign VGA_VS = presentation_base_vs;
assign VGA_R = cadence_video_r;
assign VGA_G = cadence_video_g;
assign VGA_B = cadence_video_b;

// Static field-invariant bars and a frame-stepped field-invariant moving bar
// exercise the complete native sync/timing and processed-HDMI scaler path
// without reading a framebuffer pixel or line cache. Since the MPEG pipeline
// remains active, the moving mode distinguishes retained content after the
// final FPGA mux from retained framebuffer/DDRAM data delivery.
mpeg2_native_timing_pattern mpeg2_native_timing_pattern
(
    .clk          (clk_video),
    .reset        (reset_video),
    .moving       (display_native_timing_pattern_moving),
    .frame_window (display_frame_window),
    .h_pos        (display_h_pos),
    .v_pos        (display_v_pos),
    .pixel_en     (display_pixel_en),
    .h_sync       (display_h_sync),
    .v_sync       (display_v_sync),
    .video_r      (native_pattern_r),
    .video_g      (native_pattern_g),
    .video_b      (native_pattern_b),
    .video_de     (native_pattern_de),
    .video_hs     (native_pattern_hs),
    .video_vs     (native_pattern_vs)
);

assign presentation_base_r = display_native_timing_pattern ?
                             native_pattern_r : (mpeg2_new_startup_video_blank ? 8'd0 : fb_video_r);
assign presentation_base_g = display_native_timing_pattern ?
                             native_pattern_g : (mpeg2_new_startup_video_blank ? 8'd0 : fb_video_g);
assign presentation_base_b = display_native_timing_pattern ?
                             native_pattern_b : (mpeg2_new_startup_video_blank ? 8'd0 : fb_video_b);
assign presentation_base_de = display_native_timing_pattern ?
                              native_pattern_de : fb_video_de;
assign presentation_base_hs = display_native_timing_pattern ?
                              native_pattern_hs : fb_video_hs;
assign presentation_base_vs = display_native_timing_pattern ?
                              native_pattern_vs : fb_video_vs;

// Entry 245: development-only hardware cadence snapshot. Every input is an
// already registered top-level boundary. The profiler has no control output,
// and its overlay appears after either a quiet drain or the bounded terminal
// diagnostic timeout.
wire mpeg2_new_cadence_session_quiet =
    mpeg2_new_startup_swaps_enabled &&
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
    !audio_pcm_terminal_pending;

wire [15:0] mpeg2_new_cadence_error_flags = {
    3'd0,
    mpeg2_new_ddr_bank_overlap_error,
    mpeg2_new_inband_pcm_protocol_error,
    audio_pcm_underrun_sync[1],
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

mpeg2_h262_hardware_cadence_profiler #(
    .PROFILE_START_STC_SECONDS(14'd0)
)
mpeg2_h262_hardware_cadence_profiler
(
    .clk_mpeg2                 (clk_mpeg2),
    .reset_mpeg2               (reset_mpeg2),
    .clk_video                 (clk_video),
    .reset_video               (reset_video),
    .pixel_ce                  (display_pixel_ce),
    .native_active             (display_native_interlaced),
    .framebuffer_generation_reset(
        mpeg2_new_framebuffer_generation_reset),
    .framebuffer_picture_present(
        mpeg2_new_framebuffer_picture_present),
    .framebuffer_prefill_deadline_missed(
        mpeg2_new_framebuffer_prefill_deadline_missed),
    .framebuffer_sequence_phase_error(
        mpeg2_new_framebuffer_sequence_phase_error),
    .framebuffer_first_field_region(mpeg2_new_first_field_region),
    .framebuffer_second_field_region(mpeg2_new_second_field_region),
    .framebuffer_luma_fetch_valid(mpeg2_new_luma_fetch_valid),
    .framebuffer_luma_fetch_first_field(mpeg2_new_luma_fetch_first_field),
    .framebuffer_luma_fetch_row(mpeg2_new_luma_fetch_row),
    .framebuffer_display_region(mpeg2_new_display_region),
    .framebuffer_cache_write_valid(mpeg2_new_luma_cache_write_valid),
    .framebuffer_cache_write_first_field(
        mpeg2_new_luma_cache_write_first_field),
    .framebuffer_cache_write_addr(mpeg2_new_luma_cache_write_addr),
    .framebuffer_luma_return_valid(mpeg2_new_luma_return_valid),
    .framebuffer_luma_return_first_field(mpeg2_new_luma_return_first_field),
    .framebuffer_luma_return_byte(mpeg2_new_luma_return_byte),
    .framebuffer_luma_fingerprint_valid(mpeg2_new_luma_fingerprint_valid),
    .framebuffer_luma_fingerprint_first_field(
        mpeg2_new_luma_fingerprint_first_field),
    .framebuffer_luma_fingerprint_raw(mpeg2_new_luma_fingerprint_raw),
    .framebuffer_luma_fingerprint_display(mpeg2_new_luma_fingerprint_display),
    .framebuffer_luma_fingerprint_mismatch(
        mpeg2_new_luma_fingerprint_mismatch),
    .framebuffer_luma_provenance_valid(
        mpeg2_new_luma_provenance_valid),
    .framebuffer_luma_provenance_first_field(
        mpeg2_new_luma_provenance_first_field),
    .framebuffer_luma_provenance_tag_mismatch(
        mpeg2_new_luma_provenance_tag_mismatch),
    .framebuffer_luma_provenance_content_mismatch(
        mpeg2_new_luma_provenance_content_mismatch),
    .framebuffer_luma_provenance_expected_bank(
        mpeg2_new_luma_provenance_expected_bank),
    .framebuffer_luma_provenance_tagged_bank(
        mpeg2_new_luma_provenance_tagged_bank),
    .framebuffer_luma_provenance_expected_row(
        mpeg2_new_luma_provenance_expected_row),
    .framebuffer_luma_provenance_tagged_row(
        mpeg2_new_luma_provenance_tagged_row),
    .framebuffer_luma_provenance_expected_generation(
        mpeg2_new_luma_provenance_expected_generation),
    .framebuffer_luma_provenance_tagged_generation(
        mpeg2_new_luma_provenance_tagged_generation),
    .framebuffer_luma_provenance_raw_fingerprint(
        mpeg2_new_luma_provenance_raw_fingerprint),
    .framebuffer_luma_provenance_display_fingerprint(
        mpeg2_new_luma_provenance_display_fingerprint),
    .framebuffer_luma_write_read_valid(
        mpeg2_new_luma_write_read_valid),
    .framebuffer_luma_write_read_first_field(
        mpeg2_new_luma_write_read_first_field),
    .framebuffer_luma_write_read_expected_valid(
        mpeg2_new_luma_write_read_expected_valid),
    .framebuffer_luma_write_read_region(
        mpeg2_new_luma_write_read_region),
    .framebuffer_luma_write_read_expected_fingerprint(
        mpeg2_new_luma_write_read_expected_fingerprint),
    .framebuffer_luma_write_read_raw_fingerprint(
        mpeg2_new_luma_write_read_raw_fingerprint),
    .framebuffer_luma_write_read_mismatch(
        mpeg2_new_luma_write_read_mismatch),
    .framebuffer_first_field_fetch(
        mpeg2_new_framebuffer_first_field_fetch_toggle),
    .framebuffer_second_field_fetch(
        mpeg2_new_framebuffer_second_field_fetch_toggle),
    .fifo_pending              (!mpeg2_stream_empty),
    .native_decode_active      (mpeg2_new_native_active_mpeg2),
    .decoder_input_pending     (mpeg2_new_clean_video_pending),
    .writer_capacity_blocked   (mpeg2_new_ddr_capture_blocked),
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
    .swap_window_pulse         (mpeg2_new_swap_window_pulse),
    .candidate_presentable     (mpeg2_new_b_candidate_presentable_debug),
    .timestamp_candidate_active(mpeg2_new_timestamp_candidate_active),
    .timestamp_candidate_due   (mpeg2_new_timestamp_candidate_due),
    .cadence_slot              (mpeg2_new_b_cadence_slot_debug),
    .decoder_byte_accepted     (mpeg2_new_decode_stream_valid),
    .stc_seconds               (mpeg2_new_stc_seconds),
    .associated_count          (mpeg2_new_associated_count),
    .display_pts               (mpeg2_new_display_pts),
    .pcm_sample_count          (mpeg2_new_inband_pcm_sample_count),
    .pcm_fifo_peak             (audio_pcm_fifo_peak),
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
    .terminal_defer            (audio_pcm_terminal_pending),
    .error_flags               (mpeg2_new_cadence_error_flags),
    .h_pos                     (display_h_pos),
    .v_pos                     (display_v_pos),
    .base_r                    (presentation_base_r),
    .base_g                    (presentation_base_g),
    .base_b                    (presentation_base_b),
    .base_de                   (presentation_base_de),
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

// kate - Commit 177 error-identification diagnostic.
//
// Commit-176 hardware read POWER ON / DISK OFF / USER OFF on all three P-final
// streams and all three ON on test_i_baseline.  Presentation is therefore clean
// and a decode/DDR error is latching instead, which is the opposite of the
// mechanism the static trace had favoured.  One bit cannot say which of the
// nine error flags fired, so the flags are priority-encoded and blinked out on
// LED_USER.  LED_DISK returns to its ioctl_download file-load duty in
// MediaPlayer_top_00.svh; LED_POWER keeps the presentation bit.
//
// LED_USER encoding:
//   steady ON        - no error latched and the stream is accepted
//   steady OFF       - no error latched but not accepted (acceptance
//                      prerequisites failed: picture_count,
//                      second_picture_420_parsed, p_macroblock_type_seen,
//                      reference_read_ok, implicit_reconstruct_ok)
//   N blinks, pause  - error flag N latched, per the table below
//
//   1 syntax          4 inverse_quant                   7 recon
//   2 phase1_probe    5 inverse_quant_unsupported_matrix 8 ddr_store
//   3 pred            6 idct                            9 ddr_cache
//  10 ddr_cache_bank_overlap
//
// No decode, presentation, ownership or acceptance behavior is altered; the
// acceptance term itself still drives the steady-ON state unchanged.
wire [3:0] mpeg2_new_diag_error_code_live =
    mpeg2_new_syntax_error                     ? 4'd1 :
    mpeg2_new_phase1_probe_error               ? 4'd2 :
    mpeg2_new_pred_error                       ? 4'd3 :
    mpeg2_new_inverse_quant_error              ? 4'd4 :
    mpeg2_new_inverse_quant_unsupported_matrix ? 4'd5 :
    mpeg2_new_idct_error                       ? 4'd6 :
    mpeg2_new_recon_error                      ? 4'd7 :
    mpeg2_new_ddr_store_error                  ? 4'd8 :
    mpeg2_new_ddr_cache_error                  ? 4'd9 :
    mpeg2_new_ddr_bank_overlap_error           ? 4'd10 : 4'd0;

// kate - Commit 178 sub-code diagnostic.
//
// Commit-177 hardware read 2 blinks (phase1_probe_error) on test_p_mba_escape
// and test_consecutive_chain, and steady OFF (no error latched, not accepted)
// on test_p_motion_residual.  Two distinct faults, and neither is named yet:
// probe_error ORs four sources, and the steady-OFF case does not say which
// acceptance term is false.  LED_POWER carried presentation_ok, which read ON
// on every stream and is therefore spent, so it is repurposed to blink the
// sub-code for whichever case USER is reporting.
//
// LED_POWER when USER blinks 2 (probe_error) - probe_error source.  Commit
// 179: the instantiated macrofunction is mpeg2_h262_two_picture_probe_p_chain
// (files.qip), whose probe_error is five terms, not the eight this table
// originally assumed from the uncompiled base two_picture_probe.sv:
//   1 bookkeeper_error (gated)  2 p_error_raw (gated)
//   3 b_error                   4 publication_error
//   5 reference_progress_error
//
// LED_POWER when USER is steady OFF - first false acceptance term:
//   1 p_macroblock_type_seen        2 first_picture_420_parsed
//   3 second_picture_420_parsed     4 picture_count < 2
//   5 completed != display          6 reference_read_ok
//   7 implicit_reconstruct_ok       8 recon_macroblock_420_complete
//   9 phase1n_frame_geometry_supported
//  10 ddr_write_seen               11 ddr_cache_ready
//  12 ddr_read_seen
//
// Otherwise LED_POWER is steady ON.  Observability only: no decode,
// presentation, ownership or acceptance behavior changes.
//
// Commit 199 extends the same hierarchy when USER blinks 3 (pred_error):
// POWER 1 plan adapter, 2 generalized P raster, 3 B raster/history,
// 4 legacy/base probe.  DISK then reports the selected raster engine's first
// internal assertion number; plan/base have no internal detail and report 0.
wire [3:0] mpeg2_new_diag_prereq_code =
    !mpeg2_new_p_macroblock_type_seen          ? 4'd1  :
    !mpeg2_new_first_picture_420_parsed        ? 4'd2  :
    !mpeg2_new_second_picture_420_parsed       ? 4'd3  :
    (mpeg2_new_picture_count < 8'd2)           ? 4'd4  :
    (mpeg2_new_completed_frame_bank !=
     mpeg2_new_display_frame_bank)             ? 4'd5  :
    !mpeg2_new_phase1t_reference_read_ok       ? 4'd6  :
    !mpeg2_new_phase1t_implicit_reconstruct_ok ? 4'd7  :
    !mpeg2_new_recon_macroblock_420_complete   ? 4'd8  :
    !mpeg2_new_phase1n_frame_geometry_supported ? 4'd9 :
    !mpeg2_new_ddr_write_seen                  ? 4'd10 :
    !mpeg2_new_ddr_cache_ready                 ? 4'd11 :
    !mpeg2_new_ddr_read_seen                   ? 4'd12 : 4'd0;

// kate - Commit 180 deepens the sub-code.  Commit-179 hardware read USER 2 /
// POWER 2 on all three P-final streams, i.e. phase1_probe_error sourced from
// p_error_raw, which is itself an eight-term OR in
// mpeg2_h262_p_diagnostic_controller.  When the five-way source is 2, POWER
// now carries that eight-way code instead; every other source value keeps the
// Commit-179 meaning.
//
// The compiled controller is mpeg2_h262_p_diagnostic_controller_rearm.sv
// (files.qip), whose probe_error is nine terms with legacy/wide replacing the
// base file's aligned term.  LED_POWER when USER blinks 2 and the five-way
// source is 2:
//   1 syntax_error      2 two_mb_error       3 four_mb_error
//   4 legacy_error      5 wide_error         6 progress_error
//   7 residual_error_raw 8 hold_error        9 raster_hold_error
// kate - Commit 183.  The observer error flags and their ownership claims are
// sticky/mutable state.  A live priority encoder can therefore relabel an old
// failure later in a multi-picture stream.  Snapshot the complete hierarchy on
// the first cycle that any parent error is visible, and retain it until reset.
// This changes only the LED report; every decode and acceptance signal remains
// connected exactly as before.
reg       mpeg2_new_diag_first_error_valid;
reg [3:0] mpeg2_new_diag_error_code_first;
reg [3:0] mpeg2_new_diag_phase1_source_first;
reg [3:0] mpeg2_new_diag_p_source_first;
reg [3:0] mpeg2_new_diag_progress_detail_first;
reg [2:0] mpeg2_new_diag_publication_detail_first;
reg [4:0] mpeg2_new_diag_p_wide_detail_first;
reg [2:0] mpeg2_new_diag_pred_source_first;
reg [4:0] mpeg2_new_diag_pred_detail_first;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_first_error_valid     <= 1'b0;
        mpeg2_new_diag_error_code_first      <= 4'd0;
        mpeg2_new_diag_phase1_source_first   <= 4'd0;
        mpeg2_new_diag_p_source_first        <= 4'd0;
        mpeg2_new_diag_progress_detail_first <= 4'd0;
        mpeg2_new_diag_publication_detail_first <= 3'd0;
        mpeg2_new_diag_p_wide_detail_first <= 5'd0;
        mpeg2_new_diag_pred_source_first     <= 3'd0;
        mpeg2_new_diag_pred_detail_first     <= 5'd0;
    end
    else if (!mpeg2_new_diag_first_error_valid &&
             (mpeg2_new_diag_error_code_live != 4'd0)) begin
        mpeg2_new_diag_first_error_valid     <= 1'b1;
        mpeg2_new_diag_error_code_first      <= mpeg2_new_diag_error_code_live;
        mpeg2_new_diag_phase1_source_first   <= mpeg2_new_phase1_probe_error_source;
        mpeg2_new_diag_p_source_first        <= mpeg2_new_p_probe_error_source;
        mpeg2_new_diag_progress_detail_first <= mpeg2_new_p_progress_detail;
        mpeg2_new_diag_publication_detail_first <= mpeg2_new_publication_error_detail;
        mpeg2_new_diag_p_wide_detail_first <= mpeg2_new_p_wide_probe_error_detail;
        mpeg2_new_diag_pred_source_first     <= mpeg2_new_pred_error_source;
        mpeg2_new_diag_pred_detail_first     <= mpeg2_new_pred_error_detail;
    end
end

wire [3:0] mpeg2_new_diag_error_code =
    mpeg2_new_diag_first_error_valid ? mpeg2_new_diag_error_code_first : 4'd0;

wire [3:0] mpeg2_new_diag_power_code_live =
    mpeg2_new_diag_first_error_valid ?
        ((mpeg2_new_diag_error_code_first == 4'd2) ?
            ((mpeg2_new_diag_phase1_source_first == 4'd2) ?
                 mpeg2_new_diag_p_source_first :
                 mpeg2_new_diag_phase1_source_first) :
         (mpeg2_new_diag_error_code_first == 4'd3) ?
            {1'b0, mpeg2_new_diag_pred_source_first} : 4'd0) :
        // Commit 192: prerequisites below describe the generalized P path.
        // Once the existing normal I/P/B acceptance result is true, none of
        // those P-only sub-codes is a failure and POWER must stay clear.
        (mpeg2_new_normal_user_led ? 4'd0 : mpeg2_new_diag_prereq_code);

// kate - Commit 180.  progress_error is a symptom, not a root cause: it is
// p_picture_expected && !p_macroblock_type_seen, and that signal is a deep
// conjunction.  When POWER reports 6, LED_DISK names the first false conjunct
// so one build covers both levels:
//   1 mb_seen_combined   2 residual_decision
//   3 residual required but not successful
//   4 hold_seen_combined 5 two_mb_wait      6 raster_wait
// LED_DISK is steady off in every other case; its ioctl_download file-load
// duty is displaced for the duration of this diagnostic.
// kate - Commit 185.  With no error latched and prerequisite 4 remaining,
// POWER proves that both pictures parsed but the P publication count did not
// advance.  DISK now reports the last generalized P raster stage reached:
//   1 admission/capture       2 execution started   3 reference read
//   4 reconstruction emitted 5 DDR store ack       6 verification readback
//   7 persistence asserted
// The prior Commit-180 progress-error detail remains available for its error
// case.  This changes observability only.
// Entry 210 adds publication-error detail when USER is 2 and POWER is 4:
//   1 B header before its P reference published
//   2 later I header before two P publications
//   3 I completion targets the retained reference bank
//   4 P persistence without a valid reference
//   5 P persistence targets the retained reference bank
// When publication detail 1 follows a generalized-P parser fault, DISK shows
// that parser's sticky first-fault code (state plus one, or 26..31) instead.
// Entry 223 uses an otherwise passing DISK window to report the deepest
// post-I50 hardware boundary:
//   1 third I header            2 third I publication
//   3 following P header        4 P raster metadata
//   5 first P row persistence   6 full P persistence
//   7 P reference publication   8 following B header
//   9 B persistence            10 B scratch selected
//  11 future reference presented
// USER and POWER retain all existing acceptance and error meanings.
wire [4:0] mpeg2_new_final_gop_progress_stage;
mpeg2_h262_final_gop_progress_probe mpeg2_h262_final_gop_progress_probe
(
    .clk                  (clk_mpeg2),
    .reset                (reset_mpeg2),
    .picture_header       (mpeg2_new_picture_header_classified_now),
    .picture_header_type  (mpeg2_new_picture_header_type_now),
    .picture_complete     (mpeg2_new_picture_420_complete),
    .picture_coding_type  (mpeg2_new_picture_coding_type),
    .sideband_valid       (mpeg2_new_p_residual_sample_valid),
    .sideband_index       (mpeg2_new_p_residual_sample_index),
    .row_persisted        (mpeg2_new_pred_row_persisted),
    .picture_persisted    (mpeg2_new_pred_persisted_seen),
    .b_success            (mpeg2_new_b_user_success),
    .display_scratch      (mpeg2_new_display_scratch),
    .presentation_complete(mpeg2_new_b_presentation_complete),
    .progress_stage       (mpeg2_new_final_gop_progress_stage)
);

wire [4:0] mpeg2_new_diag_disk_code_live =
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd1)) ?
        mpeg2_new_syntax_error_source :
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd3)) ?
        mpeg2_new_diag_pred_detail_first :
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd2) &&
     (mpeg2_new_diag_phase1_source_first == 4'd4)) ?
        ((mpeg2_new_diag_publication_detail_first == 3'd1) &&
         (mpeg2_new_diag_p_wide_detail_first != 5'd0) ?
            mpeg2_new_diag_p_wide_detail_first :
            {2'b00, mpeg2_new_diag_publication_detail_first}) :
    (!mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_prereq_code == 4'd4)) ?
        {1'b0, mpeg2_new_pred_progress_stage} :
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd2) &&
     (mpeg2_new_diag_phase1_source_first == 4'd2) &&
     (mpeg2_new_diag_p_source_first == 4'd6)) ?
        {1'b0, mpeg2_new_diag_progress_detail_first} :
    (mpeg2_new_normal_user_led &&
     (mpeg2_new_final_gop_progress_stage != 5'd0)) ?
        mpeg2_new_final_gop_progress_stage : 5'd0;

// Commit 189 snapshots only settled post-stream state.  sequence_end_seen is
// sticky; wait one decoder-clock second after it rises so parser, raster, DDR,
// publication and display scheduling have all drained before sampling any live
// prerequisite.  Reset the blink epoch at capture so every test begins at the
// same visible boundary.  The existing slot divider supplies the delay: four
// 250 ms slots are one second, avoiding a second wide counter/comparator.
reg        mpeg2_new_diag_snapshot_valid;
reg [3:0]  mpeg2_new_diag_error_code_snapshot;
reg [3:0]  mpeg2_new_diag_power_code_snapshot;
reg [4:0]  mpeg2_new_diag_disk_code_snapshot;
reg        mpeg2_new_diag_success_snapshot;

// 250 ms slots, divided into non-overlapping windows in a 32-second frame:
// USER 0..23, POWER 24..63, DISK 64..127.  Each numeric code uses alternating
// lit/dark slots local to its window, so simultaneous slot-zero flashes can no
// longer obscure the count.
localparam [23:0] MPEG2_NEW_DIAG_SLOT_CYCLES = 24'd13_500_000;
localparam [6:0]  MPEG2_NEW_DIAG_SLOT_LAST   = 7'd127;
localparam [6:0]  MPEG2_NEW_DIAG_POWER_FIRST = 7'd24;
localparam [6:0]  MPEG2_NEW_DIAG_DISK_FIRST  = 7'd64;

reg [23:0] mpeg2_new_diag_slot_div;
reg [6:0]  mpeg2_new_diag_slot;

wire mpeg2_new_diag_slot_tick =
    (mpeg2_new_diag_slot_div == MPEG2_NEW_DIAG_SLOT_CYCLES - 24'd1);

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_snapshot_valid      <= 1'b0;
        mpeg2_new_diag_error_code_snapshot <= 4'd0;
        mpeg2_new_diag_power_code_snapshot <= 4'd0;
        mpeg2_new_diag_disk_code_snapshot  <= 5'd0;
        mpeg2_new_diag_success_snapshot    <= 1'b0;
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= 7'd0;
    end
    // Entry 219: fail-open masks decoder validity while draining, so a fatal
    // transaction intentionally discards any later sequence-end code.  The
    // sticky fatal result is already settled diagnostic evidence and must arm
    // the same one-second snapshot delay as a normally decoded sequence end.
    else if (!mpeg2_new_diag_snapshot_valid &&
             (mpeg2_new_sequence_end_seen ||
              mpeg2_new_transport_fatal_error)) begin
        if (mpeg2_new_diag_slot_tick && (mpeg2_new_diag_slot == 7'd3)) begin
            mpeg2_new_diag_snapshot_valid      <= 1'b1;
            mpeg2_new_diag_error_code_snapshot <= mpeg2_new_diag_error_code;
            mpeg2_new_diag_power_code_snapshot <= mpeg2_new_diag_power_code_live;
            mpeg2_new_diag_disk_code_snapshot  <= mpeg2_new_diag_disk_code_live;
            mpeg2_new_diag_success_snapshot    <= mpeg2_new_normal_user_led;
            mpeg2_new_diag_slot_div            <= 24'd0;
            mpeg2_new_diag_slot                <= 7'd0;
        end
        else if (mpeg2_new_diag_slot_tick) begin
            mpeg2_new_diag_slot_div <= 24'd0;
            mpeg2_new_diag_slot     <= mpeg2_new_diag_slot + 7'd1;
        end
        else begin
            mpeg2_new_diag_slot_div <= mpeg2_new_diag_slot_div + 24'd1;
        end
    end
    else if (mpeg2_new_diag_snapshot_valid && mpeg2_new_diag_slot_tick) begin
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= (mpeg2_new_diag_slot == MPEG2_NEW_DIAG_SLOT_LAST) ?
                                   7'd0 : mpeg2_new_diag_slot + 7'd1;
    end
    else if (mpeg2_new_diag_snapshot_valid) begin
        mpeg2_new_diag_slot_div <= mpeg2_new_diag_slot_div + 24'd1;
    end
end

wire [4:0] mpeg2_new_diag_user_slots =
    {mpeg2_new_diag_error_code_snapshot, 1'b0};
wire mpeg2_new_diag_user_window = mpeg2_new_diag_slot < MPEG2_NEW_DIAG_POWER_FIRST;
wire mpeg2_new_diag_user_blink =
    mpeg2_new_diag_snapshot_valid && mpeg2_new_diag_user_window &&
    (mpeg2_new_diag_slot < mpeg2_new_diag_user_slots) &&
    !mpeg2_new_diag_slot[0];

wire [6:0] mpeg2_new_diag_power_slot =
    mpeg2_new_diag_slot - MPEG2_NEW_DIAG_POWER_FIRST;
wire [4:0] mpeg2_new_diag_power_slots =
    {mpeg2_new_diag_power_code_snapshot, 1'b0};
wire mpeg2_new_diag_power_window =
    (mpeg2_new_diag_slot >= MPEG2_NEW_DIAG_POWER_FIRST) &&
    (mpeg2_new_diag_slot < MPEG2_NEW_DIAG_DISK_FIRST);
wire mpeg2_new_diag_power_blink =
    mpeg2_new_diag_snapshot_valid && mpeg2_new_diag_power_window &&
    (mpeg2_new_diag_power_slot < mpeg2_new_diag_power_slots) &&
    !mpeg2_new_diag_power_slot[0];

assign LED_USER = !mpeg2_new_diag_snapshot_valid ? 1'b0 :
                  (mpeg2_new_diag_error_code_snapshot == 4'd0) ?
                    (mpeg2_new_diag_user_window && mpeg2_new_diag_success_snapshot) :
                    mpeg2_new_diag_user_blink;

// LED_POWER is {enable, value}; sys_top drives the POWER LED from the value
// bit when enabled.  A zero sub-code lights the complete POWER window.
assign LED_POWER = {1'b1, !mpeg2_new_diag_snapshot_valid ? 1'b0 :
                          (mpeg2_new_diag_power_code_snapshot == 4'd0) ?
                            mpeg2_new_diag_power_window :
                            mpeg2_new_diag_power_blink};

// kate - Commit 180.  LED_DISK is {enable, value} on the same active-high
// convention (sys_top.v:157 gives LED[2] = led_disk[0] when enabled).  Steady
// OFF when there is no progress sub-code to report.
wire [6:0] mpeg2_new_diag_disk_slot =
    mpeg2_new_diag_slot - MPEG2_NEW_DIAG_DISK_FIRST;
wire [5:0] mpeg2_new_diag_disk_slots =
    {mpeg2_new_diag_disk_code_snapshot, 1'b0};
wire mpeg2_new_diag_disk_blink =
    mpeg2_new_diag_snapshot_valid &&
    (mpeg2_new_diag_slot >= MPEG2_NEW_DIAG_DISK_FIRST) &&
    (mpeg2_new_diag_disk_slot < mpeg2_new_diag_disk_slots) &&
    !mpeg2_new_diag_disk_slot[0];

assign LED_DISK = {1'b1, mpeg2_new_diag_disk_blink};

endmodule
