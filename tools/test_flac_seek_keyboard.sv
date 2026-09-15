`timescale 1ns/1ps
// Production keyboard, album controller and restart CDC; decoder completion is
// modeled here. The separate DDR bench compares every landed PCM sample.
module test_flac_seek_keyboard;
 reg clk=0,mpeg=0;always #5 clk=~clk;always #7 mpeg=~mpeg;
 reg reset=1,new_file=0,osd_open=0,byte_valid=0;
 reg [10:0] key=0;reg [7:0] byte_data=0;
 reg [34:0] elapsed_q=360000000;
 wire restart,busy,resume_frame,available,seek_available,reader_start,landed;
 wire [40:0] start_offset;wire [35:0] start_sample,target_sample,total_samples;
 wire [15:0] min_block,max_block;wire [7:0] tag;
 wire paused,seek_active,seek_request;wire [34:0] seek_target_q;
 wire decoder_reset,quiesce,fifo_reset,reader_cancel;wire [31:0] generation;
 wire [148:0] config_mpeg;wire [7:0] echo;
 reg landed_mpeg=0;integer delay_count=0;
 flac_album_control dut(.clk(clk),.reset(reset),.new_file(new_file),.enabled(1'b1),.osd_open(osd_open),.key(key),
  .byte_valid(byte_valid),.byte_data(byte_data),.position(36'd44100000),.file_size(64'd2000000),
  .reader_start(reader_start),.landed(landed),.seek_request(seek_request),.seek_target_q(seek_target_q),
  .restart(restart),.busy(busy),.resume_frame(resume_frame),.start_offset(start_offset),.start_sample(start_sample),
  .target_sample(target_sample),.total_samples(total_samples),.min_block(min_block),.max_block(max_block),.tag(tag),.available(available),.seek_available(seek_available));
 media_keyboard_control #(.RESTART_BOTH_DIRECTIONS(1),.ENABLE_SEEK_GATE(1)) keyboard(
  .clk(clk),.reset(reset),.new_file(new_file),.enabled(1'b1),.seek_enabled(seek_available&&!busy),.osd_open(osd_open),.key(key),.elapsed_q(elapsed_q),
  .duration_valid(seek_available),.duration_q(35'd720000000),
  .seek_done(seek_active&&landed&&!busy),.restart_complete(reader_start),.paused(paused),.seek_active(seek_active),.seek_target_q(seek_target_q),.restart(seek_request));
 video_config_cdc #(.WIDTH(149)) config_cdc(.src_clk(clk),.dst_clk(mpeg),.src_data({tag,resume_frame,total_samples,min_block,max_block,start_sample,target_sample}),.dst_data(config_mpeg));
 video_config_cdc #(.WIDTH(8)) echo_cdc(.src_clk(mpeg),.dst_clk(clk),.src_data(config_mpeg[148:141]),.dst_data(echo));
 video_config_cdc #(.WIDTH(1)) landed_cdc(.src_clk(mpeg),.dst_clk(clk),.src_data(landed_mpeg),.dst_data(landed));
 media_session_control #(.ENABLE_START_READY(1)) session(.clk_sys(clk),.clk_mpeg2(mpeg),.reset(reset),.restart(new_file||restart),
  .reader_idle(1'b1),.ddr_idle(1'b1),.start_ready(echo==tag),.reader_cancel(reader_cancel),.fifo_reset(fifo_reset),.reader_start(reader_start),
  .quiesce(quiesce),.decoder_reset(decoder_reset),.generation(generation));
 always @(posedge mpeg)begin
  if(decoder_reset)begin landed_mpeg<=0;delay_count<=0;end
  else if(delay_count==200)landed_mpeg<=1;
  else delay_count<=delay_count+1;
 end
 task event_key(input bit down,input [8:0] code);begin
  @(negedge clk);key={!key[10],down,code};repeat(4)@(negedge clk);
 end endtask
 task jump(input bit forward,input integer seconds);begin
  event_key(1,forward?9'h174:9'h16b);wait(restart);@(negedge clk);
  if(target_sample!=((forward?36'd1000+36'(seconds):36'd1000-36'(seconds))*36'd44100))$fatal(1,"wrong keyboard landing %d",target_sample);
  wait(!busy&&!seek_active);repeat(10)@(negedge clk);
  if(!paused)$fatal(1,"seek lost pause");
  event_key(0,forward?9'h174:9'h16b);
 end endtask
 task section_jump(input [8:0] code,input integer eighth);begin
  event_key(1,code);wait(restart);@(negedge clk);
  if(target_sample!=36'(eighth)*36'd11025000)$fatal(1,"section PCM target %d",target_sample);
  wait(!busy&&!seek_active);repeat(10)@(negedge clk);
  if(!paused)$fatal(1,"section seek lost pause");event_key(0,code);
 end endtask
 byte unsigned data[0:2000000];integer fd,n,j;string path;
 initial begin
  if(!$value$plusargs("input=%s",path))$fatal(1,"input");
  fd=$fopen(path,"rb");n=$fread(data,fd);$fclose(fd);
  repeat(5)@(negedge clk);reset=0;wait(reader_start);@(negedge clk);
  for(j=0;j<n;j=j+1)begin byte_data=data[j];byte_valid=1;@(negedge clk);end
  byte_valid=0;wait(landed);repeat(10)@(negedge clk);
  if(!seek_available||available)$fatal(1,"plain FLAC seek availability");
  event_key(1,9'h029);event_key(0,9'h029);if(!paused)$fatal(1,"pause");
  jump(1,10);jump(0,10);
  event_key(1,9'h014);jump(1,30);jump(0,30);
  event_key(1,9'h011);jump(1,60);jump(0,60);
  event_key(0,9'h011);event_key(0,9'h014);
  section_jump(9'h005,0);section_jump(9'h006,1);section_jump(9'h004,2);section_jump(9'h00c,3);
  section_jump(9'h003,4);section_jump(9'h00b,5);section_jump(9'h083,6);section_jump(9'h00a,7);
  osd_open=1;event_key(1,9'h174);osd_open=0;event_key(1,9'h174);
  if(busy||seek_active)$fatal(1,"OSD key leaked");event_key(0,9'h174);
  event_key(1,9'h174);wait(busy);new_file=1;repeat(4)@(negedge clk);new_file=0;
  repeat(500)@(negedge clk);
  if(busy||seek_active||paused||resume_frame||seek_available)$fatal(1,"replacement did not cancel seek");
  $display("PASS ordinary FLAC keyboard +/-10/30/60s, pause, restart CDC, OSD and replacement");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout nav=%d seek=%b",dut.nav_state,seek_active);end
endmodule
