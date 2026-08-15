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
