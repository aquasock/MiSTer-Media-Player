// EOF is a transport event, not a duration estimate or temporary input gap.
// Completion is tagged with the reset generation and remains held until reset.
module media_eof_control(
 input wire clk_sys,clk_mpeg2,reset_sys,reset_decoder,
 input wire new_file,loaded,sys_paused,sys_seeking,preflight,
 input wire [31:0] generation,
 input wire input_eof,video_drained,audio_finished,paused,seeking,fatal,tick_90k,
 input wire [3:0] frame_rate_code,
 output reg close_file=0
);
wire [31:0] generation_mpeg;
wire [32:0] response;
video_config_cdc #(.WIDTH(32)) eof_generation_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(generation),.dst_data(generation_mpeg));
reg [31:0] active_generation=0;
reg done=0;
reg [11:0] quiet_ticks=0;
wire [11:0] frame_ticks=frame_rate_code==1?12'd3754:frame_rate_code==2?12'd3750:
 frame_rate_code==3?12'd3600:frame_rate_code==4?12'd3003:12'd3000;
wire quiet=input_eof && video_drained && audio_finished && !paused && !seeking && !fatal;
always @(posedge clk_mpeg2)begin
 if(reset_decoder)begin done<=0;quiet_ticks<=0;active_generation<=generation_mpeg;end
 else if(!done)begin
  if(!quiet)quiet_ticks<=0;
  else if(tick_90k)begin
   if(quiet_ticks==frame_ticks)done<=1;
   else quiet_ticks<=quiet_ticks+1'b1;
  end
 end
end
video_config_cdc #(.WIDTH(33)) eof_complete_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data({done,active_generation}),.dst_data(response));
reg closed=0;
always @(posedge clk_sys)begin
 close_file<=0;
 if(reset_sys || new_file)closed<=0;
 else if(loaded && !closed && !sys_paused && !sys_seeking && !preflight && response[32] && response[31:0]==generation)begin
  close_file<=1;closed<=1;
 end
end
endmodule
