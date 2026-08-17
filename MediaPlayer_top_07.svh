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
    mpeg2_new_ddr_cache_error                  ? 4'd9 : 4'd0;

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

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_first_error_valid     <= 1'b0;
        mpeg2_new_diag_error_code_first      <= 4'd0;
        mpeg2_new_diag_phase1_source_first   <= 4'd0;
        mpeg2_new_diag_p_source_first        <= 4'd0;
        mpeg2_new_diag_progress_detail_first <= 4'd0;
    end
    else if (!mpeg2_new_diag_first_error_valid &&
             (mpeg2_new_diag_error_code_live != 4'd0)) begin
        mpeg2_new_diag_first_error_valid     <= 1'b1;
        mpeg2_new_diag_error_code_first      <= mpeg2_new_diag_error_code_live;
        mpeg2_new_diag_phase1_source_first   <= mpeg2_new_phase1_probe_error_source;
        mpeg2_new_diag_p_source_first        <= mpeg2_new_p_probe_error_source;
        mpeg2_new_diag_progress_detail_first <= mpeg2_new_p_progress_detail;
    end
end

wire [3:0] mpeg2_new_diag_error_code =
    mpeg2_new_diag_first_error_valid ? mpeg2_new_diag_error_code_first : 4'd0;

wire [3:0] mpeg2_new_diag_power_code =
    mpeg2_new_diag_first_error_valid ?
        ((mpeg2_new_diag_error_code_first == 4'd2) ?
            ((mpeg2_new_diag_phase1_source_first == 4'd2) ?
                 mpeg2_new_diag_p_source_first :
                 mpeg2_new_diag_phase1_source_first) : 4'd0) :
        mpeg2_new_diag_prereq_code;

// kate - Commit 180.  progress_error is a symptom, not a root cause: it is
// p_picture_expected && !p_macroblock_type_seen, and that signal is a deep
// conjunction.  When POWER reports 6, LED_DISK names the first false conjunct
// so one build covers both levels:
//   1 mb_seen_combined   2 residual_decision
//   3 residual required but not successful
//   4 hold_seen_combined 5 two_mb_wait      6 raster_wait
// LED_DISK is steady off in every other case; its ioctl_download file-load
// duty is displaced for the duration of this diagnostic.
wire [3:0] mpeg2_new_diag_disk_code =
    mpeg2_new_diag_first_error_valid &&
    (mpeg2_new_diag_error_code_first == 4'd2) &&
    (mpeg2_new_diag_phase1_source_first == 4'd2) &&
    (mpeg2_new_diag_p_source_first == 4'd6) ?
        mpeg2_new_diag_progress_detail_first : 4'd0;

// 250 ms slot at the 54 MHz decoder clock.  Slots 0..2N-1 carry the N blinks
// (even slot lit, odd slot dark); the remaining slots of the 32-slot frame are
// the separating gap, so twelve blinks still leave ~2 s of gap.
localparam [23:0] MPEG2_NEW_DIAG_SLOT_CYCLES = 24'd13_500_000;
localparam [5:0]  MPEG2_NEW_DIAG_SLOT_LAST   = 6'd31;

reg [23:0] mpeg2_new_diag_slot_div;
reg [5:0]  mpeg2_new_diag_slot;

wire mpeg2_new_diag_slot_tick =
    (mpeg2_new_diag_slot_div == MPEG2_NEW_DIAG_SLOT_CYCLES - 24'd1);

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= 6'd0;
    end
    else if (mpeg2_new_diag_slot_tick) begin
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= (mpeg2_new_diag_slot == MPEG2_NEW_DIAG_SLOT_LAST) ?
                                   6'd0 : mpeg2_new_diag_slot + 6'd1;
    end
    else begin
        mpeg2_new_diag_slot_div <= mpeg2_new_diag_slot_div + 24'd1;
    end
end

wire [5:0] mpeg2_new_diag_blink_slots = {1'b0, mpeg2_new_diag_error_code, 1'b0};
wire mpeg2_new_diag_blink =
    (mpeg2_new_diag_slot < mpeg2_new_diag_blink_slots) &&
    !mpeg2_new_diag_slot[0];

wire [5:0] mpeg2_new_diag_power_slots = {1'b0, mpeg2_new_diag_power_code, 1'b0};
wire mpeg2_new_diag_power_blink =
    (mpeg2_new_diag_slot < mpeg2_new_diag_power_slots) &&
    !mpeg2_new_diag_slot[0];

assign LED_USER = (mpeg2_new_diag_error_code == 4'd0) ?
                  mpeg2_new_normal_user_led : mpeg2_new_diag_blink;

// LED_POWER is {enable, value}; sys_top drives the POWER LED from the value
// bit when the enable bit is set.  Steady ON when there is no sub-code.
assign LED_POWER = {1'b1, (mpeg2_new_diag_power_code == 4'd0) ?
                          1'b1 : mpeg2_new_diag_power_blink};

// kate - Commit 180.  LED_DISK is {enable, value} on the same active-high
// convention (sys_top.v:157 gives LED[2] = led_disk[0] when enabled).  Steady
// OFF when there is no progress sub-code to report.
wire [5:0] mpeg2_new_diag_disk_slots = {1'b0, mpeg2_new_diag_disk_code, 1'b0};
wire mpeg2_new_diag_disk_blink =
    (mpeg2_new_diag_slot < mpeg2_new_diag_disk_slots) &&
    !mpeg2_new_diag_slot[0];

assign LED_DISK = {1'b1, mpeg2_new_diag_disk_blink};

endmodule
