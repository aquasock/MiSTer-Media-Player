`timescale 1ns/1ps
module test_media_format_handoff;
reg clk_sys=0,clk_mpeg2=0;
always #10 clk_sys=~clk_sys;
always #8 clk_mpeg2=~clk_mpeg2;
reg reset_mpeg2_base=1,restart=0,media_music_hint_mpeg=0;
reg media_music_mode=0,media_music_idle=1,DDRAM_BUSY=0,DDRAM_DOUT_READY=0;
reg reader_rd=0;
wire media_decoder_reset,media_quiesce,media_movie_ddr_idle;
wire media_ddr_idle=media_music_mode?media_music_idle:media_movie_ddr_idle;
wire movie_rd,movie_we,reader_q,reader_start;
`include "handoff_mode.svh"
media_session_control session(.clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),
 .reset(reset_mpeg2_base),.restart(restart),.reader_idle(1'b1),.ddr_idle(media_ddr_idle),
 .reader_start(reader_start),.quiesce(media_quiesce),.decoder_reset(media_decoder_reset),.start_ready(1'b1));
mpeg2_h262_ddram_arbiter #(.ENABLE_QUIESCE(1)) movie(
 .clk(clk_mpeg2),.reset(reset_mpeg2_base||media_decoder_reset),
 `include "handoff_ports.svh"
 .idle(media_movie_ddr_idle),.release_display_bank(1'b0),
 .writer_burstcnt(8'd1),.writer_addr(29'd0),.writer_rd(1'b0),.writer_din(64'd0),.writer_be(8'hff),.writer_we(1'b0),
 .reader_burstcnt(8'd1),.reader_addr(29'h06030000),.reader_rd(reader_rd),
 .prediction_burstcnt(8'd1),.prediction_addr(29'd0),.prediction_rd(1'b0),
 .stream_addr(29'd0),.stream_din(64'd0),.stream_rd(1'b0),.stream_we(1'b0),
 .ddram_rd(movie_rd),.ddram_we(movie_we),.reader_dout_ready(reader_q));
task tick;begin @(negedge clk_mpeg2);#1;end endtask
task request_mode(input reg target);begin
 @(negedge clk_sys);media_music_hint_mpeg=target;restart=1;
 @(negedge clk_sys);restart=0;
end endtask
task running(input reg target);integer n;begin
 n=0;
 while((media_quiesce||media_music_mode!=target)&&n<300)begin tick();n=n+1;end
 if(n==300)$fatal(1,"handoff stalled target=%b mode=%b movie_idle=%b",target,media_music_mode,media_movie_ddr_idle);
 repeat(25)tick();
end endtask
always @(negedge clk_mpeg2)if(!reset_mpeg2_base&&media_music_mode&&(movie_rd||movie_we))$fatal(1,"inactive movie issued a request");
integer cycle;
initial begin
 repeat(5)tick();reset_mpeg2_base=0;running(0);
 for(cycle=0;cycle<4;cycle=cycle+1)begin
  // Hold an accepted movie response across cancellation; ownership must stay.
  reader_rd=1;tick();reader_rd=0;request_mode(1);
  repeat(20)tick();
  if(media_music_mode||media_decoder_reset)$fatal(1,"movie response was not drained before reset/switch");
  DDRAM_DOUT_READY=1;#1;if(!reader_q)$fatal(1,"old movie response lost");
  tick();DDRAM_DOUT_READY=0;running(1);
  // Stale movie requests must remain blocked even with physical DDR ready.
  reader_rd=1;repeat(5)tick();reader_rd=0;
  media_music_idle=0;DDRAM_BUSY=1;request_mode(0);
  repeat(20)tick();
  if(!media_music_mode||media_decoder_reset)$fatal(1,"active music memory work discarded");
  media_music_idle=1;repeat(5)tick();
  if(!media_music_mode)$fatal(1,"changed owner while physical DDR busy");
  DDRAM_BUSY=0;running(0);
  reader_rd=1;#1;if(!movie_rd)$fatal(1,"movie did not resume memory requests");
  tick();reader_rd=0;DDRAM_DOUT_READY=1;tick();DDRAM_DOUT_READY=0;
 end
 $display("PASS format handoff: four round trips, drained movie responses, music cancellation, physical busy and inactive grant exclusion");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
