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
(* ramstyle="M10K" *) reg [55:0] staging[0:15];
reg [55:0] active[0:11];
reg [55:0] staging_q;
reg copy_busy=0;
reg [3:0] copy_index=0;
wire [3:0] staging_read=copy_busy?copy_index+1'b1:4'd0;
always @(posedge clk) staging_q<=staging[staging_read];
reg [15:0] staged_epoch=0,active_epoch=0;
reg [1:0] staged_groups=0,groups=0;
reg [3:0] staged_scale=4,scale=4;
reg page=0;
(* ramstyle="M10K" *) reg [7:0] text_mem[0:1023];
(* ramstyle="M10K" *) reg [7:0] font[0:2047];
initial $readmemh("rtl/media_overlay_font.hex",font);
integer init_i;
initial begin
 for(init_i=0;init_i<12;init_i=init_i+1) active[init_i]=0;
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
 if(pending && frame && !copy_busy) begin
  if(staged_epoch==current_epoch) begin copy_busy<=1;copy_index<=0;end
  else begin pending<=0;acknowledged<=1;end
 end
 if(copy_busy) begin
  active[copy_index]<=staging_q;
  copy_index<=copy_index+1'b1;
  if(copy_index==11) begin
   copy_busy<=0;pending<=0;acknowledged<=1;
   if(staged_epoch==current_epoch) begin
    active_epoch<=staged_epoch;groups<=staged_groups;scale<=staged_scale;page<=~page;
   end else groups<=0;
  end
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
 i=0;rect_color=0;text_color=0;slot=0;dx=0;dy=0;hit=0;
 if(de && !copy_busy && active_epoch==current_epoch) begin
  for(i=8;i<12;i=i+1)
   if(active[i][55] && groups[active[i][54]] &&
    x>=active[i][11:0] && x<active[i][35:24] &&
    y>=active[i][23:12] && y<active[i][47:36])
     rect_color=(active[i][51] && x[3]) ? 2'd1 : active[i][53:52];
  for(i=0;i<8;i=i+1)
   if(active[i][55] && groups[active[i][54]] &&
    x>=active[i][11:0] && x<active[i][47:36] &&
    y>=active[i][23:12] && y<active[i][35:24]) begin
     hit=1;slot=i[2:0];dx=x-active[i][11:0];dy=y-active[i][23:12];text_color=active[i][53:52];
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
// Pixel coordinate conversion is a synchronous ROM, not cascaded integer
// dividers. Three 1024-entry banks encode (character, column) for each scale.
// The upper three bits are zero; using nibble-aligned storage avoids noisy
// readmemh truncation diagnostics while synthesis removes unused upper bits.
(* ramstyle="M10K" *) reg [11:0] coordinates[0:3071];
initial $readmemh("rtl/media_overlay_coordinates.hex",coordinates);
reg [11:0] mapped_x;
reg [2:0] slot_1,row_1;
reg page_1,hit_1;
reg [1:0] tc_1,rc_1;
function [2:0] glyph_y;
 input [3:0] d,input_scale;
 begin
  if(input_scale==9) case(d)
   0,1,2:glyph_y=0;3,4:glyph_y=1;5,6:glyph_y=2;7,8:glyph_y=3;
   9,10,11:glyph_y=4;12,13:glyph_y=5;default:glyph_y=6;
  endcase
  else if(input_scale==6) case(d)
   0,1:glyph_y=0;2:glyph_y=1;3,4:glyph_y=2;5:glyph_y=3;
   6,7:glyph_y=4;8:glyph_y=5;9,10:glyph_y=6;default:glyph_y=7;
  endcase
  else glyph_y=d<7?d[2:0]:3'd7;
 end
endfunction
always @(posedge clk) begin
 mapped_x<=coordinates[{(scale_q==9?2'd2:scale_q==6?2'd1:2'd0),dx_q[9:0]}];
 row_1<=glyph_y(dy_q[3:0],scale_q);slot_1<=slot_q;page_1<=page_q;
 hit_1<=hit_q && dx_q<1024 && dy_q<16;tc_1<=tc_q;rc_1<=rc_q;
end
reg [7:0] glyph;
reg [2:0] column_2,row_2;
reg hit_2;
reg [1:0] tc_2,rc_2;
always @(posedge clk) begin
 glyph<=text_mem[{page_1,slot_1,mapped_x[8:3]}];
 column_2<=mapped_x[2:0];row_2<=row_1;hit_2<=hit_1 && row_1!=7;
 tc_2<=tc_1;rc_2<=rc_1;
end
reg [7:0] glyph_row;
reg [2:0] column_3;
reg hit_3;
reg [1:0] tc_3,rc_3;
always @(posedge clk) begin
 glyph_row<=font[{glyph,row_2}];column_3<=column_2;hit_3<=hit_2;
 tc_3<=tc_2;rc_3<=rc_2;
end
reg [26:0] video_pipe[0:3];
reg [1:0] color_4;
reg [26:0] video_4;
always @(posedge clk) begin
 video_pipe[0]<={hs,vs,de,rgb};video_pipe[1]<=video_pipe[0];video_pipe[2]<=video_pipe[1];video_pipe[3]<=video_pipe[2];
 video_4<=video_pipe[3];
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
