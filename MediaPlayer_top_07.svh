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

// Commit 157 refines only the proven Commit-156 overlap diagnostic.  The active
// writer's three-bit observer now splits the prior store cause 1 into the exact
// pre-edge writer state, including writer-visible DDR busy while writing.  The
// top observer separately retains whether prediction error was already visible
// on an earlier decoder clock or first becomes visible with the overlap.
// Functional decode, writer sequencing, DDR service, and reference ownership are
// unchanged.
//
// Progress pulses (unchanged):
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
// Error pulses retained from Commit 156:
// 11 second P reached before P1 reference/publication state was ready
// 12 prediction/reference-pipeline error before a classified DDR first fault
// 13 simultaneous/unclassified DDR store/cache error
// 14 frontend/IQ/IDCT/reconstruction error
// 15 any store block_start overlap without prediction already/coincident
// 16 store pixel_valid without an active block capture
// 17 store block_complete in an invalid capture/flush/write state
// 18 store rejected block geometry/metadata
// 19 cache line-consumed event arrived before cache readiness
// 20 cache reader fell more than one displayed line behind
// 21 cache rejected picture geometry at startup
// 22 cache invalid prefill state
// 23 reserved generic overlap+prediction fallback
// 24..30 retain causes 16..22 respectively with prediction already/coincident
// Refined overlap+prediction internal terminal codes:
// 31 capture-active only; prediction was already present before overlap
// 32 capture-active only; prediction first appears coincident with overlap
// 33 flush-pending only; prediction was already present before overlap
// 34 flush-pending only; prediction first appears coincident with overlap
// 35 write-active+flush, DDR not busy; prediction already present before overlap
// 36 write-active+flush, DDR not busy; prediction first appears with overlap
// 37 write-active+flush, DDR busy; prediction already present before overlap
// 38 write-active+flush, DDR busy; prediction first appears with overlap
//
// kate - Commit 158 leaves those internal codes and all observer latches intact,
// but displays codes 31..38 as two short USER groups instead of 31..38 flashes.
// Group 1: 1=capture, 2=flush, 3=write/not-busy, 4=write/busy.
// Group 2: 1=prediction already present, 2=prediction first coincident.
//
// kate - Commit 159 resurfaces the existing Commit-154 generalized-P first-error
// carrier (paired E?/D? values).  No predictor control consumes this observer.
// When prediction is proven earlier than the DDR overlap, USER reports A-B-C:
//   A-B = first prediction cause, C = later writer-overlap state.
// Prediction causes: 1 metadata/order, 2 start prerequisites, 3 source bounds,
// 4 unsolicited DDR response, 5 persistence verify mismatch, 6 timeout,
// 7 residual-descriptor consumption mismatch, 8 other/unclassified predictor.
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
reg        mpeg2_new_pp_diag_pred_before_ddr;
reg [3:0]  mpeg2_new_pp_diag_pred_cause;
reg [2:0]  mpeg2_new_pp_diag_pred_cause_wait;
reg [3:0]  mpeg2_new_pp_diag_pred_cause_d;
reg        mpeg2_new_pp_diag_ddr_fault_latched;
reg [5:0]  mpeg2_new_pp_diag_ddr_fault_code;
reg [4:0]  mpeg2_new_pp_diag_stage;
reg [5:0]  mpeg2_new_pp_diag_code_d;
reg [30:0] mpeg2_new_pp_diag_counter;

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

wire mpeg2_new_pp_diag_ddr_error_present =
    mpeg2_new_ddr_store_error || mpeg2_new_ddr_cache_error;

wire mpeg2_new_pp_diag_store_overlap_detail =
    mpeg2_new_ddr_store_error && !mpeg2_new_ddr_cache_error &&
    (mpeg2_new_ddr_store_diag_cause >= 3'd1) &&
    (mpeg2_new_ddr_store_diag_cause <= 3'd4);

wire [5:0] mpeg2_new_pp_diag_ddr_base_code =
    mpeg2_new_pp_diag_store_overlap_detail                  ? 6'd15 :
    (mpeg2_new_ddr_store_error && !mpeg2_new_ddr_cache_error &&
     (mpeg2_new_ddr_store_diag_cause == 3'd5)) ? 6'd16 :
    (mpeg2_new_ddr_store_error && !mpeg2_new_ddr_cache_error &&
     (mpeg2_new_ddr_store_diag_cause == 3'd6)) ? 6'd17 :
    (mpeg2_new_ddr_store_error && !mpeg2_new_ddr_cache_error &&
     (mpeg2_new_ddr_store_diag_cause == 3'd7)) ? 6'd18 :
    (mpeg2_new_ddr_cache_error && !mpeg2_new_ddr_store_error &&
     (mpeg2_new_ddr_cache_diag_cause == 3'd1)) ? 6'd19 :
    (mpeg2_new_ddr_cache_error && !mpeg2_new_ddr_store_error &&
     (mpeg2_new_ddr_cache_diag_cause == 3'd2)) ? 6'd20 :
    (mpeg2_new_ddr_cache_error && !mpeg2_new_ddr_store_error &&
     (mpeg2_new_ddr_cache_diag_cause == 3'd3)) ? 6'd21 :
    (mpeg2_new_ddr_cache_error && !mpeg2_new_ddr_store_error &&
     (mpeg2_new_ddr_cache_diag_cause == 3'd4)) ? 6'd22 :
                                                               6'd13;

wire mpeg2_new_pp_diag_pred_at_or_before_ddr =
    mpeg2_new_pp_diag_pred_before_ddr || mpeg2_new_pred_error;
wire mpeg2_new_pp_diag_pred_coincident_ddr =
    !mpeg2_new_pp_diag_pred_before_ddr && mpeg2_new_pred_error;

// Commit-154 generalized-P error carrier.  The paired high nibbles and matching
// low-nibble cause make accidental interpretation of ordinary pixel data unlikely.
wire mpeg2_new_pp_diag_pred_carrier_valid =
    mpeg2_new_pred_error &&
    (mpeg2_new_pred_sample_value[7:4] == 4'hE) &&
    (mpeg2_new_pred_reconstructed_value[7:4] == 4'hD) &&
    (mpeg2_new_pred_sample_value[3:0] == mpeg2_new_pred_reconstructed_value[3:0]) &&
    (mpeg2_new_pred_sample_value[3:0] >= 4'd1) &&
    (mpeg2_new_pred_sample_value[3:0] <= 4'd7);
wire [3:0] mpeg2_new_pp_diag_pred_carrier_cause =
    mpeg2_new_pred_sample_value[3:0];

wire [5:0] mpeg2_new_pp_diag_overlap_pred_code =
    (mpeg2_new_ddr_store_diag_cause == 3'd1) ?
        (mpeg2_new_pp_diag_pred_before_ddr ? 6'd31 :
         mpeg2_new_pp_diag_pred_coincident_ddr ? 6'd32 : 6'd23) :
    (mpeg2_new_ddr_store_diag_cause == 3'd2) ?
        (mpeg2_new_pp_diag_pred_before_ddr ? 6'd33 :
         mpeg2_new_pp_diag_pred_coincident_ddr ? 6'd34 : 6'd23) :
    (mpeg2_new_ddr_store_diag_cause == 3'd3) ?
        (mpeg2_new_pp_diag_pred_before_ddr ? 6'd35 :
         mpeg2_new_pp_diag_pred_coincident_ddr ? 6'd36 : 6'd23) :
    (mpeg2_new_ddr_store_diag_cause == 3'd4) ?
        (mpeg2_new_pp_diag_pred_before_ddr ? 6'd37 :
         mpeg2_new_pp_diag_pred_coincident_ddr ? 6'd38 : 6'd23) :
                                                               6'd23;

wire [5:0] mpeg2_new_pp_diag_ddr_code_now =
    (mpeg2_new_pp_diag_store_overlap_detail &&
     mpeg2_new_pp_diag_pred_at_or_before_ddr) ?
        mpeg2_new_pp_diag_overlap_pred_code :
    ((mpeg2_new_pp_diag_ddr_base_code >= 6'd16) &&
     (mpeg2_new_pp_diag_ddr_base_code <= 6'd22) &&
     mpeg2_new_pp_diag_pred_at_or_before_ddr) ?
        (mpeg2_new_pp_diag_ddr_base_code + 6'd8) :
        mpeg2_new_pp_diag_ddr_base_code;
wire [5:0] mpeg2_new_pp_diag_ddr_display_code =
    mpeg2_new_pp_diag_ddr_fault_latched ?
        mpeg2_new_pp_diag_ddr_fault_code :
        mpeg2_new_pp_diag_ddr_code_now;

wire [5:0] mpeg2_new_pp_diag_error_code =
    (mpeg2_new_syntax_error ||
     mpeg2_new_inverse_quant_error ||
     mpeg2_new_inverse_quant_unsupported_matrix ||
     mpeg2_new_idct_error ||
     mpeg2_new_recon_error)                                  ? 6'd14 :
    mpeg2_new_pp_diag_ddr_fault_latched                      ? mpeg2_new_pp_diag_ddr_fault_code :
    mpeg2_new_pp_diag_ddr_error_present                      ? mpeg2_new_pp_diag_ddr_display_code :
    mpeg2_new_pred_error                                     ? 6'd12 :
    mpeg2_new_pp_diag_boundary_error                         ? 6'd11 :
                                                               6'd0;
wire [5:0] mpeg2_new_pp_diag_code =
    (mpeg2_new_pp_diag_error_code != 6'd0) ?
        mpeg2_new_pp_diag_error_code : {1'b0, mpeg2_new_pp_diag_stage};

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
        mpeg2_new_pp_diag_pred_before_ddr   <= 1'b0;
        mpeg2_new_pp_diag_pred_cause        <= 4'd0;
        mpeg2_new_pp_diag_pred_cause_wait   <= 3'd0;
        mpeg2_new_pp_diag_pred_cause_d      <= 4'd0;
        mpeg2_new_pp_diag_ddr_fault_latched <= 1'b0;
        mpeg2_new_pp_diag_ddr_fault_code    <= 6'd0;
        mpeg2_new_pp_diag_stage             <= 5'd0;
        mpeg2_new_pp_diag_code_d            <= 6'd0;
        mpeg2_new_pp_diag_counter           <= 31'd0;
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
            !mpeg2_new_pp_diag_ddr_fault_latched &&
            !mpeg2_new_pp_diag_ddr_error_present &&
            mpeg2_new_pred_error)
            mpeg2_new_pp_diag_pred_before_ddr <= 1'b1;

        // Wait a few clocks for the existing generalized-P E?/D? carrier to
        // become visible after probe_error first rises.  If it never appears,
        // retain a small generic class rather than inventing a specific cause.
        if (mpeg2_new_pp_diag_active &&
            mpeg2_new_pred_error &&
            (mpeg2_new_pp_diag_pred_cause == 4'd0)) begin
            if (mpeg2_new_pp_diag_pred_carrier_valid) begin
                mpeg2_new_pp_diag_pred_cause <=
                    mpeg2_new_pp_diag_pred_carrier_cause;
                mpeg2_new_pp_diag_pred_cause_wait <= 3'd0;
            end
            else if (mpeg2_new_pp_diag_pred_cause_wait < 3'd3) begin
                mpeg2_new_pp_diag_pred_cause_wait <=
                    mpeg2_new_pp_diag_pred_cause_wait + 1'b1;
            end
            else begin
                mpeg2_new_pp_diag_pred_cause <= 4'd8;
            end
        end

        if (mpeg2_new_pp_diag_active &&
            !mpeg2_new_pp_diag_ddr_fault_latched &&
            mpeg2_new_pp_diag_ddr_error_present) begin
            mpeg2_new_pp_diag_ddr_fault_latched <= 1'b1;
            mpeg2_new_pp_diag_ddr_fault_code <=
                mpeg2_new_pp_diag_ddr_code_now;
        end

        if (mpeg2_new_pp_diag_active &&
            (mpeg2_new_picture_count >= 8'd4) &&
            (mpeg2_new_reference_promotion_count >= 8'd4) &&
            mpeg2_new_normal_user_led &&
            (mpeg2_new_pp_diag_stage < 5'd10))
            mpeg2_new_pp_diag_stage <= 5'd10;

        if (mpeg2_new_pp_diag_active) begin
            if ((mpeg2_new_pp_diag_code != mpeg2_new_pp_diag_code_d) ||
                (mpeg2_new_pp_diag_pred_cause != mpeg2_new_pp_diag_pred_cause_d)) begin
                mpeg2_new_pp_diag_code_d       <= mpeg2_new_pp_diag_code;
                mpeg2_new_pp_diag_pred_cause_d <= mpeg2_new_pp_diag_pred_cause;
                mpeg2_new_pp_diag_counter      <= 31'd0;
            end
            else begin
                mpeg2_new_pp_diag_counter <=
                    mpeg2_new_pp_diag_counter + 1'b1;
            end
        end
    end
end

// The historical single-count display is preserved for progress and all other
// terminal codes.  Commit 158 makes refined overlap codes 31..38 easier to read
// as writer-state then prediction-order groups.  Commit 159 gives prediction-
// before cases with a classified first cause a three-group A-B-C presentation.
// The ON/OFF slot remains based on bit 24.
wire [6:0] mpeg2_new_pp_diag_phase = mpeg2_new_pp_diag_counter[30:24];
wire [6:0] mpeg2_new_pp_diag_limit = {mpeg2_new_pp_diag_code_d, 1'b0};
wire mpeg2_new_pp_diag_single_led =
    (mpeg2_new_pp_diag_phase < mpeg2_new_pp_diag_limit) &&
    !mpeg2_new_pp_diag_phase[0];

wire mpeg2_new_pp_diag_split_display =
    (mpeg2_new_pp_diag_code_d >= 6'd31) &&
    (mpeg2_new_pp_diag_code_d <= 6'd38);
wire [2:0] mpeg2_new_pp_diag_split_state_count =
    (mpeg2_new_pp_diag_code_d <= 6'd32) ? 3'd1 :
    (mpeg2_new_pp_diag_code_d <= 6'd34) ? 3'd2 :
    (mpeg2_new_pp_diag_code_d <= 6'd36) ? 3'd3 : 3'd4;
wire [1:0] mpeg2_new_pp_diag_split_pred_count =
    mpeg2_new_pp_diag_code_d[0] ? 2'd1 : 2'd2;
wire [4:0] mpeg2_new_pp_diag_split_phase = mpeg2_new_pp_diag_counter[28:24];
wire [4:0] mpeg2_new_pp_diag_split_first_end =
    {1'b0, mpeg2_new_pp_diag_split_state_count, 1'b0};
wire [4:0] mpeg2_new_pp_diag_split_second_start =
    mpeg2_new_pp_diag_split_first_end + 5'd3;
wire [4:0] mpeg2_new_pp_diag_split_second_end =
    mpeg2_new_pp_diag_split_second_start +
    {2'b00, mpeg2_new_pp_diag_split_pred_count, 1'b0};
wire [4:0] mpeg2_new_pp_diag_split_second_phase =
    mpeg2_new_pp_diag_split_phase - mpeg2_new_pp_diag_split_second_start;
wire mpeg2_new_pp_diag_split_led =
    ((mpeg2_new_pp_diag_split_phase < mpeg2_new_pp_diag_split_first_end) &&
     !mpeg2_new_pp_diag_split_phase[0]) ||
    ((mpeg2_new_pp_diag_split_phase >= mpeg2_new_pp_diag_split_second_start) &&
     (mpeg2_new_pp_diag_split_phase < mpeg2_new_pp_diag_split_second_end) &&
     !mpeg2_new_pp_diag_split_second_phase[0]);

// Commit 159 A-B-C mapping.  Cause 1..4 => A=1, cause 5..8 => A=2;
// B is the 1..4 position inside that group.  C repeats the later writer state.
// This mode is used only for odd internal codes 31/33/35/37, so A-B-C itself
// also proves prediction was already present before the DDR overlap.
wire mpeg2_new_pp_diag_pred_detail_display =
    (mpeg2_new_pp_diag_pred_cause_d != 4'd0) &&
    ((mpeg2_new_pp_diag_code_d == 6'd31) ||
     (mpeg2_new_pp_diag_code_d == 6'd33) ||
     (mpeg2_new_pp_diag_code_d == 6'd35) ||
     (mpeg2_new_pp_diag_code_d == 6'd37));
wire [2:0] mpeg2_new_pp_diag_pred_detail_group =
    (mpeg2_new_pp_diag_pred_cause_d <= 4'd4) ? 3'd1 : 3'd2;
wire [2:0] mpeg2_new_pp_diag_pred_detail_item =
    (mpeg2_new_pp_diag_pred_cause_d == 4'd1 || mpeg2_new_pp_diag_pred_cause_d == 4'd5) ? 3'd1 :
    (mpeg2_new_pp_diag_pred_cause_d == 4'd2 || mpeg2_new_pp_diag_pred_cause_d == 4'd6) ? 3'd2 :
    (mpeg2_new_pp_diag_pred_cause_d == 4'd3 || mpeg2_new_pp_diag_pred_cause_d == 4'd7) ? 3'd3 : 3'd4;
wire [2:0] mpeg2_new_pp_diag_pred_detail_writer =
    (mpeg2_new_pp_diag_code_d == 6'd31) ? 3'd1 :
    (mpeg2_new_pp_diag_code_d == 6'd33) ? 3'd2 :
    (mpeg2_new_pp_diag_code_d == 6'd35) ? 3'd3 : 3'd4;
wire [4:0] mpeg2_new_pp_diag_pred_detail_phase =
    mpeg2_new_pp_diag_counter[28:24];
wire [4:0] mpeg2_new_pp_diag_pred_detail_first_end =
    {1'b0, mpeg2_new_pp_diag_pred_detail_group, 1'b0};
wire [4:0] mpeg2_new_pp_diag_pred_detail_second_start =
    mpeg2_new_pp_diag_pred_detail_first_end + 5'd3;
wire [4:0] mpeg2_new_pp_diag_pred_detail_second_end =
    mpeg2_new_pp_diag_pred_detail_second_start +
    {1'b0, mpeg2_new_pp_diag_pred_detail_item, 1'b0};
wire [4:0] mpeg2_new_pp_diag_pred_detail_third_start =
    mpeg2_new_pp_diag_pred_detail_second_end + 5'd3;
wire [4:0] mpeg2_new_pp_diag_pred_detail_third_end =
    mpeg2_new_pp_diag_pred_detail_third_start +
    {1'b0, mpeg2_new_pp_diag_pred_detail_writer, 1'b0};
wire [4:0] mpeg2_new_pp_diag_pred_detail_second_phase =
    mpeg2_new_pp_diag_pred_detail_phase -
    mpeg2_new_pp_diag_pred_detail_second_start;
wire [4:0] mpeg2_new_pp_diag_pred_detail_third_phase =
    mpeg2_new_pp_diag_pred_detail_phase -
    mpeg2_new_pp_diag_pred_detail_third_start;
wire mpeg2_new_pp_diag_pred_detail_led =
    ((mpeg2_new_pp_diag_pred_detail_phase <
      mpeg2_new_pp_diag_pred_detail_first_end) &&
     !mpeg2_new_pp_diag_pred_detail_phase[0]) ||
    ((mpeg2_new_pp_diag_pred_detail_phase >=
      mpeg2_new_pp_diag_pred_detail_second_start) &&
     (mpeg2_new_pp_diag_pred_detail_phase <
      mpeg2_new_pp_diag_pred_detail_second_end) &&
     !mpeg2_new_pp_diag_pred_detail_second_phase[0]) ||
    ((mpeg2_new_pp_diag_pred_detail_phase >=
      mpeg2_new_pp_diag_pred_detail_third_start) &&
     (mpeg2_new_pp_diag_pred_detail_phase <
      mpeg2_new_pp_diag_pred_detail_third_end) &&
     !mpeg2_new_pp_diag_pred_detail_third_phase[0]);

wire mpeg2_new_pp_diag_led = mpeg2_new_pp_diag_pred_detail_display ?
    mpeg2_new_pp_diag_pred_detail_led :
    mpeg2_new_pp_diag_split_display ?
        mpeg2_new_pp_diag_split_led : mpeg2_new_pp_diag_single_led;

assign LED_USER = mpeg2_new_pp_diag_active ?
    mpeg2_new_pp_diag_led : mpeg2_new_normal_user_led;

endmodule