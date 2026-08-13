//============================================================================
// MiSTer Media Player - controlled explicit P reference-read diagnostics
// kate - Phase 1T-p preserves the hardware-proven integer and horizontal
// half-sample reference-read paths while implicit macroblock reconstruction is
// factored into a separate engine.
//============================================================================
module mpeg2_h262_p_explicit_reference_probe
(
 input wire clk,input wire reset,input wire proof_seen,
 input wire p_forward_vector_valid,input wire signed [12:0] p_forward_vector_x,
 input wire signed [12:0] p_forward_vector_y,input wire [3:0] f_code_x,input wire [3:0] f_code_y,
 input wire reference_valid,input wire reference_bank,input wire ddram_busy,
 input wire [63:0] ddram_dout,input wire ddram_dout_ready,
 output wire active,output wire [7:0] ddram_burstcnt,output wire [28:0] ddram_addr,output wire ddram_rd,
 output reg read_seen,output reg [7:0] sample_value,output reg sample_nonzero,
 output reg half_sample_seen,output reg error
);
localparam [28:0] DDR_Y_BASE=29'h06000000,DDR_BANK_WORDS=29'h00010000;
localparam [7:0] EXPECTED_INTEGER=8'd162;

function automatic [7:0] byte_at; input [63:0] w; input [2:0] lane; begin case(lane)
 0:byte_at=w[7:0];1:byte_at=w[15:8];2:byte_at=w[23:16];3:byte_at=w[31:24];
 4:byte_at=w[39:32];5:byte_at=w[47:40];6:byte_at=w[55:48];default:byte_at=w[63:56];endcase end endfunction

wire integer_mode=p_forward_vector_valid&&(p_forward_vector_x==13'sd4)&&(p_forward_vector_y==0)&&(f_code_x==1)&&(f_code_y==1);
wire halfpel_mode=p_forward_vector_valid&&(p_forward_vector_x==13'sd3)&&(p_forward_vector_y==0)&&(f_code_x==2)&&(f_code_y==2);
wire mode=integer_mode||halfpel_mode;
wire signed [12:0] ix=p_forward_vector_x>>>1, iy=p_forward_vector_y>>>1;
wire signed [12:0] tx=ix+ix,ty=iy+iy;
wire hx=((p_forward_vector_x-tx)!=0),hy=((p_forward_vector_y-ty)!=0);
wire [11:0] dx=integer_mode?12'd7:12'd0;
wire signed [13:0] rxs=$signed({1'b0,dx})+ix;
wire signed [13:0] rys=$signed(14'sd0)+iy;
wire [11:0] rx=rxs[11:0],ry=rys[11:0];
wire vector_ok=integer_mode?((ix==2)&&(iy==0)&&!hx&&!hy&&(rxs==9)&&(rys==0)):
                         ((ix==1)&&(iy==0)&&hx&&!hy&&(rxs==1)&&(rys==0));
wire [28:0] bankoff=reference_bank?DDR_BANK_WORDS:29'd0;
wire [28:0] row90=({17'd0,ry}<<6)+({17'd0,ry}<<4)+({17'd0,ry}<<3)+({17'd0,ry}<<1);
wire [28:0] address=DDR_Y_BASE+bankoff+row90+{20'd0,rx[11:3]};
wire [7:0] left=byte_at(ddram_dout,rx[2:0]);
wire [7:0] right=byte_at(ddram_dout,rx[2:0]+3'd1);
wire [8:0] sum={1'b0,left}+{1'b0,right};
wire [7:0] filtered=(sum+9'd1)>>1;
wire [8:0] twice={filtered,1'b0};
wire relation_ok=sum[0]?(twice==(sum+9'd1)):(twice==sum);
wire [7:0] mn=(left<right)?left:right,mx=(left>right)?left:right;
wire nontrivial=(left!=right)&&(filtered>mn)&&(filtered<mx);

reg started,req,response;reg [19:0] timeout;
assign active=started&&!read_seen;
assign ddram_burstcnt=req?8'd1:8'd0;assign ddram_addr=req?address:29'd0;assign ddram_rd=req;
always @(posedge clk) begin
 if(reset) begin started<=0;req<=0;response<=0;timeout<=0;read_seen<=0;sample_value<=0;sample_nonzero<=0;half_sample_seen<=0;error<=0;end
 else begin
  if(proof_seen&&mode&&!started) begin started<=1;timeout<=20'hfffff;if(!reference_valid||!vector_ok||(halfpel_mode&&(rx[2:0]==7))) error<=1;else req<=1;end
  if(started&&!read_seen&&timeout!=0) begin timeout<=timeout-1'b1;if(timeout==1) error<=1;end
  if(req&&!ddram_busy) begin req<=0;response<=1;end
  if(ddram_dout_ready) begin
   if(!response) error<=1;
   else begin response<=0;read_seen<=1;timeout<=0;
    if(halfpel_mode) begin sample_value<=filtered;sample_nonzero<=|filtered;half_sample_seen<=1;if(!relation_ok||!nontrivial||!filtered) error<=1;end
    else begin sample_value<=left;sample_nonzero<=|left;if(left!=EXPECTED_INTEGER) error<=1;end
   end
  end
 end
end
endmodule
