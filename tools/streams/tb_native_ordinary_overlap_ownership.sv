`timescale 1ns/1ps

module tb_native_ordinary_overlap_ownership;
reg clk=0,reset=1,swap=0,cadence=0,frame_waiting=0;
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
    .sequence_end(1'b0),.b_user_success(1'b0),.b_decode_error(1'b0),
    .display_frame_bank(display_bank),.presentation_hold(hold),
    .presentation_error(error)
);

task automatic reset_case;
begin
    reset=1; swap=0; cadence=0; frame_waiting=0;
    completed_bank=0; active_bank=1;
    i_start=0; p_start=0; non_b_start=0;
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

    // Completion before the predecessor presents cannot overwrite pending.
    reset_case(); publish_bank1(); header_i();
    completed_bank=2; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0;
    if (!error) $fatal(1,"premature completion was not caught");
    if (dut.pending_frame_bank != 1)
        $fatal(1,"premature completion overwrote predecessor bank");

    $display("NATIVE_ORDINARY_OWNERSHIP_PASS p_serial=1 display_guard=1 pending_guard=1");
    $finish;
end
endmodule
