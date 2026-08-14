//============================================================================
// MiSTer Media Player - controlled 8x6 P motion+residual raster engine
//
// Executes the established 48-position right-shift plan.  Macroblock 0 alone
// adds a captured six-block / 384-sample residual to its motion-compensated
// prediction with 8-bit clipping; all other macroblocks remain prediction-only.
// Every block is written through the ordinary planar DDR writer and read back.
//============================================================================
module mpeg2_h262_p_motion_residual_raster_engine
(
 input wire clk,input wire reset,input wire capture_enable,input wire request,input wire [47:0] shift_right_map,
 input wire residual_valid,input wire [5:0] residual_index,input wire signed [15:0] residual_value,
 input wire reference_valid,input wire reference_bank,input wire destination_bank,input wire store_block_stored,
 input wire ddram_busy,input wire [63:0] ddram_dout,input wire ddram_dout_ready,
 output wire [7:0] ddram_burstcnt,output wire [28:0] ddram_addr,output wire ddram_rd,
 output wire store_select,output wire [7:0] store_pixel_value,output wire [11:0] store_pixel_x,output wire [11:0] store_pixel_y,
 output wire store_pixel_valid,output wire store_block_start,output wire store_block_complete,
 output reg active,output reg read_seen,output reg [7:0] sample_value,output reg sample_nonzero,
 output reg reconstructed_seen,output reg [7:0] reconstructed_value,output reg persisted_seen,output reg [7:0] persisted_value,output reg error
);
localparam [28:0] Y=29'h06000000,CB=29'h0600A8C0,CR=29'h0600D2F0,BANK=29'h00010000;
localparam [47:0] LASTCOL=48'h808080808080;localparam [15:0] MBC=48;localparam [8:0] MBW=8;
function automatic [28:0] r90;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);end endfunction
function automatic [28:0] r45;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r45=(x<<5)+(x<<3)+(x<<2)+x;end endfunction
function automatic [28:0] addr;input [28:0] off;input [8:0] c;input [8:0] mr;input [2:0] b;input [2:0] rr;reg[11:0] lr,lw,cr;begin if(b<4)begin lr=({3'd0,mr}<<4)+{8'd0,b[1],rr};lw=({3'd0,c}<<1)+{11'd0,b[0]};addr=Y+off+r90(lr)+{17'd0,lw};end else begin cr=({3'd0,mr}<<3)+{9'd0,rr};addr=(b==4?CB:CR)+off+r45(cr)+{20'd0,c};end end endfunction
function automatic [7:0] bat;input [63:0] w;input [2:0] n;begin case(n)0:bat=w[7:0];1:bat=w[15:8];2:bat=w[23:16];3:bat=w[31:24];4:bat=w[39:32];5:bat=w[47:40];6:bat=w[55:48];default:bat=w[63:56];endcase end endfunction
function automatic [7:0] clip;input [7:0] p;input signed [15:0] f;reg signed[16:0] s;begin s=$signed({9'd0,p})+{f[15],f};if(s<0)clip=0;else if(s>255)clip=255;else clip=s[7:0];end endfunction
reg signed[15:0] rm[0:383];reg[8:0] rc;reg pending,started,rb,db,rkind,req,waitresp;reg[47:0] map;reg[15:0] mbi;reg[8:0] col,mrow;reg[2:0] blk,row;reg[23:0] timeout;reg[63:0] refrows[0:7],resrows[0:7];integer i;reg emit,wstore;reg[5:0] ei;
wire [28:0] roff=rb?BANK:0,doff=db?BANK:0;wire shift=map[mbi[5:0]];wire[8:0] rcol=shift?(col+1'b1):col;wire[8:0] acol=rkind?col:rcol;
assign ddram_burstcnt=req?8'd1:0;assign ddram_addr=req?addr(rkind?doff:roff,acol,mrow,blk,row):0;assign ddram_rd=req;
wire[2:0] er=ei[5:3],el=ei[2:0];wire[8:0] ridx={blk,ei};wire[7:0] pred=bat(refrows[er],el);wire[7:0] outpel=(mbi==0)?clip(pred,rm[ridx]):pred;
wire[11:0] luma_x=({3'd0,col}<<4)+{8'd0,blk[0],el};
wire[11:0] luma_y=({3'd0,mrow}<<4)+{8'd0,blk[1],er};
wire[11:0] chroma_x=({3'd0,col}<<3)+{9'd0,el};
wire[11:0] chroma_y=({3'd0,mrow}<<3)+{9'd0,er};
assign store_select=emit;assign store_pixel_value=outpel;assign store_pixel_valid=emit;assign store_block_start=emit&&(ei==0);assign store_block_complete=emit&&(ei==63);
assign store_pixel_x=(blk<4)?luma_x:(blk==4)?{2'b01,chroma_x[9:0]}:{2'b10,chroma_x[9:0]};
assign store_pixel_y=(blk<4)?luma_y:chroma_y;
wire ready_res=(rc==9'd384);
always @(posedge clk)begin
 if(reset)begin rc<=0;pending<=0;started<=0;active<=0;rb<=0;db<=0;rkind<=0;req<=0;waitresp<=0;map<=0;mbi<=0;col<=0;mrow<=0;blk<=0;row<=0;timeout<=0;emit<=0;wstore<=0;ei<=0;read_seen<=0;sample_value<=0;sample_nonzero<=0;reconstructed_seen<=0;reconstructed_value<=0;persisted_seen<=0;persisted_value<=0;error<=0;for(i=0;i<8;i=i+1)begin refrows[i]<=0;resrows[i]<=0;end end
 else begin
  if(capture_enable&&residual_valid)begin if(rc>=384||residual_index!=rc[5:0]||residual_value!=16'sd4)error<=1;else begin rm[rc]<=residual_value;rc<=rc+1'b1;end end
  if(request&&!started)pending<=1;
  if(pending&&!started&&ready_res)begin pending<=0;started<=1;active<=1;rb<=reference_bank;db<=destination_bank;map<=shift_right_map;timeout<=24'hffffff;mbi<=0;col<=0;mrow<=0;blk<=0;row<=0;rkind<=0;if(!reference_valid||(reference_bank==destination_bank)||(shift_right_map&LASTCOL)!=0||!shift_right_map[0])error<=1;else req<=1;end
  if(started&&!persisted_seen&&timeout!=0)begin timeout<=timeout-1'b1;if(timeout==1)error<=1;end
  if(req&&!ddram_busy)begin req<=0;waitresp<=1;end
  if(ddram_dout_ready)begin if(!waitresp)error<=1;else begin waitresp<=0;if(!rkind)begin refrows[row]<=ddram_dout;if(mbi==0&&blk==0&&row==0)begin read_seen<=1;sample_value<=ddram_dout[7:0];sample_nonzero<=|ddram_dout[7:0];end if(row==7)begin ei<=0;emit<=1;end else begin row<=row+1'b1;req<=1;end end else begin if(ddram_dout!=resrows[row])error<=1;if(mbi==0&&blk==0&&row==0&&ddram_dout==resrows[0])persisted_value<=ddram_dout[7:0];if(row==7)begin if(blk==5)begin if(mbi+1>=MBC)begin if(ddram_dout==resrows[7])begin persisted_seen<=1;reconstructed_seen<=1;active<=0;timeout<=0;end end else begin mbi<=mbi+1'b1;if(col+1>=MBW)begin col<=0;mrow<=mrow+1'b1;end else col<=col+1'b1;blk<=0;row<=0;rkind<=0;req<=1;end end else begin blk<=blk+1'b1;row<=0;rkind<=0;req<=1;end end else begin row<=row+1'b1;req<=1;end end end end
  if(emit)begin resrows[er][{el,3'b000}+:8]<=outpel;if(mbi==0&&blk==0&&ei==0)reconstructed_value<=outpel;if(ei==63)begin emit<=0;wstore<=1;end else ei<=ei+1'b1;end
  if(wstore&&store_block_stored)begin wstore<=0;rkind<=1;row<=0;req<=1;end
 end
end
endmodule
