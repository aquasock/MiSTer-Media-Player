//============================================================================
// MiSTer Media Player - Phase 1T-p controlled P residual pipeline wrapper
//
// kate - Phase 1T-p serializes Y0..Y3 residual parsing, non-intra IQ, and IDCT
// through one transform engine. Cb/Cr remain outside this diagnostic boundary.
// The module retains the Phase 1T-o public probe interface. Four 0..63 residual
// sample sequences are emitted strictly in Y0,Y1,Y2,Y3 order; downstream logic
// can therefore derive the 0..255 macroblock sample number without another
// top-level sideband.
//============================================================================
module mpeg2_h262_p_residual_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_expected,
    output wire       decision_complete,
    output wire       residual_required,
    output wire       residual_success,
    output wire       first_sample_valid,
    output wire signed [15:0] first_sample_value,
    output wire       residual_sample_valid,
    output wire [5:0] residual_sample_index,
    output wire signed [15:0] residual_sample_value,
    output wire       probe_error
);
wire transform_block_done;
wire [1:0] qfs_block_index;
wire qfs_block_start,qfs_write_en,qfs_block_end;
wire [5:0] qfs_write_index;
wire signed [12:0] qfs_write_value;
wire [4:0] quantiser_scale_code;
wire q_scale_type,alternate_scan,parser_error,transform_error;
wire [1:0] residual_sample_block_index_unused;

mpeg2_h262_p_residual_parser parser
(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .p_picture_expected(p_picture_expected),.transform_block_done(transform_block_done),
 .decision_complete(decision_complete),.residual_required(residual_required),.residual_success(residual_success),
 .qfs_block_index(qfs_block_index),.qfs_block_start(qfs_block_start),.qfs_write_en(qfs_write_en),
 .qfs_write_index(qfs_write_index),.qfs_write_value(qfs_write_value),.qfs_block_end(qfs_block_end),
 .quantiser_scale_code(quantiser_scale_code),.q_scale_type(q_scale_type),.alternate_scan(alternate_scan),
 .probe_error(parser_error)
);
mpeg2_h262_p_non_intra_transform transform
(
 .clk(clk),.reset(reset),.qfs_block_index(qfs_block_index),.qfs_block_start(qfs_block_start),
 .qfs_write_en(qfs_write_en),.qfs_write_index(qfs_write_index),.qfs_write_value(qfs_write_value),
 .qfs_block_end(qfs_block_end),.quantiser_scale_code(quantiser_scale_code),.q_scale_type(q_scale_type),
 .alternate_scan(alternate_scan),.intra_block(1'b0),.intra_dc_precision(2'd0),
 .block_done(transform_block_done),.first_sample_valid(first_sample_valid),
 .first_sample_value(first_sample_value),.residual_sample_valid(residual_sample_valid),
 .residual_sample_block_index(residual_sample_block_index_unused),.residual_sample_index(residual_sample_index),
 .residual_sample_value(residual_sample_value),.probe_error(transform_error)
);
assign probe_error=parser_error|transform_error;
endmodule
