//============================================================================
// MiSTer Media Player - Phase 1T continuous H.262 picture wrapper
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 6.2.2 video_sequence().
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 3.111 and 7.6.2.2.
//   A reference frame is a reconstructed I- or P-frame.  Frame prediction in
//   a P-picture uses the most recently reconstructed reference frame.
//
// kate - Phase 1S extended the proven Phase 1Q/1R single-parser re-arm path to
// every supported picture.  Every picture still waits for the DDR persistence
// handshake block by block.  The active write bank alternates 0/1 after each
// complete picture, and a one-cycle completion pulse reports which bank just
// became complete so the top level can republish it safely.
//
// kate - Phase 1T-a adds explicit reference-frame ownership bookkeeping without
// changing the proven all-I decode path.  phase1_supported currently admits only
// I-pictures, so every accepted persisted picture is a reference picture.  The
// most recently completed bank is promoted to current reference ownership only
// after full DDR persistence.  When P-picture decoding is enabled later, this
// promotion point will be qualified for I/P pictures while B-pictures will not
// replace the reference.
//
// kate - Phase 1T-d passively observes the first unsupported P-picture syntax
// between supported I-pictures.  The existing front-end phase1_supported falling
// edge independently arms the probe; USER can remain on for all-I streams, while
// a controlled I/P/I/I diagnostic cannot reach USER unless a live P slice,
// macroblock_address_increment and Table B.3 macroblock_type are verified.
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

    // kate - Phase 1T-a reference-picture state.  These outputs are sideband
    // metadata for later prediction work; the current top level does not need
    // them to preserve the hardware-proven Phase 1S presentation path.
    output wire        reference_frame_valid,
    output wire        reference_frame_bank,
    output wire [7:0]  reference_promotion_count,

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

// kate - Phase 1T-a current-reference bookkeeping.  Because the current
// supported decoder subset accepts only I-pictures, each fully persisted picture
// is a reference frame.  Promotion occurs on the same completion edge that
// commits completed_frame_bank_reg, never before the final block_stored handshake.
reg       reference_frame_valid_reg;
reg       reference_frame_bank_reg;
reg [7:0] reference_promotion_count_reg;
reg       reference_error_latched;

// kate - Phase 1T-d uses the existing standards front end as an independent
// expectation source.  Its supported-I level falls when a P picture header is
// accepted; latch that fact across the unsupported picture until the passive
// syntax observer verifies a live Table B.3 macroblock type.
reg phase1_supported_d;
reg p_picture_expected;
wire p_macroblock_type_seen;
wire p_syntax_probe_error;
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

// kate - parser_rearm is synchronous to clk.  The parser's ordinary reset path
// clears all picture-local sticky state for exactly one clock between pictures.
wire parser_reset = reset || parser_rearm;

// kate - Every picture must wait until the current reconstructed block is
// physically accepted by the DDR writer.  recon_block_complete remains in the
// interface for compatibility but is not the persistence handshake.
wire active_pipeline_block_done = pipeline_block_done;
wire unused_recon_block_complete = recon_block_complete;

// One completion event per fully persisted picture.  The parser completion is
// sticky until parser_rearm, so suppress the re-arm cycle itself.
wire picture_persisted_now = !parser_rearm && parser_picture_420_parsed;

// After three persisted pictures the existing USER diagnostic already expects
// a 0 -> 1 -> 0 bank sequence.  Tie the new reference bookkeeping into that
// proof without changing the top-level LED equation: probe_error must remain
// clear only if reference ownership has also advanced three times and the newest
// reference is the completed bank rather than the next write bank.
wire reference_progress_error =
    (picture_count_reg >= 8'd3) &&
    (!reference_frame_valid_reg ||
     (reference_promotion_count_reg < 8'd3) ||
     (reference_frame_bank_reg != completed_frame_bank_reg) ||
     (reference_frame_bank_reg == active_frame_bank_reg));

assign stream_ready              = parser_stream_ready;
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
                                   p_syntax_progress_error;

// Preserve picture-1 diagnostics across all later parser re-arm cycles.  Before
// picture 1 completes, expose the live parser values exactly as earlier phases.
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

        // Do not treat initial header acquisition as a P expectation: only a
        // true high-to-low transition from the already-proven supported-I state
        // arms the Phase 1T-d passive probe.
        if (phase1_supported_d && !phase1_supported)
            p_picture_expected <= 1'b1;

        if (parser_probe_error)
            probe_error_latched <= 1'b1;

        if (picture_persisted_now) begin
            // The completion pulse is delayed one registered cycle relative to
            // the parser's sticky picture-complete indication.  At this point
            // every block is already stored because pipeline_block_done is the
            // DDR block_stored handshake.
            picture_complete_pulse   <= 1'b1;
            completed_frame_bank_reg <= active_frame_bank_reg;
            active_frame_bank_reg    <= ~active_frame_bank_reg;
            parser_rearm             <= 1'b1;

            if (picture_count_reg != 8'hff)
                picture_count_reg <= picture_count_reg + 8'd1;

            // kate - Phase 1T-a promotion point.  The bank being completed may
            // not already be the current reference: that would mean the writer
            // overwrote the reference before a replacement was fully persisted.
            // With the current all-I ping-pong path this invariant must hold on
            // every picture after the first.
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

// kate - Phase 1T-d passive observer.  This sees only bytes already accepted by
// the main stream handshake and therefore cannot disturb decoder backpressure.
mpeg2_h262_p_syntax_probe p_syntax_probe
(
    .clk                    (clk),
    .reset                  (reset),
    .stream_data            (stream_data),
    .stream_valid           (stream_valid),
    .p_picture_expected     (p_picture_expected),
    .p_macroblock_type_seen (p_macroblock_type_seen),
    .probe_error            (p_syntax_probe_error)
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
