`timescale 1ns/1ps
module test_flac_album_control;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,new_file=0,enabled=1,osd_open=0,byte_valid=0,reader_start=0,landed=0;
 reg [10:0] key=0;
 reg [7:0] byte_data=0;
 reg [35:0] position=0;
 reg [63:0] file_size=0;
 reg seek_request=0;reg [34:0] seek_target_q=0;
 wire restart,busy,resume_frame,available,seek_available;
 wire current_track_valid,track_changed;
 wire [6:0] current_track_number;
 wire [35:0] current_track_start,current_track_end;
 integer changes=0;
 always @(posedge clk)if(track_changed)changes<=changes+1;
 task check_track(input [35:0] p,start_value,end_value,input [6:0] number);
 integer before_changes;
 begin
  before_changes=changes;position=p;repeat(220)@(negedge clk);
  if(!current_track_valid||current_track_start!=start_value||current_track_end!=end_value||current_track_number!=number)
   $fatal(1,"track observer p=%d n=%d start=%d end=%d",p,current_track_number,current_track_start,current_track_end);
  if(changes-before_changes>1)$fatal(1,"repeated natural transition");
  before_changes=changes;repeat(220)@(negedge clk);
  if(changes!=before_changes)$fatal(1,"stationary track retriggers UI");
 end endtask
 wire [40:0] start_offset;
 wire [35:0] start_sample,target_sample,total_samples;
 wire [15:0] min_block,max_block;
 wire [7:0] tag;
 flac_album_control dut(.*);
 byte unsigned bytes[0:2000000];
 integer fd,length,n,j,count_expected=3;
 integer target_expected=44100,base_expected=40960,offset_expected=0;
 string path;
 task key_event(input bit down,input [8:0] code);begin
  @(negedge clk);key={!key[10],down,code};repeat(4)@(negedge clk);
 end endtask
 task settle;begin repeat(6)@(negedge clk);end endtask
 task finish_jump;begin
  reader_start=1;settle;reader_start=0;landed=1;settle;landed=0;
  if(busy)$fatal(1,"navigation did not finish");
 end endtask
 task next_jump;begin
  key_event(1,9'h031);
  wait(restart);@(negedge clk);
  if(target_sample!=36'(target_expected)||start_sample!=36'(base_expected)||start_offset!=41'(offset_expected))
   $fatal(1,"wrong track seek target=%d base=%d offset=%d",target_sample,start_sample,start_offset);
  finish_jump();
  key_event(1,9'h031);if(busy)$fatal(1,"typematic repeated");key_event(0,9'h031);
 end endtask
 initial begin
  if(!$value$plusargs("input=%s",path))$fatal(1,"input");
  n=$value$plusargs("tracks=%d",count_expected);n=$value$plusargs("target=%d",target_expected);
  n=$value$plusargs("base=%d",base_expected);n=$value$plusargs("offset=%d",offset_expected);
  fd=$fopen(path,"rb");length=$fread(bytes,fd);$fclose(fd);file_size=64'(length);
  repeat(4)@(negedge clk);reset=0;
  for(j=0;j<length;j=j+1)begin
   byte_data=bytes[j];byte_valid=1;@(negedge clk);byte_valid=0;
   if(j%11==0)repeat(3)@(negedge clk);
  end
  settle;
  if(count_expected!=0)begin
  if(!available||int'(dut.track_count)!=count_expected)$fatal(1,"cue unavailable count=%d bad=%b",dut.track_count,dut.cue_bad);
  check_track(0,0,44100,1);
  check_track(44099,0,44100,1);
  check_track(44100,44100,88200,2);
  check_track(88200,88200,total_samples,3);
  check_track(total_samples-1,88200,total_samples,3);
  check_track(0,0,44100,1);
  osd_open=1;key_event(1,9'h031);osd_open=0;
  key_event(1,9'h031);if(busy)$fatal(1,"OSD key leaked");key_event(0,9'h031);
  next_jump();
  position=36'(target_expected+100);key_event(1,9'h04d);wait(restart);@(negedge clk);
  if(target_sample!=0||start_sample!=0||start_offset!=dut.first_audio)$fatal(1,"previous track did not return to first track");
  finish_jump();key_event(0,9'h04d);
  position=total_samples-1;key_event(1,9'h031);repeat(1500)@(negedge clk);
  if(busy||restart)$fatal(1,"last track should not wrap");key_event(0,9'h031);
  end else begin
   check_track(0,0,total_samples,1);
   if(available||!seek_available)$fatal(1,"optional cue blocked normal seek");
   key_event(1,9'h031);settle;if(busy)$fatal(1,"invalid cue navigation");key_event(0,9'h031);
  end
  seek_target_q=360000;seek_request=1;settle;seek_request=0;wait(restart);@(negedge clk);
  if(target_sample!=44100)$fatal(1,"time seek sample conversion");finish_jump();
  seek_target_q=108000000;seek_request=1;settle;seek_request=0;wait(restart);@(negedge clk);
  if(target_sample!=total_samples-1)$fatal(1,"end seek clamp");finish_jump();
  seek_target_q=0;seek_request=1;settle;seek_request=0;wait(restart);@(negedge clk);
  if(target_sample!=0||start_sample!=0)$fatal(1,"backward seek zero");finish_jump();
  position=0;key_event(1,9'h031);new_file=1;settle;new_file=0;settle;
  if(available||busy||resume_frame||target_sample!=0||start_offset!=0||current_track_valid)$fatal(1,"replacement retained album state");
  $display("PASS embedded CD cues, exact seek-point selection, N/P, OSD/held keys, last-track clamp and replacement");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout nav=%d",dut.nav_state);end
endmodule
