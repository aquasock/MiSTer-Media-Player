`timescale 1ns/1ps

// Verifies, against the real mpeg2_h262_two_picture_probe (the compiled
// mpeg2_h262_two_picture_probe_p_chain.sv), entry 990's fix: a pulse on
// overlap_reference_abandoned advances active_frame_bank exactly as a real
// picture completion would (0->1->2->0 wraparound), while every piece of
// reference/publication bookkeeping a real completion would also touch
// (reference_frame_valid, reference_frame_bank, reference_promotion_count,
// picture_count, completed_frame_bank) stays untouched, since the abandoned
// picture was never actually reconstructed and must never be published as a
// usable reference. Without this, active_frame_bank freezes forever on an
// abandoned overlap reference's bank (entry 986's abort clears the
// scheduler's own bookkeeping but never told this separate module), and the
// next real picture header collides with that frozen bank in the top-level
// P-destination-ownership-hold check - a second, distinct deadlock hardware
// testing found after entry 986/988/989 shipped.
module test_two_picture_probe_abandon;

reg clk=0, reset=1;
reg overlap_reference_abandoned=0;

wire [1:0] active_frame_bank, completed_frame_bank, reference_frame_bank, previous_reference_frame_bank;
wire [7:0] picture_count, reference_promotion_count;
wire reference_frame_valid, picture_420_complete;

mpeg2_h262_two_picture_probe dut(
    .clk(clk), .reset(reset),
    .stream_data(8'h00), .stream_valid(1'b0),
    .phase1_supported(1'b1), .vertical_size(14'd480),
    .intra_dc_precision(2'd0), .intra_vlc_format(1'b0), .frame_pred_frame_dct(1'b1),
    .pipeline_block_done(1'b0), .recon_block_complete(1'b0),
    .p_persistence_complete(1'b0), .p_row_persistence_complete(1'b0),
    .overlap_reference_abandoned(overlap_reference_abandoned),
    .active_frame_bank(active_frame_bank), .completed_frame_bank(completed_frame_bank),
    .picture_count(picture_count), .reference_frame_valid(reference_frame_valid),
    .reference_frame_bank(reference_frame_bank),
    .previous_reference_frame_bank(previous_reference_frame_bank),
    .reference_promotion_count(reference_promotion_count),
    .picture_420_complete(picture_420_complete)
);

always #5 clk = ~clk;

task fail; input [8*200-1:0] message; begin $display("FAIL: %0s",message); $fatal(1); end endtask
task pulse_clk; begin @(posedge clk); #1; end endtask

integer i;

initial begin
    @(negedge clk); reset=1;
    repeat(4) @(posedge clk);
    @(negedge clk); reset=0;

    if (active_frame_bank !== 2'd0) fail("active_frame_bank did not reset to 0");
    if (reference_frame_valid !== 1'b0) fail("reference_frame_valid did not reset to 0");

    // Three abandon pulses exercise the full 0->1->2->0 wraparound, matching
    // the real completion branch's own rotation exactly.
    for (i=0;i<3;i=i+1) begin
        @(negedge clk); overlap_reference_abandoned=1;
        @(negedge clk); overlap_reference_abandoned=0;
        if (picture_420_complete !== 1'b0)
            fail("abandon incorrectly asserted picture_420_complete - the abandoned picture must never be reported as a real completion");
    end
    if (active_frame_bank !== 2'd0)
        fail("active_frame_bank did not wrap 0->1->2->0 after three abandon pulses");

    // The reference/publication bookkeeping a real completion advances must
    // stay completely untouched - this picture was never reconstructed.
    if (reference_frame_valid !== 1'b0)
        fail("reference_frame_valid was set by an abandon pulse - the abandoned picture must never be published as a reference");
    if (reference_frame_bank !== 2'd0)
        fail("reference_frame_bank moved from an abandon pulse");
    if (reference_promotion_count !== 8'd0)
        fail("reference_promotion_count advanced from an abandon pulse");
    if (picture_count !== 8'd0)
        fail("picture_count advanced from an abandon pulse");
    if (completed_frame_bank !== 2'd0)
        fail("completed_frame_bank moved from an abandon pulse");

    // A single further pulse must advance exactly one step, not two - proves
    // the pulse is truly one-cycle wide in this module's response, not level
    // sensitive.
    @(negedge clk); overlap_reference_abandoned=1;
    @(negedge clk); overlap_reference_abandoned=0;
    pulse_clk; pulse_clk;
    if (active_frame_bank !== 2'd1)
        fail("a single abandon pulse did not advance active_frame_bank by exactly one step");

    $display("PASS: overlap_reference_abandoned advances active_frame_bank like a real completion without touching reference/publication bookkeeping");
    $finish;
end

initial begin
    #100000;
    fail("simulation timed out");
end

endmodule
