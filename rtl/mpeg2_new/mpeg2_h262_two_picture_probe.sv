//============================================================================
// MiSTer Media Player - Phase 1Q two-picture H.262 diagnostic wrapper
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000, 6.2.2 video_sequence().
//   A video sequence repeats picture_header(), picture_coding_extension() and
//   picture_data() while additional pictures/groups are present.
//
// kate - Phase 1Q is deliberately an implementation diagnostic, not a syntax
// restriction.  Keep the hardware-proven complete-picture parser untouched and
// run a second identical parser after the first picture_data() completes.  The
// first picture still waits for DDR persistence block-by-block.  The second
// picture waits for reconstruction block completion but is not stored yet; the
// next phase will add ping-pong frame storage/presentation once successive
// picture decode is proven in hardware.
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

    // Picture 1 is not allowed to advance until its reconstructed block has
    // actually reached DDR.  Picture 2 is diagnostic-only and advances once
    // reconstruction itself has completed the block.
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

wire first_stream_ready;
wire second_stream_ready;
wire first_probe_error;
wire second_probe_error;

wire [4:0]  first_quantiser_scale_code;
wire [11:0] first_macroblock_address_increment;
wire        first_macroblock_quant;
wire [4:0]  first_macroblock_quantiser_scale_code;
wire [7:0]  first_slice_vertical_position;
wire [2:0]  first_slice_vertical_position_extension;
wire        first_slice_start;
wire        first_luma_macroblock_start;
wire [2:0]  first_qfs_block_index;
wire        first_qfs_block_start;
wire        first_qfs_write_en;
wire [5:0]  first_qfs_write_index;
wire signed [12:0] first_qfs_write_value;
wire        first_qfs_block_end;

wire [4:0]  second_quantiser_scale_code;
wire [11:0] second_macroblock_address_increment;
wire        second_macroblock_quant;
wire [4:0]  second_macroblock_quantiser_scale_code;
wire [7:0]  second_slice_vertical_position;
wire [2:0]  second_slice_vertical_position_extension;
wire        second_slice_start;
wire        second_luma_macroblock_start;
wire [2:0]  second_qfs_block_index;
wire        second_qfs_block_start;
wire        second_qfs_write_en;
wire [5:0]  second_qfs_write_index;
wire signed [12:0] second_qfs_write_value;
wire        second_qfs_block_end;

// kate - first_picture_420_parsed is generated in clk and stays asserted.  It
// therefore provides a synchronous handoff between the two otherwise identical
// parsers.  The second instance is held in reset until that handoff occurs.
wire use_second_picture = first_picture_420_parsed;
wire second_reset = reset || !first_picture_420_parsed;

assign stream_ready = use_second_picture ? second_stream_ready : first_stream_ready;
assign probe_error  = first_probe_error | second_probe_error;

assign quantiser_scale_code = use_second_picture ?
    second_quantiser_scale_code : first_quantiser_scale_code;
assign macroblock_address_increment = use_second_picture ?
    second_macroblock_address_increment : first_macroblock_address_increment;
assign macroblock_quant = use_second_picture ?
    second_macroblock_quant : first_macroblock_quant;
assign macroblock_quantiser_scale_code = use_second_picture ?
    second_macroblock_quantiser_scale_code : first_macroblock_quantiser_scale_code;
assign slice_vertical_position = use_second_picture ?
    second_slice_vertical_position : first_slice_vertical_position;
assign slice_vertical_position_extension = use_second_picture ?
    second_slice_vertical_position_extension : first_slice_vertical_position_extension;
assign slice_start = use_second_picture ? second_slice_start : first_slice_start;
assign luma_macroblock_start = use_second_picture ?
    second_luma_macroblock_start : first_luma_macroblock_start;
assign qfs_block_index = use_second_picture ? second_qfs_block_index : first_qfs_block_index;
assign qfs_block_start = use_second_picture ? second_qfs_block_start : first_qfs_block_start;
assign qfs_write_en = use_second_picture ? second_qfs_write_en : first_qfs_write_en;
assign qfs_write_index = use_second_picture ? second_qfs_write_index : first_qfs_write_index;
assign qfs_write_value = use_second_picture ? second_qfs_write_value : first_qfs_write_value;
assign qfs_block_end = use_second_picture ? second_qfs_block_end : first_qfs_block_end;

mpeg2_h262_luma4_probe first_picture_probe
(
    .clk                         (clk),
    .reset                       (reset),
    .stream_data                 (stream_data),
    .stream_valid                (stream_valid),
    .stream_ready                (first_stream_ready),
    .phase1_supported            (phase1_supported),
    .vertical_size               (vertical_size),
    .intra_dc_precision          (intra_dc_precision),
    .intra_vlc_format            (intra_vlc_format),
    .pipeline_block_done         (pipeline_block_done),

    .slice_header_seen           (slice_header_seen),
    .macroblock_address_seen     (macroblock_address_seen),
    .first_i_macroblock_seen     (first_i_macroblock_seen),
    .first_luma_dc_seen          (first_luma_dc_seen),
    .first_luma_block_complete   (first_luma_block_complete),
    .first_picture_420_parsed    (first_picture_420_parsed),
    .probe_error                 (first_probe_error),
    .quantiser_scale_code        (first_quantiser_scale_code),
    .macroblock_address_increment(first_macroblock_address_increment),
    .macroblock_quant            (first_macroblock_quant),
    .macroblock_quantiser_scale_code(first_macroblock_quantiser_scale_code),
    .slice_vertical_position     (first_slice_vertical_position),
    .slice_vertical_position_extension(first_slice_vertical_position_extension),
    .first_luma_dc_size          (first_luma_dc_size),
    .first_luma_dc_differential  (first_luma_dc_differential),
    .first_luma_dc_coefficient   (first_luma_dc_coefficient),
    .first_luma_ac_nonzero_count (first_luma_ac_nonzero_count),
    .first_luma_last_coeff_index (first_luma_last_coeff_index),
    .first_luma_last_ac_level    (first_luma_last_ac_level),
    .slice_start                 (first_slice_start),
    .luma_macroblock_start       (first_luma_macroblock_start),
    .qfs_block_index             (first_qfs_block_index),
    .qfs_block_start             (first_qfs_block_start),
    .qfs_write_en                (first_qfs_write_en),
    .qfs_write_index             (first_qfs_write_index),
    .qfs_write_value             (first_qfs_write_value),
    .qfs_block_end               (first_qfs_block_end)
);

mpeg2_h262_luma4_probe second_picture_probe
(
    .clk                         (clk),
    .reset                       (second_reset),
    .stream_data                 (stream_data),
    .stream_valid                (stream_valid),
    .stream_ready                (second_stream_ready),
    .phase1_supported            (phase1_supported),
    .vertical_size               (vertical_size),
    .intra_dc_precision          (intra_dc_precision),
    .intra_vlc_format            (intra_vlc_format),
    .pipeline_block_done         (recon_block_complete),

    .slice_header_seen           (),
    .macroblock_address_seen     (),
    .first_i_macroblock_seen     (),
    .first_luma_dc_seen          (),
    .first_luma_block_complete   (),
    .first_picture_420_parsed    (second_picture_420_parsed),
    .probe_error                 (second_probe_error),
    .quantiser_scale_code        (second_quantiser_scale_code),
    .macroblock_address_increment(second_macroblock_address_increment),
    .macroblock_quant            (second_macroblock_quant),
    .macroblock_quantiser_scale_code(second_macroblock_quantiser_scale_code),
    .slice_vertical_position     (second_slice_vertical_position),
    .slice_vertical_position_extension(second_slice_vertical_position_extension),
    .first_luma_dc_size          (),
    .first_luma_dc_differential  (),
    .first_luma_dc_coefficient   (),
    .first_luma_ac_nonzero_count (),
    .first_luma_last_coeff_index (),
    .first_luma_last_ac_level    (),
    .slice_start                 (second_slice_start),
    .luma_macroblock_start       (second_luma_macroblock_start),
    .qfs_block_index             (second_qfs_block_index),
    .qfs_block_start             (second_qfs_block_start),
    .qfs_write_en                (second_qfs_write_en),
    .qfs_write_index             (second_qfs_write_index),
    .qfs_write_value             (second_qfs_write_value),
    .qfs_block_end               (second_qfs_block_end)
);

endmodule
