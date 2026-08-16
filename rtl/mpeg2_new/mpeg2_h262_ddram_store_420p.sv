// kate Phase 1T-q: ordinary planar writer plus internal P chroma X-tag decode.
// Commit 128 adds an internal B-scratch tag: pixel_x[11:10]==2'b11 and
// pixel_x[9:8] selects Y/Cb/Cr.  Scratch writes use a third non-reference
// frame region and therefore cannot overwrite either I/P reference bank.
module mpeg2_h262_ddram_store(input wire clk,input wire reset,input wire frame_bank,input wire [7:0] pixel_value,input wire [1:0] pixel_component,input wire [11:0] pixel_x,input wire [11:0] pixel_y,input wire pixel_valid,input wire block_start,input wire block_complete,output reg block_stored,output reg write_seen,output reg store_error,input wire ddram_busy,output wire [7:0] ddram_burstcnt,output wire [28:0] ddram_addr,output wire ddram_rd,output wire [63:0] ddram_din,output wire [7:0] ddram_be,output wire ddram_we);
localparam [1:0] Y=0,CB=1,CR=2;localparam [28:0] YB=29'h06000000,CBB=29'h0600A8C0,CRB=29'h0600D2F0,BANK=29'h00010000,SCRATCH=29'h00020000;
wire bs=(pixel_component==Y)&&(pixel_x[11:10]==2'b11);wire tcb=(pixel_component==Y)&&(pixel_x[11:10]==2'b01),tcr=(pixel_component==Y)&&(pixel_x[11:10]==2'b10),tag=tcb||tcr||bs;
wire [1:0] bsc=(pixel_x[9:8]==2'b00)?Y:(pixel_x[9:8]==2'b01)?CB:(pixel_x[9:8]==2'b10)?CR:2'b11;
wire [1:0] ec=bs?bsc:tcb?CB:tcr?CR:pixel_component;wire [11:0] ex=bs?{4'b0000,pixel_x[7:0]}:(tag?{2'b00,pixel_x[9:0]}:pixel_x);
function automatic [28:0] r90;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);end endfunction
function automatic [28:0] r45;input [11:0] r;reg [28:0] x;begin x={17'd0,r};r45=(x<<5)+(x<<3)+(x<<2)+x;end endfunction
reg [63:0] b0,b1,b2,b3,b4,b5,b6,b7,sh;wire [63:0] shn={pixel_value,sh[63:8]};reg cap,flush,writing,ab,ascratch;reg [1:0] ac;reg [11:0] ox,oy;reg [2:0] wr;reg [28:0] wa;wire good=((ac==Y)&&(ox<720)&&(oy<480))||(((ac==CB)||(ac==CR))&&(ox<360)&&(oy<240));wire [28:0] off=ascratch?SCRATCH:(ab?BANK:0);wire [28:0] first=(ac==Y)?YB+off+r90(oy)+{20'd0,ox[11:3]}:(ac==CB)?CBB+off+r45(oy)+{20'd0,ox[11:3]}:CRB+off+r45(oy)+{20'd0,ox[11:3]};wire [28:0] stride=(ac==Y)?90:45;
assign ddram_burstcnt=writing?1:0;assign ddram_addr=writing?wa:0;assign ddram_rd=0;assign ddram_din=(wr==0)?b0:(wr==1)?b1:(wr==2)?b2:(wr==3)?b3:(wr==4)?b4:(wr==5)?b5:(wr==6)?b6:b7;assign ddram_be=8'hff;assign ddram_we=writing;
always @(posedge clk)begin if(reset)begin cap<=0;flush<=0;writing<=0;ab<=0;ascratch<=0;ac<=0;ox<=0;oy<=0;wr<=0;wa<=0;sh<=0;block_stored<=0;write_seen<=0;store_error<=0;end else begin block_stored<=0;
if(block_start)begin if(cap||flush||writing)store_error<=1;cap<=1;ac<=ec;ab<=frame_bank;ascratch<=bs;ox<={ex[11:3],3'b000};oy<={pixel_y[11:3],3'b000};if(bs&&(bsc==2'b11))store_error<=1;end
if(pixel_valid)begin if(!(cap||block_start))store_error<=1;else begin sh<=shn;if(pixel_x[2:0]==7)case(pixel_y[2:0])0:b0<=shn;1:b1<=shn;2:b2<=shn;3:b3<=shn;4:b4<=shn;5:b5<=shn;6:b6<=shn;7:b7<=shn;endcase end end
if(block_complete)begin if(!cap||flush||writing)store_error<=1;cap<=0;flush<=1;end
if(!writing&&flush)begin if(!good)begin store_error<=1;flush<=0;block_stored<=1;end else begin wr<=0;wa<=first;writing<=1;end end else if(writing&&!ddram_busy)begin write_seen<=1;if(wr==7)begin writing<=0;flush<=0;block_stored<=1;end else begin wr<=wr+1'b1;wa<=wa+stride;end end
end end
endmodule
