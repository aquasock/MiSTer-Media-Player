`timescale 1ns/1ps
module test_media_playback_control;
reg clk=0;always #5 clk=~clk;
reg reset=1,paused=0,seek_active=0;
reg [34:0] seek_target_q=0;
reg [3:0] frame_rate_code=3;
reg [2:0] swap_reset_count=0;
reg first_picture_complete=0,swap_window=0,drained=0,fatal=0;
reg display_pts_valid=0;
reg [32:0] display_pts=0;
wire [34:0] elapsed_q;
wire seek_done,scheduler_window,fast_seek,rebase;
wire [32:0] seek_elapsed_90k;
media_playback_control dut(.*);
reg tick_90k=1;
wire anchored,active,due;
wire [32:0] stc;
reg metadata=0;
mpeg2_h262_pts_presentation_timeline #(.ENABLE_PLAYBACK_CONTROL(1)) timeline(
 .clk(clk),.reset(reset),.tick_90k(tick_90k),.hold_time(paused||seek_active),
 .rebase(rebase),.rebase_pts(33'd90000+seek_elapsed_90k),
 .metadata_valid(metadata),.metadata_pts(33'd81000),
 .candidate_valid(1'b1),.candidate_pts(33'd90000),
 .anchored(anchored),.stc_90k(stc),.candidate_active(active),.candidate_due(due));
integer cycle=0,frames=0;
reg auto_frames=0;
always @(negedge clk) begin
 cycle=cycle+1;
 if(auto_frames) begin
  if(scheduler_window) begin swap_reset_count=4;frames=frames+1;end
  else if(swap_reset_count!=0) swap_reset_count=swap_reset_count-1'b1;
 end
end
task cold;
 begin
 reset=1;auto_frames=0;swap_reset_count=0;swap_window=0;frames=0;
 repeat(4) @(negedge clk);reset=0;
 metadata=1;first_picture_complete=1;
 @(negedge clk);metadata=0;first_picture_complete=0;
 end
endtask
reg [32:0] saved;
integer rate,seconds,period;
initial begin
 cold();repeat(8) @(negedge clk);paused=1;
 @(negedge clk);saved=stc;
 repeat(200) begin
  swap_window=~swap_window;@(negedge clk);
  if(stc!=saved||scheduler_window) $fatal(1,"pause advanced clock/presentation");
 end
 paused=0;swap_window=1;#1;if(!scheduler_window) $fatal(1,"resume window");
 // All five rates and every user seek interval, including exact fractional rates.
 for(rate=1;rate<=5;rate=rate+1) begin
  frame_rate_code=rate;
  period=rate==1?15015:rate==2?15000:rate==3?14400:rate==4?12012:12000;
  for(seconds=10;seconds<=300;seconds=seconds==10?30:seconds==30?300:301) begin
   seek_active=1;seek_target_q=seconds*360000;paused=1;cold();auto_frames=1;
   wait(dut.reached);@(negedge clk);auto_frames=0;
   if(elapsed_q<seek_target_q||elapsed_q-seek_target_q>=period)
    $fatal(1,"seek rounding rate=%d target=%d actual=%d",rate,seek_target_q,elapsed_q);
   if(seek_done) $fatal(1,"seek released outside real vblank");
   swap_reset_count=0;swap_window=1;
   repeat(3) @(negedge clk);
   if(!seek_done||stc!=90000+elapsed_q/4) $fatal(1,"seek completion/rebase");
   seek_active=0;swap_window=0;repeat(3) @(negedge clk);
   saved=stc;repeat(30) @(negedge clk);
   if(stc!=saved||scheduler_window) $fatal(1,"paused seek resumed");
  end
 end
 // Zero target, EOF clamp, fatal retirement and timestamp wrap.
 seek_active=1;seek_target_q=0;cold();
 repeat(5) @(negedge clk);if(!dut.reached) $fatal(1,"seek start clamp");
 swap_window=1;repeat(3) @(negedge clk);if(!seek_done) $fatal(1,"zero target completion");
 seek_target_q=108000000;cold();drained=1;@(negedge clk);drained=0;
 repeat(4) @(negedge clk);swap_window=1;repeat(3) @(negedge clk);
 if(!seek_done||elapsed_q!=0) $fatal(1,"EOF clamp");
 cold();fatal=1;repeat(3) @(negedge clk);fatal=0;swap_window=1;
 repeat(3) @(negedge clk);if(!seek_done) $fatal(1,"fatal left controls busy");
 seek_active=0;paused=0;cold();display_pts_valid=1;display_pts=33'h1fffffff0;
 repeat(3) @(negedge clk);display_pts=33'd3584;swap_reset_count=4;
 repeat(2) @(negedge clk);
 if(elapsed_q!=14400) $fatal(1,"timestamp wrap %d",elapsed_q);
 $display("PASS: pause clock/window, 15 rate/seek combinations, target rounding, paused seek, vblank release, EOF, fatal and PTS wrap");$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
