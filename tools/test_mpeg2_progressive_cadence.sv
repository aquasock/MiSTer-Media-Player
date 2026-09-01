`timescale 1ns/1ps

module test_mpeg2_progressive_cadence;
reg clk=0,reset=1,tick=0,consume=0;
reg [3:0] frame_rate_code=0;
wire slot;
integer count,index;

always #5 clk=~clk;

mpeg2_h262_output_cadence dut(
    .clk(clk),.reset(reset),.tick(tick),.consume(consume),
    .frame_rate_code(frame_rate_code),.slot(slot)
);

task fail;
input [8*120-1:0] message;
begin $display("FAIL: %0s",message);$fatal(1);end
endtask

task reset_rate;
input [3:0] code;
begin
    @(negedge clk);
    reset=1;tick=0;consume=0;frame_rate_code=0;
    repeat(3) @(posedge clk);
    @(negedge clk);
    frame_rate_code=code;reset=0;
    repeat(2) @(posedge clk);
end
endtask

task count_slots;
input integer boundaries;
output integer presentations;
begin
    presentations=0;
    for(index=0;index<boundaries;index=index+1)begin
        @(negedge clk);
        tick=1;consume=slot;
        if(slot)presentations=presentations+1;
        @(negedge clk);
        tick=0;consume=0;
    end
end
endtask

initial begin
    reset_rate(4'd1);count_slots(5,count);
    if(count!=2)fail("24000/1001 is not exactly two pictures per five frames");
    reset_rate(4'd2);count_slots(2500,count);
    if(count!=1001)fail("24 fps ratio is not 1001/2500");
    reset_rate(4'd3);count_slots(2400,count);
    if(count!=1001)fail("25 fps ratio is not 1001/2400");
    reset_rate(4'd4);count_slots(2,count);
    if(count!=1)fail("30000/1001 ratio is not one picture per two frames");
    reset_rate(4'd5);count_slots(2000,count);
    if(count!=1001)fail("30 fps ratio is not 1001/2000");
    $display("PASS: exact progressive source cadence for frame-rate codes 1..5");
    $finish;
end
endmodule
