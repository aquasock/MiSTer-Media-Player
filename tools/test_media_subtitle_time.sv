`timescale 1ns/1ps
module test_media_subtitle_time;
 reg clk=0;always #5 clk=~clk;
 reg reset=1;reg[34:0] elapsed_q=0;reg[6:0] offset_code=0,speed_code=0;
 wire[36:0] subtitle_q;wire before_start,restart;
 media_subtitle_time dut(.*);
 integer o,v,n=0;reg signed[63:0] shifted,expected;integer offset,speed;
 task check(input[34:0] t,input[6:0] oc,sc);
 begin
  @(negedge clk);elapsed_q=t;offset_code=oc;speed_code=sc;
  repeat(120)@(negedge clk);
  offset=oc<=50?oc:oc<=100?integer'(oc)-101:0;
  speed=sc<=50?integer'(sc)+100:sc<=100?integer'(sc)-1:100;
  shifted=$signed({29'd0,t})-64'(offset)*36000;
  expected=shifted<0?0:shifted*speed/100;
  if(restart||before_start!==(shifted<0)||subtitle_q!==expected[36:0])
   $fatal(1,"subtitle time t=%d offset=%d speed=%d got=%d expected=%d pre=%b",t,offset,speed,subtitle_q,expected,before_start);
  n=n+1;
 end endtask
 initial begin
  repeat(3)@(negedge clk);reset=0;
  check(0,0,0);check(0,50,0);check(1799999,50,0);check(1800000,50,0);check(0,51,0);
  for(o=0;o<=100;o=o+1)for(v=0;v<=100;v=v+1)check(35'd123456789,7'(o),7'(v));
  check(35'h7ffffffff,51,50);check(35'h7ffffffff,50,51);check(123456789,127,127);
  // A change during division aborts the stale result and requests cue reload.
  @(negedge clk);offset_code=1;@(negedge clk);if(!restart)$fatal(1,"missing retime request");
  repeat(7)@(negedge clk);speed_code=51;repeat(9)@(negedge clk);offset_code=51;
  check(123456789,51,51);
  reset=1;@(negedge clk);if(!restart||subtitle_q!=0)$fatal(1,"new file reset");
  $display("PASS subtitle timeline %0d cases: all offset/speed pairs, pre-zero, exact boundary, long duration, invalid codes, mid-calculation retime",n);$finish;
 end
endmodule
