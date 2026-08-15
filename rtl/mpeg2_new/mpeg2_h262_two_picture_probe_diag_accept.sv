// Commit 141 diagnostic adapter.  Reuses the exact Commit-136 publication
// shell diagnostic carrier while preserving the Commit-138+ b_user_success
// interface expected by the current top level.  No decode/control path depends
// on this adapter; b_user_success is decoded from the old 0xBDss status carrier.
module mpeg2_h262_two_picture_probe_diag_accept
(
    input wire clk,input wire reset,input wire[7:0] stream_data,input wire stream_valid,output wire stream_ready,
    input wire phase1_supported,input wire[13:0] vertical_size,input wire[1:0] intra_dc_precision,input wire intra_vlc_format,
    input wire pipeline_block_done,input wire recon_block_complete,input wire p_persistence_complete,
    output wire slice_header_seen,output wire macroblock_address_seen,output wire first_i_macroblock_seen,
    output wire first_luma_dc_seen,output wire first_luma_block_complete,output wire first_picture_420_parsed,
    output wire second_picture_420_parsed,output wire picture_420_complete,output wire active_frame_bank,
    output wire completed_frame_bank,output wire[7:0] picture_count,output wire reference_frame_valid,
    output wire reference_frame_bank,output wire[7:0] reference_promotion_count,
    output wire p_macroblock_type_seen,output wire p_forward_vector_valid,output wire signed[12:0] p_forward_vector_x,
    output wire signed[12:0] p_forward_vector_y,output wire p_residual_required,output wire p_residual_success,
    output wire p_first_residual_sample_valid,output wire signed[15:0] p_first_residual_sample_value,
    output wire p_residual_sample_valid,output wire[5:0] p_residual_sample_index,output wire signed[15:0] p_residual_sample_value,
    output wire probe_error,output wire b_user_success,output wire[4:0] quantiser_scale_code,output wire[11:0] macroblock_address_increment,
    output wire macroblock_quant,output wire[4:0] macroblock_quantiser_scale_code,output wire[7:0] slice_vertical_position,
    output wire[2:0] slice_vertical_position_extension,output wire[3:0] first_luma_dc_size,
    output wire signed[12:0] first_luma_dc_differential,output wire[10:0] first_luma_dc_coefficient,
    output wire[6:0] first_luma_ac_nonzero_count,output wire[5:0] first_luma_last_coeff_index,
    output wire signed[11:0] first_luma_last_ac_level,output wire slice_start,output wire luma_macroblock_start,
    output wire[2:0] qfs_block_index,output wire qfs_block_start,output wire qfs_write_en,
    output wire[5:0] qfs_write_index,output wire signed[12:0] qfs_write_value,output wire qfs_block_end
);

mpeg2_h262_two_picture_probe commit136_probe(.*);

assign b_user_success =
    (p_first_residual_sample_value[15:8] == 8'hBD) &&
    (p_first_residual_sample_value[7:4]  == 4'b0001);

endmodule
