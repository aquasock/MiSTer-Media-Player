// Nine-cycle post-scaler renderer, matching O-scope. Independent FFT bands
// drive hard-edged blocks: no interpolation, turbulence or color blending.
module media_fire_renderer(
 input wire clk,active,input wire [255:0] levels,
 input wire [23:0] rgb,input wire hs,vs,de,layout_de,
 output reg [23:0] rgb_out=0,output reg hs_out=0,vs_out=0,de_out=0
);
 reg [11:0] x=0,y=0,width=0,height=0;
 reg de_d=0,vs_d=0,frame_active=0;
 reg [255:0] snapshot=0;
 reg [5:0] copy=32;
 (* ramstyle="M10K, no_rw_check" *) reg [4:0] bands[0:31];
 reg [4:0] band_q=0,column=0;
 // A remainder accumulator divides the viewport into exactly 32 columns.
 reg [12:0] phase_x=0;
 wire [12:0] next_x=phase_x+13'd32;
 wire [11:0] base_y=height-(height>>3);
 wire [11:0] max_height=(height>>1)+(height>>2);
 wire [11:0] row_pitch=max_height>>5;
 wire [11:0] grid_top=base_y-(row_pitch<<5);
 wire [11:0] row_gap=row_pitch>>2;
 reg [11:0] row_edge=0;
 reg [5:0] row_needed=32;
 always @(posedge clk)begin
  de_d<=layout_de;vs_d<=vs;
  if(layout_de)begin
   x<=x+1'b1;
   if(next_x>={1'b0,width})begin phase_x<=next_x-{1'b0,width};column<=column+1'b1;end
   else phase_x<=next_x;
  end else begin x<=0;phase_x<=0;column<=0;end
  if(de_d&&!layout_de)begin
   width<=x;y<=y+1'b1;
   if(row_needed!=0&&y+12'd1>=row_edge)begin
    row_edge<=row_edge+row_pitch;row_needed<=row_needed-1'b1;
   end
  end
  if(vs&&!vs_d)begin
   height<=y;y<=0;snapshot<=levels;copy<=0;frame_active<=active;
   row_edge<=grid_top+row_pitch;row_needed<=32;
  end else if(copy<32)begin
   bands[copy[4:0]]<=snapshot[7:3];
   snapshot<=snapshot>>8;copy<=copy+1'b1;
  end
  band_q<=bands[column];
 end
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [26:0] video[0:7];
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [7:0] enable_pipe=0;
 // Only lit/color selection bits traverse the pipe, not repeated RGB values.
 (* altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [6:0] lit_pipe=0,orange_pipe=0;
 reg cell_visible=0;
 reg [5:0] needed_q=0;
 always @(posedge clk)begin
  video[0]<={hs,vs,de,rgb};
  for(integer k=1;k<8;k=k+1)video[k]<=video[k-1];
  enable_pipe<={enable_pipe[6:0],frame_active&&active&&layout_de&&copy==32&&width>=256&&height>=240};
  needed_q<=row_needed;
  cell_visible<=y>=grid_top&&row_needed!=0&&y<row_edge-row_gap&&phase_x>={1'b0,width>>3};
  lit_pipe<={lit_pipe[5:0],cell_visible&&{1'b0,band_q}>=needed_q};
  orange_pipe<={orange_pipe[5:0],needed_q=={1'b0,band_q}};
  {hs_out,vs_out,de_out}<=video[7][26:24];
  rgb_out<=enable_pipe[7]?(lit_pipe[6]?(orange_pipe[6]?24'hff8800:24'hffdd00):24'h030810):video[7][23:0];
 end
endmodule
