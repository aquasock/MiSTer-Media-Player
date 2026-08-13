//============================================================================
// MiSTer Media Player - Phase 1T continuous H.262 picture wrapper
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 6.2.2 video_sequence().
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 3.111 and 7.6.2.2.
//   A reference frame is a reconstructed I- or P-frame. Frame prediction in
//   a P-picture uses the most recently reconstructed reference frame.
//
// kate - Phase 1S extended the proven Phase 1Q/1R single-parser re-arm path to
// every supported picture. Every picture still waits for the DDR persistence
// handshake block by block. The active write bank alternates 0/1 after each
// complete picture, and a one-cycle completion pulse reports which bank just
// became complete so the top level can republish it safely.
//
// kate - Phase 1T-a adds explicit reference-frame ownership bookkeeping without
// changing the proven all-I decode path. phase1_supported currently admits only
// I-pictures, so every accepted persisted picture is a reference picture. The
// most recently completed bank is promoted to current reference ownership only
// after full DDR persistence. When P-picture decoding is enabled later, this
// promotion point will be qualified for I/P pictures while B-pictures will not
// replace the reference.
//
// kate - Phase 1T-d passively observes the first unsupported P-picture syntax
// between supported I-pictures. The existing front-end phase1_supported falling
// edge independently arms the probe; USER can remain on for all-I streams, while
// a controlled I/P/I diagnostic cannot report P-syntax success unless a live P
// slice, macroblock_address_increment and Table B.3 macroblock_type are verified.
//
// kate - Phase 1T-i exports the verified explicit forward vector from that
// passive observer. Implicit-zero and intra P macroblocks still report syntax
// success but do not assert p_forward_vector_valid.
//
// kate - Phase 1T-k adds an independent passive residual-transform proof for
// the controlled pattern-only first P macroblock in test_ipii.m2v. The ordinary
// p_syntax result is now gated until that observer has classified the first P
// macroblock. If it is the controlled pattern-only case, success additionally
// requires complete first-Y0 coefficient decoding, non-intra inverse
// quantisation and a full IDCT result. Explicit-motion regressions retain the
// already-proven Phase 1T-i completion boundary.
//
// kate - Phase 1T-l exports the controlled residual requirement, completion and
// first spatial residual sample. These are diagnostic sidebands only; the P
// picture still does not enter the normal I reconstruction or DDR write path.
//
// kate - Phase 1T-n adds a controlled stream hold at the same first-P-slice
// capture boundary used by the residual probe. Once that buffered boundary is
// reached, following compressed bytes are held until either an explicit/no-
// residual P proof completes or the controlled reconstructed pel has completed
// its real destination DDR write/readback. This prevents the following I picture
// from racing the P destination bank. P publication/reference promotion remain
// outside this phase.
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

    // kate - Phase 1T-l controlled residual reconstruction sideband.
    output wire        p_residual_required,
    output wire        p_residual_success,
    output wire        p_first_residual_sample_valid,
    output wire signed [15:0] p_first_residual_sample_value,

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

reg first_picture_done;
reg second_picture_done;
reg parser_rearm;
reg probe_error_latched;
reg picture_complete_pulse;
reg active_frame_bank_reg;
reg completed_frame_bank_reg;
reg [7:0] picture_count_reg;

reg       reference_frame_valid_reg;
reg       reference_frame_bank_reg;
reg [7:0] reference_promotion_count_reg;
reg       reference_error_latched;

reg phase1_supported_d;
reg p_picture_expected;
wire p_syntax_probe_error;
wire p_macroblock_type_seen_raw;

wire p_residual_decision_complete;
wire p_residual_required_raw;
wire p_residual_success_raw;
wire p_first_residual_sample_valid_raw;
wire signed [15:0] p_first_residual_sample_value_raw;
wire p_residual_probe_error;
wire p_stream_hold;
wire p_stream_hold_seen;
wire p_stream_hold_error;

assign p_residual_required            = p_residual_required_raw;
assign p_residual_success             = p_residual_success_raw;
assign p_first_residual_sample_valid  = p_first_residual_sample_valid_raw;
assign p_first_residual_sample_value  = p_first_residual_sample_value_raw;

wire p_macroblock_type_seen_decoded =
    p_macroblock_type_seen_raw &&
    (!p_picture_expected ||
     (p_residual_decision_complete &&
      (!p_residual_required_raw || p_residual_success_raw)));

assign p_macroblock_type_seen =
    p_macroblock_type_seen_decoded &&
    (!p_picture_expected || p_stream_hold_seen);

wire p_syntax_progress_error =
    p_picture_expected && !p_macroblock_type_seen;

reg        first_slice_header_seen_latched;
reg        first_macroblock_address_seen_latched;
reg        first_i_macroblock_seen_latched;
reg        first_luma_dc_seen_latched;
reg        first_luma_block_complete_latched;
reg [3:0]  first_luma_dc_size_latched;
reg signed [12:0] first_luma_dc_differential_latched;
reg [10:0] first_luma_dc_coefficient_latched;
reg [6:0]  first_luma_ac_nonzero_count_latched;
reg [5:0]  first_luma_last_coeff_index_latched;
reg signed [11:0] first_luma_last_ac_level_latched;

wire parser_stream_ready;
wire parser_slice_header_seen;
wire parser_macroblock_address_seen;
wire parser_first_i_macroblock_seen;
wire parser_first_luma_dc_seen;
wire parser_first_luma_block_complete;
wire parser_picture_420_parsed;
wire parser_probe_error;
wire [3:0] parser_first_luma_dc_size;
wire signed [12:0] parser_first_luma_dc_differential;
wire [10:0] parser_first_luma_dc_coefficient;
wire [6:0] parser_first_luma_ac_nonzero_count;
wire [5:0] parser_first_luma_last_coeff_index;
wire signed [11:0] parser_first_luma_last_ac_level;

wire parser_reset = reset || parser_rearm;
wire active_pipeline_block_done = pipeline_block_done;
wire unused_recon_block_complete = recon_block_complete;
wire picture_persisted_now = !parser_rearm && parser_picture_420_parsed;

wire reference_progress_error =
    (picture_count_reg >= 8'd3) &&
    (!reference_frame_valid_reg ||
     (reference_promotion_count_reg < 8'd3) ||
     (reference_frame_bank_reg != completed_frame_bank_reg) ||
     (reference_frame_bank_reg == active_frame_bank_reg));

assign stream_ready              = parser_stream_ready && !p_stream_hold;
assign first_picture_420_parsed  = first_picture_done;
assign second_picture_420_parsed = second_picture_done;
assign picture_420_complete      = picture_complete_pulse;
assign active_frame_bank         = active_frame_bank_reg;
assign completed_frame_bank      = completed_frame_bank_reg;
assign picture_count             = picture_count_reg;
assign reference_frame_valid     = reference_frame_valid_reg;
assign reference_frame_bank      = reference_frame_bank_reg;
assign reference_promotion_count = reference_promotion_count_reg;
assign probe_error               = probe_error_latched |
                                   parser_probe_error |
                                   reference_error_latched |
                                   reference_progress_error |
                                   p_syntax_probe_error |
                                   p_residual_probe_error |
                                   p_stream_hold_error |
                                   p_syntax_progress_error;

assign slice_header_seen = first_picture_done ?
                           first_slice_header_seen_latched :
                           parser_slice_header_seen;
assign macroblock_address_seen = first_picture_done ?
                                 first_macroblock_address_seen_latched :
                                 parser_macroblock_address_seen;
assign first_i_macroblock_seen = first_picture_done ?
                                 first_i_macroblock_seen_latched :
                                 parser_first_i_macroblock_seen;
assign first_luma_dc_seen = first_picture_done ?
                            first_luma_dc_seen_latched :
                            parser_first_luma_dc_seen;
assign first_luma_block_complete = first_picture_done ?
                                   first_luma_block_complete_latched :
                                   parser_first_luma_block_complete;
assign first_luma_dc_size = first_picture_done ?
                            first_luma_dc_size_latched :
                            parser_first_luma_dc_size;
assign first_luma_dc_differential = first_picture_done ?
                                    first_luma_dc_differential_latched :
                                    parser_first_luma_dc_differential;
assign first_luma_dc_coefficient = first_picture_done ?
                                   first_luma_dc_coefficient_latched :
                                   parser_first_luma_dc_coefficient;
assign first_luma_ac_nonzero_count = first_picture_done ?
                                     first_luma_ac_nonzero_count_latched :
                                     parser_first_luma_ac_nonzero_count;
assign first_luma_last_coeff_index = first_picture_done ?
                                     first_luma_last_coeff_index_latched :
                                     parser_first_luma_last_coeff_index;
assign first_luma_last_ac_level = first_picture_done ?
                                  first_luma_last_ac_level_latched :
                                  parser_first_luma_last_ac_level;

always @(posedge clk) begin
    if (reset) begin
        first_picture_done                    <= 1'b0;
        second_picture_done                   <= 1'b0;
        parser_rearm                          <= 1'b0;
        probe_error_latched                   <= 1'b0;
        picture_complete_pulse                <= 1'b0;
        active_frame_bank_reg                 <= 1'b0;
        completed_frame_bank_reg              <= 1'b0;
        picture_count_reg                     <= 8'd0;
        reference_frame_valid_reg             <= 1'b0;
        reference_frame_bank_reg              <= 1'b0;
        reference_promotion_count_reg         <= 8'd0;
        reference_error_latched               <= 1'b0;
        phase1_supported_d                     <= 1'b0;
        p_picture_expected                    <= 1'b0;
        first_slice_header_seen_latched       <= 1'b0;
        first_macroblock_address_seen_latched <= 1'b0;
        first_i_macroblock_seen_latched       <= 1'b0;
        first_luma_dc_seen_latched            <= 1'b0;
        first_luma_block_complete_latched     <= 1'b0;
        first_luma_dc_size_latched            <= 4'd0;
        first_luma_dc_differential_latched    <= 13'sd0;
        first_luma_dc_coefficient_latched     <= 11'd0;
        first_luma_ac_nonzero_count_latched   <= 7'd0;
        first_luma_last_coeff_index_latched   <= 6'd0;
        first_luma_last_ac_level_latched      <= 12'sd0;
    end
    else begin
        parser_rearm           <= 1'b0;
        picture_complete_pulse <= 1'b0;
        phase1_supported_d     <= phase1_supported;

        if (phase1_supported_d && !phase1_supported)
            p_picture_expected <= 1'b1;

        if (parser_probe_error)
            probe_error_latched <= 1'b1;

        if (picture_persisted_now) begin
            picture_complete_pulse   <= 1'b1;
            completed_frame_bank_reg <= active_frame_bank_reg;
            active_frame_bank_reg    <= ~active_frame_bank_reg;
            parser_rearm             <= 1'b1;

            if (picture_count_reg != 8'hff)
                picture_count_reg <= picture_count_reg + 8'd1;

            if (reference_frame_valid_reg &&
                (active_frame_bank_reg == reference_frame_bank_reg))
                reference_error_latched <= 1'b1;

            reference_frame_valid_reg <= 1'b1;
            reference_frame_bank_reg  <= active_frame_bank_reg;
            if (reference_promotion_count_reg != 8'hff)
                reference_promotion_count_reg <=
                    reference_promotion_count_reg + 8'd1;

            if (!first_picture_done) begin
                first_picture_done                    <= 1'b1;
                first_slice_header_seen_latched       <= parser_slice_header_seen;
                first_macroblock_address_seen_latched <= parser_macroblock_address_seen;
                first_i_macroblock_seen_latched       <= parser_first_i_macroblock_seen;
                first_luma_dc_seen_latched            <= parser_first_luma_dc_seen;
                first_luma_block_complete_latched     <= parser_first_luma_block_complete;
                first_luma_dc_size_latched            <= parser_first_luma_dc_size;
                first_luma_dc_differential_latched    <= parser_first_luma_dc_differential;
                first_luma_dc_coefficient_latched     <= parser_first_luma_dc_coefficient;
                first_luma_ac_nonzero_count_latched   <= parser_first_luma_ac_nonzero_count;
                first_luma_last_coeff_index_latched   <= parser_first_luma_last_coeff_index;
                first_luma_last_ac_level_latched      <= parser_first_luma_last_ac_level;
            end
            else if (!second_picture_done) begin
                second_picture_done <= 1'b1;
            end
        end
    end
end

mpeg2_h262_p_syntax_probe p_syntax_probe
(
    .clk                    (clk),
    .reset                  (reset),
    .stream_data            (stream_data),
    .stream_valid           (stream_valid),
    .p_picture_expected     (p_picture_expected),
    .p_macroblock_type_seen (p_macroblock_type_seen_raw),
    .p_forward_vector_valid (p_forward_vector_valid),
    .p_forward_vector_x     (p_forward_vector_x),
    .p_forward_vector_y     (p_forward_vector_y),
    .probe_error            (p_syntax_probe_error)
);

mpeg2_h262_p_residual_probe p_residual_probe
(
    .clk                (clk),
    .reset              (reset),
    .stream_data        (stream_data),
    .stream_valid       (stream_valid),
    .p_picture_expected (p_picture_expected),
    .decision_complete  (p_residual_decision_complete),
    .residual_required  (p_residual_required_raw),
    .residual_success   (p_residual_success_raw),
    .first_sample_valid (p_first_residual_sample_valid_raw),
    .first_sample_value (p_first_residual_sample_value_raw),
    .probe_error        (p_residual_probe_error)
);

mpeg2_h262_p_stream_hold p_stream_hold_probe
(
    .clk                    (clk),
    .reset                  (reset),
    .stream_data            (stream_data),
    .stream_valid           (stream_valid),
    .p_picture_active       (p_picture_expected),
    .p_macroblock_type_seen (p_macroblock_type_seen_decoded),
    .p_residual_required    (p_residual_required_raw),
    .p_persistence_complete (p_persistence_complete),
    .stream_hold            (p_stream_hold),
    .hold_seen              (p_stream_hold_seen),
    .hold_error             (p_stream_hold_error)
);

mpeg2_h262_luma4_probe picture_probe
(
    .clk                         (clk),
    .reset                       (parser_reset),
    .stream_data                 (stream_data),
    .stream_valid                (stream_valid),
    .stream_ready                (parser_stream_ready),
    .phase1_supported            (phase1_supported),
    .vertical_size               (vertical_size),
    .intra_dc_precision          (intra_dc_precision),
    .intra_vlc_format            (intra_vlc_format),
    .pipeline_block_done         (active_pipeline_block_done),

    .slice_header_seen           (parser_slice_header_seen),
    .macroblock_address_seen     (parser_macroblock_address_seen),
    .first_i_macroblock_seen     (parser_first_i_macroblock_seen),
    .first_luma_dc_seen          (parser_first_luma_dc_seen),
    .first_luma_block_complete   (parser_first_luma_block_complete),
    .first_picture_420_parsed    (parser_picture_420_parsed),
    .probe_error                 (parser_probe_error),
    .quantiser_scale_code        (quantiser_scale_code),
    .macroblock_address_increment(macroblock_address_increment),
    .macroblock_quant            (macroblock_quant),
    .macroblock_quantiser_scale_code(macroblock_quantiser_scale_code),
    .slice_vertical_position     (slice_vertical_position),
    .slice_vertical_position_extension(slice_vertical_position_extension),
    .first_luma_dc_size          (parser_first_luma_dc_size),
    .first_luma_dc_differential  (parser_first_luma_dc_differential),
    .first_luma_dc_coefficient   (parser_first_luma_dc_coefficient),
    .first_luma_ac_nonzero_count (parser_first_luma_ac_nonzero_count),
    .first_luma_last_coeff_index (parser_first_luma_last_coeff_index),
    .first_luma_last_ac_level    (parser_first_luma_last_ac_level),
    .slice_start                 (slice_start),
    .luma_macroblock_start       (luma_macroblock_start),
    .qfs_block_index             (qfs_block_index),
    .qfs_block_start             (qfs_block_start),
    .qfs_write_en                (qfs_write_en),
    .qfs_write_index             (qfs_write_index),
    .qfs_write_value             (qfs_write_value),
    .qfs_block_end               (qfs_block_end)
);

endmodule
