        mpeg2_new_b_scratch_pending             <= 1'b0;
        mpeg2_new_b_future_frame_pending        <= 1'b0;
        mpeg2_new_b_future_frame_bank           <= 1'b0;
        mpeg2_new_b_scratch_presented           <= 1'b0;
        mpeg2_new_b_presentation_complete       <= 1'b0;
        mpeg2_new_b_presentation_error          <= 1'b0;
    end
    else begin
        mpeg2_new_b_user_success_d     <= mpeg2_new_b_user_success;
        mpeg2_new_b_picture_frontend_d <= mpeg2_new_b_picture_frontend_active;

        if (mpeg2_new_frame_waiting &&
            !mpeg2_new_b_reorder_active &&
            !mpeg2_new_b_picture_start_edge &&
            !mpeg2_new_b_user_success_edge) begin
            mpeg2_new_pending_frame_valid <= 1'b1;
            mpeg2_new_pending_frame_bank  <= mpeg2_new_completed_frame_bank;
        end

        if (mpeg2_new_b_picture_start_edge) begin
            mpeg2_new_b_reorder_active       <= 1'b1;
            mpeg2_new_b_scratch_pending      <= 1'b0;
            mpeg2_new_b_future_frame_pending <= 1'b1;
            mpeg2_new_b_future_frame_bank    <= mpeg2_new_reference_frame_bank;
            mpeg2_new_b_scratch_presented    <= 1'b0;
            mpeg2_new_b_presentation_complete<= 1'b0;
            mpeg2_new_pending_frame_valid    <= 1'b0;
            if (mpeg2_new_display_scratch ||
                (mpeg2_new_display_frame_bank == mpeg2_new_reference_frame_bank))
                mpeg2_new_b_presentation_error <= 1'b1;
        end

        if (mpeg2_new_b_user_success_edge) begin
            if (!mpeg2_new_b_reorder_active)
                mpeg2_new_b_presentation_error <= 1'b1;
            mpeg2_new_b_scratch_pending <= 1'b1;
        end

        if (mpeg2_new_swap_window_pulse &&
            mpeg2_new_scheduled_frame_valid &&
            mpeg2_new_scheduled_frame_differs) begin
            mpeg2_new_display_scratch <= mpeg2_new_scheduled_frame_scratch;
            if (!mpeg2_new_scheduled_frame_scratch)
                mpeg2_new_display_frame_bank <= mpeg2_new_scheduled_frame_bank;
            mpeg2_new_framebuffer_swap_reset_count <= 3'd4;

            if (mpeg2_new_b_scratch_waiting) begin
                mpeg2_new_b_scratch_pending   <= 1'b0;
                mpeg2_new_b_scratch_presented <= 1'b1;
            end
            else if (mpeg2_new_b_future_waiting) begin
                mpeg2_new_b_future_frame_pending <= 1'b0;
                mpeg2_new_b_reorder_active       <= 1'b0;
                mpeg2_new_pending_frame_valid    <= 1'b0;
                if (mpeg2_new_b_scratch_presented &&
                    !mpeg2_new_b_presentation_error)
                    mpeg2_new_b_presentation_complete <= 1'b1;
                else
                    mpeg2_new_b_presentation_error <= 1'b1;
            end
            else begin
                mpeg2_new_pending_frame_valid <= 1'b0;
            end
        end
        else if (mpeg2_new_framebuffer_swap_reset_count != 3'd0) begin
            mpeg2_new_framebuffer_swap_reset_count <=
                mpeg2_new_framebuffer_swap_reset_count - 3'd1;
        end
    end
end

wire mpeg2_new_framebuffer_reset =
    reset_mpeg2 || (mpeg2_new_framebuffer_swap_reset_count != 3'd0);

localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK_WORDS    = 29'h00010000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH_WORDS = 29'h00020000;
wire [28:0] mpeg2_new_display_frame_offset =
    mpeg2_new_display_scratch ? MPEG2_NEW_DDR_FRAME_SCRATCH_WORDS :
    mpeg2_new_display_frame_bank ? MPEG2_NEW_DDR_FRAME_BANK_WORDS : 29'd0;
assign mpeg2_new_ddr_rd_banked_addr =
    mpeg2_new_ddr_rd_addr + mpeg2_new_display_frame_offset;


mpeg2_luma_framebuffer mpeg2_luma_framebuffer
(
    .reset          (mpeg2_new_framebuffer_reset),
    .mem_clk        (clk_mpeg2),
    .picture_complete(mpeg2_new_first_picture_420_parsed),
    .horizontal_size(mpeg2_new_horizontal_size),
    .vertical_size  (mpeg2_new_vertical_size),
    .ddram_busy     (mpeg2_new_ddr_reader_busy),
    .ddram_dout     (DDRAM_DOUT),
    .ddram_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .ddram_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .ddram_addr     (mpeg2_new_ddr_rd_addr),
    .ddram_rd       (mpeg2_new_ddr_rd),
    .cache_ready    (mpeg2_new_ddr_cache_ready),
    .read_seen      (mpeg2_new_ddr_read_seen),
    .cache_error    (mpeg2_new_ddr_cache_error),
    .rd_clk         (clk_video),
    .h_pos          (display_h_pos),
    .v_pos          (display_v_pos),
    .pixel_en       (display_pixel_en),
    .h_sync         (display_h_sync),
    .v_sync         (display_v_sync),
    .video_r        (fb_video_r),
    .video_g        (fb_video_g),
    .video_b        (fb_video_b),
    .video_de       (fb_video_de),
    .video_hs       (fb_video_hs),
    .video_vs       (fb_video_vs)
);

mpeg2_h262_ddram_arbiter mpeg2_h262_ddram_arbiter
(
    .clk             (clk_mpeg2),
    .reset           (reset_mpeg2),
    .writer_burstcnt (mpeg2_new_ddr_wr_burstcnt),
    .writer_addr     (mpeg2_new_ddr_wr_addr),
    .writer_rd       (mpeg2_new_ddr_wr_rd),
    .writer_din      (mpeg2_new_ddr_wr_din),
    .writer_be       (mpeg2_new_ddr_wr_be),
    .writer_we       (mpeg2_new_ddr_wr_we),
    .writer_busy     (mpeg2_new_ddr_writer_busy),
    .reader_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .reader_addr     (mpeg2_new_ddr_rd_banked_addr),
    .reader_rd       (mpeg2_new_ddr_rd),
    .reader_busy     (mpeg2_new_ddr_reader_busy),
    .reader_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .prediction_burstcnt (mpeg2_new_pred_burstcnt),
    .prediction_addr     (mpeg2_new_pred_addr),
    .prediction_rd       (mpeg2_new_pred_rd),
    .prediction_busy     (mpeg2_new_pred_busy),
    .prediction_dout_ready(mpeg2_new_pred_dout_ready),
    .ddram_busy      (DDRAM_BUSY),
    .ddram_dout_ready(DDRAM_DOUT_READY),
    .ddram_burstcnt  (DDRAM_BURSTCNT),
    .ddram_addr      (DDRAM_ADDR),
    .ddram_rd        (DDRAM_RD),
    .ddram_din       (DDRAM_DIN),
    .ddram_be        (DDRAM_BE),
    .ddram_we        (DDRAM_WE)
);

