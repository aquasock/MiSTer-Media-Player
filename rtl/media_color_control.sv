// Color mode and displayed-picture context cross independently, then commit
// together at the first pixel of the next raster. No mid-picture color seam.
module media_color_control(
 input wire sys_clk, decoder_clk, video_clk,
 input wire video_reset,
 input wire [1:0] mode,
 input wire display_bt709,
 input wire frame_start,
 output reg matrix_bt709=0
);
wire [1:0] mode_video;
wire display_video;
video_config_cdc #(.WIDTH(2)) color_mode_config(
 .src_clk(sys_clk),.dst_clk(video_clk),.src_data(mode),.dst_data(mode_video));
video_config_cdc #(.WIDTH(1)) display_color_config(
 .src_clk(decoder_clk),.dst_clk(video_clk),
 .src_data(display_bt709),.dst_data(display_video));
always @(posedge video_clk) begin
 if(video_reset) matrix_bt709<=0;
 else if(frame_start) begin
  case(mode_video)
   2'd1: matrix_bt709<=0;
   2'd2: matrix_bt709<=1;
   default: matrix_bt709<=display_video;
  endcase
 end
end
endmodule
