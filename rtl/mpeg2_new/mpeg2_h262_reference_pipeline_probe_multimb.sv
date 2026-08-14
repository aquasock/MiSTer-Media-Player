//============================================================================
// MiSTer Media Player - Phase 1T-r reference pipeline
//
// kate - Keep the public reference-probe interface unchanged.  Existing
// explicit x=4/x=3 diagnostics retain their proven client; the accepted
// implicit residual path retains the complete first-420-macroblock engine; and
// the semantic two-MB observer alone exports explicit (0,0), selecting the new
// serialized two-macroblock copy/readback client.
//============================================================================

module mpeg2_h262_reference_read_probe
(
    input  wire        clk,
    input  wire        reset,
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

wire copy_request =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd0) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd1) &&
    (forward_f_code_vertical   == 4'd1) &&
    !p_implicit_reconstruct_request;

// Keep the selected diagnostic client stable after the following I picture is
// released.  Its picture-coding extension can replace the live f_code fields,
// but the completed P persistence sideband must remain visible to the P
// controller and USER success predicate.
reg copy_selected;
always @(posedge clk) begin
    if (reset)
        copy_selected <= 1'b0;
    else if (copy_request)
        copy_selected <= 1'b1;
end

wire copy_sel = copy_selected || copy_request;
wire implicit_sel = p_implicit_reconstruct_request && !copy_sel;
wire explicit_sel = !copy_sel && !implicit_sel;

wire [7:0]  explicit_burstcnt;
wire [28:0] explicit_addr;
wire        explicit_rd;
wire        explicit_read_seen;
wire [7:0]  explicit_sample;
wire        explicit_nonzero;
wire        explicit_half;
wire        explicit_error;
wire        explicit_active;

wire [7:0]  implicit_burstcnt;
wire [28:0] implicit_addr;
wire        implicit_rd;
wire        implicit_read_seen;
wire [7:0]  implicit_sample;
wire        implicit_nonzero;
wire        implicit_reconstructed_seen;
wire [7:0]  implicit_reconstructed_value;
wire        implicit_persisted_seen;
wire [7:0]  implicit_persisted_value;
wire        implicit_error;
wire        implicit_store_select;
wire [7:0]  implicit_store_value;
wire [11:0] implicit_store_x;
wire [11:0] implicit_store_y;
wire        implicit_store_valid;
wire        implicit_store_start;
wire        implicit_store_complete;

wire [7:0]  copy_burstcnt;
wire [28:0] copy_addr;
wire        copy_rd;
wire        copy_read_seen;
wire [7:0]  copy_sample;
wire        copy_nonzero;
wire        copy_reconstructed_seen;
wire [7:0]  copy_reconstructed_value;
wire        copy_persisted_seen;
wire [7:0]  copy_persisted_value;
wire        copy_error;
wire        copy_store_select;
wire [7:0]  copy_store_value;
wire [11:0] copy_store_x;
wire [11:0] copy_store_y;
wire        copy_store_valid;
wire        copy_store_start;
wire        copy_store_complete;

mpeg2_h262_p_explicit_reference_probe explicit_probe
(
    .clk                   (clk),
    .reset                 (reset),
    .proof_seen            (p_vector_proof_seen),
    .p_forward_vector_valid(p_forward_vector_valid),
    .p_forward_vector_x    (p_forward_vector_x),
    .p_forward_vector_y    (p_forward_vector_y),
    .f_code_x              (forward_f_code_horizontal),
    .f_code_y              (forward_f_code_vertical),
    .reference_valid       (reference_frame_valid),
    .reference_bank        (reference_frame_bank),
    .ddram_busy            (ddram_busy),
    .ddram_dout            (ddram_dout),
    .ddram_dout_ready      (ddram_dout_ready && explicit_sel),
    .active                (explicit_active),
    .ddram_burstcnt        (explicit_burstcnt),
    .ddram_addr            (explicit_addr),
    .ddram_rd              (explicit_rd),
    .read_seen             (explicit_read_seen),
    .sample_value          (explicit_sample),
    .sample_nonzero        (explicit_nonzero),
    .half_sample_seen      (explicit_half),
    .error                 (explicit_error)
);

mpeg2_h262_p_luma_macroblock_engine implicit_probe
(
    .clk                  (clk),
    .reset                (reset),
    .request              (p_implicit_reconstruct_request),
    .residual_valid       (p_residual_sample_valid),
    .residual_index       (p_residual_sample_index),
    .residual_value       (p_residual_sample_value),
    .reference_valid      (reference_frame_valid),
    .reference_bank       (reference_frame_bank),
    .destination_bank     (destination_frame_bank),
    .store_block_stored   (p_store_block_stored),
    .ddram_busy           (ddram_busy),
    .ddram_dout           (ddram_dout),
    .ddram_dout_ready     (ddram_dout_ready && implicit_sel),
    .ddram_burstcnt       (implicit_burstcnt),
    .ddram_addr           (implicit_addr),
    .ddram_rd             (implicit_rd),
    .store_select         (implicit_store_select),
    .store_pixel_value    (implicit_store_value),
    .store_pixel_x        (implicit_store_x),
    .store_pixel_y        (implicit_store_y),
    .store_pixel_valid    (implicit_store_valid),
    .store_block_start    (implicit_store_start),
    .store_block_complete (implicit_store_complete),
    .read_seen            (implicit_read_seen),
    .sample_value         (implicit_sample),
    .sample_nonzero       (implicit_nonzero),
    .reconstructed_seen   (implicit_reconstructed_seen),
    .reconstructed_value  (implicit_reconstructed_value),
    .persisted_seen       (implicit_persisted_seen),
    .persisted_value      (implicit_persisted_value),
    .error                (implicit_error)
);

mpeg2_h262_p_two_mb_copy_engine copy_probe
(
    .clk                  (clk),
    .reset                (reset),
    .request              (copy_sel),
    .reference_valid      (reference_frame_valid),
    .reference_bank       (reference_frame_bank),
    .destination_bank     (destination_frame_bank),
    .store_block_stored   (p_store_block_stored),
    .ddram_busy           (ddram_busy),
    .ddram_dout           (ddram_dout),
    .ddram_dout_ready     (ddram_dout_ready && copy_sel),
    .ddram_burstcnt       (copy_burstcnt),
    .ddram_addr           (copy_addr),
    .ddram_rd             (copy_rd),
    .store_select         (copy_store_select),
    .store_pixel_value    (copy_store_value),
    .store_pixel_x        (copy_store_x),
    .store_pixel_y        (copy_store_y),
    .store_pixel_valid    (copy_store_valid),
    .store_block_start    (copy_store_start),
    .store_block_complete (copy_store_complete),
    .read_seen            (copy_read_seen),
    .sample_value         (copy_sample),
    .sample_nonzero       (copy_nonzero),
    .reconstructed_seen   (copy_reconstructed_seen),
    .reconstructed_value  (copy_reconstructed_value),
    .persisted_seen       (copy_persisted_seen),
    .persisted_value      (copy_persisted_value),
    .error                (copy_error)
);

assign ddram_burstcnt = copy_sel ? copy_burstcnt :
                        implicit_sel ? implicit_burstcnt : explicit_burstcnt;
assign ddram_addr = copy_sel ? copy_addr :
                    implicit_sel ? implicit_addr : explicit_addr;
assign ddram_rd = copy_sel ? copy_rd :
                  implicit_sel ? implicit_rd : explicit_rd;

assign p_store_select = copy_sel ? copy_store_select : implicit_store_select;
assign p_store_pixel_value = copy_sel ? copy_store_value : implicit_store_value;
assign p_store_pixel_x = copy_sel ? copy_store_x : implicit_store_x;
assign p_store_pixel_y = copy_sel ? copy_store_y : implicit_store_y;
assign p_store_pixel_valid = copy_sel ? copy_store_valid : implicit_store_valid;
assign p_store_block_start = copy_sel ? copy_store_start : implicit_store_start;
assign p_store_block_complete = copy_sel ? copy_store_complete : implicit_store_complete;

assign read_seen = copy_sel ? copy_read_seen :
                   implicit_sel ? implicit_read_seen : explicit_read_seen;
assign sample_value = copy_sel ? copy_sample :
                      implicit_sel ? implicit_sample : explicit_sample;
assign sample_nonzero = copy_sel ? copy_nonzero :
                        implicit_sel ? implicit_nonzero : explicit_nonzero;
assign half_sample_seen = explicit_sel ? explicit_half : 1'b0;
assign reconstructed_seen = copy_sel ? copy_reconstructed_seen :
                            implicit_reconstructed_seen;
assign reconstructed_value = copy_sel ? copy_reconstructed_value :
                             implicit_reconstructed_value;
assign persisted_seen = copy_sel ? copy_persisted_seen : implicit_persisted_seen;
assign persisted_value = copy_sel ? copy_persisted_value : implicit_persisted_value;
assign probe_error = explicit_error || implicit_error || copy_error;

wire unused_explicit_active = explicit_active;

endmodule
