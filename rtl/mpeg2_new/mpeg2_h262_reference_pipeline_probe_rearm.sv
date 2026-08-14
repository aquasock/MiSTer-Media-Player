//============================================================================
// MiSTer Media Player - re-arm wrapper for accepted P reference pipeline
//
// Phase 1U-n reuses the exact accepted Phase 1U-l reference pipeline logic.
// The included source declares an internal base module explicitly, then this
// public wrapper applies a one-cycle local reset when a persisted plan has
// completed and the controller withdraws its representative vector at the
// following P header.  The explicit base name is Quartus-17-safe and avoids
// relying on preprocessor identifier renaming.
//============================================================================

`include "rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_plan.sv"

module mpeg2_h262_reference_read_probe
(
    input  wire        clk,
    input  wire        reset,
    input  wire [13:0] horizontal_size,
    input  wire [13:0] vertical_size,
    input  wire        p_vector_proof_seen,
    input  wire        p_forward_vector_valid,
    input  wire signed [12:0] p_forward_vector_x,
    input  wire signed [12:0] p_forward_vector_y,
    input  wire [3:0]  forward_f_code_horizontal,
    input  wire [3:0]  forward_f_code_vertical,
    input  wire        p_implicit_reconstruct_request,
    input  wire        p_residual_sample_valid,
    input  wire [5:0]  p_residual_sample_index,
    input  wire signed [15:0] p_residual_sample_value,
    input  wire        reference_frame_valid,
    input  wire        reference_frame_bank,
    input  wire        destination_frame_bank,
    input  wire        p_store_block_stored,
    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,
    output wire        p_store_select,
    output wire [7:0]  p_store_pixel_value,
    output wire [11:0] p_store_pixel_x,
    output wire [11:0] p_store_pixel_y,
    output wire        p_store_pixel_valid,
    output wire        p_store_block_start,
    output wire        p_store_block_complete,
    output wire        read_seen,
    output wire [7:0]  sample_value,
    output wire        sample_nonzero,
    output wire        half_sample_seen,
    output wire        reconstructed_seen,
    output wire [7:0]  reconstructed_value,
    output wire        persisted_seen,
    output wire [7:0]  persisted_value,
    output wire        probe_error
);

wire base_persisted_seen;
wire base_probe_error;
reg  p_forward_vector_valid_d;

wire plan_rearm_now =
    base_persisted_seen &&
    p_forward_vector_valid_d &&
    !p_forward_vector_valid;
wire base_reset = reset || plan_rearm_now;

always @(posedge clk) begin
    if (reset)
        p_forward_vector_valid_d <= 1'b0;
    else
        p_forward_vector_valid_d <= p_forward_vector_valid;
end

mpeg2_h262_reference_read_probe_base base_probe
(
    .reset         (base_reset),
    .persisted_seen(base_persisted_seen),
    .probe_error   (base_probe_error),
    .*
);

assign persisted_seen = base_persisted_seen;
assign probe_error     = base_probe_error;

endmodule
