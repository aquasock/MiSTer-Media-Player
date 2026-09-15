`timescale 1ns/1ps
module test_audio_track_ui;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,new_file=0,loaded=0,osd_open=0,byte_valid=0;
 reg [7:0] byte_data=0;reg [10:0] key=0;
 reg [35:0] position=0;
 wire available,seek_available,track_valid,track_changed;
 wire [6:0] track_number;wire [35:0] start_sample,end_sample,total;
 flac_album_control album(.clk(clk),.reset(reset),.new_file(new_file),.enabled(1'b1),.osd_open(osd_open),.key(11'd0),
  .byte_valid(byte_valid),.byte_data(byte_data),.position(position),.file_size(64'd2000000),
  .reader_start(1'b0),.landed(1'b0),.seek_request(1'b0),.seek_target_q(35'd0),
  .restart(),.busy(),.resume_frame(),.start_offset(),.start_sample(),.target_sample(),
  .total_samples(total),.min_block(),.max_block(),.tag(),.available(available),.seek_available(seek_available),
  .current_track_valid(track_valid),.track_changed(track_changed),.current_track_number(track_number),
  .current_track_start(start_sample),.current_track_end(end_sample));
 wire [34:0] elapsed,duration,track_elapsed,track_duration,track_origin;
 wire times_valid;
 media_music_time times(.clk(clk),.reset(reset||new_file),.track_changed(track_changed),
  .position(position),.total(total),.track_position(position>=start_sample?position-start_sample:36'd0),
  .track_total(end_sample-start_sample),.track_start(start_sample),.elapsed_q(elapsed),.total_q(duration),
  .track_elapsed_q(track_elapsed),.track_total_q(track_duration),.track_start_q(track_origin),.track_times_valid(times_valid));
 wire paused,seeking,restart,known;wire [34:0] target;reg seek_done=0;
 media_keyboard_control #(.RESTART_BOTH_DIRECTIONS(1),.ENABLE_SEEK_GATE(1)) keyboard(
  .clk(clk),.reset(reset),.new_file(new_file),.enabled(loaded),.osd_open(osd_open),.key(key),
  .elapsed_q(elapsed),.duration_q(track_duration),.seek_origin_q(track_origin),
  .duration_valid(known&&track_valid&&times_valid&&!track_changed),.seek_enabled(seek_available),
  .seek_done(seek_done),.restart_complete(1'b1),.paused(paused),.seek_active(seeking),.seek_target_q(target),.restart(restart));
 wire [90:0] scene;
 media_ui_state #(.CLOCK_HZ(1000)) ui(.clk(clk),.reset(reset),.new_file(new_file),.loaded(loaded),
  .paused(paused),.seeking(seeking),.elapsed_q(elapsed),.target_q(target),.duration_q(duration),.duration_valid(total!=0),
  .music_mode(1'b1),.track_changed(track_changed),.track_valid(track_valid&&times_valid),
  .track_elapsed_q(track_elapsed),.track_origin_q(track_origin),.track_duration_q(track_duration),.album_duration_known(known),.scene_state(scene));
 task press(input [8:0] code);begin
  @(negedge clk);key={!key[10],1'b1,code};repeat(4)@(negedge clk);
  key={!key[10],1'b0,code};repeat(4)@(negedge clk);
 end endtask
 task section(input [8:0] code,input [34:0] expected);begin
  press(code);if(!seeking||target!=expected)$fatal(1,"F-key not current track got %d expected %d",target,expected);
  seek_done=1;repeat(4)@(negedge clk);seek_done=0;repeat(4)@(negedge clk);
 end endtask
 byte unsigned data[0:2000000];integer fd,n,j;string path;
 initial begin
  if(!$value$plusargs("input=%s",path))$fatal(1,"input");
  fd=$fopen(path,"rb");n=$fread(data,fd);$fclose(fd);
  repeat(5)@(negedge clk);reset=0;
  for(j=0;j<n;j=j+1)begin byte_data=data[j];byte_valid=1;@(negedge clk);end
  byte_valid=0;wait(times_valid);loaded=1;repeat(100)@(negedge clk);
  if(!scene[73]||scene[69:35]!=360000)$fatal(1,"initial track time");
  repeat(3100)@(negedge clk);
  if(!scene[73]||scene[69:35]!=1080000)$fatal(1,"initial album time");
  repeat(3000)@(negedge clk);if(scene[73])$fatal(1,"audio UI did not hide");
  // A natural crossing alone starts a fresh track/album sequence.
  position=44100;wait(track_changed);@(negedge clk);repeat(300)@(negedge clk);
  if(track_number!=2||!scene[73]||scene[69:35]!=360000)$fatal(1,"natural track phase");
  // F-keys use track coordinates in either display phase.
  repeat(3100)@(negedge clk);
  if(!scene[73]||scene[69:35]!=1080000)$fatal(1,"natural album phase");
  // Album display is active, but F5 must target the middle of track 2.
  section(9'h003,35'd540000);
  repeat(100)@(negedge clk);
  if(!scene[73]||scene[69:35]!=360000||scene[34:0]!=0)$fatal(1,"track-relative time");
  repeat(3000)@(negedge clk);if(scene[73])$fatal(1,"manual seek exceeded three seconds");
  section(9'h005,35'd360000);
  press(9'h029);if(!paused)$fatal(1,"pause");section(9'h00a,35'd675000);
  if(!paused)$fatal(1,"F-key lost pause");
  position=88200;wait(track_changed);repeat(300)@(negedge clk);
  section(9'h005,35'd720000);
  new_file=1;loaded=0;@(negedge clk);new_file=0;repeat(10)@(negedge clk);
  if(scene[73]||seeking||paused||track_valid)$fatal(1,"replacement retained track UI");
  $display("PASS integrated natural track UI phases, current-track F-keys in both phases, pause and replacement");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
