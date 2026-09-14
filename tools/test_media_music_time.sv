`timescale 1ns/1ps
module test_media_music_time;
 reg clk=0;always #5 clk=~clk;
 reg reset=1;reg[35:0] position=0,total=0;
 wire[34:0] elapsed_q,total_q;
 media_music_time dut(.*);
 task check(input[35:0] p,t);
 reg[63:0] e,d;
 begin
  @(negedge clk);position=p;total=t;
  repeat(160)@(negedge clk);
  e=(64'(p)/44100)*360000;d=(64'(t)/44100)*360000;
  if(e>34359738367)e=34359738367;if(d>34359738367)d=34359738367;
  if(elapsed_q!==e[34:0]||total_q!==d[34:0])$fatal(1,"music time %d/%d got %d/%d wanted %d/%d",p,t,elapsed_q,total_q,e,d);
 end endtask
 initial begin
  repeat(3)@(negedge clk);reset=0;
  check(0,0);check(44099,44100);check(44100,441000);check(44100000,44100001);
  check(36'hfffffffff,36'hfffffffff);
  check(1234567,7654321);
  reset=1;@(negedge clk);if(elapsed_q||total_q)$fatal(1,"replacement did not clear times");
  $display("PASS music sample-count time conversion, rounding, saturation and replacement");$finish;
 end
endmodule
