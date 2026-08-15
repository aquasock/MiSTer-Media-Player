    (mpeg2_new_display_scratch ||
     (mpeg2_new_completed_frame_bank != mpeg2_new_display_frame_bank));

// Commit 139 adds one non-reference presentation slot.  The controlled stream
// is coded I / future-P / B.  Bank 0 already displays the first I picture; the
// completed future P remains pending while B reconstructs into fixed scratch
// storage.  Once B persistence is proven, scratch gets the next swap and the
// retained future-P bank gets the following swap.  B never becomes a reference.
wire mpeg2_new_b_scratch_waiting =
    mpeg2_new_b_scratch_pending || mpeg2_new_b_user_success_edge;
wire mpeg2_new_scheduled_frame_valid =
    mpeg2_new_b_scratch_waiting ||
    mpeg2_new_b_future_waiting ||
    (!mpeg2_new_b_reorder_active &&
     !mpeg2_new_b_picture_start_edge &&
     (mpeg2_new_frame_waiting || mpeg2_new_pending_frame_valid));
wire mpeg2_new_scheduled_frame_scratch = mpeg2_new_b_scratch_waiting;
wire mpeg2_new_scheduled_frame_bank =
    mpeg2_new_b_future_waiting ?
        mpeg2_new_b_future_frame_bank :
    mpeg2_new_frame_waiting ?
        mpeg2_new_completed_frame_bank :
        mpeg2_new_pending_frame_bank;
wire mpeg2_new_scheduled_frame_differs =
    mpeg2_new_scheduled_frame_scratch ?
        !mpeg2_new_display_scratch :
        (mpeg2_new_display_scratch ||
         (mpeg2_new_scheduled_frame_bank != mpeg2_new_display_frame_bank));

// Commit 140 temporarily restores the proven slow USER pulse diagnostic used
// during B-core bring-up, now scoped only to the presentation/reorder path.
// Each stage number is emitted as that many ~0.30 s ON pulses separated by
// equal ~0.30 s OFF slots, followed by the same long dark repeat gap.
// Progress: 1 B frontend; 2 reorder armed; 3 clean B completion; 4 scratch
// waiting; 5 scratch swap; 6 future-P waiting; 7 future-P swap; 8 complete.
// Errors: 9 invalid state at B start; 10 B completion without active reorder;
// 11 invalid future-P swap completion; 12 other sticky presentation error.
reg        mpeg2_new_b_presentation_diag_active;
reg [3:0]  mpeg2_new_b_presentation_diag_stage;
reg [3:0]  mpeg2_new_b_presentation_diag_error;
reg [29:0] mpeg2_new_b_presentation_diag_counter;

wire mpeg2_new_b_presentation_diag_scratch_swap =
    mpeg2_new_swap_window_pulse &&
    mpeg2_new_scheduled_frame_valid &&
    mpeg2_new_scheduled_frame_differs &&
    mpeg2_new_b_scratch_waiting;
wire mpeg2_new_b_presentation_diag_future_swap =
    mpeg2_new_swap_window_pulse &&
    mpeg2_new_scheduled_frame_valid &&
    mpeg2_new_scheduled_frame_differs &&
    mpeg2_new_b_future_waiting;
wire mpeg2_new_b_presentation_diag_start_error =
    mpeg2_new_b_picture_start_edge &&
    (mpeg2_new_display_scratch ||
     (mpeg2_new_display_frame_bank == mpeg2_new_reference_frame_bank));
wire [3:0] mpeg2_new_b_presentation_diag_progress =
    mpeg2_new_b_presentation_complete             ? 4'd8 :
    mpeg2_new_b_presentation_diag_future_swap     ? 4'd7 :
    mpeg2_new_b_future_waiting                     ? 4'd6 :
    mpeg2_new_b_presentation_diag_scratch_swap    ? 4'd5 :
    mpeg2_new_b_scratch_waiting                    ? 4'd4 :
    mpeg2_new_b_user_success                       ? 4'd3 :
    mpeg2_new_b_reorder_active                     ? 4'd2 :
    mpeg2_new_b_picture_frontend_active            ? 4'd1 :
                                                       4'd0;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_b_presentation_diag_active  <= 1'b0;
        mpeg2_new_b_presentation_diag_stage   <= 4'd0;
        mpeg2_new_b_presentation_diag_error   <= 4'd0;
        mpeg2_new_b_presentation_diag_counter <= 30'd0;
    end
    else if (!mpeg2_new_b_presentation_diag_active &&
             mpeg2_new_b_picture_frontend_active) begin
        mpeg2_new_b_presentation_diag_active  <= 1'b1;
        mpeg2_new_b_presentation_diag_stage   <= 4'd1;
        mpeg2_new_b_presentation_diag_error   <=
            mpeg2_new_b_presentation_diag_start_error ? 4'd9 : 4'd0;
        mpeg2_new_b_presentation_diag_counter <= 30'd0;
    end
    else if (mpeg2_new_b_presentation_diag_active) begin
        if (mpeg2_new_b_presentation_diag_error == 4'd0) begin
            if (mpeg2_new_b_user_success_edge && !mpeg2_new_b_reorder_active)
                mpeg2_new_b_presentation_diag_error <= 4'd10;
            else if (mpeg2_new_b_presentation_diag_future_swap &&
                     (!mpeg2_new_b_scratch_presented ||
                      mpeg2_new_b_presentation_error))
                mpeg2_new_b_presentation_diag_error <= 4'd11;
            else if (mpeg2_new_b_presentation_error)
                mpeg2_new_b_presentation_diag_error <= 4'd12;
        end

        if ((mpeg2_new_b_presentation_diag_error != 4'd0) &&
            (mpeg2_new_b_presentation_diag_error !=
             mpeg2_new_b_presentation_diag_stage)) begin
            mpeg2_new_b_presentation_diag_stage <=
                mpeg2_new_b_presentation_diag_error;
            mpeg2_new_b_presentation_diag_counter <= 30'd0;
        end
        else if (mpeg2_new_b_presentation_diag_progress >
                 mpeg2_new_b_presentation_diag_stage) begin
            mpeg2_new_b_presentation_diag_stage <=
                mpeg2_new_b_presentation_diag_progress;
            mpeg2_new_b_presentation_diag_counter <= 30'd0;
        end
        else begin
            mpeg2_new_b_presentation_diag_counter <=
                mpeg2_new_b_presentation_diag_counter + 1'b1;
        end
    end
end

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_display_frame_bank            <= 1'b0;
        mpeg2_new_display_scratch               <= 1'b0;
        mpeg2_new_framebuffer_swap_reset_count  <= 3'd0;
        mpeg2_new_pending_frame_valid           <= 1'b0;
        mpeg2_new_pending_frame_bank            <= 1'b0;
        mpeg2_new_b_user_success_d              <= 1'b0;
        mpeg2_new_b_picture_frontend_d          <= 1'b0;
        mpeg2_new_b_reorder_active              <= 1'b0;
