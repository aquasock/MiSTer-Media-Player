`timescale 1ns/1ps

module tb_native_ordinary_overlap_ownership;
reg clk=0,reset=1,swap=0,cadence=0,frame_waiting=0,sequence_end=0;
reg [1:0] completed_bank=0,active_bank=1;
reg i_start=0,p_start=0,non_b_start=0;
wire [1:0] display_bank;
wire hold,error;
always #5 clk=~clk;

mpeg2_h262_b_presentation_scheduler dut
(
    .clk(clk),.reset(reset),.swap_window_pulse(swap),
    .cadence_tick_pulse(cadence),.frame_rate_code(4'h4),
    .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),
    .native_ordinary_overlap_enable(1'b1),.active_frame_bank(active_bank),
    .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
    .reference_frame_bank(2'd0),.reference_promotion_count(8'd0),
    .b_picture_start(1'b0),.non_b_picture_start(non_b_start),
    .i_picture_start(i_start),.p_picture_start(p_start),
    .sequence_end(sequence_end),.b_user_success(1'b0),.b_decode_error(1'b0),
    .display_frame_bank(display_bank),.presentation_hold(hold),
    .presentation_error(error)
);

task automatic reset_case;
begin
    reset=1; swap=0; cadence=0; frame_waiting=0;
    completed_bank=0; active_bank=1;
    i_start=0; p_start=0; non_b_start=0; sequence_end=0;
    repeat(2) @(posedge clk); #1; reset=0;
    repeat(2) @(posedge clk); #1;
end
endtask

task automatic publish_bank1;
begin
    completed_bank=1; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0; active_bank=2;
end
endtask

task automatic header_i;
begin
    i_start=1; non_b_start=1;
    @(posedge clk); #1; i_start=0; non_b_start=0;
end
endtask

initial begin
    // A P picture may never enter the native all-I exception.
    reset_case(); publish_bank1();
    p_start=1; non_b_start=1;
    @(posedge clk); #1; p_start=0; non_b_start=0;
    if (dut.ordinary_reference_decode_open || !hold || error)
        $fatal(1,"P header escaped ordinary serialization");

    // Changing the decode destination to the displayed bank is fatal.
    reset_case(); publish_bank1(); header_i();
    if (!dut.ordinary_reference_decode_open || hold || error)
        $fatal(1,"safe I overlap did not open");
    active_bank=0;
    @(posedge clk); #1;
    if (!error) $fatal(1,"display-bank ownership violation was not caught");

    // A faster all-I decode may retain one completed successor without
    // overwriting the predecessor that still owns the primary pending slot.
    reset_case(); publish_bank1(); header_i();
    completed_bank=2; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0; active_bank=0;
    if (error) $fatal(1,"safe secondary completion raised an error");
    if (!dut.ordinary_secondary_valid || dut.ordinary_secondary_bank != 2)
        $fatal(1,"secondary completion was not retained");
    if (dut.pending_frame_bank != 1)
        $fatal(1,"secondary completion overwrote predecessor bank");
    if (hold) $fatal(1,"next I classification boundary was not admitted");
    header_i();
    if (!dut.ordinary_secondary_released ||
        !dut.ordinary_resume_pending || !hold || error)
        $fatal(1,"secondary release did not apply bounded backpressure");
    swap=1;
    @(posedge clk); #1; swap=0;
    if (error || display_bank != 1 || !dut.pending_frame_valid ||
        dut.pending_frame_bank != 2 || !dut.pending_frame_released)
        $fatal(1,"secondary promotion did not preserve presentation order");
    if (dut.ordinary_secondary_valid ||
        !dut.ordinary_reference_decode_open ||
        dut.ordinary_reference_decode_bank != 0 || hold)
        $fatal(1,"decode did not resume into the newly freed bank");

    // A completed bank may never alias the predecessor still waiting.
    reset_case(); publish_bank1(); header_i();
    completed_bank=1; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0;
    if (!error) $fatal(1,"duplicate pending-bank completion was not caught");

    $display({"NATIVE_ORDINARY_OWNERSHIP_PASS p_serial=1 display_guard=1 ",
              "secondary_queue=1 ordered_resume=1 duplicate_guard=1"});
    $finish;
end
endmodule
