// One restoring divider shared by scene formatting and layout, never pixels.
module media_ui_divider(
 input wire clk,start,input wire [47:0] numerator,input wire [34:0] denominator,
 output reg busy=0,output reg done=0,output reg [47:0] quotient=0,
 output reg [34:0] remainder=0
);
reg [34:0] divisor=1;
reg [5:0] count=0;
wire [35:0] trial={remainder,quotient[47]};
always @(posedge clk) begin
 done<=0;
 if(start && !busy) begin
  quotient<=numerator;divisor<=denominator;remainder<=0;count<=48;busy<=1;
 end else if(busy) begin
  if(trial>={1'b0,divisor}) begin
   remainder<=trial-{1'b0,divisor};quotient<={quotient[46:0],1'b1};
  end else begin remainder<=trial[34:0];quotient<={quotient[46:0],1'b0};end
  count<=count-1'b1;
  if(count==1) begin busy<=0;done<=1;end
 end
end
endmodule
