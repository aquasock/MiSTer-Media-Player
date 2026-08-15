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

// Commit 141 restores the exact Commit-136 slow direct USER override and the
// proven 1..15 B execution trace.  After raster stage 15 it switches to the
// same stable completion-status trace.  The publication-shell carrier is
// 0xBDss: status in bits 7:4, B-core execution stage in bits 3:0.
// Completion pulses: 1 B-core error; 2 B-raster/reference-wrapper error;
// 3 DDR scratch-store error; 4 publication/reference error; 5 P/bookkeeper
// contamination; 6 other top-level prerequisite/error; 7 everything clean.
reg        mpeg2_new_b_diag_active;
reg        mpeg2_new_b_diag_completion_mode;
reg        mpeg2_new_b_diag_pred_error_seen;
reg [3:0]  mpeg2_new_b_diag_stage;
reg [29:0] mpeg2_new_b_diag_counter;

wire mpeg2_new_b_core_diag_valid =
    (mpeg2_new_p_first_residual_sample_value[15:8] == 8'hBD);
wire [3:0] mpeg2_new_b_core_diag_status = mpeg2_new_b_core_diag_valid ?
    mpeg2_new_p_first_residual_sample_value[7:4] : 4'd0;
wire [3:0] mpeg2_new_b_core_diag_stage = mpeg2_new_b_core_diag_valid ?
    mpeg2_new_p_first_residual_sample_value[3:0] : 4'd0;
wire mpeg2_new_b_raster_diag_valid =
    (mpeg2_new_b_core_diag_stage >= 4'd10) &&
    (mpeg2_new_pred_sample_value[7:4] == 4'hD);
wire [2:0] mpeg2_new_b_raster_diag_stage = mpeg2_new_b_raster_diag_valid ?
    mpeg2_new_pred_sample_value[2:0] : 3'd0;
wire [3:0] mpeg2_new_b_raster_diag_mapped =
    (mpeg2_new_b_raster_diag_stage >= 3'd7) ? 4'd15 :
    (mpeg2_new_b_raster_diag_stage >= 3'd6) ? 4'd14 :
    (mpeg2_new_b_raster_diag_stage >= 3'd5) ? 4'd13 :
    (mpeg2_new_b_raster_diag_stage >= 3'd4) ? 4'd12 : 4'd0;
wire [3:0] mpeg2_new_b_exec_diag_target =
    (mpeg2_new_b_raster_diag_mapped > mpeg2_new_b_core_diag_stage) ?
        mpeg2_new_b_raster_diag_mapped : mpeg2_new_b_core_diag_stage;
wire mpeg2_new_b_completion_reached =
    (mpeg2_new_b_raster_diag_mapped >= 4'd15);

wire mpeg2_new_b_core_error =
    mpeg2_new_b_core_diag_status[3];
wire mpeg2_new_b_publication_reference_error =
    mpeg2_new_b_core_diag_status[2] ||
    !mpeg2_new_b_core_diag_status[0];
wire mpeg2_new_b_p_bookkeeper_error =
    mpeg2_new_b_core_diag_status[1];

wire mpeg2_new_b_other_top_level_failure =
    !(mpeg2_new_phase1s_all_i_user_success ||
      mpeg2_new_phase1t_p_syntax_user_success) ||
    !mpeg2_new_recon_macroblock_420_complete ||
    !mpeg2_new_phase1n_frame_geometry_supported ||
    mpeg2_new_syntax_error ||
    mpeg2_new_inverse_quant_error ||
    mpeg2_new_inverse_quant_unsupported_matrix ||
    mpeg2_new_idct_error ||
    mpeg2_new_recon_error ||
    !mpeg2_new_ddr_write_seen ||
    !mpeg2_new_ddr_cache_ready ||
    !mpeg2_new_ddr_read_seen ||
    mpeg2_new_ddr_cache_error;

wire [3:0] mpeg2_new_b_completion_diag_target =
    mpeg2_new_b_core_error                                      ? 4'd1 :
    (mpeg2_new_b_diag_pred_error_seen || mpeg2_new_pred_error) ? 4'd2 :
    mpeg2_new_ddr_store_error                                  ? 4'd3 :
    mpeg2_new_b_publication_reference_error                    ? 4'd4 :
    mpeg2_new_b_p_bookkeeper_error                             ? 4'd5 :
    mpeg2_new_b_other_top_level_failure                        ? 4'd6 :
                                                                  4'd7;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_b_diag_active          <= 1'b0;
        mpeg2_new_b_diag_completion_mode <= 1'b0;
        mpeg2_new_b_diag_pred_error_seen <= 1'b0;
        mpeg2_new_b_diag_stage           <= 4'd0;
        mpeg2_new_b_diag_counter         <= 30'd0;
    end
    else if (!mpeg2_new_b_diag_active &&
             mpeg2_new_picture_seen &&
             (mpeg2_new_picture_coding_type == 3'b011)) begin
        mpeg2_new_b_diag_active          <= 1'b1;
        mpeg2_new_b_diag_completion_mode <= 1'b0;
        mpeg2_new_b_diag_pred_error_seen <= 1'b0;
        mpeg2_new_b_diag_stage           <= 4'd0;
        mpeg2_new_b_diag_counter         <= 30'd0;
    end
    else if (mpeg2_new_b_diag_active) begin
        if (mpeg2_new_b_diag_completion_mode) begin
            if (mpeg2_new_pred_error)
                mpeg2_new_b_diag_pred_error_seen <= 1'b1;
            if (mpeg2_new_b_completion_diag_target != mpeg2_new_b_diag_stage) begin
                mpeg2_new_b_diag_stage   <= mpeg2_new_b_completion_diag_target;
                mpeg2_new_b_diag_counter <= 30'd0;
            end
            else
                mpeg2_new_b_diag_counter <= mpeg2_new_b_diag_counter + 1'b1;
        end
        else if (mpeg2_new_b_completion_reached) begin
            mpeg2_new_b_diag_completion_mode <= 1'b1;
            mpeg2_new_b_diag_pred_error_seen <= mpeg2_new_pred_error;
            mpeg2_new_b_diag_stage           <= mpeg2_new_b_completion_diag_target;
            mpeg2_new_b_diag_counter         <= 30'd0;
        end
        else if (mpeg2_new_b_exec_diag_target > mpeg2_new_b_diag_stage) begin
            mpeg2_new_b_diag_stage   <= mpeg2_new_b_exec_diag_target;
            mpeg2_new_b_diag_counter <= 30'd0;
        end
        else
            mpeg2_new_b_diag_counter <= mpeg2_new_b_diag_counter + 1'b1;
    end
end

// Exact Commit-136 cadence: counter[29:24], about 0.30 s per ON/OFF slot.
wire [5:0] mpeg2_new_b_diag_phase = mpeg2_new_b_diag_counter[29:24];
wire [5:0] mpeg2_new_b_diag_limit = {1'b0, mpeg2_new_b_diag_stage, 1'b0};
wire mpeg2_new_b_diag_led =
    (mpeg2_new_b_diag_phase < mpeg2_new_b_diag_limit) &&
    !mpeg2_new_b_diag_phase[0];

// Commit 138 normal acceptance plus Commit 139 presentation completion remain
// intact underneath the direct B-only diagnostic override.
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

// Commit 143 returns USER to the existing Commit-140 presentation trace while
// leaving the Commit-141 execution/completion trace active only as an observer.
wire [5:0] mpeg2_new_b_presentation_diag_phase =
    mpeg2_new_b_presentation_diag_counter[29:24];
wire [5:0] mpeg2_new_b_presentation_diag_limit =
    {1'b0, mpeg2_new_b_presentation_diag_stage, 1'b0};
wire mpeg2_new_b_presentation_diag_led =
    (mpeg2_new_b_presentation_diag_phase <
     mpeg2_new_b_presentation_diag_limit) &&
    !mpeg2_new_b_presentation_diag_phase[0];

assign LED_USER = mpeg2_new_b_presentation_diag_active ?
    mpeg2_new_b_presentation_diag_led : mpeg2_new_normal_user_led;

endmodule
