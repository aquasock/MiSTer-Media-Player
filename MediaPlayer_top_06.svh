(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_native_active_sync;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2)
        mpeg2_new_native_active_sync <= 3'b000;
    else
        mpeg2_new_native_active_sync <=
            {mpeg2_new_native_active_sync[1:0], display_native_interlaced};
end

wire mpeg2_new_native_mode_change =
    mpeg2_new_native_active_sync[1] ^ mpeg2_new_native_active_sync[2];
assign mpeg2_new_native_active_mpeg2 = mpeg2_new_native_active_sync[2];
wire mpeg2_new_framebuffer_reset =
    reset_mpeg2 ||
    (mpeg2_new_framebuffer_swap_reset_count != 3'd0) ||
    mpeg2_new_native_mode_change;
wire mpeg2_new_framebuffer_generation_reset =
    (mpeg2_new_framebuffer_swap_reset_count != 3'd0) ||
    mpeg2_new_native_mode_change;

wire mpeg2_new_framebuffer_picture_present_rd;
wire mpeg2_new_framebuffer_prefill_deadline_missed_rd;
// Entry 516: additional video-domain per-field evidence levels/toggles.
wire mpeg2_new_framebuffer_sequence_phase_error_rd;
wire mpeg2_new_framebuffer_first_field_line_toggle_rd;
wire mpeg2_new_framebuffer_second_field_line_toggle_rd;
// The DDR service evidence is generated on mem_clk, which is clk_mpeg2 itself,
// so it needs no synchronizer and stays fully timed.
wire mpeg2_new_framebuffer_first_field_fetch_toggle;
wire mpeg2_new_framebuffer_second_field_fetch_toggle;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_picture_present_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_prefill_missed_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_phase_error_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_first_field_line_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_second_field_line_sync;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_framebuffer_picture_present_sync <= 3'b000;
        mpeg2_new_framebuffer_prefill_missed_sync <= 3'b000;
        mpeg2_new_framebuffer_phase_error_sync <= 3'b000;
        mpeg2_new_framebuffer_first_field_line_sync <= 3'b000;
        mpeg2_new_framebuffer_second_field_line_sync <= 3'b000;
    end
    else begin
        mpeg2_new_framebuffer_picture_present_sync <=
            {mpeg2_new_framebuffer_picture_present_sync[1:0],
             mpeg2_new_framebuffer_picture_present_rd};
        mpeg2_new_framebuffer_prefill_missed_sync <=
            {mpeg2_new_framebuffer_prefill_missed_sync[1:0],
             mpeg2_new_framebuffer_prefill_deadline_missed_rd};
        mpeg2_new_framebuffer_phase_error_sync <=
            {mpeg2_new_framebuffer_phase_error_sync[1:0],
             mpeg2_new_framebuffer_sequence_phase_error_rd};
        mpeg2_new_framebuffer_first_field_line_sync <=
            {mpeg2_new_framebuffer_first_field_line_sync[1:0],
             mpeg2_new_framebuffer_first_field_line_toggle_rd};
        mpeg2_new_framebuffer_second_field_line_sync <=
            {mpeg2_new_framebuffer_second_field_line_sync[1:0],
             mpeg2_new_framebuffer_second_field_line_toggle_rd};
    end
end

wire mpeg2_new_framebuffer_picture_present =
    mpeg2_new_framebuffer_picture_present_sync[2];
wire mpeg2_new_framebuffer_prefill_deadline_missed =
    mpeg2_new_framebuffer_prefill_missed_sync[2];
wire mpeg2_new_framebuffer_sequence_phase_error =
    mpeg2_new_framebuffer_phase_error_sync[2];
wire mpeg2_new_framebuffer_first_field_line =
    mpeg2_new_framebuffer_first_field_line_sync[2];
wire mpeg2_new_framebuffer_second_field_line =
    mpeg2_new_framebuffer_second_field_line_sync[2];

localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK_WORDS     = 29'h00010000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH0_WORDS = 29'h00020000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH1_WORDS = 29'h00030000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK2_WORDS    = 29'h00040000;
wire [28:0] mpeg2_new_display_frame_offset =
    mpeg2_new_display_scratch ?
        (mpeg2_new_display_scratch_bank ? MPEG2_NEW_DDR_FRAME_SCRATCH1_WORDS :
                                           MPEG2_NEW_DDR_FRAME_SCRATCH0_WORDS) :
    (mpeg2_new_display_frame_bank == 2'd1) ? MPEG2_NEW_DDR_FRAME_BANK_WORDS :
    (mpeg2_new_display_frame_bank == 2'd2) ? MPEG2_NEW_DDR_FRAME_BANK2_WORDS :
                                             29'd0;
assign mpeg2_new_ddr_rd_banked_addr =
    mpeg2_new_ddr_rd_addr + mpeg2_new_display_frame_offset;


mpeg2_luma_framebuffer mpeg2_luma_framebuffer
(
    .reset          (mpeg2_new_framebuffer_reset),
    .mem_clk        (clk_mpeg2),
    .picture_complete(mpeg2_new_first_picture_420_parsed),
    .horizontal_size(mpeg2_new_horizontal_size),
    .vertical_size  (mpeg2_new_vertical_size),
    // Use the fully synchronized presentation-mode level on the memory side.
    // The framebuffer carries this descriptor back through its existing
    // video-domain descriptor synchronizers with the published picture.
    .native_interlaced(mpeg2_new_native_active_sync[2]),
    .top_field_first(mpeg2_new_native_top_field_first),
    .ddram_busy     (mpeg2_new_ddr_reader_busy),
    .ddram_dout     (DDRAM_DOUT),
    .ddram_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .ddram_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .ddram_addr     (mpeg2_new_ddr_rd_addr),
    .ddram_rd       (mpeg2_new_ddr_rd),
    .cache_ready    (mpeg2_new_ddr_cache_ready),
    .read_seen      (mpeg2_new_ddr_read_seen),
    .cache_error    (mpeg2_new_ddr_cache_error),
    .bank_overlap_error(mpeg2_new_ddr_bank_overlap_error),
    .picture_present_debug(mpeg2_new_framebuffer_picture_present_rd),
    .prefill_deadline_missed_debug(
        mpeg2_new_framebuffer_prefill_deadline_missed_rd),
    .sequence_phase_error_debug(
        mpeg2_new_framebuffer_sequence_phase_error_rd),
    .first_field_line_toggle_debug(
        mpeg2_new_framebuffer_first_field_line_toggle_rd),
    .second_field_line_toggle_debug(
        mpeg2_new_framebuffer_second_field_line_toggle_rd),
    .first_field_fetch_toggle_debug(
        mpeg2_new_framebuffer_first_field_fetch_toggle),
    .second_field_fetch_toggle_debug(
        mpeg2_new_framebuffer_second_field_fetch_toggle),
    .rd_clk         (clk_video),
    .h_pos          (display_h_pos),
    .v_pos          (display_v_pos),
    .pixel_ce       (display_pixel_ce),
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
