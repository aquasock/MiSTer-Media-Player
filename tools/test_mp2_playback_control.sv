`timescale 1ns/1ps
module test_mp2_playback_control;
reg clk=0;always #5 clk=~clk;
reg reset=1,pause=1,seek=1,origin_valid=0;
reg [32:0] origin_pts,seek_target,first_pts;
wire [66:0] fifo_data;
wire fifo_empty=index>600;
wire fifo_rd,underrun,timestamp_error,finished;
wire signed [15:0] audio_l,audio_r;
wire [31:0] samples_played;
integer index=0,case_id,played,last_cycle,cycle=0;
reg check_cadence=0;
assign fifo_data={index==600,index%48==0,33'(first_pts+(index/48)*90),16'(index),16'(-index)};
mp2_pcm_output #(.ENABLE_PLAYBACK_CONTROL(1)) dut(.*);
always @(posedge clk) begin
 cycle=cycle+1;
 if(!reset&&fifo_rd) begin
  if(!seek&&!dut.catchup&&index<600) begin
   if(check_cadence&&cycle-last_cycle!=512) $fatal(1,"resume sample cadence");
   last_cycle=cycle;
  end
  index<=index+1;
 end
end
reg [32:0] saved_stc;
reg [8:0] saved_phase;
integer saved_index;
initial begin
 for(case_id=0;case_id<2;case_id=case_id+1) begin
  reset=1;index=0;pause=1;seek=1;check_cadence=0;
  first_pts=case_id==0?33'd90000:33'h1ffffff00;
  origin_pts=first_pts-90;seek_target=first_pts+450;
  repeat(4) @(negedge clk);reset=0;origin_valid=1;
  @(negedge clk);origin_valid=0;
  wait(index==240);repeat(50) @(negedge clk);
  if(index!=240||audio_l||audio_r||samples_played) $fatal(1,"seek failed to hold exact sample");
  seek=0;repeat(20) @(negedge clk);
  if(index!=240||audio_l||audio_r) $fatal(1,"paused seek consumed audio");
  pause=0;wait(index==241);@(negedge clk);
  if(audio_l!=240||audio_r!=-240) $fatal(1,"wrong resumed sample");
  check_cadence=1;
  wait(index==300);repeat(123) @(negedge clk);
  pause=1;check_cadence=0;@(negedge clk);
  saved_stc=dut.stc;saved_phase=dut.sample_phase;saved_index=index;
  repeat(10000) @(negedge clk);
  if(index!=saved_index||dut.stc!=saved_stc||dut.sample_phase!=saved_phase||audio_l||audio_r)
   $fatal(1,"pause lost timeline or queued PCM");
  pause=0;wait(index==301);@(negedge clk);
  if(audio_l!=300) $fatal(1,"pause skipped or repeated sample");
  check_cadence=1;
  wait(finished);@(negedge clk);
  if(underrun||timestamp_error||samples_played!=360) $fatal(1,"audio seek result flags %b %b count %d",underrun,timestamp_error,samples_played);
 end
 // Seeking past EOF drains once and remains silent.
 reset=1;index=0;pause=0;seek=1;check_cadence=0;
 first_pts=90000;origin_pts=81000;seek_target=900000;
 repeat(4) @(negedge clk);reset=0;origin_valid=1;
 @(negedge clk);origin_valid=0;
 wait(finished);repeat(5) @(negedge clk);
 if(index!=601||samples_played||underrun||timestamp_error||audio_l||audio_r) $fatal(1,"seek beyond EOF");
 $display("PASS: exact PCM seek/discard, sparse timestamps, PTS wrap, silence, pause phase/queue retention, resume cadence and EOF");$finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
