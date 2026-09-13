`timescale 1ns/1ps

// Verifies, against the real mpeg2_h262_b_presentation_scheduler, the fix
// for the deadlock entry 985's hardware telemetry confirmed: an early
// B-picture header arriving while an overlap reference (an I/P admitted
// immediately after this run closed) is still decoding gets deferred via
// deferred_queued_b_start. That alone asserts presentation_hold - a
// separate, unconditional OR-term, not gated on promotion_pending - which
// blocks all further decoder input at the top level (MediaPlayer.sv's
// mpeg2_new_stream_ready). That starves the very overlap-reference decode
// deferred_queued_b_start's own clear condition (a frame_waiting pulse)
// is waiting on: a permanent circular wait without the fix below.
//
// Sequence driven: admit and complete two B pictures (closing a
// two-picture reorder run requires a third, non-B header anyway; this
// mirrors the run_picture_count=2 the hardware snapshot showed), admit a
// non-B header that closes the run and opens an overlap decode, admit an
// early third B header before ever pulsing frame_waiting for that overlap
// reference (so deferred_queued_b_start latches while overlap_decode_open
// is still 1), then run cadence/swap pulses until the closed run's own
// future frame is ready to retire - all without ever supplying the
// overlap reference's completion, exactly reproducing "decode already
// stopped, so it never will".
module test_b_presentation_scheduler_deadlock;

reg clk=0, reset=1;
reg swap_window_pulse=0, cadence_tick_pulse=0;
reg [3:0] frame_rate_code=4'h2;
reg display_picture_present=1, display_repeat_first_field=0, candidate_top_field_first=0;
reg timestamp_candidate_active=0, timestamp_candidate_due=0;
reg native_ordinary_overlap_enable=0;
reg [1:0] active_frame_bank=0;
reg frame_waiting=0;
// Different from display_frame_bank's reset value (0), so the first B's
// admission takes the "distinct reference" branch (future_reference_pending
// <= 0) rather than the "same bank, unknown promotion history" branch
// (future_reference_pending <= 1), which is not what this test is about.
reg [1:0] completed_frame_bank=0, reference_frame_bank=1;
reg [7:0] reference_promotion_count=0;
reg b_picture_start=0, non_b_picture_start=0, i_picture_start=0, p_picture_start=0;
reg sequence_end=0, b_user_success=0, b_decode_error=0;

wire [1:0] display_frame_bank;
wire display_scratch, display_scratch_bank, decode_scratch_bank;
wire candidate_frame_valid, candidate_frame_scratch, candidate_scratch_bank;
wire [1:0] candidate_frame_bank;
wire cadence_slot_debug, candidate_presentable_debug;
wire [2:0] framebuffer_swap_reset_count;
wire reference_overlap_header, presentation_hold;
wire scratch_available, promotion_active;
wire presentation_complete, presentation_error;
wire [31:0] debug_state;

always #5 clk = ~clk;

mpeg2_h262_b_presentation_scheduler dut(
    .clk(clk), .reset(reset),
    .swap_window_pulse(swap_window_pulse), .cadence_tick_pulse(cadence_tick_pulse),
    .frame_rate_code(frame_rate_code),
    .native_film_mode(1'b0), .native_field(1'b0),
    .display_picture_present(display_picture_present),
    .display_repeat_first_field(display_repeat_first_field),
    .candidate_top_field_first(candidate_top_field_first),
    .timestamp_candidate_active(timestamp_candidate_active),
    .timestamp_candidate_due(timestamp_candidate_due),
    .native_ordinary_overlap_enable(native_ordinary_overlap_enable),
    .active_frame_bank(active_frame_bank), .frame_waiting(frame_waiting),
    .completed_frame_bank(completed_frame_bank),
    .reference_frame_bank(reference_frame_bank),
    .reference_promotion_count(reference_promotion_count),
    .b_picture_start(b_picture_start), .non_b_picture_start(non_b_picture_start),
    .i_picture_start(i_picture_start), .p_picture_start(p_picture_start),
    .sequence_end(sequence_end), .b_user_success(b_user_success),
    .b_decode_error(b_decode_error),
    .display_frame_bank(display_frame_bank), .display_scratch(display_scratch),
    .display_scratch_bank(display_scratch_bank), .decode_scratch_bank(decode_scratch_bank),
    .candidate_frame_valid(candidate_frame_valid), .candidate_frame_scratch(candidate_frame_scratch),
    .candidate_scratch_bank(candidate_scratch_bank), .candidate_frame_bank(candidate_frame_bank),
    .cadence_slot_debug(cadence_slot_debug), .candidate_presentable_debug(candidate_presentable_debug),
    .framebuffer_swap_reset_count(framebuffer_swap_reset_count),
    .reference_overlap_header(reference_overlap_header), .presentation_hold(presentation_hold),
    .scratch_available(scratch_available), .promotion_active(promotion_active),
    .presentation_complete(presentation_complete), .presentation_error(presentation_error),
    .debug_state(debug_state)
);

task fail; input [8*200-1:0] message; begin $display("FAIL: %0s",message); $fatal(1); end endtask

task pulse_clk; begin @(posedge clk); #1; end endtask

// Drives swap_window_pulse and cadence_tick_pulse together for `n` clocks,
// giving presentation_consume every opportunity to fire.
task pump_cadence; input integer n; integer k;
begin
    for (k=0;k<n;k=k+1) begin
        @(negedge clk);
        cadence_tick_pulse=1; swap_window_pulse=1;
        @(negedge clk);
        cadence_tick_pulse=0; swap_window_pulse=0;
    end
end
endtask

integer i;

initial begin
    @(negedge clk); reset=1;
    repeat(4) @(posedge clk);
    @(negedge clk); reset=0;

    // Admit and complete B1.
    @(negedge clk); b_picture_start=1; @(negedge clk); b_picture_start=0;
    if (!dut.reorder_active || dut.run_picture_count!==2'd1)
        fail("B1 admission did not start a one-picture reorder run");
    @(negedge clk); b_user_success=1; @(negedge clk); b_user_success=0;
    if (!dut.scratch0_pending)
        fail("B1 completion did not mark scratch0 pending");

    // Admit and complete B2.
    @(negedge clk); b_picture_start=1; @(negedge clk); b_picture_start=0;
    if (dut.run_picture_count!==2'd2)
        fail("B2 admission did not advance run_picture_count to 2");
    @(negedge clk); b_user_success=1; @(negedge clk); b_user_success=0;
    if (!dut.scratch1_pending)
        fail("B2 completion did not mark scratch1 pending");

    // Admit a non-B (P) header: closes the run and opens an overlap decode
    // for this new reference, matching the real hardware's run_closed=1,
    // run_picture_count=2 snapshot exactly.
    @(negedge clk); non_b_picture_start=1; p_picture_start=1;
    @(negedge clk); non_b_picture_start=0; p_picture_start=0;
    if (!dut.run_closed) fail("P header did not close the reorder run");
    if (!dut.overlap_decode_open) fail("P header did not open an overlap decode");

    // Admit an early third B header *before* the overlap reference's own
    // completion (frame_waiting) ever arrives - the exact race entry 985
    // identified.
    @(negedge clk); b_picture_start=1; @(negedge clk); b_picture_start=0;
    if (!dut.deferred_queued_b_start)
        fail("early B header did not defer while the overlap reference was still open");
    if (!presentation_hold)
        fail("deferred_queued_b_start did not assert presentation_hold");

    // Drain both scratch pictures and let the run's own future frame
    // become ready to retire - all without ever supplying frame_waiting,
    // simulating the overlap reference never completing because decode
    // input is already blocked.
    pump_cadence(40);
    if (dut.scratch0_pending || dut.scratch1_pending)
        fail("scratch pictures never drained after 40 cadence cycles");

    // Entry 985's fix: this specific combination (deferred_queued_b_start
    // while its overlap reference is still open) must now abort instead of
    // latching promotion_pending and hanging forever.
    if (!presentation_error)
        fail("deferred_queued_b_start + overlap_decode_open at future_waiting did not abort (fix not applied or not effective)");
    if (dut.deferred_queued_b_start)
        fail("deferred_queued_b_start was not cleared by the abort");
    if (dut.overlap_decode_open)
        fail("overlap_decode_open was not cleared by the abort");

    // Critically, presentation_hold itself must clear once the abort
    // registers land (one more cycle for the combinational expression to
    // reflect the cleared state) - this is what actually frees the
    // decoder to resume accepting compressed bytes.
    pulse_clk;
    if (presentation_hold)
        fail("presentation_hold is still asserted after the abort - the deadlock is not actually broken");

    $display("PASS: the fix aborts the unrecoverable defer instead of hanging, and presentation_hold clears");
    $finish;
end

initial begin
    #2000000;
    fail("simulation timed out");
end

endmodule
