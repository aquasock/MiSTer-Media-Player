`timescale 1ns/1ps
// Exercise completion through the production restart handshake, with independent
// clocks and explicit reader/DDR drain delays. Decoder/audio inputs are driven
// here; the mixed raster oracle separately checks real I/P/B presentation drain.
module test_media_eof_control;
reg clk_sys=0,clk_mpeg2=0;
always #5 clk_sys=~clk_sys;
always #7 clk_mpeg2=~clk_mpeg2;
reg reset_sys=1,new_file=0,loaded=0,sys_paused=0,sys_seeking=0,preflight=0;
reg input_eof=0,video_drained=0,audio_finished=0,paused=0,seeking=0,fatal=0,tick_90k=1;
reg [3:0] frame_rate_code=3;
reg reader_idle=1,ddr_idle=1,seek_restart=0;
wire close_file,reset_decoder,reader_cancel,fifo_reset,reader_start,quiesce;
wire [31:0] generation;
wire restart=new_file || close_file || seek_restart;
integer closes=0,checks=0;
media_session_control session(.clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),
 .reset(reset_sys),.restart(restart),.reader_idle(reader_idle),.ddr_idle(ddr_idle),
 .reader_cancel(reader_cancel),.fifo_reset(fifo_reset),.reader_start(reader_start),
 .quiesce(quiesce),.decoder_reset(reset_decoder),.generation(generation),.start_ready(1'b1));
media_eof_control dut(.*);
always @(posedge clk_sys)begin
 if(close_file)closes<=closes+1;
 // This is the production priority: a simultaneous replacement mount wins.
 if(reset_sys)loaded<=0;
 else if(new_file)loaded<=1;
 else if(close_file)loaded<=0;
end
always @(posedge clk_mpeg2)if(reset_decoder)begin
 input_eof<=0;video_drained<=0;audio_finished<=0;
end
task cycles(input integer n);repeat(n)@(negedge clk_mpeg2);endtask
task check(input bit ok,input string message);
 if(!ok)$fatal(1,"%s generation=%d closes=%d",message,generation,closes);
 checks=checks+1;
endtask
task load;
 @(negedge clk_sys);new_file=1;
 @(negedge clk_sys);new_file=0;
 wait(reader_start);cycles(4);
 check(!reset_decoder && loaded,"new session did not start");
 check(dut.active_generation==generation,"reset generation failed to cross before release");
endtask
task drain;
 cycles(1);input_eof=1;video_drained=1;audio_finished=1;
endtask
task no_close(input integer count,input string message);
 integer before_count;
 before_count=closes;cycles(count);check(closes==before_count,message);
endtask
task complete;
 integer before_count;
 before_count=closes;
 wait(close_file);@(negedge clk_sys);
 wait(reset_decoder);wait(reader_start);cycles(20);
 check(closes==before_count+1 && !loaded,"completion did not return to empty startup");
 no_close(4000,"empty player repeated closure");
endtask
initial begin
 cycles(10);reset_sys=0;
 wait(reader_start);load();
 video_drained=1;audio_finished=1;
 no_close(4000,"temporary input gap treated as EOF");
 input_eof=1;video_drained=0;
 no_close(4000,"closed with queued video");
 video_drained=1;audio_finished=0;
 no_close(8000,"closed before longer audio tail finished");
 audio_finished=1;paused=1;sys_paused=1;
 no_close(4000,"closed while paused at EOF");
 paused=0;sys_paused=0;seeking=1;sys_seeking=1;
 no_close(4000,"closed during seek");
 seeking=0;sys_seeking=0;fatal=1;
 no_close(4000,"fatal stream treated as clean EOF");
 fatal=0;cycles(3000);video_drained=0;cycles(1);video_drained=1;
 no_close(3500,"renewed video activity did not reset final-frame guard");
 complete();
 // Check actual source frame intervals, independent of 50/59.94 output mode.
 for(integer rate=1;rate<=5;rate=rate+1)begin
  integer ticks;
  load();frame_rate_code=rate;
  ticks=rate==1?3754:rate==2?3750:rate==3?3600:rate==4?3003:3000;
  drain();no_close(ticks,"last frame not held for its source interval");complete();
 end
 // No clock ticks means no wall-time progress.
 load();drain();tick_90k=0;no_close(6000,"guard ignored 90 kHz enable");tick_90k=1;complete();
 // Pause entered in sys domain while the completion mailbox was in flight.
 load();drain();wait(dut.done);sys_paused=1;
 no_close(100,"late sys pause lost to CDC completion");sys_paused=0;complete();
 // Probes are never allowed to close a loaded file.
 load();preflight=1;drain();no_close(5000,"duration probe closed the movie");
 // Old completion already latched; replace it and verify generation isolation.
 load();preflight=0;no_close(5000,"old EOF closed a replacement movie");
 check(loaded,"replacement was forgotten");drain();
 // DDR and host transactions must retire before decoder reset/restart.
 ddr_idle=0;reader_idle=0;wait(close_file);wait(quiesce);cycles(20);
 check(!reset_decoder && reader_cancel,"EOF reset decoder before DDR retirement");
 ddr_idle=1;wait(reset_decoder);cycles(40);
 check(!reader_start && reader_cancel,"EOF released before host response retirement");
 reader_idle=1;wait(reader_start);cycles(20);check(!loaded,"EOF retained old file");
 // Simultaneous replacement and close: the mount keeps its file size and the
 // following generation cannot consume the old response.
 load();drain();wait(close_file);@(negedge clk_sys);new_file=1;
 @(negedge clk_sys);new_file=0;wait(reader_start);cycles(20);
 check(loaded,"simultaneous new mount lost to EOF");
 no_close(5000,"stale completion affected simultaneous replacement");
 // A seek generation also invalidates an in-flight terminal response.
 drain();wait(dut.done);sys_seeking=1;
 @(negedge clk_sys);seek_restart=1;
 @(negedge clk_sys);seek_restart=0;
 wait(reader_start);cycles(20);sys_seeking=0;
 no_close(5000,"old EOF crossed a seek restart");
 check(loaded,"seek restart forgot the movie");drain();complete();
 $display("EOF CONTROL PASS checks=%0d closures=%0d",checks,closes);$finish;
end
initial begin #20000000;$fatal(1,"EOF test timed out");end
endmodule
