//============================================================================
// MiSTer Media Player - controlled 8x6 P motion+residual raster engine
//
// Motion and residual placement are supplied over the existing residual sideband.
// Six A1xx metadata words carry the 48-bit right-shift map, Bxxx descriptor words
// identify up to sixteen (macroblock, block) residual targets, each descriptor is
// followed by 64 spatial samples, and A2FF terminates the plan.  The controlled
// residual value remains +4/pel for this hardware proof.
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
localparam [47:0] LASTCOL=48'h808080808080;localparam [15:0] MBC=48;localparam [8:0] MBW=8;localparam integer MAX_BLOCKS=16;
function automatic [28:0] r90;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);end endfunction
function automatic [28:0] r45;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r45=(x<<5)+(x<<3)+(x<<2)+x;end endfunction
function automatic [28:0] addr;input [28:0] off;input [8:0] c;input [8:0] mr;input [2:0] b;input [2:0] rr;reg[11:0] lr,lw,cr;begin if(b<4)begin lr=({3'd0,mr}<<4)+{8'd0,b[1],rr};lw=({3'd0,c}<<1)+{11'd0,b[0]};addr=Y+off+r90(lr)+{17'd0,lw};end else begin cr=({3'd0,mr}<<3)+{9'd0,rr};addr=(b==4?CB:CR)+off+r45(cr)+{20'd0,c};end end endfunction
function automatic [7:0] bat;input [63:0] w;input [2:0] n;begin case(n)0:bat=w[7:0];1:bat=w[15:8];2:bat=w[23:16];3:bat=w[31:24];4:bat=w[39:32];5:bat=w[47:40];6:bat=w[55:48];default:bat=w[63:56];endcase end endfunction
function automatic [7:0] clip;input [7:0] p;input signed [15:0] f;reg signed[16:0] s;begin s=$signed({9'd0,p})+{f[15],f};if(s<0)clip=0;else if(s>255)clip=255;else clip=s[7:0];end endfunction

reg signed[15:0] rm[0:1023];reg[5:0] desc_mb[0:15];reg[2:0] desc_block[0:15];reg[4:0] desc_count;
reg[3:0] current_desc_slot;reg desc_active;reg[5:0] sample_expected;reg[2:0] map_byte_count;reg metadata_done;reg[4:0] exec_desc_slot;
reg pending,started,rb,db,rkind,req,waitresp;reg[47:0] map;reg[15:0] mbi;reg[8:0] col,mrow;reg[2:0] blk,row;reg[23:0] timeout;
reg[63:0] refrows[0:7],resrows[0:7];integer i;reg emit,wstore;reg[5:0] ei;
wire [28:0] roff=rb?BANK:0,doff=db?BANK:0;wire shift=map[mbi[5:0]];wire[8:0] rcol=shift?(col+1'b1):col;wire[8:0] acol=rkind?col:rcol;
assign ddram_burstcnt=req?8'd1:0;assign ddram_addr=req?addr(rkind?doff:roff,acol,mrow,blk,row):0;assign ddram_rd=req;
wire[2:0] er=ei[5:3],el=ei[2:0];wire[7:0] pred=bat(refrows[er],el);
wire residual_hit=(exec_desc_slot<desc_count)&&(desc_mb[exec_desc_slot[3:0]]==mbi[5:0])&&(desc_block[exec_desc_slot[3:0]]==blk);
wire[9:0] residual_mem_index={exec_desc_slot[3:0],6'b000000}+{4'd0,ei};
wire signed[15:0] residual_pel=residual_hit?rm[residual_mem_index]:16'sd0;wire[7:0] outpel=clip(pred,residual_pel);
wire[11:0] luma_x=({3'd0,col}<<4)+{8'd0,blk[0],el};wire[11:0] luma_y=({3'd0,mrow}<<4)+{8'd0,blk[1],er};
wire[11:0] chroma_x=({3'd0,col}<<3)+{9'd0,el};wire[11:0] chroma_y=({3'd0,mrow}<<3)+{9'd0,er};
assign store_select=emit;assign store_pixel_value=outpel;assign store_pixel_valid=emit;assign store_block_start=emit&&(ei==0);assign store_block_complete=emit&&(ei==63);
assign store_pixel_x=(blk<4)?luma_x:(blk==4)?{2'b01,chroma_x[9:0]}:{2'b10,chroma_x[9:0]};assign store_pixel_y=(blk<4)?luma_y:chroma_y;
wire ready_res=metadata_done;
wire descriptor_order_error=(desc_count!=0)&&({residual_value[8:3],residual_value[2:0]}<={desc_mb[(desc_count-1'b1)&5'h0f],desc_block[(desc_count-1'b1)&5'h0f]});

always @(posedge clk)begin
 if(reset)begin
  desc_count<=0;current_desc_slot<=0;desc_active<=0;sample_expected<=0;map_byte_count<=0;metadata_done<=0;map<=0;exec_desc_slot<=0;
  pending<=0;started<=0;active<=0;rb<=0;db<=0;rkind<=0;req<=0;waitresp<=0;mbi<=0;col<=0;mrow<=0;blk<=0;row<=0;timeout<=0;emit<=0;wstore<=0;ei<=0;
  read_seen<=0;sample_value<=0;sample_nonzero<=0;reconstructed_seen<=0;reconstructed_value<=0;persisted_seen<=0;persisted_value<=0;error<=0;
  for(i=0;i<16;i=i+1)begin desc_mb[i]<=0;desc_block[i]<=0;end for(i=0;i<8;i=i+1)begin refrows[i]<=0;resrows[i]<=0;end
 end else begin
  if(capture_enable&&residual_valid)begin
   if((residual_index==6'h3f)&&(residual_value[15:8]==8'hA1))begin
    if(desc_active||metadata_done||(map_byte_count>=6))error<=1;else begin
     case(map_byte_count)0:map[7:0]<=residual_value[7:0];1:map[15:8]<=residual_value[7:0];2:map[23:16]<=residual_value[7:0];3:map[31:24]<=residual_value[7:0];4:map[39:32]<=residual_value[7:0];default:map[47:40]<=residual_value[7:0];endcase
     map_byte_count<=map_byte_count+1'b1;
    end
   end else if((residual_index==6'h3f)&&(residual_value[15:12]==4'hB))begin
    if((map_byte_count!=6)||desc_active||metadata_done||(desc_count>=MAX_BLOCKS)||(residual_value[8:3]>=48)||(residual_value[2:0]>=6)||descriptor_order_error)error<=1;
    else begin current_desc_slot<=desc_count[3:0];desc_mb[desc_count]<=residual_value[8:3];desc_block[desc_count]<=residual_value[2:0];desc_count<=desc_count+1'b1;desc_active<=1;sample_expected<=0;end
   end else if((residual_index==6'h3f)&&(residual_value==16'shA2FF))begin
    if((map_byte_count!=6)||desc_active||metadata_done||(desc_count==0))error<=1;else metadata_done<=1;
   end else begin
    if(!desc_active||(residual_index!=sample_expected)||(residual_value!=16'sd4))error<=1;
    else begin rm[{current_desc_slot,6'b000000}+residual_index]<=residual_value;if(residual_index==63)desc_active<=0;else sample_expected<=sample_expected+1'b1;end
   end
  end
  if(request&&!started)pending<=1;
  if(pending&&!started&&ready_res)begin pending<=0;started<=1;active<=1;rb<=reference_bank;db<=destination_bank;timeout<=24'hffffff;mbi<=0;col<=0;mrow<=0;blk<=0;row<=0;rkind<=0;exec_desc_slot<=0;
   if(!reference_valid||(reference_bank==destination_bank)||(map&LASTCOL)!=0||!(|map)||(desc_count==0))error<=1;else req<=1;end
  if(started&&!persisted_seen&&timeout!=0)begin timeout<=timeout-1'b1;if(timeout==1)error<=1;end
  if(req&&!ddram_busy)begin req<=0;waitresp<=1;end
  if(ddram_dout_ready)begin if(!waitresp)error<=1;else begin waitresp<=0;if(!rkind)begin refrows[row]<=ddram_dout;if(mbi==0&&blk==0&&row==0)begin read_seen<=1;sample_value<=ddram_dout[7:0];sample_nonzero<=|ddram_dout[7:0];end
    if(row==7)begin ei<=0;emit<=1;end else begin row<=row+1'b1;req<=1;end end
   else begin if(ddram_dout!=resrows[row])error<=1;if(mbi==0&&blk==0&&row==0&&ddram_dout==resrows[0])persisted_value<=ddram_dout[7:0];
    if(row==7)begin
     if(residual_hit)exec_desc_slot<=exec_desc_slot+1'b1;
     if(blk==5)begin if(mbi+1>=MBC)begin if(ddram_dout==resrows[7])begin
       if((exec_desc_slot+(residual_hit?1'b1:1'b0))!=desc_count)error<=1;
       persisted_seen<=1;reconstructed_seen<=1;active<=0;timeout<=0;end end
      else begin mbi<=mbi+1'b1;if(col+1>=MBW)begin col<=0;mrow<=mrow+1'b1;end else col<=col+1'b1;blk<=0;row<=0;rkind<=0;req<=1;end end
     else begin blk<=blk+1'b1;row<=0;rkind<=0;req<=1;end end else begin row<=row+1'b1;req<=1;end end end end
  if(emit)begin resrows[er][{el,3'b000}+:8]<=outpel;if(mbi==0&&blk==0&&ei==0)reconstructed_value<=outpel;if(ei==63)begin emit<=0;wstore<=1;end else ei<=ei+1'b1;end
  if(wstore&&store_block_stored)begin wstore<=0;rkind<=1;row<=0;req<=1;end
 end
end
wire unused_shift_map=&{1'b0,shift_right_map};
endmodule
