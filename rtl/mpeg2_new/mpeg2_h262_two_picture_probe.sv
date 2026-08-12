//============================================================================
// MiSTer Media Player - Phase 1Q two-picture H.262 diagnostic wrapper
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 6.2.2 video_sequence().
//   A video sequence repeats picture_header(), picture_coding_extension() and
//   picture_data() while additional pictures/groups are present.
//
// kate - Phase 1Q reuses the hardware-proven complete-picture parser for both
// pictures.  After picture 1 completes, this wrapper latches its diagnostics,
// gives the parser one local reset/re-arm cycle, then lets the same parser find
// and decode picture 2.  Picture 1 still waits for DDR persistence block by
// block.  Picture 2 waits only for reconstruction completion and remains a
// diagnostic-only decode until ping-pong frame storage is added.
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
reg first_probe_error_latched;

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
wire active_pipeline_block_done = first_picture_done ?
                                  recon_block_complete :
                                  pipeline_block_done;

assign stream_ready              = parser_stream_ready;
assign first_picture_420_parsed  = first_picture_done;
assign second_picture_420_parsed = second_picture_done;
assign probe_error               = first_probe_error_latched | parser_probe_error;

// Preserve picture-1 diagnostics across the parser's re-arm cycle.  Before
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
        first_probe_error_latched             <= 1'b0;
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
        parser_rearm <= 1'b0;

        if (!first_picture_done && parser_probe_error)
            first_probe_error_latched <= 1'b1;

        if (!first_picture_done && parser_picture_420_parsed) begin
            // Picture 1 is complete only after every reconstructed block has
            // reached DDR because active_pipeline_block_done still selects the
            // DDR writer's block_stored pulse during this phase.
            first_picture_done                    <= 1'b1;
            parser_rearm                          <= 1'b1;
            first_probe_error_latched             <= parser_probe_error;
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
        else if (first_picture_done && !parser_rearm &&
                 parser_picture_420_parsed) begin
            second_picture_done <= 1'b1;
        end
    end
end

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
