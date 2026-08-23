//============================================================================
// MiSTer Media Player - consolidated legacy P reference clients
//
// Post-v0.4.0 consolidation keeps the accepted explicit-reference and
// implicit-residual clients, while sharing one generic zero-motion raster-copy
// engine between the historical two-macroblock and coded-raster proof paths.
// The historical 128x96 +32/0 motion-plan client is adapted to the generalized
// raster engine by the outer re-arm wrapper and is intentionally absent here.
//============================================================================

module mpeg2_h262_reference_read_probe_base
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

wire [14:0] raster_horizontal_size_rounded =
    {1'b0, horizontal_size} + 15'd15;
wire [10:0] raster_macroblock_width_full =
    raster_horizontal_size_rounded[14:4];
wire [8:0] raster_macroblock_width =
    ((horizontal_size != 14'd0) && (horizontal_size <= 14'd720)) ?
        raster_macroblock_width_full[8:0] : 9'd0;

wire [14:0] raster_vertical_size_rounded =
    {1'b0, vertical_size} + 15'd15;
wire [10:0] raster_macroblock_height_full =
    raster_vertical_size_rounded[14:4];
wire [8:0] raster_macroblock_height =
    ((vertical_size != 14'd0) && (vertical_size <= 14'd480)) ?
        raster_macroblock_height_full[8:0] : 9'd0;

wire [17:0] raster_macroblock_count_full =
    raster_macroblock_width * raster_macroblock_height;
wire [15:0] raster_macroblock_count =
    ((raster_macroblock_width != 9'd0) &&
     (raster_macroblock_height != 9'd0)) ?
        raster_macroblock_count_full[15:0] : 16'd0;

wire raster_zero_request =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd0) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd2) &&
    (forward_f_code_vertical   == 4'd2) &&
    !p_implicit_reconstruct_request;

wire two_zero_request =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd0) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd1) &&
    (forward_f_code_vertical   == 4'd1) &&
    !p_implicit_reconstruct_request;

wire zero_request = raster_zero_request || two_zero_request;
reg zero_selected;
always @(posedge clk) begin
    if (reset)
        zero_selected <= 1'b0;
    else if (zero_request)
        zero_selected <= 1'b1;
end

wire zero_sel = zero_selected || zero_request;
wire implicit_sel = p_implicit_reconstruct_request && !zero_sel;
wire explicit_sel = !zero_sel && !implicit_sel;

// The generic raster engine latches width/count on its request edge.  The
// historical f_code=1 proof is exactly two adjacent macroblocks in row zero;
// the f_code=2 path retains its live coded-raster geometry.
wire [8:0] zero_macroblock_width =
    two_zero_request ? 9'd2 : raster_macroblock_width;
wire [15:0] zero_macroblock_count =
    two_zero_request ? 16'd2 : raster_macroblock_count;

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

wire [7:0]  zero_burstcnt;
wire [28:0] zero_addr;
wire        zero_rd;
wire        zero_read_seen;
wire [7:0]  zero_sample;
wire        zero_nonzero;
wire        zero_reconstructed_seen;
wire [7:0]  zero_reconstructed_value;
wire        zero_persisted_seen;
wire [7:0]  zero_persisted_value;
wire        zero_error;
wire        zero_store_select;
wire [7:0]  zero_store_value;
wire [11:0] zero_store_x;
wire [11:0] zero_store_y;
wire        zero_store_valid;
wire        zero_store_start;
wire        zero_store_complete;

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
    .ddram_rd              (implicit_rd),
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

mpeg2_h262_p_four_mb_two_row_copy_engine zero_probe
(
    .clk                  (clk),
    .reset                (reset),
    .request              (zero_sel),
    .macroblock_width     (zero_macroblock_width),
    .macroblock_count     (zero_macroblock_count),
    .reference_valid      (reference_frame_valid),
    .reference_bank       (reference_frame_bank),
    .destination_bank     (destination_frame_bank),
    .store_block_stored   (p_store_block_stored),
    .ddram_busy           (ddram_busy),
    .ddram_dout           (ddram_dout),
    .ddram_dout_ready     (ddram_dout_ready && zero_sel),
    .ddram_burstcnt       (zero_burstcnt),
    .ddram_addr           (zero_addr),
    .ddram_rd              (zero_rd),
    .store_select         (zero_store_select),
    .store_pixel_value    (zero_store_value),
    .store_pixel_x        (zero_store_x),
    .store_pixel_y        (zero_store_y),
    .store_pixel_valid    (zero_store_valid),
    .store_block_start    (zero_store_start),
    .store_block_complete (zero_store_complete),
    .read_seen            (zero_read_seen),
    .sample_value         (zero_sample),
    .sample_nonzero       (zero_nonzero),
    .reconstructed_seen   (zero_reconstructed_seen),
    .reconstructed_value  (zero_reconstructed_value),
    .persisted_seen       (zero_persisted_seen),
    .persisted_value      (zero_persisted_value),
    .error                (zero_error)
);

assign ddram_burstcnt = zero_sel ? zero_burstcnt :
                        implicit_sel ? implicit_burstcnt : explicit_burstcnt;
assign ddram_addr = zero_sel ? zero_addr :
                    implicit_sel ? implicit_addr : explicit_addr;
assign ddram_rd = zero_sel ? zero_rd :
                  implicit_sel ? implicit_rd : explicit_rd;

assign p_store_select = zero_sel ? zero_store_select : implicit_store_select;
assign p_store_pixel_value = zero_sel ? zero_store_value : implicit_store_value;
assign p_store_pixel_x = zero_sel ? zero_store_x : implicit_store_x;
assign p_store_pixel_y = zero_sel ? zero_store_y : implicit_store_y;
assign p_store_pixel_valid = zero_sel ? zero_store_valid : implicit_store_valid;
assign p_store_block_start = zero_sel ? zero_store_start : implicit_store_start;
assign p_store_block_complete = zero_sel ? zero_store_complete : implicit_store_complete;

assign read_seen = zero_sel ? zero_read_seen :
                   implicit_sel ? implicit_read_seen : explicit_read_seen;
assign sample_value = zero_sel ? zero_sample :
                      implicit_sel ? implicit_sample : explicit_sample;
assign sample_nonzero = zero_sel ? zero_nonzero :
                        implicit_sel ? implicit_nonzero : explicit_nonzero;
assign half_sample_seen = explicit_sel ? explicit_half : 1'b0;
assign reconstructed_seen = zero_sel ? zero_reconstructed_seen :
                            implicit_reconstructed_seen;
assign reconstructed_value = zero_sel ? zero_reconstructed_value :
                             implicit_reconstructed_value;
assign persisted_seen = zero_sel ? zero_persisted_seen : implicit_persisted_seen;
assign persisted_value = zero_sel ? zero_persisted_value : implicit_persisted_value;
assign probe_error = explicit_error || implicit_error || zero_error;

wire unused_explicit_active = explicit_active;

endmodule
