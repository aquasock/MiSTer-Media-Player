`timescale 1ns/1ps
module test_direct_seek_restart;
reg sys=0,mpeg=0;always #25 sys=~sys;always #8.333 mpeg=~mpeg;
reg reset=1,new_file=0;reg [10:0] key=0;
wire paused,seeking,keyboard_request,done,done_sys;
wire [34:0] target,elapsed_sys,elapsed;
wire busy,probing,restart,start,cancel,flush,decoder_reset,quiesce;
wire [40:0] offset,video_start;
wire [7:0] tag,echo;
wire [90:0] config_mpeg;
wire probe_mpeg=config_mpeg[82];
wire [40:0] offset_mpeg=config_mpeg[81:41];
wire [36:0] command;
wire [123:0] response;
reg reader_idle=1,ddr_idle=1;
media_keyboard_control #(.RESTART_BOTH_DIRECTIONS(1)) keyboard(
 .clk(sys),.reset(reset),.new_file(new_file),.enabled(1'b1),.osd_open(1'b0),.key(key),
 .duration_valid(1'b1),.duration_q(35'd288000000),.elapsed_q(elapsed_sys),.seek_done(done_sys&&!busy),.restart_complete(start&&!probing),
 .paused(paused),.seek_active(seeking),.seek_target_q(target),.restart(keyboard_request));
media_seek_search search(
 .clk(sys),.reset(reset),.new_file(new_file),.request(keyboard_request),
 .program_stream(1'b1),.origin_valid(1'b1),.origin(33'd90000),.target_q(target),
 .file_size(64'd2000000),.reader_start(start),.reader_position({23'd0,offset}),
 .response_tag(response[123:116]),.point_found(response[115]),.probe_end(1'b0),
 .point_pts(response[114:82]),.point_pack(response[81:41]),.point_sequence(response[40:0]),
 .busy(busy),.probing(probing),.restart(restart),.tag(tag),.start_offset(offset),.video_start(video_start));
video_config_cdc #(.WIDTH(91)) cfg(sys,mpeg,{tag,probing,offset,video_start},config_mpeg);
video_config_cdc #(.WIDTH(8)) ack(mpeg,sys,config_mpeg[90:83],echo);
video_config_cdc #(.WIDTH(37)) cmd(sys,mpeg,{paused,seeking,target},command);
video_config_cdc #(.WIDTH(36)) pos(mpeg,sys,{done,elapsed},{done_sys,elapsed_sys});
reg found=0;reg [7:0] probe_delay=0;
wire [40:0] fake_pack=((offset_mpeg/1000)+1)*1000;
wire [32:0] fake_pts=90000+(fake_pack/1000)*90000;
video_config_cdc #(.WIDTH(124)) result_cdc(mpeg,sys,
 {config_mpeg[90:83],found,fake_pts,fake_pack,(fake_pack+41'd8)},response);
media_session_control #(.ENABLE_START_READY(1)) session_control(
 .clk_sys(sys),.clk_mpeg2(mpeg),.reset(reset),.restart(restart||new_file),
 .reader_idle(reader_idle),.ddr_idle(ddr_idle),.reader_cancel(cancel),.fifo_reset(flush),
 .reader_start(start),.quiesce(quiesce),.decoder_reset(decoder_reset),.generation(),.start_ready(tag==echo));
reg [2:0] swaps=0;reg [9:0] raster=0;
reg [32:0] display_pts=90000;
wire scheduler,fast,rebase;wire [32:0] seek_elapsed;
media_playback_control #(.ENABLE_MOVIE_ORIGIN(1)) playback(
 .clk(mpeg),.reset(decoder_reset),.paused(command[36]),.seek_active(command[35]),
 .seek_target_q(command[34:0]),.frame_rate_code(4'd3),.swap_reset_count(swaps),
 .first_picture_complete(!probe_mpeg&&!decoder_reset),.swap_window(raster==0),
 .drained(1'b0),.fatal(1'b0),.display_pts_valid(!probe_mpeg),.display_pts(display_pts),
 .elapsed_q(elapsed),.seek_done(done),.scheduler_window(scheduler),.fast_seek(fast),
 .rebase(rebase),.seek_elapsed_90k(seek_elapsed),.movie_origin_valid(1'b1),.movie_origin(33'd90000));
always @(posedge mpeg) begin
 raster<=raster+1'b1;
 if(decoder_reset) begin
  swaps<=0;display_pts<=90000+(offset_mpeg/1000)*90000;found<=0;probe_delay<=0;
 end else if(probe_mpeg) begin
  if(probe_delay==100) found<=1;else probe_delay<=probe_delay+1'b1;
 end else if(scheduler) begin swaps<=4;display_pts<=display_pts+3600;end
 else if(swaps!=0) swaps<=swaps-1'b1;
end
integer starts=0,final_starts=0;
always @(posedge sys) if(start&&!reset)begin
 starts<=starts+1;
 if(!probing)final_starts<=final_starts+1;
 if(!reader_idle||!ddr_idle||decoder_reset||flush||echo!=tag || config_mpeg!={tag,probing,offset,video_start})
  $fatal(1,"restart released before retirement/configuration acknowledgement");
end
task key_event(input [8:0] code,input down);
 begin @(negedge sys);key={!key[10],down,code};repeat(3)@(negedge sys);end
endtask
task jump(input [8:0] code);
 reg [34:0] expected;
 integer old_final;
 begin
  expected=code==9'h174 ? elapsed_sys+3600000 : (elapsed_sys<3600000?0:elapsed_sys-3600000);
  if(code==9'h003)expected=35'd144000000;
  if(code==9'h005)expected=0;
  if(code==9'h00a)expected=35'd252000000;
  old_final=final_starts;reader_idle=0;ddr_idle=0;
  key_event(code,1);key_event(code,0);
  wait(quiesce);repeat(40)@(negedge sys);
  if(decoder_reset || !flush || !seeking)$fatal(1,"old DDR ownership reset early");
  ddr_idle=1;wait(decoder_reset);repeat(40)@(negedge sys);
  if(!flush || !seeking)$fatal(1,"host retirement or command lost during probes");
  reader_idle=1;
  wait(!busy);wait(!seeking);wait(!done_sys);repeat(20)@(negedge sys);
  if(final_starts!=old_final+1 || !paused || elapsed_sys<expected || elapsed_sys-expected>14400)
   $fatal(1,"target/pause/final restart lost got=%0d expected=%0d",elapsed_sys,expected);
 end
endtask
initial begin
 repeat(5)@(negedge sys);reset=0;wait(final_starts==1);
 key_event(9'h029,1);key_event(9'h029,0);repeat(30)@(negedge sys);
 jump(9'h174);jump(9'h174);jump(9'h16b);jump(9'h174);jump(9'h16b);
 jump(9'h003);jump(9'h005);jump(9'h00a);
 @(negedge sys);new_file=1;@(negedge sys);new_file=0;
 wait(!flush);wait(start);repeat(20)@(negedge sys);
 if(paused || seeking || busy || offset!=0)$fatal(1,"new file retained seek state");
 $display("PASS: asynchronous direct forward/backward keyboard seeks, repeated probe generations, configuration acknowledgement, DDR/host retirement, global time and paused destinations");$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
