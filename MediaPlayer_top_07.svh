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

// Commit 146 is observer-only.  Trace the rejected Commit-145 mixed-GOP stream
// without changing parser, prediction, DDR, pacing, or presentation behavior.
// The B transport sentinel is emitted only after the complete B parser has
// accepted all six rows, so reaching stages 2/8 also proves the new internal
// MBA-increment skip map parsed successfully for that B picture.
//
// Progress pulses:
//  1 first B detected
//  2 first B parse/skip map complete; replay transport begins
//  3 first B persisted / clean B success
//  4 first B scratch presented
//  5 first future-P presented / first reorder complete
//  6 second P/reference publication complete
//  7 second B detected / B core re-arm reached
//  8 second B parse/skip map complete; replay transport begins
//  9 second B persisted / clean B success
// 10 second B scratch presented
// 11 final future-P presented / second reorder complete
// 12 normal USER acceptance after the second B
// Error pulses:
// 13 parser/skip/publication-shell probe error not otherwise classified
// 14 prediction or DDR persistence error
// 15 reference/publication state was not ready at a B boundary
// 16 pacing/presentation error
reg        mpeg2_new_b_mixed_diag_active;
reg [1:0]  mpeg2_new_b_mixed_diag_b_count;
reg [4:0]  mpeg2_new_b_mixed_diag_stage;
reg        mpeg2_new_b_mixed_diag_publication_error;
reg [4:0]  mpeg2_new_b_mixed_diag_code_d;
reg [29:0] mpeg2_new_b_mixed_diag_counter;

wire mpeg2_new_b_mixed_diag_transport =
    mpeg2_new_p_forward_vector_valid &&
    (mpeg2_new_p_forward_vector_x == 13'sd2047) &&
    (mpeg2_new_p_forward_vector_y == -13'sd2048);

wire mpeg2_new_b_mixed_diag_first_boundary_bad =
    !mpeg2_new_reference_frame_valid ||
    (mpeg2_new_picture_count < 8'd2) ||
    (mpeg2_new_reference_promotion_count < 8'd2);
wire mpeg2_new_b_mixed_diag_second_boundary_bad =
    !mpeg2_new_reference_frame_valid ||
    (mpeg2_new_picture_count < 8'd3) ||
    (mpeg2_new_reference_promotion_count < 8'd3);
wire mpeg2_new_b_mixed_diag_pacing_error =
    mpeg2_new_b_presentation_hold && mpeg2_stream_rd;

wire [4:0] mpeg2_new_b_mixed_diag_error_code =
    (mpeg2_new_b_presentation_error || mpeg2_new_b_mixed_diag_pacing_error) ? 5'd16 :
    mpeg2_new_b_mixed_diag_publication_error                                ? 5'd15 :
    (mpeg2_new_pred_error || mpeg2_new_ddr_store_error)                     ? 5'd14 :
    mpeg2_new_phase1_probe_error                                             ? 5'd13 :
                                                                               5'd0;
wire [4:0] mpeg2_new_b_mixed_diag_code =
    (mpeg2_new_b_mixed_diag_error_code != 5'd0) ?
        mpeg2_new_b_mixed_diag_error_code : mpeg2_new_b_mixed_diag_stage;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_b_mixed_diag_active            <= 1'b0;
        mpeg2_new_b_mixed_diag_b_count           <= 2'd0;
        mpeg2_new_b_mixed_diag_stage             <= 5'd0;
        mpeg2_new_b_mixed_diag_publication_error <= 1'b0;
        mpeg2_new_b_mixed_diag_code_d            <= 5'd0;
        mpeg2_new_b_mixed_diag_counter           <= 30'd0;
    end
    else begin
        if (mpeg2_new_b_picture_start_edge) begin
            if (!mpeg2_new_b_mixed_diag_active) begin
                mpeg2_new_b_mixed_diag_active  <= 1'b1;
                mpeg2_new_b_mixed_diag_b_count <= 2'd1;
                if (mpeg2_new_b_mixed_diag_stage < 5'd1)
                    mpeg2_new_b_mixed_diag_stage <= 5'd1;
                if (mpeg2_new_b_mixed_diag_first_boundary_bad)
                    mpeg2_new_b_mixed_diag_publication_error <= 1'b1;
            end
            else if (mpeg2_new_b_mixed_diag_b_count == 2'd1) begin
                mpeg2_new_b_mixed_diag_b_count <= 2'd2;
                if (mpeg2_new_b_mixed_diag_stage < 5'd7)
                    mpeg2_new_b_mixed_diag_stage <= 5'd7;
                if (mpeg2_new_b_mixed_diag_second_boundary_bad)
                    mpeg2_new_b_mixed_diag_publication_error <= 1'b1;
            end
        end

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd1) &&
            mpeg2_new_b_mixed_diag_transport &&
            (mpeg2_new_b_mixed_diag_stage < 5'd2))
            mpeg2_new_b_mixed_diag_stage <= 5'd2;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd1) &&
            mpeg2_new_b_user_success_edge &&
            (mpeg2_new_b_mixed_diag_stage < 5'd3))
            mpeg2_new_b_mixed_diag_stage <= 5'd3;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd1) &&
            mpeg2_new_b_scratch_presented &&
            (mpeg2_new_b_mixed_diag_stage < 5'd4))
            mpeg2_new_b_mixed_diag_stage <= 5'd4;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd1) &&
            mpeg2_new_b_presentation_complete &&
            (mpeg2_new_b_mixed_diag_stage < 5'd5))
            mpeg2_new_b_mixed_diag_stage <= 5'd5;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd1) &&
            mpeg2_new_b_presentation_complete &&
            (mpeg2_new_picture_count >= 8'd3) &&
            (mpeg2_new_reference_promotion_count >= 8'd3) &&
            (mpeg2_new_b_mixed_diag_stage < 5'd6))
            mpeg2_new_b_mixed_diag_stage <= 5'd6;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd2) &&
            mpeg2_new_b_mixed_diag_transport &&
            (mpeg2_new_b_mixed_diag_stage < 5'd8))
            mpeg2_new_b_mixed_diag_stage <= 5'd8;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd2) &&
            mpeg2_new_b_user_success_edge &&
            (mpeg2_new_b_mixed_diag_stage < 5'd9))
            mpeg2_new_b_mixed_diag_stage <= 5'd9;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd2) &&
            mpeg2_new_b_scratch_presented &&
            (mpeg2_new_b_mixed_diag_stage < 5'd10))
            mpeg2_new_b_mixed_diag_stage <= 5'd10;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd2) &&
            mpeg2_new_b_presentation_complete &&
            (mpeg2_new_b_mixed_diag_stage < 5'd11))
            mpeg2_new_b_mixed_diag_stage <= 5'd11;

        if ((mpeg2_new_b_mixed_diag_b_count == 2'd2) &&
            mpeg2_new_b_presentation_complete &&
            mpeg2_new_normal_user_led &&
            (mpeg2_new_b_mixed_diag_stage < 5'd12))
            mpeg2_new_b_mixed_diag_stage <= 5'd12;

        if (mpeg2_new_b_mixed_diag_active) begin
            if (mpeg2_new_b_mixed_diag_code != mpeg2_new_b_mixed_diag_code_d) begin
                mpeg2_new_b_mixed_diag_code_d  <= mpeg2_new_b_mixed_diag_code;
                mpeg2_new_b_mixed_diag_counter <= 30'd0;
            end
            else begin
                mpeg2_new_b_mixed_diag_counter <=
                    mpeg2_new_b_mixed_diag_counter + 1'b1;
            end
        end
    end
end

// Same slow cadence used by earlier B bring-up traces: counter[29:24], about
// 0.30 s per ON/OFF slot, followed by a long dark repeat gap.
wire [5:0] mpeg2_new_b_mixed_diag_phase =
    mpeg2_new_b_mixed_diag_counter[29:24];
wire [5:0] mpeg2_new_b_mixed_diag_limit =
    {mpeg2_new_b_mixed_diag_code_d, 1'b0};
wire mpeg2_new_b_mixed_diag_led =
    (mpeg2_new_b_mixed_diag_phase < mpeg2_new_b_mixed_diag_limit) &&
    !mpeg2_new_b_mixed_diag_phase[0];

assign LED_USER = mpeg2_new_b_mixed_diag_active ?
    mpeg2_new_b_mixed_diag_led : mpeg2_new_normal_user_led;

endmodule
