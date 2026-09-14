// Bounded progressive duration arithmetic. H.262 6.3.9 temporal_reference
// advances in display order modulo 1024 and resets at a GOP header.
// One serial multiplier avoids adding DSPs or a long combinational product.
module media_duration_timeline(
 input wire clk,reset,gop,picture,
 input wire [9:0] temporal_reference,
 input wire [2:0] picture_type,
 input wire [14:0] period_q,
 input wire pts_valid,
 input wire [32:0] pts,origin,
 output wire ready,known,
 output reg bad=0,
 output reg [34:0] end_q=0
);
reg [3:0] state=0;
reg have_reference=0,have_picture=0,base_known=0;
reg [19:0] reference_index=0,max_index=0,max_q=0;
reg signed [35:0] base_q=0,group_end=0,next_base=0,endpoint=0,base_error=0;
reg [14:0] rate=0,rate_q=0;
reg [32:0] relative_pts=0;
reg timestamped=0;
reg [34:0] product=0,multiplicand=0,offset_q=0,max_offset=0;
reg [19:0] multiplier=0;
reg [4:0] count=0;
wire [9:0] forward_delta=temporal_reference-reference_index[9:0];
wire [9:0] backward_delta=reference_index[9:0]-temporal_reference;
wire [20:0] forward_index={1'b0,reference_index}+{11'd0,forward_delta};
wire [20:0] backward_index={1'b0,reference_index}-{11'd0,backward_delta};
wire [20:0] next_index=!have_reference?{11'd0,temporal_reference}:
 picture_type==3?backward_index:forward_index;
assign ready=state==0;
assign known=base_known && have_picture && !bad && ready;
always @(posedge clk) begin
 if(reset) begin
  state<=0;have_reference<=0;have_picture<=0;base_known<=0;
  reference_index<=0;max_index<=0;base_q<=0;group_end<=0;
  bad<=0;end_q<=0;rate<=0;
 end else case(state)
  0:begin
   if(gop) begin
    // The next GOP's TR zero follows the previous group's last display slot.
    base_q<=group_end;base_known<=base_known && have_picture;
    have_reference<=0;have_picture<=0;max_index<=0;
   end
   if(picture) begin
    if(picture_type<1 || picture_type>3 || period_q==0 || next_index[20] ||
       (have_reference && picture_type!=3 && forward_delta==0)) bad<=1;
    max_q<=!have_picture || next_index[19:0]>max_index ? next_index[19:0]:max_index;
    if(picture_type!=3) begin reference_index<=next_index[19:0];have_reference<=1;end
    if(rate!=0 && rate!=period_q) bad<=1; // mixed-rate window needs separate qualification
    rate<=period_q;rate_q<=period_q;timestamped<=pts_valid;relative_pts<=pts-origin;
    product<=0;multiplicand<={20'd0,period_q};multiplier<=next_index[19:0];count<=20;state<=1;
   end
  end
  1:begin
   if(multiplier[0]) product<=product+multiplicand;
   multiplier<=multiplier>>1;multiplicand<=multiplicand<<1;count<=count-1'b1;
   if(count==1) state<=2;
  end
  2:begin
   offset_q<=product;product<=0;multiplicand<={20'd0,rate_q};multiplier<=max_q;count<=20;state<=3;
  end
  3:begin
   if(multiplier[0]) product<=product+multiplicand;
   multiplier<=multiplier>>1;multiplicand<=multiplicand<<1;count<=count-1'b1;
   if(count==1) state<=4;
  end
  4:begin
   max_offset<=product;
   next_base<=timestamped ? $signed({1'b0,relative_pts,2'b00})-$signed({1'b0,offset_q}):base_q;
   if(timestamped && relative_pts[32]) bad<=1;
   state<=5;
  end
  5:begin
   base_error<=next_base-base_q;
   endpoint<=next_base+$signed({1'b0,max_offset})+$signed({21'd0,rate_q});state<=6;
  end
  6:begin
   // PTS quantization at 90 kHz can move the inferred base by up to one tick.
   if(timestamped && base_known && (base_error>36'sd4 || base_error< -36'sd4)) bad<=1;
   base_q<=next_base;base_known<=base_known || timestamped;
   group_end<=endpoint;max_index<=max_q;have_picture<=1;
   if((base_known || timestamped) && !endpoint[35] && endpoint[34:0]>end_q) end_q<=endpoint[34:0];
   if((base_known || timestamped) && endpoint[35]) bad<=1;
   state<=0;
  end
  default:state<=0;
 endcase
end
endmodule
