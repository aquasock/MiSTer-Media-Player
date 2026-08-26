// kate Phase 1T-q: ordinary planar writer plus internal P chroma X-tag decode.
// Commit 128 adds an internal B-scratch tag in pixel_x[11:10]==2'b11.
// kate - Commit 169: preserve the legacy 8-bit-X B tag and add a wide scratch
// encoding: pixel_x[9:0] carries X while pixel_y[11:9]=100/101/110 selects
// Y/Cb/Cr and pixel_y[8:0] carries Y. Both forms target only SCRATCH.
module mpeg2_h262_ddram_store(
 input wire clk,input wire reset,input wire[1:0] frame_bank,input wire [7:0] pixel_value,
 input wire [1:0] pixel_component,input wire [11:0] pixel_x,input wire [11:0] pixel_y,
 input wire pixel_valid,input wire block_start,input wire block_complete,
 output reg block_stored,output reg write_seen,output reg store_error,
 input wire ddram_busy,output wire [7:0] ddram_burstcnt,output wire [28:0] ddram_addr,
 output wire ddram_rd,output wire [63:0] ddram_din,output wire [7:0] ddram_be,output wire ddram_we,
 // Entry 531: passive metadata for an accepted writer word.  The arbiter
 // supplies the acceptance pulse; these values describe the simultaneously
 // presented store word and never feed the writer or DDR control path.
 output wire luma_word_debug,output wire [2:0] luma_region_debug,
 output wire luma_row_parity_debug,output wire luma_picture_start_debug,
 output wire luma_picture_complete_debug,
 output wire [31:0] luma_position_fingerprint_debug);
localparam [1:0] Y=0,CB=1,CR=2;
localparam [28:0] YB=29'h06000000,CBB=29'h0600A8C0,CRB=29'h0600D2F0,BANK=29'h00010000,SCRATCH0=29'h00020000,SCRATCH1=29'h00030000;
wire scratch_tag=(pixel_component==Y)&&(pixel_x[11:10]==2'b11);
wire wide_bs0=scratch_tag&&pixel_y[11]&&(pixel_y[10:9]!=2'b11);
wire wide_bs1=scratch_tag&&!pixel_y[11]&&(pixel_y[10:9]!=2'b00);
wire wide_bs=wide_bs0||wide_bs1;
wire legacy_bs=scratch_tag&&!wide_bs;
wire tcb=(pixel_component==Y)&&(pixel_x[11:10]==2'b01);
wire tcr=(pixel_component==Y)&&(pixel_x[11:10]==2'b10);
wire tag=tcb||tcr||scratch_tag;
wire [1:0] legacy_bsc=(pixel_x[9:8]==2'b00)?Y:(pixel_x[9:8]==2'b01)?CB:(pixel_x[9:8]==2'b10)?CR:2'b11;
wire [1:0] wide_bsc=wide_bs0?pixel_y[10:9]:(pixel_y[10:9]-2'b01);
wire [1:0] bsc=wide_bs?wide_bsc:legacy_bsc;
wire [1:0] ec=scratch_tag?bsc:tcb?CB:tcr?CR:pixel_component;
wire [11:0] ex=wide_bs?{2'b00,pixel_x[9:0]}:legacy_bs?{4'b0000,pixel_x[7:0]}:(tag?{2'b00,pixel_x[9:0]}:pixel_x);
wire [11:0] ey=wide_bs?{3'b000,pixel_y[8:0]}:pixel_y;
function automatic [28:0] r90;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);end endfunction
function automatic [28:0] r45;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r45=(x<<5)+(x<<3)+(x<<2)+x;end endfunction
reg [63:0] b0,b1,b2,b3,b4,b5,b6,b7,sh;
wire [63:0] shn={pixel_value,sh[63:8]};
reg cap,flush,writing,ascratch,ascratch_bank;reg[1:0] ab;reg [1:0] ac;reg [11:0] ox,oy;reg [2:0] wr;reg [28:0] wa;
wire good=((ac==Y)&&(ox<720)&&(oy<480))||(((ac==CB)||(ac==CR))&&(ox<360)&&(oy<240));
wire [28:0] off=ascratch?(ascratch_bank?SCRATCH1:SCRATCH0):
                 (ab==2'd1)?BANK:(ab==2'd2)?29'h00040000:29'd0;
wire [28:0] first=(ac==Y)?YB+off+r90(oy)+{20'd0,ox[11:3]}:(ac==CB)?CBB+off+r45(oy)+{20'd0,ox[11:3]}:CRB+off+r45(oy)+{20'd0,ox[11:3]};
wire [28:0] stride=(ac==Y)?90:45;
assign ddram_burstcnt=writing?1:0;assign ddram_addr=writing?wa:0;assign ddram_rd=0;
assign ddram_din=(wr==0)?b0:(wr==1)?b1:(wr==2)?b2:(wr==3)?b3:(wr==4)?b4:(wr==5)?b5:(wr==6)?b6:b7;
assign ddram_be=8'hff;assign ddram_we=writing;

wire [11:0] luma_debug_row=oy+{9'd0,wr};
wire [6:0] luma_debug_word=ox[9:3];

// XORing independently position-mixed word contributions makes the completed
// field fingerprint insensitive to the writer's block-row transaction order
// while retaining row, word, lane and byte sensitivity.
function automatic [31:0] position_fingerprint_word;
 input [2:0] region;
 input [10:0] row;
 input [6:0] word_index;
 input [63:0] value;
 reg [31:0] result;
 reg [31:0] token;
 integer lane;
 begin
  result=32'd0;
  for(lane=0;lane<8;lane=lane+1)begin
   token={row[8:0],word_index,lane[2:0],value[lane*8 +: 8],5'b10101}^
         {region,29'h12d4a6b};
   token=token^{token[15:0],token[31:16]};
   token=token^{token[26:0],token[31:27]};
   result=result^token;
  end
  position_fingerprint_word=result;
 end
endfunction

assign luma_word_debug=writing&&(ac==Y);
assign luma_region_debug=wa[18:16];
assign luma_row_parity_debug=luma_debug_row[0];
assign luma_picture_start_debug=luma_word_debug&&
    (luma_debug_row==12'd0)&&(luma_debug_word==7'd0);
assign luma_picture_complete_debug=luma_word_debug&&
    (luma_debug_row==12'd479)&&(luma_debug_word==7'd89);
assign luma_position_fingerprint_debug=position_fingerprint_word(
    luma_region_debug,luma_debug_row[10:0],luma_debug_word,ddram_din);
always @(posedge clk)begin
 if(reset)begin cap<=0;flush<=0;writing<=0;ab<=0;ascratch<=0;ascratch_bank<=0;ac<=0;ox<=0;oy<=0;wr<=0;wa<=0;sh<=0;block_stored<=0;write_seen<=0;store_error<=0;end
 else begin
  block_stored<=0;
  if(block_start)begin
   if(cap||flush||writing)store_error<=1;
   cap<=1;ac<=ec;ab<=frame_bank;ascratch<=scratch_tag;ascratch_bank<=wide_bs1;ox<={ex[11:3],3'b000};oy<={ey[11:3],3'b000};
   if(scratch_tag&&(bsc==2'b11))store_error<=1;
  end
  if(pixel_valid)begin
   if(!(cap||block_start))store_error<=1;
   else begin sh<=shn;if(pixel_x[2:0]==7)case(pixel_y[2:0])0:b0<=shn;1:b1<=shn;2:b2<=shn;3:b3<=shn;4:b4<=shn;5:b5<=shn;6:b6<=shn;7:b7<=shn;endcase end
  end
  if(block_complete)begin if(!cap||flush||writing)store_error<=1;cap<=0;flush<=1;end
  if(!writing&&flush)begin
   if(!good)begin store_error<=1;flush<=0;block_stored<=1;end
   else begin wr<=0;wa<=first;writing<=1;end
  end else if(writing&&!ddram_busy)begin
   write_seen<=1;
   if(wr==7)begin writing<=0;flush<=0;block_stored<=1;end
   else begin wr<=wr+1'b1;wa<=wa+stride;end
  end
 end
end
endmodule
