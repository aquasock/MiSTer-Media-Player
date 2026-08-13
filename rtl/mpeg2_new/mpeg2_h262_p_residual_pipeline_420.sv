// kate - Phase 1T-q: Y0,Y1,Y2,Y3,Cb,Cr residual pipeline; public interface retained.
module mpeg2_h262_p_residual_probe(
 input wire clk,input wire reset,input wire [7:0] stream_data,input wire stream_valid,input wire p_picture_expected,
 output wire decision_complete,output wire residual_required,output wire residual_success,
 output wire first_sample_valid,output wire signed [15:0] first_sample_value,
 output wire residual_sample_valid,output wire [5:0] residual_sample_index,
 output wire signed [15:0] residual_sample_value,output wire probe_error);
wire transform_block_done; wire [2:0] qfs_block_index;
wire [1:0] transform_block_index=(qfs_block_index==3'd0)?2'd0:2'd1;
wire qfs_block_start,qfs_write_en,qfs_block_end; wire [5:0] qfs_write_index;
wire signed [12:0] qfs_write_value; wire [4:0] quantiser_scale_code;
wire q_scale_type,alternate_scan,parser_error,transform_error; wire [1:0] unused_block_index;
mpeg2_h262_p_residual_parser_420 parser(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),.p_picture_expected(p_picture_expected),
 .transform_block_done(transform_block_done),.decision_complete(decision_complete),.residual_required(residual_required),
 .residual_success(residual_success),.quantiser_scale_code(quantiser_scale_code),.q_scale_type(q_scale_type),
 .alternate_scan(alternate_scan),.qfs_block_index(qfs_block_index),.qfs_block_start(qfs_block_start),
 .qfs_write_en(qfs_write_en),.qfs_write_index(qfs_write_index),.qfs_write_value(qfs_write_value),
 .qfs_block_end(qfs_block_end),.probe_error(parser_error));
mpeg2_h262_p_non_intra_transform transform(
 .clk(clk),.reset(reset),.qfs_block_index(transform_block_index),.qfs_block_start(qfs_block_start),
 .qfs_write_en(qfs_write_en),.qfs_write_index(qfs_write_index),.qfs_write_value(qfs_write_value),
 .qfs_block_end(qfs_block_end),.quantiser_scale_code(quantiser_scale_code),.q_scale_type(q_scale_type),
 .alternate_scan(alternate_scan),.block_done(transform_block_done),.first_sample_valid(first_sample_valid),
 .first_sample_value(first_sample_value),.residual_sample_valid(residual_sample_valid),
 .residual_sample_block_index(unused_block_index),.residual_sample_index(residual_sample_index),
 .residual_sample_value(residual_sample_value),.probe_error(transform_error));
assign probe_error=parser_error|transform_error;
endmodule
