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
wire mpeg2_new_diag_presentation_ok =
    (mpeg2_new_completed_frame_bank == mpeg2_new_display_frame_bank);

wire [3:0] mpeg2_new_diag_error_code =
    mpeg2_new_syntax_error                     ? 4'd1 :
    mpeg2_new_phase1_probe_error               ? 4'd2 :
    mpeg2_new_pred_error                       ? 4'd3 :
    mpeg2_new_inverse_quant_error              ? 4'd4 :
    mpeg2_new_inverse_quant_unsupported_matrix ? 4'd5 :
    mpeg2_new_idct_error                       ? 4'd6 :
    mpeg2_new_recon_error                      ? 4'd7 :
    mpeg2_new_ddr_store_error                  ? 4'd8 :
    mpeg2_new_ddr_cache_error                  ? 4'd9 : 4'd0;

// 250 ms slot at the 54 MHz decoder clock.  Slots 0..2N-1 carry the N blinks
// (even slot lit, odd slot dark); the remaining slots of the 26-slot frame are
// the ~2 s separating gap, so nine blinks stay countable.
localparam [23:0] MPEG2_NEW_DIAG_SLOT_CYCLES = 24'd13_500_000;
localparam [4:0]  MPEG2_NEW_DIAG_SLOT_LAST   = 5'd25;

reg [23:0] mpeg2_new_diag_slot_div;
reg [4:0]  mpeg2_new_diag_slot;

wire mpeg2_new_diag_slot_tick =
    (mpeg2_new_diag_slot_div == MPEG2_NEW_DIAG_SLOT_CYCLES - 24'd1);

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= 5'd0;
    end
    else if (mpeg2_new_diag_slot_tick) begin
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= (mpeg2_new_diag_slot == MPEG2_NEW_DIAG_SLOT_LAST) ?
                                   5'd0 : mpeg2_new_diag_slot + 5'd1;
    end
    else begin
        mpeg2_new_diag_slot_div <= mpeg2_new_diag_slot_div + 24'd1;
    end
end

wire [4:0] mpeg2_new_diag_blink_slots = {mpeg2_new_diag_error_code, 1'b0};
wire mpeg2_new_diag_blink =
    (mpeg2_new_diag_slot < mpeg2_new_diag_blink_slots) &&
    !mpeg2_new_diag_slot[0];

assign LED_USER = (mpeg2_new_diag_error_code == 4'd0) ?
                  mpeg2_new_normal_user_led : mpeg2_new_diag_blink;

// LED_POWER is {enable, value}; sys_top drives the POWER LED from the value
// bit when the enable bit is set.
assign LED_POWER = {1'b1, mpeg2_new_diag_presentation_ok};

endmodule
