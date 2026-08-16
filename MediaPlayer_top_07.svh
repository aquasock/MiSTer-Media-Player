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

// Commit 153 is observer-only.  It targets the intermittent I/P1/P2/I
// consecutive-reference hang without changing parser, replay, prediction, DDR,
// publication, or stream-ready behavior.  The raw picture-header observer is
// intentionally local to the LED diagnostic so no decoder state depends on it.
//
// Progress pulses (last reached stage repeats after a stall):
//  1 first P header consumed
//  2 P1 reference publication complete
//  3 immediately consecutive second P header consumed; diagnostic becomes active
//  4 P2 generalized replay begins (first 0x3e motion word)
//  5 P2 generalized replay metadata terminator A2FF emitted
//  6 first P2 DDR reconstruction block stored
//  7 P2 full persistence indication rises
//  8 P2 reference publication complete
//  9 following I header consumed, proving the compressed stream was released
// 10 following I published and normal USER acceptance is clean
// Error pulses:
// 11 second P reached before P1 reference/publication state was ready
// 12 prediction/reference-pipeline error
// 13 DDR store/cache error
// 14 frontend/IQ/IDCT/reconstruction error
reg [31:0] mpeg2_new_pp_diag_picture_window;
reg        mpeg2_new_pp_diag_header_capture;
reg        mpeg2_new_pp_diag_header_second_byte;
reg        mpeg2_new_pp_diag_last_picture_was_p;
reg        mpeg2_new_pp_diag_first_p_seen;
reg        mpeg2_new_pp_diag_first_p_published;
reg        mpeg2_new_pp_diag_active;
reg        mpeg2_new_pp_diag_boundary_error;
reg        mpeg2_new_pp_diag_p2_replay_started;
reg        mpeg2_new_pp_diag_p2_replay_done;
reg        mpeg2_new_pp_diag_p2_store_seen;
reg        mpeg2_new_pp_diag_p2_persisted;
reg        mpeg2_new_pp_diag_pred_persisted_d;
reg [4:0]  mpeg2_new_pp_diag_stage;
reg [4:0]  mpeg2_new_pp_diag_code_d;
reg [29:0] mpeg2_new_pp_diag_counter;

wire [31:0] mpeg2_new_pp_diag_picture_window_next =
    {mpeg2_new_pp_diag_picture_window[23:0], mpeg2_stream_data};
wire mpeg2_new_pp_diag_picture_start_now =
    (mpeg2_new_pp_diag_picture_window_next == 32'h00000100);
wire mpeg2_new_pp_diag_p2_motion_word =
    mpeg2_new_pp_diag_active &&
    mpeg2_new_p_residual_sample_valid &&
    (mpeg2_new_p_residual_sample_index == 6'h3e);
wire mpeg2_new_pp_diag_p2_metadata_done =
    mpeg2_new_pp_diag_active &&
    mpeg2_new_p_residual_sample_valid &&
    (mpeg2_new_p_residual_sample_index == 6'h3f) &&
    (mpeg2_new_p_residual_sample_value == 16'shA2FF);
wire mpeg2_new_pp_diag_persisted_edge =
    mpeg2_new_pred_persisted_seen && !mpeg2_new_pp_diag_pred_persisted_d;

wire [4:0] mpeg2_new_pp_diag_error_code =
    (mpeg2_new_syntax_error ||
     mpeg2_new_inverse_quant_error ||
     mpeg2_new_inverse_quant_unsupported_matrix ||
     mpeg2_new_idct_error ||
     mpeg2_new_recon_error)                                  ? 5'd14 :
    (mpeg2_new_ddr_store_error || mpeg2_new_ddr_cache_error) ? 5'd13 :
    mpeg2_new_pred_error                                     ? 5'd12 :
    mpeg2_new_pp_diag_boundary_error                         ? 5'd11 :
                                                               5'd0;
wire [4:0] mpeg2_new_pp_diag_code =
    (mpeg2_new_pp_diag_error_code != 5'd0) ?
        mpeg2_new_pp_diag_error_code : mpeg2_new_pp_diag_stage;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_pp_diag_picture_window     <= 32'd0;
        mpeg2_new_pp_diag_header_capture    <= 1'b0;
        mpeg2_new_pp_diag_header_second_byte<= 1'b0;
        mpeg2_new_pp_diag_last_picture_was_p<= 1'b0;
        mpeg2_new_pp_diag_first_p_seen      <= 1'b0;
        mpeg2_new_pp_diag_first_p_published <= 1'b0;
        mpeg2_new_pp_diag_active            <= 1'b0;
        mpeg2_new_pp_diag_boundary_error    <= 1'b0;
        mpeg2_new_pp_diag_p2_replay_started <= 1'b0;
        mpeg2_new_pp_diag_p2_replay_done    <= 1'b0;
        mpeg2_new_pp_diag_p2_store_seen     <= 1'b0;
        mpeg2_new_pp_diag_p2_persisted      <= 1'b0;
        mpeg2_new_pp_diag_pred_persisted_d  <= 1'b0;
        mpeg2_new_pp_diag_stage             <= 5'd0;
        mpeg2_new_pp_diag_code_d            <= 5'd0;
        mpeg2_new_pp_diag_counter           <= 30'd0;
    end
    else begin
        mpeg2_new_pp_diag_pred_persisted_d <= mpeg2_new_pred_persisted_seen;

        if (!mpeg2_new_pp_diag_active &&
            mpeg2_new_pp_diag_first_p_seen &&
            mpeg2_new_reference_frame_valid &&
            (mpeg2_new_picture_count >= 8'd2) &&
            (mpeg2_new_reference_promotion_count >= 8'd2)) begin
            mpeg2_new_pp_diag_first_p_published <= 1'b1;
            if (mpeg2_new_pp_diag_stage < 5'd2)
                mpeg2_new_pp_diag_stage <= 5'd2;
        end

        if (mpeg2_stream_rd) begin
            mpeg2_new_pp_diag_picture_window <= mpeg2_new_pp_diag_picture_window_next;

            if (mpeg2_new_pp_diag_picture_start_now) begin
                mpeg2_new_pp_diag_header_capture     <= 1'b1;
                mpeg2_new_pp_diag_header_second_byte <= 1'b0;
            end
            else if (mpeg2_new_pp_diag_header_capture) begin
                if (!mpeg2_new_pp_diag_header_second_byte) begin
                    mpeg2_new_pp_diag_header_second_byte <= 1'b1;
                end
                else begin
                    mpeg2_new_pp_diag_header_capture     <= 1'b0;
                    mpeg2_new_pp_diag_header_second_byte <= 1'b0;

                    if (mpeg2_stream_data[5:3] == 3'b010) begin
                        if (mpeg2_new_pp_diag_last_picture_was_p) begin
                            mpeg2_new_pp_diag_active <= 1'b1;
                            if (mpeg2_new_pp_diag_stage < 5'd3)
                                mpeg2_new_pp_diag_stage <= 5'd3;
                            if (!mpeg2_new_pp_diag_first_p_published ||
                                !mpeg2_new_reference_frame_valid ||
                                (mpeg2_new_picture_count < 8'd2) ||
                                (mpeg2_new_reference_promotion_count < 8'd2))
                                mpeg2_new_pp_diag_boundary_error <= 1'b1;
                        end
                        else begin
                            mpeg2_new_pp_diag_first_p_seen <= 1'b1;
                            if (mpeg2_new_pp_diag_stage < 5'd1)
                                mpeg2_new_pp_diag_stage <= 5'd1;
                        end
                        mpeg2_new_pp_diag_last_picture_was_p <= 1'b1;
                    end
                    else begin
                        if (mpeg2_new_pp_diag_active &&
                            (mpeg2_stream_data[5:3] == 3'b001) &&
                            (mpeg2_new_pp_diag_stage < 5'd9))
                            mpeg2_new_pp_diag_stage <= 5'd9;
                        mpeg2_new_pp_diag_last_picture_was_p <= 1'b0;
                    end
                end
            end
        end

        if (mpeg2_new_pp_diag_p2_motion_word) begin
            mpeg2_new_pp_diag_p2_replay_started <= 1'b1;
            if (mpeg2_new_pp_diag_stage < 5'd4)
                mpeg2_new_pp_diag_stage <= 5'd4;
        end

        if (mpeg2_new_pp_diag_p2_metadata_done) begin
            mpeg2_new_pp_diag_p2_replay_done <= 1'b1;
            if (mpeg2_new_pp_diag_stage < 5'd5)
                mpeg2_new_pp_diag_stage <= 5'd5;
        end

        if (mpeg2_new_pp_diag_active &&
            mpeg2_new_pp_diag_p2_replay_done &&
            mpeg2_new_ddr_block_stored) begin
            mpeg2_new_pp_diag_p2_store_seen <= 1'b1;
            if (mpeg2_new_pp_diag_stage < 5'd6)
                mpeg2_new_pp_diag_stage <= 5'd6;
        end

        if (mpeg2_new_pp_diag_active &&
            mpeg2_new_pp_diag_p2_replay_done &&
            mpeg2_new_pp_diag_persisted_edge) begin
            mpeg2_new_pp_diag_p2_persisted <= 1'b1;
            if (mpeg2_new_pp_diag_stage < 5'd7)
                mpeg2_new_pp_diag_stage <= 5'd7;
        end

        if (mpeg2_new_pp_diag_active &&
            mpeg2_new_pp_diag_p2_persisted &&
            mpeg2_new_reference_frame_valid &&
            (mpeg2_new_picture_count >= 8'd3) &&
            (mpeg2_new_reference_promotion_count >= 8'd3) &&
            (mpeg2_new_pp_diag_stage < 5'd8))
            mpeg2_new_pp_diag_stage <= 5'd8;

        if (mpeg2_new_pp_diag_active &&
            (mpeg2_new_picture_count >= 8'd4) &&
            (mpeg2_new_reference_promotion_count >= 8'd4) &&
            mpeg2_new_normal_user_led &&
            (mpeg2_new_pp_diag_stage < 5'd10))
            mpeg2_new_pp_diag_stage <= 5'd10;

        if (mpeg2_new_pp_diag_active) begin
            if (mpeg2_new_pp_diag_code != mpeg2_new_pp_diag_code_d) begin
                mpeg2_new_pp_diag_code_d  <= mpeg2_new_pp_diag_code;
                mpeg2_new_pp_diag_counter <= 30'd0;
            end
            else begin
                mpeg2_new_pp_diag_counter <=
                    mpeg2_new_pp_diag_counter + 1'b1;
            end
        end
    end
end

// Same slow cadence used by prior hardware traces: counter[29:24], roughly
// 0.30 s per ON/OFF slot, followed by a long dark repeat gap.
wire [5:0] mpeg2_new_pp_diag_phase = mpeg2_new_pp_diag_counter[29:24];
wire [5:0] mpeg2_new_pp_diag_limit = {mpeg2_new_pp_diag_code_d, 1'b0};
wire mpeg2_new_pp_diag_led =
    (mpeg2_new_pp_diag_phase < mpeg2_new_pp_diag_limit) &&
    !mpeg2_new_pp_diag_phase[0];

assign LED_USER = mpeg2_new_pp_diag_active ?
    mpeg2_new_pp_diag_led : mpeg2_new_normal_user_led;

endmodule