    (mpeg2_new_display_scratch ||
     (mpeg2_new_completed_frame_bank != mpeg2_new_display_frame_bank));

// kate - Commit 162 fixes the proven consecutive-P publication/presentation
// race without weakening Commit-142 DDR ownership protection.  After a P is
// published, accepted stream bytes are allowed to reach and classify the next
// picture header.  Only when that next picture is another P and its selected
// destination bank is still the displayed reference bank is input then parked.
// The hold releases as soon as presentation moves away from that bank.  A
// following B or I disarms the P-only gate and retains the existing B reorder
// and presentation path unchanged.
reg [31:0] mpeg2_new_p_ownership_picture_window;
reg        mpeg2_new_p_ownership_header_capture;
reg        mpeg2_new_p_ownership_header_second_byte;
reg        mpeg2_new_p_ownership_arm;
reg        mpeg2_new_p_destination_ownership_hold_reg;

wire [31:0] mpeg2_new_p_ownership_picture_window_next =
    {mpeg2_new_p_ownership_picture_window[23:0], mpeg2_stream_data};
wire mpeg2_new_p_ownership_picture_start_now =
    (mpeg2_new_p_ownership_picture_window_next == 32'h00000100);
wire mpeg2_new_p_destination_display_owned =
    !mpeg2_new_display_scratch &&
    (mpeg2_new_active_frame_bank == mpeg2_new_display_frame_bank);
wire mpeg2_new_p_publication_now =
    mpeg2_new_picture_420_complete &&
    (mpeg2_new_picture_coding_type == 3'b010);

assign mpeg2_new_p_destination_ownership_hold =
    mpeg2_new_p_destination_ownership_hold_reg;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_p_ownership_picture_window      <= 32'd0;
        mpeg2_new_p_ownership_header_capture      <= 1'b0;
        mpeg2_new_p_ownership_header_second_byte  <= 1'b0;
        mpeg2_new_p_ownership_arm                 <= 1'b0;
        mpeg2_new_p_destination_ownership_hold_reg <= 1'b0;
    end
    else begin
        if (mpeg2_new_p_destination_ownership_hold_reg &&
            !mpeg2_new_p_destination_display_owned)
            mpeg2_new_p_destination_ownership_hold_reg <= 1'b0;

        if (mpeg2_new_p_publication_now)
            mpeg2_new_p_ownership_arm <= 1'b1;

        if (mpeg2_stream_rd) begin
            mpeg2_new_p_ownership_picture_window <=
                mpeg2_new_p_ownership_picture_window_next;

            if (mpeg2_new_p_ownership_picture_start_now) begin
                mpeg2_new_p_ownership_header_capture     <= 1'b1;
                mpeg2_new_p_ownership_header_second_byte <= 1'b0;
            end
            else if (mpeg2_new_p_ownership_header_capture) begin
                if (!mpeg2_new_p_ownership_header_second_byte) begin
                    mpeg2_new_p_ownership_header_second_byte <= 1'b1;
                end
                else begin
                    mpeg2_new_p_ownership_header_capture     <= 1'b0;
                    mpeg2_new_p_ownership_header_second_byte <= 1'b0;

                    if (mpeg2_new_p_ownership_arm) begin
                        mpeg2_new_p_ownership_arm <= 1'b0;
                        if ((mpeg2_stream_data[5:3] == 3'b010) &&
                            mpeg2_new_p_destination_display_owned)
                            mpeg2_new_p_destination_ownership_hold_reg <= 1'b1;
                    end
                end
            end
        end
    end
end

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
