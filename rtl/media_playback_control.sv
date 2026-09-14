// Decoder-domain presentation time and reconstruction seek controller.
// Quarter-90-kHz units represent all supported progressive frame periods exactly.
// Supports retained reconstruction and direct restarts with a movie-wide PTS origin.
module media_playback_control #(parameter ENABLE_MOVIE_ORIGIN=0)(
 input wire clk,reset,paused,seek_active,
 input wire [34:0] seek_target_q,
 input wire [3:0] frame_rate_code,
 input wire [2:0] swap_reset_count,
 input wire first_picture_complete,swap_window,drained,fatal,
 input wire display_pts_valid,
 input wire [32:0] display_pts,
 output reg [34:0] elapsed_q=0,
 output reg seek_done=0,
 output wire scheduler_window,
 output wire fast_seek,
 output reg rebase=0,
 output wire [32:0] seek_elapsed_90k,
 input wire movie_origin_valid,
 input wire [32:0] movie_origin
);
reg [2:0] swap_q=0;
reg first_picture=0,origin_valid=0;
reg [32:0] origin_pts=0;
reg [3:0] fast_phase=0;
reg reached=0,landed=0;
reg seek_q=0;
reg [32:0] landing_time=0;
wire presented=swap_reset_count==4 && swap_q!=4;
wire [14:0] period_q=frame_rate_code==1?15'd15015:
 frame_rate_code==2?15'd15000:frame_rate_code==3?15'd14400:
 frame_rate_code==4?15'd12012:15'd12000;
wire [32:0] relative_pts=display_pts-
 ((ENABLE_MOVIE_ORIGIN && movie_origin_valid) ? movie_origin : origin_pts);
wire at_target=first_picture && elapsed_q>=seek_target_q;
assign fast_seek=seek_active&&!seek_done&&!reached;
assign scheduler_window=!reset && (seek_active ?
 (fast_seek&&!at_target&&fast_phase==0) : (!paused&&swap_window));
assign seek_elapsed_90k=(seek_active&&!seek_q)?seek_target_q[34:2]:
 (landed?landing_time:(reached?elapsed_q[34:2]:seek_target_q[34:2]));
always @(posedge clk) begin
 rebase<=0;
 swap_q<=swap_reset_count;
 fast_phase<=fast_phase+1'b1;
 seek_q<=seek_active;
 if(reset) begin
  elapsed_q<=0;seek_done<=0;reached<=0;first_picture<=0;landed<=0;landing_time<=0;
  origin_valid<=0;origin_pts<=0;swap_q<=0;fast_phase<=0;seek_q<=0;
 end else begin
  if(first_picture_complete) first_picture<=1;
  if(display_pts_valid&&!origin_valid) begin origin_valid<=1;origin_pts<=display_pts;end
  if(presented) begin
   if(display_pts_valid&&origin_valid) elapsed_q<={relative_pts,2'b00};
   else elapsed_q<=elapsed_q+{20'd0,period_q};
  end
  if(!seek_active) begin seek_done<=0;reached<=0;end
  else begin
   // A retained-session seek must not reuse the previous landing timestamp.
   if(!seek_q) begin landed<=0;reached<=0;seek_done<=0;end
   if(at_target||drained||fatal) reached<=1;
   // Give a final bank commit time to settle, then release only in real vblank.
   if(reached&&swap_reset_count==0&&swap_window&&!seek_done) begin
    seek_done<=1;rebase<=1;landed<=1;landing_time<=elapsed_q[34:2];
   end
  end
 end
end
endmodule
