`timescale 1ns/1ps
// Functional reader failure must still retire seek control after the statistics
// mailbox is removed. No final picture/EOF is supplied to help the seek finish.
module test_reader_error_seek;
reg sys=0,mpeg=0;always #25 sys=~sys;always #8.333 mpeg=~mpeg;
reg [3:0] reader_error=0;
wire fatal,seek_done,fast_seek;
reg reset=1,seeking=0,swap_window=0;
video_config_cdc #(.WIDTH(1)) reader_error_config(
 .src_clk(sys),.dst_clk(mpeg),.src_data(|reader_error),.dst_data(fatal));
media_playback_control control(.clk(mpeg),.reset(reset),.paused(1'b0),
 .seek_active(seeking),.seek_target_q(35'd108000000),.frame_rate_code(4'd1),
 .swap_reset_count(3'd0),.first_picture_complete(1'b0),.swap_window(swap_window),
 .drained(1'b0),.fatal(fatal),.display_pts_valid(1'b0),.display_pts(33'd0),
 .seek_done(seek_done),.fast_seek(fast_seek),.movie_origin_valid(1'b0),.movie_origin(33'd0));
initial begin
 for(integer code=1;code<=3;code=code+1)begin
  reset=1;seeking=0;swap_window=0;reader_error=0;
  // Normal file replacement resets the error before decoder reset releases.
  repeat(32)@(negedge sys);reset=0;seeking=1;
  repeat(32)@(negedge mpeg);
  if(fatal || seek_done || !fast_seek)$fatal(1,"new session retained an old error");
  @(negedge sys);reader_error=code;
  repeat(32)@(negedge mpeg);
  if(!fatal || fast_seek || seek_done)$fatal(1,"reader error did not stop seeking safely");
  swap_window=1;repeat(4)@(negedge mpeg);
  if(!seek_done)$fatal(1,"reader failure left controls busy");
  $display("READER ERROR SEEK PASS code=%0d",code);
 end
 $finish;
end
endmodule
