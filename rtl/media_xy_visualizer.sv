// Stereo XY trace with sixteen phosphor levels in on-chip RAM. Audio is an
// observation-only tap; line drawing and fading never backpressure playback.
module media_xy_visualizer(
 input wire clk,active,sample_toggle,
 input wire signed [15:0] sample_left,sample_right,
 input wire [23:0] rgb,input wire hs,vs,de,layout_de,
 output reg [23:0] rgb_out=0,output reg hs_out=0,vs_out=0,de_out=0
);
 reg [11:0] x=0,y=0,width=0,height=0;
 reg de_d=0,vs_d=0;
 wire frame_tick=vs&&!vs_d;
 wire [11:0] side=width<height?width:height;
 wire [11:0] left_edge=(width-side)>>1,top_edge=(height-side)>>1;
 wire in_square=layout_de&&x>=left_edge&&x<left_edge+side&&y>=top_edge&&y<top_edge+side;
 reg [12:0] phase_x=0,phase_y=0;
 reg [6:0] pixel_x=0,pixel_y=0;
 wire [12:0] next_x=phase_x+13'd128,next_y=phase_y+13'd128;
 always @(posedge clk)begin
  de_d<=layout_de;vs_d<=vs;
  if(layout_de)x<=x+1'b1;else x<=0;
  if(layout_de&&x>=left_edge&&x<left_edge+side)begin
   if(next_x>={1'b0,side})begin phase_x<=next_x-{1'b0,side};pixel_x<=pixel_x+1'b1;end
   else phase_x<=next_x;
  end else begin phase_x<=0;pixel_x<=0;end
  if(de_d&&!layout_de)begin
   width<=x;y<=y+1'b1;
   if(y>=top_edge&&y<top_edge+side)begin
    if(next_y>={1'b0,side})begin phase_y<=next_y-{1'b0,side};pixel_y<=pixel_y+1'b1;end
    else phase_y<=next_y;
   end
  end
  if(frame_tick)begin height<=y;y<=0;phase_y<=0;pixel_y<=0;end
 end

 (* ramstyle="M10K, no_rw_check" *) reg [3:0] phosphor[0:16383];
 reg clear=1;reg [13:0] clear_address=0,fade_address=0;
 reg fade_busy=0;reg [1:0] fade_state=0;
 reg seen_toggle=0,pending=0,have_previous=0,drawing=0;
 reg [6:0] pending_x=64,pending_y=64,previous_x=64,previous_y=64;
 reg [6:0] draw_x=64,draw_y=64,end_x=64,end_y=64,dx=0,dy=0;
 reg step_x=0,step_y=0;
 reg signed [8:0] error=0;
 wire signed [9:0] twice_error=$signed({error[8],error})<<<1;
 wire move_x=twice_error>-$signed({3'd0,dy});
 wire move_y=twice_error<$signed({3'd0,dx});
 wire [13:0] ram_address=clear?clear_address:drawing?{draw_y,draw_x}:fade_address;
 reg [3:0] fade_q=0,display_q=0;
 always @(posedge clk)begin
  fade_q<=phosphor[ram_address];
  if(clear)phosphor[ram_address]<=0;
  else if(drawing)phosphor[ram_address]<=15;
  // Two intensity steps per frame: eight sweeps to black, saturating at zero.
  else if(fade_busy&&fade_state==2)phosphor[ram_address]<=(fade_q<=4'd2) ? 4'd0 : fade_q-4'd2;
  display_q<=phosphor[{pixel_y,pixel_x}];
 end
 always @(posedge clk)begin
  seen_toggle<=sample_toggle;
  if(!active)begin
   clear<=1;clear_address<=0;pending<=0;drawing<=0;have_previous<=0;fade_busy<=0;fade_state<=0;
  end else if(clear)begin
   clear_address<=clear_address+1'b1;
   if(&clear_address)clear<=0;
  end else begin
   // The latest sample wins if display work momentarily falls behind.
   if(sample_toggle!=seen_toggle)begin
    pending_x<=sample_left[15:9]^7'h40;pending_y<=~(sample_right[15:9]^7'h40);pending<=1;
   end
   if(frame_tick&&!fade_busy)begin fade_address<=0;fade_busy<=1;fade_state<=0;end
   if(drawing)begin
    fade_state<=0;
    if(draw_x==end_x&&draw_y==end_y)drawing<=0;
    else begin
     if(move_x)draw_x<=step_x?draw_x+1'b1:draw_x-1'b1;
     if(move_y)draw_y<=step_y?draw_y+1'b1:draw_y-1'b1;
     error<=error-(move_x?$signed({2'd0,dy}):9'sd0)+(move_y?$signed({2'd0,dx}):9'sd0);
    end
   end else if(pending)begin
    pending<=sample_toggle!=seen_toggle;drawing<=1;fade_state<=0;
    draw_x<=have_previous?previous_x:pending_x;draw_y<=have_previous?previous_y:pending_y;
    end_x<=pending_x;end_y<=pending_y;
    dx<=!have_previous?7'd0:(pending_x>=previous_x?pending_x-previous_x:previous_x-pending_x);
    dy<=!have_previous?7'd0:(pending_y>=previous_y?pending_y-previous_y:previous_y-pending_y);
    error<=!have_previous?9'sd0:
     $signed({2'd0,(pending_x>=previous_x?pending_x-previous_x:previous_x-pending_x)})-
     $signed({2'd0,(pending_y>=previous_y?pending_y-previous_y:previous_y-pending_y)});
    step_x<=pending_x>=previous_x;step_y<=pending_y>=previous_y;
    previous_x<=pending_x;previous_y<=pending_y;have_previous<=1;
   end else if(fade_busy)begin
    if(fade_state==2)begin fade_state<=0;fade_address<=fade_address+1'b1;if(&fade_address)fade_busy<=0;end
    else fade_state<=fade_state+1'b1;
   end
  end
 end

 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [26:0] video[0:7];
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [7:0] enable_pipe=0;
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [3:0] intensity[0:6];
 reg square_q=0;
 always @(posedge clk)begin
  video[0]<={hs,vs,de,rgb};for(integer k=1;k<8;k=k+1)video[k]<=video[k-1];
  enable_pipe<={enable_pipe[6:0],active&&layout_de&&side>=128};
  square_q<=in_square&&!clear;
  intensity[0]<=square_q?display_q:4'd0;
  for(integer k=1;k<7;k=k+1)intensity[k]<=intensity[k-1];
  {hs_out,vs_out,de_out}<=video[7][26:24];
  rgb_out<=enable_pipe[7]?{2'b00,intensity[6],2'b00,intensity[6],intensity[6],2'b00,intensity[6],2'b00}:video[7][23:0];
 end
endmodule
