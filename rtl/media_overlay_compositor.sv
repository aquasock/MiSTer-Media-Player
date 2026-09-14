// Generic bounded glyph/rectangle scene. Single HDMI clock owns both pages;
// coherent control snapshots arrive upstream through video_config_cdc.
// Producer writes only inactive storage, then commits. Publication/ack occur
// at a frame boundary, so active glyph memory is never changed mid-frame.
module media_overlay_compositor(
 input wire clk,
 input wire [23:0] rgb,input wire hs,vs,de,
 input wire [15:0] current_epoch,
 input wire text_we,input wire [8:0] text_addr,input wire [7:0] text_data,
 input wire object_we,input wire [3:0] object_addr,input wire [55:0] object_data,
 input wire commit,input wire [15:0] commit_epoch,input wire [1:0] commit_groups,
 input wire [3:0] commit_scale,
 output reg pending=0,output reg acknowledged=0,
 output reg [11:0] width=0,height=0,
 output reg [23:0] rgb_out=0,output reg hs_out=0,vs_out=0,de_out=0
);
// Text: valid[55], group[54], color[53:52], length[29:24], y[23:12], x[11:0].
// Rect: valid[55], group[54], color[53:52], hatch[51], y1[47:36],
// x1[35:24], y0[23:12], x0[11:0]. Bounds are half-open.
reg [55:0] staging[0:11],active[0:11];
reg [15:0] staged_epoch=0,active_epoch=0;
reg [1:0] staged_groups=0,groups=0;
reg [3:0] staged_scale=4,scale=4;
reg page=0;
(* ramstyle="M10K" *) reg [7:0] text_mem[0:1023];
(* ramstyle="M10K" *) reg [4:0] font[0:2047];
initial $readmemh("rtl/media_overlay_font.hex",font);
integer init_i;
initial begin
 for(init_i=0;init_i<12;init_i=init_i+1) begin staging[init_i]=0;active[init_i]=0;end
end
reg [11:0] x=0,y=0;
reg de_d=0,vs_d=0;
wire frame=vs&&!vs_d;
always @(posedge clk) begin
 de_d<=de;vs_d<=vs;
 if(de) x<=x+1'b1;else x<=0;
 if(de_d&&!de) begin width<=x;y<=y+1'b1;end
 if(frame) begin height<=y;y<=0;end
 acknowledged<=0;
 if(!pending) begin
  if(text_we) text_mem[{~page,text_addr}]<=text_data;
  if(object_we && object_addr<12) staging[object_addr]<=object_data;
  if(commit) begin
   staged_epoch<=commit_epoch;staged_groups<=commit_groups;
   staged_scale<=commit_scale;pending<=1;
  end
 end
 if(pending && frame) begin
  if(staged_epoch==current_epoch) begin
   for(integer j=0;j<12;j=j+1) active[j]<=staging[j];
   active_epoch<=staged_epoch;groups<=staged_groups;scale<=staged_scale;page<=~page;
  end
  pending<=0;acknowledged<=1;
 end
end
// Bounding tests run once per object. Only the winning text object addresses
// the shared character/font ports. Scale is quarter-pixel units: 4/6/9 for
// 480/720/1080-line output, preserving uniform glyph scaling across aspect.
reg [1:0] rect_color,text_color;
reg [2:0] slot;
reg [11:0] dx,dy;
reg hit;
integer i;
always @* begin
 rect_color=0;text_color=0;slot=0;dx=0;dy=0;hit=0;
 if(de && active_epoch==current_epoch) begin
  for(i=8;i<12;i=i+1)
   if(active[i][55] && groups[active[i][54]] &&
    x>=active[i][11:0] && x<active[i][35:24] &&
    y>=active[i][23:12] && y<active[i][47:36])
     rect_color=(active[i][51] && x[3]) ? 2'd1 : active[i][53:52];
  for(i=0;i<8;i=i+1)
   if(active[i][55] && groups[active[i][54]] &&
    x>=active[i][11:0] && x<active[i][47:36] &&
    y>=active[i][23:12] && y<active[i][35:24]) begin
     hit=1;slot=i;dx=x-active[i][11:0];dy=y-active[i][23:12];text_color=active[i][53:52];
   end
 end
end
reg [11:0] dx_q,dy_q;
reg [2:0] slot_q;
reg [3:0] scale_q;
reg hit_q;
reg [1:0] tc_q,rc_q;
reg page_q;
always @(posedge clk) begin
 dx_q<=dx;dy_q<=dy;slot_q<=slot;hit_q<=hit;tc_q<=text_color;rc_q<=rect_color;
 scale_q<=scale;page_q<=page;
end
// Constant divisions, selected after the bounding-test pipeline stage.
wire [11:0] gx=scale_q==9 ? ({dx_q,2'b00}/9) : scale_q==6 ? ({dx_q,1'b0}/3) : dx_q;
wire [11:0] gy=scale_q==9 ? ({dy_q,2'b00}/9) : scale_q==6 ? ({dy_q,1'b0}/3) : dy_q;
wire [5:0] character=gx/6;
wire [2:0] column=gx%6;
reg [7:0] glyph;
reg [2:0] column_2,row_2;
reg hit_2;
reg [1:0] tc_2,rc_2;
always @(posedge clk) begin
 glyph<=text_mem[{page_q,slot_q,character}];
 column_2<=column;row_2<=gy[2:0];hit_2<=hit_q && gy<7 && gx<384;
 tc_2<=tc_q;rc_2<=rc_q;
end
reg [4:0] glyph_row;
reg [2:0] column_3;
reg hit_3;
reg [1:0] tc_3,rc_3;
always @(posedge clk) begin
 glyph_row<=font[{glyph,row_2}];column_3<=column_2;hit_3<=hit_2;
 tc_3<=tc_2;rc_3<=rc_2;
end
reg [26:0] video_pipe[0:2];
reg [1:0] color_4;
reg [26:0] video_4;
always @(posedge clk) begin
 video_pipe[0]<={hs,vs,de,rgb};video_pipe[1]<=video_pipe[0];video_pipe[2]<=video_pipe[1];
 video_4<=video_pipe[2];
 color_4<=hit_3 && column_3<5 && glyph_row[4-column_3] ? tc_3 : rc_3;
end
// Alpha 160/255 dark palette entry; exact divide-by-255 rounded downward.
function [7:0] dark;
 input [7:0] value,background;
 reg [15:0] sum;
 reg [16:0] folded;
 begin sum=value*8'd95+background*8'd160;folded={1'b0,sum}+17'd1+sum[15:8];dark=folded[15:8];end
endfunction
always @(posedge clk) begin
 {hs_out,vs_out,de_out}<=video_4[26:24];
 case(color_4)
  1:rgb_out<={dark(video_4[23:16],8'h18),dark(video_4[15:8],8'h1b),dark(video_4[7:0],8'h20)};
  2:rgb_out<=24'h687d89;
  3:rgb_out<=24'heef2f4;
  default:rgb_out<=video_4[23:0];
 endcase
end
endmodule
