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
wire mpeg2_new_b_cadence_slot_debug;
wire mpeg2_new_b_candidate_presentable_debug;
wire mpeg2_new_startup_swaps_enabled;
wire mpeg2_new_startup_video_blank;
mpeg2_h262_native_startup mpeg2_h262_native_startup (
    .clk_mpeg2(clk_mpeg2), .reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video), .reset_video(reset_video),
    .native_request(mpeg2_new_native_480i_request),
    .frame_rate_code(mpeg2_new_frame_rate_code),
    .first_picture_complete(mpeg2_new_first_picture_420_parsed),
    .candidate_presentable(mpeg2_new_b_candidate_presentable_debug),
    .sequence_end_seen(mpeg2_new_sequence_end_seen),
    .bypass_event(mpeg2_new_extracted_metadata_valid ||
        mpeg2_new_inband_pcm_valid ||
        (mpeg2_new_picture_header_classified_now && !mpeg2_new_i_picture_start_now) ||
        mpeg2_new_syntax_error || mpeg2_new_phase1_probe_error),
    .frame_window(display_frame_window),
    .swaps_enabled(mpeg2_new_startup_swaps_enabled),
    .video_blank(mpeg2_new_startup_video_blank)
);
mpeg2_h262_picture_timestamp mpeg2_h262_picture_timestamp
(
    .clk                     (clk_mpeg2),
    .reset                   (reset_mpeg2),
    .metadata_valid          (mpeg2_new_inband_valid),
    .metadata_pts            (mpeg2_new_inband_pts_90k),
    .picture_coding_extension_valid(mpeg2_new_picture_coding_extension_valid),
    .picture_top_field_first (mpeg2_new_picture_coding_extension_top_field_first),
    .picture_start           (mpeg2_new_picture_header_classified_now),
    .picture_is_b            (mpeg2_new_b_picture_start_now),
    .decode_scratch_bank     (mpeg2_new_b_decode_scratch_bank),
    .b_picture_complete      (mpeg2_new_b_user_success),
    .active_frame_bank       (mpeg2_new_active_frame_bank),
    .display_frame_bank      (mpeg2_new_display_frame_bank),
    .display_scratch         (mpeg2_new_display_scratch),
    .display_scratch_bank    (mpeg2_new_display_scratch_bank),
    .candidate_frame_valid   (mpeg2_new_candidate_frame_valid),
    .candidate_frame_scratch (mpeg2_new_candidate_frame_scratch),
    .candidate_scratch_bank  (mpeg2_new_candidate_scratch_bank),
    .candidate_frame_bank    (mpeg2_new_candidate_frame_bank),
    .display_pts             (mpeg2_new_display_pts),
    .display_pts_valid       (mpeg2_new_display_pts_valid),
    .display_top_field_first (mpeg2_new_display_top_field_first),
    .candidate_pts           (mpeg2_new_candidate_pts),
    .candidate_pts_valid     (mpeg2_new_candidate_pts_valid),
    .associated_count        (mpeg2_new_associated_count)
);

mpeg2_h262_pts_presentation_timeline mpeg2_h262_pts_presentation_timeline
(
    .clk              (clk_mpeg2),
    .reset            (reset_mpeg2),
    .tick_90k         (mpeg2_new_stc_tick_90k),
    .metadata_valid   (mpeg2_new_inband_valid),
    .metadata_pts     (mpeg2_new_inband_pts_90k),
    .candidate_valid  (mpeg2_new_candidate_pts_valid),
    .candidate_pts    (mpeg2_new_candidate_pts),
    .anchored         (mpeg2_new_pts_timeline_anchored),
    .stc_90k          (mpeg2_new_pts_timeline_stc),
    .candidate_active (mpeg2_new_timestamp_candidate_active),
    .candidate_due    (mpeg2_new_timestamp_candidate_due)
);

mpeg2_h262_b_presentation_scheduler mpeg2_h262_b_presentation_scheduler
(
    .clk                         (clk_mpeg2),
    .reset                       (reset_mpeg2),
    .swap_window_pulse           (mpeg2_new_swap_window_pulse &&
                                 mpeg2_new_startup_swaps_enabled),
    .cadence_tick_pulse          (mpeg2_new_cadence_window_pulse),
    .frame_rate_code             (mpeg2_new_frame_rate_code),
    .timestamp_candidate_active  (mpeg2_new_timestamp_candidate_active),
    .timestamp_candidate_due     (mpeg2_new_timestamp_candidate_due),
    .native_ordinary_overlap_enable(mpeg2_new_native_active_mpeg2),
    .active_frame_bank           (mpeg2_new_active_frame_bank),
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
    .candidate_frame_valid       (mpeg2_new_candidate_frame_valid),
    .candidate_frame_scratch     (mpeg2_new_candidate_frame_scratch),
    .candidate_scratch_bank      (mpeg2_new_candidate_scratch_bank),
    .candidate_frame_bank        (mpeg2_new_candidate_frame_bank),
    .cadence_slot_debug          (mpeg2_new_b_cadence_slot_debug),
    .candidate_presentable_debug (mpeg2_new_b_candidate_presentable_debug),
    .framebuffer_swap_reset_count(mpeg2_new_framebuffer_swap_reset_count),
    .reference_overlap_header    (mpeg2_new_b_reference_overlap_header),
    .presentation_hold           (mpeg2_new_b_presentation_hold),
    .scratch_available           (mpeg2_new_b_scratch_available),
    .promotion_active            (mpeg2_new_b_promotion_active),
    .presentation_complete       (mpeg2_new_b_presentation_complete),
    .presentation_error          (mpeg2_new_b_presentation_error),
    .debug_state                 (mpeg2_new_b_scheduler_debug_state)
);
