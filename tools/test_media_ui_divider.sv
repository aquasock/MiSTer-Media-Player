`timescale 1ns/1ps
module test_media_ui_divider;
reg clk=0;always #5 clk=~clk;
reg [1:0] phase=0;always @(posedge clk) phase<=phase+1'b1;
wire ce=phase==0;
reg start=0;reg [47:0] n=0;reg [34:0] d=1;
wire busy,done;wire [47:0] q;wire [34:0] r;
media_ui_divider dut(.clk(clk),.ce(ce),.start(start),.numerator(n),.denominator(d),.busy(busy),.done(done),.quotient(q),.remainder(r));
reg [47:0] previous_q;reg [34:0] previous_r;reg enabled;
always @(posedge clk) begin
 enabled=ce;previous_q=q;previous_r=r;
 #1;if(!enabled && (q!==previous_q || r!==previous_r)) $fatal(1,"divider advanced off enable");
end
task divide(input [47:0] numerator,input [34:0] denominator);
 begin
  @(negedge clk);n=numerator;d=denominator;start=1;
  wait(busy);@(negedge clk);start=0;
  wait(done);@(negedge clk);
  if(q!=numerator/denominator || r!=numerator%denominator)
   $fatal(1,"divide n=%d d=%d q=%d r=%d",numerator,denominator,q,r);
 end
endtask
reg [31:0] rng=32'h2341feda;
function [31:0] random_word(input [31:0] x);
 reg [31:0] y;begin y=x^(x<<13);y=y^(y>>17);random_word=y^(y<<5);end
endfunction
reg [47:0] rn;reg [34:0] rd;
initial begin
 divide(0,1);divide(48'hffffffffffff,1);divide(48'hffffffffffff,35'h7ffffffff);
 divide(48'h800000000000,35'h400000001);divide(360000,360000);divide(359999,360000);
 for(integer i=0;i<512;i=i+1) begin
  rng=random_word(rng);rn[31:0]=rng;rng=random_word(rng);rn[47:32]=rng[15:0];
  rng=random_word(rng);rd[31:0]=rng;rng=random_word(rng);rd[34:32]=rng[2:0];
  if(i%3==0) rd=rd%720+1;if(rd==0) rd=1;
  divide(rn,rd);
 end
 $display("UI_DIVIDER_PASS 518 wide arithmetic cases with modulo-four enable");$finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
