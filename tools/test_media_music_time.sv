`timescale 1ns/1ps
module test_media_music_time;
 reg clk=0;always #5 clk=~clk;
 reg reset=1;reg[35:0] position=0,total=0,track_position=0,track_total=0,track_start=0;
 reg track_changed=0;wire track_times_valid;
 wire[34:0] elapsed_q,total_q,track_elapsed_q,track_total_q,track_start_q;
 media_music_time dut(.*);
 task check(input[35:0] p,t);
 reg[63:0] e,d,te,td;
 begin
  @(negedge clk);position=p;total=t;track_position=t;track_total=p;track_start=p;track_changed=1;@(negedge clk);track_changed=0;
  repeat(510)@(negedge clk);
  e=(64'(p)*400)/49;d=(64'(t)*400+48)/49;te=(64'(t)*400)/49;td=(64'(p)*400+48)/49;
  if(e>34359738367)e=34359738367;if(d>34359738367)d=34359738367;
  if(te>34359738367)te=34359738367;if(td>34359738367)td=34359738367;
  if(elapsed_q!==e[34:0]||total_q!==d[34:0]||track_elapsed_q!==te[34:0]||track_total_q!==td[34:0]||track_start_q!==td[34:0]||!track_times_valid)$fatal(1,"music time %d/%d got %d/%d wanted %d/%d",p,t,elapsed_q,total_q,e,d);
 end endtask
 initial begin
  repeat(3)@(negedge clk);reset=0;
  check(0,0);check(44099,44100);check(44100,441000);check(44100000,44100001);
  check(36'hfffffffff,36'hfffffffff);
  check(1234567,7654321);
  reset=1;@(negedge clk);if(elapsed_q||total_q||track_elapsed_q||track_total_q||track_start_q||track_times_valid)$fatal(1,"replacement did not clear times");
  $display("PASS music sample-count time conversion, rounding, saturation and replacement");$finish;
 end
endmodule
