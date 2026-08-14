//============================================================================
// MiSTer Media Player - consecutive P-picture publication/reference shell
//
// Phase 1U-n extends the accepted Phase 1U-m publication path across two
// consecutive controlled P pictures.  Each persisted P publishes its destination
// bank as the next forward reference, flips the destination bank, and locally
// re-arms the accepted per-picture aligned/plan state without resetting the
// long-lived sequence context or consuming/replaying compressed bytes.
//============================================================================

module mpeg2_h262_two_picture_probe
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,
    output wire        stream_ready,

    input  wire        phase1_supported,
    input  wire [13:0] vertical_size,
    input  wire [1:0]  intra_dc_precision,
    input  wire        intra_vlc_format,

    input  wire        pipeline_block_done,
    input  wire        recon_block_complete,
    input  wire        p_persistence_complete,

    output wire        slice_header_seen,
    output wire        macroblock_address_seen,
    output wire        first_i_macroblock_seen,
    output wire        first_luma_dc_seen,
    output wire        first_luma_block_complete,
    output wire        first_picture_420_parsed,
    output wire        second_picture_420_parsed,
    output wire        picture_420_complete,
    output wire        active_frame_bank,
    output wire        completed_frame_bank,
    output wire [7:0]  picture_count,

    output wire        reference_frame_valid,
    output wire        reference_frame_bank,
    output wire [7:0]  reference_promotion_count,

    output wire        p_macroblock_type_seen,
    output wire        p_forward_vector_valid,
    output wire signed [12:0] p_forward_vector_x,
    output wire signed [12:0] p_forward_vector_y,
    output wire        p_residual_required,
    output wire        p_residual_success,
    output wire        p_first_residual_sample_valid,
    output wire signed [15:0] p_first_residual_sample_value,
    output wire        p_residual_sample_valid,
    output wire [5:0]  p_residual_sample_index,
    output wire signed [15:0] p_residual_sample_value,

    output wire        probe_error,

    output wire [4:0]  quantiser_scale_code,
    output wire [11:0] macroblock_address_increment,
    output wire        macroblock_quant,
    output wire [4:0]  macroblock_quantiser_scale_code,
    output wire [7:0]  slice_vertical_position,
    output wire [2:0]  slice_vertical_position_extension,

    output wire [3:0]  first_luma_dc_size,
    output wire signed [12:0] first_luma_dc_differential,
    output wire [10:0] first_luma_dc_coefficient,
    output wire [6:0]  first_luma_ac_nonzero_count,
    output wire [5:0]  first_luma_last_coeff_index,
    output wire signed [11:0] first_luma_last_ac_level,

    output wire        slice_start,
    output wire        luma_macroblock_start,
    output wire [2:0]  qfs_block_index,
    output wire        qfs_block_start,
    output wire        qfs_write_en,
    output wire [5:0]  qfs_write_index,
    output wire signed [12:0] qfs_write_value,
    output wire        qfs_block_end
);

wire parser_ready;
wire p_picture_expected;
wire bookkeeper_error;
wire p_hold_raw;
wire p_error_raw;

wire base_picture_420_complete;
wire base_active_frame_bank;
wire base_completed_frame_bank;
wire [7:0] base_picture_count;
wire base_reference_frame_valid;
wire base_reference_frame_bank;
wire [7:0] base_reference_promotion_count;

mpeg2_h262_picture_bookkeeper bookkeeper
(
    .clk                         (clk),
    .reset                       (reset),
    .stream_data                 (stream_data),
    .stream_valid                (stream_valid),
    .parser_stream_ready         (parser_ready),
    .phase1_supported            (phase1_supported),
    .vertical_size               (vertical_size),
    .intra_dc_precision          (intra_dc_precision),
    .intra_vlc_format            (intra_vlc_format),
    .pipeline_block_done         (pipeline_block_done),
    .recon_block_complete        (recon_block_complete),
    .p_picture_expected          (p_picture_expected),
    .slice_header_seen           (slice_header_seen),
    .macroblock_address_seen     (macroblock_address_seen),
    .first_i_macroblock_seen     (first_i_macroblock_seen),
    .first_luma_dc_seen          (first_luma_dc_seen),
    .first_luma_block_complete   (first_luma_block_complete),
    .first_picture_420_parsed    (first_picture_420_parsed),
    .second_picture_420_parsed   (second_picture_420_parsed),
    .picture_420_complete        (base_picture_420_complete),
    .active_frame_bank           (base_active_frame_bank),
    .completed_frame_bank        (base_completed_frame_bank),
    .picture_count               (base_picture_count),
    .reference_frame_valid       (base_reference_frame_valid),
    .reference_frame_bank        (base_reference_frame_bank),
    .reference_promotion_count   (base_reference_promotion_count),
    .probe_error                 (bookkeeper_error),
    .quantiser_scale_code        (quantiser_scale_code),
    .macroblock_address_increment(macroblock_address_increment),
    .macroblock_quant            (macroblock_quant),
    .macroblock_quantiser_scale_code(macroblock_quantiser_scale_code),
    .slice_vertical_position     (slice_vertical_position),
    .slice_vertical_position_extension(slice_vertical_position_extension),
    .first_luma_dc_size          (first_luma_dc_size),
    .first_luma_dc_differential  (first_luma_dc_differential),
    .first_luma_dc_coefficient   (first_luma_dc_coefficient),
    .first_luma_ac_nonzero_count (first_luma_ac_nonzero_count),
    .first_luma_last_coeff_index (first_luma_last_coeff_index),
    .first_luma_last_ac_level    (first_luma_last_ac_level),
    .slice_start                 (slice_start),
    .luma_macroblock_start       (luma_macroblock_start),
    .qfs_block_index             (qfs_block_index),
    .qfs_block_start             (qfs_block_start),
    .qfs_write_en                (qfs_write_en),
    .qfs_write_index             (qfs_write_index),
    .qfs_write_value             (qfs_write_value),
    .qfs_block_end               (qfs_block_end)
);

reg        p_persistence_d;
reg [1:0]  p_publication_count;
reg        publication_error;
reg        picture_complete_pulse;
reg        active_frame_bank_reg;
reg        completed_frame_bank_reg;
reg [7:0]  picture_count_reg;
reg        reference_frame_valid_reg;
reg        reference_frame_bank_reg;
reg [7:0]  reference_promotion_count_reg;

wire p_persisted_now = p_persistence_complete && !p_persistence_d;

// Independent picture-header observer used only to make the I/P/P/I regression
// self-checking.  picture_coding_type occupies bits 5:3 of the second picture
// header payload byte after the 00 00 01 00 start code.
reg [31:0] picture_window;
wire [31:0] picture_window_next = {picture_window[23:0], stream_data};
wire picture_start_now = (picture_window_next == 32'h00000100);
reg       picture_header_capture;
reg       picture_header_second_byte;
reg [1:0] p_header_count;
reg       consecutive_candidate_seen;

wire reference_progress_error =
    (picture_count_reg >= 8'd2) && (p_publication_count != 2'd0) &&
    (!reference_frame_valid_reg ||
     (reference_promotion_count_reg < picture_count_reg) ||
     (reference_frame_bank_reg != completed_frame_bank_reg) ||
     (reference_frame_bank_reg == active_frame_bank_reg));

assign picture_420_complete      = picture_complete_pulse;
assign active_frame_bank         = active_frame_bank_reg;
assign completed_frame_bank      = completed_frame_bank_reg;
assign picture_count             = picture_count_reg;
assign reference_frame_valid     = reference_frame_valid_reg;
assign reference_frame_bank      = reference_frame_bank_reg;
assign reference_promotion_count = reference_promotion_count_reg;

always @(posedge clk) begin
    if (reset) begin
        p_persistence_d               <= 1'b0;
        p_publication_count           <= 2'd0;
        publication_error             <= 1'b0;
        picture_complete_pulse        <= 1'b0;
        active_frame_bank_reg         <= 1'b0;
        completed_frame_bank_reg      <= 1'b0;
        picture_count_reg             <= 8'd0;
        reference_frame_valid_reg     <= 1'b0;
        reference_frame_bank_reg      <= 1'b0;
        reference_promotion_count_reg <= 8'd0;
        picture_window                <= 32'd0;
        picture_header_capture        <= 1'b0;
        picture_header_second_byte    <= 1'b0;
        p_header_count                <= 2'd0;
        consecutive_candidate_seen    <= 1'b0;
    end
    else begin
        p_persistence_d        <= p_persistence_complete;
        picture_complete_pulse <= 1'b0;

        if (stream_valid) begin
            picture_window <= picture_window_next;
            if (picture_start_now) begin
                picture_header_capture     <= 1'b1;
                picture_header_second_byte <= 1'b0;
            end
            else if (picture_header_capture) begin
                if (!picture_header_second_byte) begin
                    picture_header_second_byte <= 1'b1;
                end
                else begin
                    picture_header_capture     <= 1'b0;
                    picture_header_second_byte <= 1'b0;
                    if (stream_data[5:3] == 3'b010) begin
                        if (p_header_count != 2'd3)
                            p_header_count <= p_header_count + 2'd1;
                        if (p_header_count >= 2'd1)
                            consecutive_candidate_seen <= 1'b1;
                    end
                    else if ((stream_data[5:3] == 3'b001) &&
                             consecutive_candidate_seen &&
                             (p_publication_count < 2'd2)) begin
                        publication_error <= 1'b1;
                    end
                end
            end
        end

        if (base_picture_420_complete) begin
            picture_complete_pulse   <= 1'b1;
            completed_frame_bank_reg <= active_frame_bank_reg;
            active_frame_bank_reg    <= ~active_frame_bank_reg;
            if (picture_count_reg != 8'hFF)
                picture_count_reg <= picture_count_reg + 8'd1;
            if (reference_frame_valid_reg &&
                (active_frame_bank_reg == reference_frame_bank_reg))
                publication_error <= 1'b1;
            reference_frame_valid_reg <= 1'b1;
            reference_frame_bank_reg  <= active_frame_bank_reg;
            if (reference_promotion_count_reg != 8'hFF)
                reference_promotion_count_reg <=
                    reference_promotion_count_reg + 8'd1;
        end
        else if (p_persisted_now) begin
            if (!reference_frame_valid_reg ||
                (active_frame_bank_reg == reference_frame_bank_reg)) begin
                publication_error <= 1'b1;
            end
            else begin
                if (p_publication_count != 2'd3)
                    p_publication_count <= p_publication_count + 2'd1;
                picture_complete_pulse   <= 1'b1;
                completed_frame_bank_reg <= active_frame_bank_reg;
                active_frame_bank_reg    <= ~active_frame_bank_reg;
                if (picture_count_reg != 8'hFF)
                    picture_count_reg <= picture_count_reg + 8'd1;
                reference_frame_valid_reg <= 1'b1;
                reference_frame_bank_reg  <= active_frame_bank_reg;
                if (reference_promotion_count_reg != 8'hFF)
                    reference_promotion_count_reg <=
                        reference_promotion_count_reg + 8'd1;
            end
        end
    end
end

wire p_macroblock_type_seen_raw;
wire p_forward_vector_valid_raw;
wire signed [12:0] p_forward_vector_x_raw;
wire signed [12:0] p_forward_vector_y_raw;
wire p_residual_required_raw;
wire p_residual_success_raw;
wire p_first_residual_sample_valid_raw;
wire signed [15:0] p_first_residual_sample_value_raw;
wire p_residual_sample_valid_raw;
wire [5:0] p_residual_sample_index_raw;
wire signed [15:0] p_residual_sample_value_raw;

mpeg2_h262_p_diagnostic_controller p_controller
(
    .clk                         (clk),
    .reset                       (reset),
    .stream_data                 (stream_data),
    .stream_valid                (stream_valid),
    .p_picture_expected          (p_picture_expected),
    .p_persistence_complete      (p_persistence_complete),
    .stream_hold                 (p_hold_raw),
    .p_macroblock_type_seen      (p_macroblock_type_seen_raw),
    .p_forward_vector_valid      (p_forward_vector_valid_raw),
    .p_forward_vector_x          (p_forward_vector_x_raw),
    .p_forward_vector_y          (p_forward_vector_y_raw),
    .p_residual_required         (p_residual_required_raw),
    .p_residual_success          (p_residual_success_raw),
    .p_first_residual_sample_valid(p_first_residual_sample_valid_raw),
    .p_first_residual_sample_value(p_first_residual_sample_value_raw),
    .p_residual_sample_valid     (p_residual_sample_valid_raw),
    .p_residual_sample_index     (p_residual_sample_index_raw),
    .p_residual_sample_value     (p_residual_sample_value_raw),
    .probe_error                 (p_error_raw)
);

assign p_macroblock_type_seen        = p_macroblock_type_seen_raw;
assign p_forward_vector_valid        = p_forward_vector_valid_raw;
assign p_forward_vector_x            = p_forward_vector_x_raw;
assign p_forward_vector_y            = p_forward_vector_y_raw;
assign p_residual_required           = p_residual_required_raw;
assign p_residual_success            = p_residual_success_raw;
assign p_first_residual_sample_valid = p_first_residual_sample_valid_raw;
assign p_first_residual_sample_value = p_first_residual_sample_value_raw;
assign p_residual_sample_valid       = p_residual_sample_valid_raw;
assign p_residual_sample_index       = p_residual_sample_index_raw;
assign p_residual_sample_value       = p_residual_sample_value_raw;

assign stream_ready = parser_ready && !p_hold_raw;
assign probe_error  = bookkeeper_error || p_error_raw ||
                      publication_error || reference_progress_error;

wire unused_base_state = &{1'b0, base_active_frame_bank,
                           base_completed_frame_bank, base_picture_count,
                           base_reference_frame_valid, base_reference_frame_bank,
                           base_reference_promotion_count};

endmodule
