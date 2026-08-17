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

assign LED_USER = mpeg2_new_normal_user_led;

// kate - Commit 176 presentation diagnostic.
//
// Commit-175 hardware showed the USER LED (board LED[0]) is OFF in exactly the
// three streams whose final coded picture is a P, and the captured display
// carries none of the final P's residual content.  Static analysis narrowed the
// cause to two mechanisms that the single acceptance bit cannot separate:
// either the final P never completes (so picture_count/second_picture_420_parsed
// never advance), or it completes but its frame never reaches the display
// (completed_frame_bank never equals display_frame_bank).  These two wires make
// that distinction directly observable instead of guessed at, without altering
// any decode, presentation, ownership or acceptance behavior.
//
// Board LED[4] (LED_POWER): the completed frame is the frame being displayed.
// Board LED[2] (LED_DISK) : no decode/DDR error has latched.
//
// Reading a P-final stream with board LED[0] OFF:
//   LED[4] OFF               -> completed frame never presented (swap path)
//   LED[4] ON  and LED[2] OFF-> a decode/DDR error latched
//   LED[4] ON  and LED[2] ON -> P acceptance prerequisites failed
//                               (picture_count, second_picture_420_parsed,
//                                p_macroblock_type_seen, reference_read_ok,
//                                implicit_reconstruct_ok)
wire mpeg2_new_diag_presentation_ok =
    (mpeg2_new_completed_frame_bank == mpeg2_new_display_frame_bank);

wire mpeg2_new_diag_error_free =
    !mpeg2_new_syntax_error &&
    !mpeg2_new_phase1_probe_error &&
    !mpeg2_new_pred_error &&
    !mpeg2_new_inverse_quant_error &&
    !mpeg2_new_inverse_quant_unsupported_matrix &&
    !mpeg2_new_idct_error &&
    !mpeg2_new_recon_error &&
    !mpeg2_new_ddr_store_error &&
    !mpeg2_new_ddr_cache_error;

// LED_POWER/LED_DISK are {enable, value}; sys_top drives board LED[4]/LED[2]
// from the value bit when the enable bit is set.
assign LED_POWER = {1'b1, mpeg2_new_diag_presentation_ok};
assign LED_DISK  = {1'b1, mpeg2_new_diag_error_free};

endmodule
