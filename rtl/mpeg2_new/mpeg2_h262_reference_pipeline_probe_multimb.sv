//============================================================================
// MiSTer Media Player - Phase 1T-s reference pipeline
//
// kate - Keep the public reference-probe interface unchanged.  The accepted
// f_code=(1,1) two-MB client remains untouched.  A distinct f_code=(2,2),
// zero-vector semantic proof selects a new 2x2-macroblock/two-row copy client.
// Existing explicit-motion and implicit-residual clients retain their behavior.
//============================================================================

module mpeg2_h262_reference_read_probe
(
    input  wire        clk,
    input  wire        reset,
    // kate - Phase 1T-x: expose coded horizontal geometry at this boundary.
    // It is intentionally not consumed until the top-level connection is
    // hardware-validated in the next increment.
    input  wire [13:0] horizontal_size,
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

// kate - Phase 1T-w: move raster width ownership out of the four-MB engine.
// The current syntax proof still admits only the accepted two-Macroblock-wide
// controlled picture, so this interface value remains 2 for this increment.
// The next geometry step can replace this source with live coded width without
// changing the engine's address or raster machinery again.
wire [8:0] four_macroblock_width = 9'd2;

wire four_request =
    p_forward_vector_valid &&
    (p_forward_vector_x == 13'sd0) &&
    (p_forward_vector_y == 13'sd0) &&
    (forward_f_code_horizontal == 4'd2) &&
    (forward_f_code_vertical   == 4'd2) &&
    !p_implicit_reconstruct_request;

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
reg four_selected;
always @(posedge clk) begin
    if (reset) begin
        copy_selected <= 1'b0;
        four_selected <= 1'b0;
    end
    else begin
        if (copy_request)
            copy_selected <= 1'b1;
        if (four_request)
            four_selected <= 1'b1;
    end
end

wire four_sel = four_selected || four_request;
wire copy_sel = !four_sel && (copy_selected || copy_request);
wire implicit_sel = p_implicit_reconstruct_request && !four_sel && !copy_sel;
wire explicit_sel = !four_sel && !copy_sel && !implicit_sel;

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

wire [7:0]  four_burstcnt;
wire [28:0] four_addr;
wire        four_rd;
wire        four_read_seen;
wire [7:0]  four_sample;
wire        four_nonzero;
wire        four_reconstructed_seen;
wire [7:0]  four_reconstructed_value;
wire        four_persisted_seen;
wire [7:0]  four_persisted_value;
wire        four_error;
wire        four_store_select;
wire [7:0]  four_store_value;
wire [11:0] four_store_x;
wire [11:0] four_store_y;
wire        four_store_valid;
wire        four_store_start;
wire        four_store_complete;

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

mpeg2_h262_p_four_mb_two_row_copy_engine four_probe
(
    .clk                  (clk),
    .reset                (reset),
    .request              (four_sel),
    .macroblock_width     (four_macroblock_width),
    .reference_valid      (reference_frame_valid),
    .reference_bank       (reference_frame_bank),
    .destination_bank     (destination_frame_bank),
    .store_block_stored   (p_store_block_stored),
    .ddram_busy           (ddram_busy),
    .ddram_dout           (ddram_dout),
    .ddram_dout_ready     (ddram_dout_ready && four_sel),
    .ddram_burstcnt       (four_burstcnt),
    .ddram_addr           (four_addr),
    .ddram_rd             (four_rd),
    .store_select         (four_store_select),
    .store_pixel_value    (four_store_value),
    .store_pixel_x        (four_store_x),
    .store_pixel_y        (four_store_y),
    .store_pixel_valid    (four_store_valid),
    .store_block_start    (four_store_start),
    .store_block_complete (four_store_complete),
    .read_seen            (four_read_seen),
    .sample_value         (four_sample),
    .sample_nonzero       (four_nonzero),
    .reconstructed_seen   (four_reconstructed_seen),
    .reconstructed_value  (four_reconstructed_value),
    .persisted_seen       (four_persisted_seen),
    .persisted_value      (four_persisted_value),
    .error                (four_error)
);

assign ddram_burstcnt = four_sel ? four_burstcnt :
                        copy_sel ? copy_burstcnt :
                        implicit_sel ? implicit_burstcnt : explicit_burstcnt;
assign ddram_addr = four_sel ? four_addr :
                    copy_sel ? copy_addr :
                    implicit_sel ? implicit_addr : explicit_addr;
assign ddram_rd = four_sel ? four_rd :
                  copy_sel ? copy_rd :
                  implicit_sel ? implicit_rd : explicit_rd;

assign p_store_select = four_sel ? four_store_select :
                        copy_sel ? copy_store_select : implicit_store_select;
assign p_store_pixel_value = four_sel ? four_store_value :
                             copy_sel ? copy_store_value : implicit_store_value;
assign p_store_pixel_x = four_sel ? four_store_x :
                         copy_sel ? copy_store_x : implicit_store_x;
assign p_store_pixel_y = four_sel ? four_store_y :
                         copy_sel ? copy_store_y : implicit_store_y;
assign p_store_pixel_valid = four_sel ? four_store_valid :
                             copy_sel ? copy_store_valid : implicit_store_valid;
assign p_store_block_start = four_sel ? four_store_start :
                             copy_sel ? copy_store_start : implicit_store_start;
assign p_store_block_complete = four_sel ? four_store_complete :
                                copy_sel ? copy_store_complete : implicit_store_complete;

assign read_seen = four_sel ? four_read_seen :
                   copy_sel ? copy_read_seen :
                   implicit_sel ? implicit_read_seen : explicit_read_seen;
assign sample_value = four_sel ? four_sample :
                      copy_sel ? copy_sample :
                      implicit_sel ? implicit_sample : explicit_sample;
assign sample_nonzero = four_sel ? four_nonzero :
                        copy_sel ? copy_nonzero :
                        implicit_sel ? implicit_nonzero : explicit_nonzero;
assign half_sample_seen = explicit_sel ? explicit_half : 1'b0;
assign reconstructed_seen = four_sel ? four_reconstructed_seen :
                            copy_sel ? copy_reconstructed_seen :
                            implicit_reconstructed_seen;
assign reconstructed_value = four_sel ? four_reconstructed_value :
                             copy_sel ? copy_reconstructed_value :
                             implicit_reconstructed_value;
assign persisted_seen = four_sel ? four_persisted_seen :
                        copy_sel ? copy_persisted_seen : implicit_persisted_seen;
assign persisted_value = four_sel ? four_persisted_value :
                         copy_sel ? copy_persisted_value : implicit_persisted_value;
assign probe_error = explicit_error || implicit_error || copy_error || four_error;

wire unused_explicit_active = explicit_active;

endmodule
