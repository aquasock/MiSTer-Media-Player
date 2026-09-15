`timescale 1ns/1ps
module test_playback_restart;
reg clk_sys=0;always #25 clk_sys=~clk_sys;
reg clk_mpeg2=0;always #8.333 clk_mpeg2=~clk_mpeg2;
reg reset=1,new_file=0;
reg [10:0] key=0;
wire paused_sys,seeking_sys,restart;
wire [34:0] target_sys,elapsed,elapsed_sys;
wire done,done_sys;
wire [36:0] command;
wire paused=command[36],seeking=command[35];
wire [34:0] target=command[34:0];
reg reader_idle=1,ddr_idle=1;
wire cancel,flush,start,quiesce,decoder_reset;
wire [31:0] generation;
media_keyboard_control keyboard(
 .clk(clk_sys),.reset(reset),.new_file(new_file),.enabled(1'b1),.osd_open(1'b0),
 .duration_q(35'd0),.duration_valid(1'b0),.key(key),.elapsed_q(elapsed_sys),.seek_done(done_sys),.restart_complete(start),.paused(paused_sys),
 .seek_active(seeking_sys),.seek_target_q(target_sys),.restart(restart));
video_config_cdc #(.WIDTH(37)) command_cdc(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data({paused_sys,seeking_sys,target_sys}),.dst_data(command));
video_config_cdc #(.WIDTH(36)) result_cdc(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data({done,elapsed}),.dst_data({done_sys,elapsed_sys}));
media_session_control session_control(
 .clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),.reset(reset),.restart(restart||new_file),
 .reader_idle(reader_idle),.ddr_idle(ddr_idle),.reader_cancel(cancel),.fifo_reset(flush),
 .reader_start(start),.quiesce(quiesce),.decoder_reset(decoder_reset),.generation(generation));
reg [2:0] swaps=0;
reg [9:0] raster=0;
wire window=raster==0;
wire scheduler_window,fast,rebase;
wire [32:0] seek_elapsed;
media_playback_control playback(
 .clk(clk_mpeg2),.reset(decoder_reset),.paused(paused),.seek_active(seeking),
 .seek_target_q(target),.frame_rate_code(4'd3),.swap_reset_count(swaps),
 .first_picture_complete(!decoder_reset),.swap_window(window),.drained(1'b0),.fatal(1'b0),
 .display_pts_valid(1'b0),.display_pts(33'd0),.elapsed_q(elapsed),.seek_done(done),
 .scheduler_window(scheduler_window),.fast_seek(fast),.rebase(rebase),.seek_elapsed_90k(seek_elapsed));
always @(posedge clk_mpeg2) begin
 raster<=raster+1'b1;
 if(decoder_reset) swaps<=0;
 else if(scheduler_window) swaps<=4;
 else if(swaps!=0) swaps<=swaps-1'b1;
end
integer starts=0;
always @(posedge clk_sys) if(start&&!reset) begin
 starts<=starts+1;
 if(!reader_idle||!ddr_idle||decoder_reset||flush) $fatal(1,"restart released outstanding work");
 if(seeking_sys&&(!seeking||target!=target_sys)) $fatal(1,"seek command not settled before start");
end
task key_event(input [8:0] code,input down);
 begin @(negedge clk_sys);key={!key[10],down,code};repeat(3) @(negedge clk_sys);end
endtask
integer i;
reg [34:0] expected;
initial begin
 repeat(5) @(negedge clk_sys);reset=0;wait(starts==1);
 key_event(9'h029,1);key_event(9'h029,0);wait(paused);
 repeat(30) @(negedge clk_sys);
 for(i=0;i<3;i=i+1) begin
  expected=elapsed_sys+3600000;
  reader_idle=0;ddr_idle=0;
  key_event(9'h174,1);key_event(9'h174,0);
  repeat(40) @(negedge clk_sys);
  if(decoder_reset||quiesce||flush||starts!=i+1) $fatal(1,"forward seek restarted session");
  wait(done_sys);wait(!seeking_sys);wait(!done_sys);
  repeat(20) @(negedge clk_sys);
  if(elapsed_sys!=expected||!paused) $fatal(1,"forward target/pause lost");
  expected=elapsed_sys<3600000?0:elapsed_sys-3600000;
  key_event(9'h16b,1);key_event(9'h16b,0);
  repeat(2000) @(negedge clk_sys);
  if(decoder_reset||!quiesce||!flush) $fatal(1,"DDR was reset before retirement");
  ddr_idle=1;wait(decoder_reset);
  repeat(40) @(negedge clk_sys);
  if(!flush) $fatal(1,"host response not retired before FIFO release");
  reader_idle=1;
  wait(starts==i+2);wait(done_sys);wait(!seeking_sys);wait(!done_sys);
  repeat(20) @(negedge clk_sys);
  if(elapsed_sys<expected||elapsed_sys-expected>14400||!paused) $fatal(1,"restart target/pause lost");
 end
 new_file=1;@(negedge clk_sys);new_file=0;wait(starts==5);
 if(paused_sys||seeking_sys) $fatal(1,"new file retained controls");
 $display("PASS: three retained forward and three restart backward async keyboard seeks with in-flight host/DDR retirement, command settling, acknowledged completion and paused state");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
