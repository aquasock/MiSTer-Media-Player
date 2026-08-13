// kate - Phase 1T-q: controlled first P macroblock, Y0/Y1/Y2/Y3/Cb/Cr.
// core-standards.md source_id H262 is the project standards authority.
// Cb/Cr are temporarily tagged in store_pixel_x[11:10]: 01=Cb, 10=Cr.
module mpeg2_h262_p_luma_macroblock_engine(
 input wire clk,input wire reset,input wire request,input wire residual_valid,input wire [5:0] residual_index,
 input wire signed [15:0] residual_value,input wire reference_valid,input wire reference_bank,input wire destination_bank,
 input wire store_block_stored,input wire ddram_busy,input wire [63:0] ddram_dout,input wire ddram_dout_ready,
 output wire [7:0] ddram_burstcnt,output wire [28:0] ddram_addr,output wire ddram_rd,output wire store_select,
 output wire [7:0] store_pixel_value,output wire [11:0] store_pixel_x,output wire [11:0] store_pixel_y,
 output wire store_pixel_valid,output wire store_block_start,output wire store_block_complete,
 output reg read_seen,output reg [7:0] sample_value,output reg sample_nonzero,output reg reconstructed_seen,
 output reg [7:0] reconstructed_value,output reg persisted_seen,output reg [7:0] persisted_value,output reg error);
localparam [28:0] YBASE=29'h06000000,CBBASE=29'h0600A8C0,CRBASE=29'h0600D2F0,BANK=29'h00010000;
function automatic [28:0] r90;input [3:0] r;reg [28:0] x;begin x={25'd0,r};r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);end endfunction
function automatic [28:0] r45;input [2:0] r;reg [28:0] x;begin x={26'd0,r};r45=(x<<5)+(x<<3)+(x<<2)+x;end endfunction
function automatic [28:0] addr;input [28:0] off;input [2:0] b;input [2:0] r;begin
 if(b<4) addr=YBASE+off+r90({b[1],r})+{28'd0,b[0]}; else if(b==4) addr=CBBASE+off+r45(r); else addr=CRBASE+off+r45(r);end endfunction
function automatic [7:0] bat;input [63:0] w;input [2:0] n;begin case(n)
0:bat=w[7:0];1:bat=w[15:8];2:bat=w[23:16];3:bat=w[31:24];4:bat=w[39:32];5:bat=w[47:40];6:bat=w[55:48];default:bat=w[63:56];endcase end endfunction
function automatic [7:0] clipadd;input [7:0] p;input signed [15:0] f;reg signed [16:0] s;begin s=$signed({9'd0,p})+{f[15],f};if(s<0)clipadd=0;else if(s>255)clipadd=255;else clipadd=s[7:0];end endfunction
(* ramstyle="M10K" *) reg signed [15:0] rm[0:511];reg [8:0] rc;
reg [63:0] rr[0:7],dr[0:7];integer i;
reg started,rb,db,rkind,req,waitresp;reg [2:0] blk,row;reg [19:0] timeout;
wire [28:0] roff=rb?BANK:0,doff=db?BANK:0;assign ddram_burstcnt=req?1:0;assign ddram_addr=req?addr(rkind?doff:roff,blk,row):0;assign ddram_rd=req;
reg fetch,apply;reg [5:0] si,sid;reg signed [15:0] rd;wire [8:0] ra={blk,si};wire [2:0] sr=sid[5:3],sl=sid[2:0];wire [7:0] pel=clipadd(bat(rr[sr],sl),rd);
reg emit,wstore;reg [5:0] ei;wire [2:0] er=ei[5:3],el=ei[2:0];assign store_select=emit;assign store_pixel_value=bat(dr[er],el);assign store_pixel_valid=emit;assign store_block_start=emit&&(ei==0);assign store_block_complete=emit&&(ei==63);
assign store_pixel_x=(blk<4)?{8'd0,blk[0],el}:(blk==4)?{2'b01,7'd0,el}:{2'b10,7'd0,el};assign store_pixel_y=(blk<4)?{8'd0,blk[1],er}:{9'd0,er};
always @(posedge clk) begin
 if(reset) begin rc<=0;started<=0;rb<=0;db<=0;rkind<=0;req<=0;waitresp<=0;blk<=0;row<=0;timeout<=0;fetch<=0;apply<=0;si<=0;sid<=0;rd<=0;emit<=0;wstore<=0;ei<=0;read_seen<=0;sample_value<=0;sample_nonzero<=0;reconstructed_seen<=0;reconstructed_value<=0;persisted_seen<=0;persisted_value<=0;error<=0;for(i=0;i<8;i=i+1)begin rr[i]<=0;dr[i]<=0;end end
 else begin
  if(residual_valid)begin if((rc>=384)||(residual_index!=rc[5:0]))error<=1;else begin rm[rc]<=residual_value;rc<=rc+1'b1;end end
  if(request&&!started)begin started<=1;rb<=reference_bank;db<=destination_bank;timeout<=20'hfffff;blk<=0;row<=0;rkind<=0;if(!reference_valid||(destination_bank==reference_bank)||(rc!=384))error<=1;else req<=1;end
  if(started&&!persisted_seen&&timeout!=0)begin timeout<=timeout-1'b1;if(timeout==1)error<=1;end
  if(req&&!ddram_busy)begin req<=0;waitresp<=1;end
  if(ddram_dout_ready)begin
   if(!waitresp)error<=1;else begin waitresp<=0;
    if(!rkind)begin rr[row]<=ddram_dout;if((blk==0)&&(row==0))begin read_seen<=1;sample_value<=ddram_dout[7:0];sample_nonzero<=|ddram_dout[7:0];end
     if(row==7)begin si<=0;fetch<=1;end else begin row<=row+1'b1;req<=1;end end
    else begin if(ddram_dout!=dr[row])error<=1;if((blk==0)&&(row==0)&&(ddram_dout==dr[0]))persisted_value<=ddram_dout[7:0];
     if(row==7)begin if(blk==5)begin if(ddram_dout==dr[7])begin persisted_seen<=1;reconstructed_seen<=1;timeout<=0;end end else begin blk<=blk+1'b1;row<=0;rkind<=0;req<=1;end end else begin row<=row+1'b1;req<=1;end end
   end
  end
  if(fetch)begin rd<=rm[ra];sid<=si;fetch<=0;apply<=1;end
  else if(apply)begin dr[sr][{sl,3'b000}+:8]<=pel;if((blk==0)&&(sid==0))reconstructed_value<=pel;apply<=0;if(sid==63)begin ei<=0;emit<=1;end else begin si<=sid+1'b1;fetch<=1;end end
  if(emit)begin if(ei==63)begin emit<=0;wstore<=1;end else ei<=ei+1'b1;end
  if(wstore&&store_block_stored)begin wstore<=0;rkind<=1;row<=0;req<=1;end
 end
end
endmodule
