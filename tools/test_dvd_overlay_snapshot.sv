`timescale 1ns/1ps

module test_dvd_overlay_snapshot;
reg clk=0,reset=1,session_active=0,overlay_commit_seen=0;
wire capture,armed;
wire [1:0] reason;
wire [31:0] settle_elapsed;
integer capture_count=0;

always #5 clk=~clk;
always @(posedge clk) if(capture) capture_count=capture_count+1;

mpeg2_h262_overlay_snapshot_trigger #(
    .SETTLE_CYCLES(32'd4),
    .FALLBACK_CYCLES(32'd10)
) dut (
    .clk(clk),.reset(reset),.session_active(session_active),
    .overlay_commit_seen(overlay_commit_seen),.capture(capture),
    .armed(armed),.reason(reason),.settle_elapsed(settle_elapsed)
);

initial begin
    repeat(3)@(posedge clk);
    @(negedge clk);reset=0;session_active=1;
    repeat(3)@(posedge clk);
    @(negedge clk);overlay_commit_seen=1;
    wait(capture);
    @(posedge clk);
    if(!armed||reason!=2'd1||settle_elapsed!=32'd3)
        $fatal(1,"commit capture armed=%0d reason=%0d elapsed=%0d",
               armed,reason,settle_elapsed);
    repeat(5)@(posedge clk);
    if(capture_count!=1)$fatal(1,"commit capture repeated %0d",capture_count);

    @(negedge clk);reset=1;session_active=0;overlay_commit_seen=0;
    repeat(3)@(posedge clk);
    @(negedge clk);reset=0;session_active=1;
    wait(capture);
    @(posedge clk);
    if(armed||reason!=2'd2)
        $fatal(1,"fallback capture armed=%0d reason=%0d",armed,reason);
    repeat(5)@(posedge clk);
    if(capture_count!=2)$fatal(1,"fallback capture repeated %0d",capture_count);
    $display("dvd overlay snapshot: settled commit and bounded fallback pass");
    $finish;
end
endmodule
