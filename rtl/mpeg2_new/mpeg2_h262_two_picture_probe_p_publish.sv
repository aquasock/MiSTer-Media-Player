//============================================================================
// MiSTer Media Player - P-picture publication/reference compatibility shell
//
// Phase 1U-m preserves the accepted I-picture parser/bookkeeper and P
// diagnostics while promoting a persisted P destination bank into the normal
// completed-frame/reference bookkeeping path.  This adds publication and
// reference ownership for one controlled P picture; consecutive-P client re-arm
// remains the next integration boundary.
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
wire p_hold;
wire p_error;

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

// Phase 1U-m owns the externally visible frame/reference bank state.  I-picture
// completion is inherited from the accepted bookkeeper.  A rising P-persistence
// completion is treated identically for publication/reference ownership.
reg        p_persistence_d;
reg        p_published_seen;
reg        publication_error;
reg        picture_complete_pulse;
reg        active_frame_bank_reg;
reg        completed_frame_bank_reg;
reg [7:0]  picture_count_reg;
reg        reference_frame_valid_reg;
reg        reference_frame_bank_reg;
reg [7:0]  reference_promotion_count_reg;

wire p_persisted_now = p_persistence_complete && !p_persistence_d;
wire reference_progress_error =
    (picture_count_reg >= 8'd2) && p_published_seen &&
    (!reference_frame_valid_reg ||
     (reference_promotion_count_reg < picture_count_reg) ||
     (reference_frame_bank_reg != completed_frame_bank_reg) ||
     (reference_frame_bank_reg == active_frame_bank_reg));
wire publication_progress_error =
    second_picture_420_parsed && p_picture_expected && !p_published_seen;

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
        p_published_seen              <= 1'b0;
        publication_error             <= 1'b0;
        picture_complete_pulse        <= 1'b0;
        active_frame_bank_reg         <= 1'b0;
        completed_frame_bank_reg      <= 1'b0;
        picture_count_reg             <= 8'd0;
        reference_frame_valid_reg     <= 1'b0;
        reference_frame_bank_reg      <= 1'b0;
        reference_promotion_count_reg <= 8'd0;
    end
    else begin
        p_persistence_d        <= p_persistence_complete;
        picture_complete_pulse <= 1'b0;

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
                p_published_seen         <= 1'b1;
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

mpeg2_h262_p_diagnostic_controller p_controller
(
    .clk                         (clk),
    .reset                       (reset),
    .stream_data                 (stream_data),
    .stream_valid                (stream_valid),
    .p_picture_expected          (p_picture_expected),
    .p_persistence_complete      (p_persistence_complete),
    .stream_hold                 (p_hold),
    .p_macroblock_type_seen      (p_macroblock_type_seen),
    .p_forward_vector_valid      (p_forward_vector_valid),
    .p_forward_vector_x          (p_forward_vector_x),
    .p_forward_vector_y          (p_forward_vector_y),
    .p_residual_required         (p_residual_required),
    .p_residual_success          (p_residual_success),
    .p_first_residual_sample_valid(p_first_residual_sample_valid),
    .p_first_residual_sample_value(p_first_residual_sample_value),
    .p_residual_sample_valid     (p_residual_sample_valid),
    .p_residual_sample_index     (p_residual_sample_index),
    .p_residual_sample_value     (p_residual_sample_value),
    .probe_error                 (p_error)
);

assign stream_ready = parser_ready && !p_hold;
assign probe_error  = bookkeeper_error || p_error || publication_error ||
                      reference_progress_error || publication_progress_error;

// Base frame/reference outputs remain intentionally observed so accidental
// synthesis pruning cannot hide a divergence in the accepted I-only bookkeeper.
wire unused_base_state = &{1'b0, base_active_frame_bank,
                           base_completed_frame_bank, base_picture_count,
                           base_reference_frame_valid, base_reference_frame_bank,
                           base_reference_promotion_count};

endmodule
