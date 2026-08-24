`timescale 1ns/1ps
module tb_native_field_order;
reg clk=0,reset=1,pce=0,progressive=0,tff=1;
wire locked,locked_tff,mismatch;
always #5 clk=~clk;

mpeg2_h262_native_field_order dut(
    .clk(clk),.reset(reset),
    .picture_coding_extension_valid(pce),
    .progressive_sequence(progressive),
    .picture_top_field_first(tff),
    .locked(locked),.top_field_first(locked_tff),.mismatch(mismatch));

task picture(input progressive_value,input tff_value);
begin
    @(negedge clk);progressive=progressive_value;tff=tff_value;pce=1;
    @(negedge clk);pce=0;
end
endtask

initial begin
    repeat(3)@(posedge clk);reset=0;
    picture(1,0);
    if(locked||mismatch)$fatal(1,"progressive picture affected native order");
    picture(0,1);
    if(!locked||!locked_tff||mismatch)$fatal(1,"TFF lock failed");
    picture(0,1);
    if(mismatch)$fatal(1,"stable TFF order rejected");
    picture(0,0);
    if(!mismatch||!locked_tff)$fatal(1,"field-order change not rejected");
    picture(0,1);
    if(!mismatch)$fatal(1,"mismatch was not sticky");
    @(negedge clk);reset=1;@(negedge clk);reset=0;
    picture(0,0);
    if(!locked||locked_tff||mismatch)$fatal(1,"BFF rearm failed");
    $display("RESULT stable_tff=PASS change_rejected=PASS reset_bff=PASS");
    $finish;
end
endmodule
