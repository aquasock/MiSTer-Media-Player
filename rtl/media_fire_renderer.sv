// Nine-cycle post-scaler renderer, matching O-scope. Procedural rising flames
// follow FFT band energy; no framebuffer, external DDR or audio backpressure.
module media_fire_renderer(
 input wire clk,active,input wire [255:0] levels,
 input wire [23:0] rgb,input wire hs,vs,de,layout_de,
 output reg [23:0] rgb_out=0,output reg hs_out=0,vs_out=0,de_out=0
);
 reg [11:0] x=0,y=0,width=0,height=0;
 reg de_d=0,vs_d=0;
 reg [7:0] animation=0;
 reg [255:0] snapshot=0;
 reg [5:0] copy=32;
 (* ramstyle="M10K, no_rw_check" *) reg [15:0] bands[0:31];
 reg [15:0] band_q=0;
 reg frame_active=0;
 reg [11:0] divided_width=0;
 reg [15:0] quotient=0,position_x=0;
 reg [12:0] remainder=0;
 reg [4:0] divide_count=0;
 reg [7:0] step_x=1;
 wire [13:0] trial={remainder,quotient[15]};
 always @(posedge clk)begin
  de_d<=layout_de;vs_d<=vs;
  if(layout_de)x<=x+1'b1;else x<=0;
  if(de_d&&!layout_de)begin width<=x;y<=y+1'b1;end
  if(vs&&!vs_d)begin
   height<=y;y<=0;snapshot<=levels;copy<=0;animation<=animation+1'b1;frame_active<=active;
  end else if(copy<32)begin
   bands[copy[4:0]]<=copy==31?{snapshot[7:0],snapshot[7:0]}:snapshot[15:0];
   snapshot<=snapshot>>8;copy<=copy+1'b1;
  end
  band_q<=bands[position_x[15:11]];
  if(width>=256&&width!=divided_width)begin divided_width<=width;quotient<=16'hffff;remainder<=0;divide_count<=16;end
  else if(divide_count!=0)begin
   if(trial>={2'b0,divided_width})begin remainder<=13'(trial-{2'b0,divided_width});quotient<={quotient[14:0],1'b1};end
   else begin remainder<=trial[12:0];quotient<={quotient[14:0],1'b0};end
   divide_count<=divide_count-1'b1;
   if(divide_count==1)step_x<={quotient[6:0],trial>={2'b0,divided_width}};
  end
  if(layout_de)position_x<=position_x+{8'd0,step_x};else position_x<=0;
 end
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [26:0] video[0:7];
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [7:0] enable_pipe=0;
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [11:0] yy[0:4];
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [7:0] xx[0:4];
 reg [7:0] fraction0=0,fraction1=0,base1=0,base2=0;
 reg signed [8:0] difference=0;
 reg signed [17:0] blend=0;
 reg [7:0] energy=0;
 reg [11:0] height_product=0;
 reg [11:0] flame_height=0,distance=0;
 reg [7:0] turbulence=0;
 reg below_base=0,lit=0;
 reg [7:0] heat=0;
 wire [11:0] depth=flame_height-distance;
 wire [11:0] shade=height>=700?depth>>1:depth;
 wire [9:0] green=heat>48?({2'd0,heat}-10'd48)*10'd3:10'd0;
 wire [7:0] blue=heat>128?(heat-8'd128)<<1:8'd0;
 reg [23:0] color=0;
 wire [11:0] base_y=height-(height>>3);
 wire [11:0] max_height=(height>>1)+(height>>2);
 wire [7:0] flow=xx[4]+animation+{yy[4][4:0],3'b0};
 wire [7:0] curl=(flow[7]?~flow:flow)^{3'd0,xx[4][4:0]};
 always @(posedge clk)begin
  video[0]<={hs,vs,de,rgb};yy[0]<=y;xx[0]<=position_x[15:8];
  for(integer k=1;k<8;k=k+1)video[k]<=video[k-1];
  for(integer k=1;k<5;k=k+1)begin yy[k]<=yy[k-1];xx[k]<=xx[k-1];end
  enable_pipe<={enable_pipe[6:0],frame_active&&active&&layout_de&&copy==32&&width>=256&&height>=240};
  fraction0<=position_x[10:3];
  difference<=$signed({1'b0,band_q[15:8]})-$signed({1'b0,band_q[7:0]});fraction1<=fraction0;base1<=band_q[7:0];
  blend<=difference*$signed({1'b0,fraction1});base2<=base1;
  energy<=8'($signed({1'b0,base2})+(blend>>>8));
  height_product<=12'(20'(energy*max_height)>>8);
  flame_height<=height_product;distance<=base_y-yy[4];below_base<=yy[4]>base_y;
  turbulence<=curl>>2;
  lit<=!below_base&&flame_height>distance+{4'd0,turbulence};
  heat<=shade>=256?8'd255:shade[7:0];
  color<=!lit?24'h030810:{(heat>=64?8'hff:{heat[5:0],2'b0}),(green>=256?8'hff:green[7:0]),blue[7:0]};
  {hs_out,vs_out,de_out}<=video[7][26:24];rgb_out<=enable_pipe[7]?color:video[7][23:0];
 end
endmodule
