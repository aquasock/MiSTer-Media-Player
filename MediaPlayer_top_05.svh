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
wire mpeg2_new_picture_header_classified_now =
    mpeg2_new_decode_stream_valid &&
    mpeg2_new_p_ownership_header_capture &&
    mpeg2_new_p_ownership_header_second_byte;
wire [2:0] mpeg2_new_picture_header_type_now = mpeg2_stream_data[5:3];
wire mpeg2_new_b_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b011);
wire mpeg2_new_non_b_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now != 3'b011);
wire mpeg2_new_i_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b001);
wire mpeg2_new_p_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b010);
wire mpeg2_new_sequence_end_now =
    mpeg2_new_decode_stream_valid &&
    (mpeg2_new_p_ownership_picture_window_next == 32'h000001b7);
wire mpeg2_new_p_destination_display_owned =
    !mpeg2_new_display_scratch &&
    (mpeg2_new_active_frame_bank == mpeg2_new_display_frame_bank);
wire mpeg2_new_p_publication_now =
    mpeg2_new_picture_420_complete &&
    (mpeg2_new_picture_coding_type == 3'b010);

assign mpeg2_new_p_destination_ownership_hold =
    mpeg2_new_p_destination_ownership_hold_reg;

wire mpeg2_new_b_reference_overlap_header;

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

        if (mpeg2_new_decode_stream_valid) begin
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

                    if (mpeg2_new_p_ownership_arm ||
                        mpeg2_new_b_reference_overlap_header) begin
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

// Entry 206: every accepted picture header produces an explicit event, so two
// adjacent B headers cannot collapse into one coding-type level.  The scheduler
// alternates two scratch frames and owns the complete B...B->future-reference
// presentation transaction, including fail-open error retirement.
wire [31:0] mpeg2_new_b_scheduler_debug_state;
mpeg2_h262_picture_timestamp mpeg2_h262_picture_timestamp
(
    .clk                (clk_mpeg2),
    .reset              (reset_mpeg2),
    .metadata_valid     (mpeg2_new_inband_valid),
    .metadata_pts       (mpeg2_new_inband_pts_90k),
    .picture_start      (mpeg2_new_picture_header_classified_now),
    .active_frame_bank  (mpeg2_new_active_frame_bank),
    .display_frame_bank (mpeg2_new_display_frame_bank),
    .display_pts        (mpeg2_new_display_pts),
    .display_pts_valid  (mpeg2_new_display_pts_valid),
    .associated_count   (mpeg2_new_associated_count)
);

mpeg2_h262_b_presentation_scheduler mpeg2_h262_b_presentation_scheduler
(
    .clk                         (clk_mpeg2),
    .reset                       (reset_mpeg2),
    .swap_window_pulse           (mpeg2_new_swap_window_pulse),
    .frame_rate_code             (mpeg2_new_frame_rate_code),
    .frame_waiting               (mpeg2_new_frame_waiting),
    .completed_frame_bank        (mpeg2_new_completed_frame_bank),
    .reference_frame_bank        (mpeg2_new_reference_frame_bank),
    .reference_promotion_count   (mpeg2_new_reference_promotion_count),
    .b_picture_start             (mpeg2_new_b_picture_start_now),
    .non_b_picture_start         (mpeg2_new_non_b_picture_start_now),
    .i_picture_start             (mpeg2_new_i_picture_start_now),
    .p_picture_start             (mpeg2_new_p_picture_start_now),
    .sequence_end                (mpeg2_new_sequence_end_now),
    .b_user_success              (mpeg2_new_b_user_success),
    .b_decode_error              (mpeg2_new_phase1_probe_error),
    .display_frame_bank          (mpeg2_new_display_frame_bank),
    .display_scratch             (mpeg2_new_display_scratch),
    .display_scratch_bank        (mpeg2_new_display_scratch_bank),
    .decode_scratch_bank         (mpeg2_new_b_decode_scratch_bank),
    .framebuffer_swap_reset_count(mpeg2_new_framebuffer_swap_reset_count),
    .reference_overlap_header    (mpeg2_new_b_reference_overlap_header),
    .presentation_hold           (mpeg2_new_b_presentation_hold),
    .scratch_available           (mpeg2_new_b_scratch_available),
    .promotion_active            (mpeg2_new_b_promotion_active),
    .presentation_complete       (mpeg2_new_b_presentation_complete),
    .presentation_error          (mpeg2_new_b_presentation_error),
    .debug_state                 (mpeg2_new_b_scheduler_debug_state)
);
