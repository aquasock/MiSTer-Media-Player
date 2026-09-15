`timescale 1ns/1ps
module test_media_fft_peaks;
 reg clk=0;always #5 clk=~clk;
 reg active=1,vs=0;reg [255:0] levels=0;
 media_fire_renderer dut(.clk(clk),.active(active),.levels(levels),
  .rgb(24'd0),.hs(1'b0),.vs(vs),.de(1'b0),.layout_de(1'b0),
  .rgb_out(),.hs_out(),.vs_out(),.de_out());
 task frame;
  @(negedge clk);vs=1;repeat(2)@(negedge clk);vs=0;
  repeat(70)@(negedge clk);
 endtask
 task check(input integer band,level,peak);
  if(dut.bands[band][4:0]!=5'(level)||dut.bands[band][9:5]!=5'(peak))
   $fatal(1,"band %0d expected level/peak %0d/%0d got %0d/%0d",band,level,peak,dut.bands[band][4:0],dut.bands[band][9:5]);
 endtask
 initial begin
  frame();for(integer b=0;b<32;b++)check(b,0,0);
  // Distinct peaks exercise every RAM address and blanking read/write order.
  for(integer b=0;b<32;b++)levels[b*8+:8]=8'(b*8);
  frame();for(integer b=0;b<32;b++)check(b,b,b);
  levels=0;
  repeat(30)begin frame();for(integer b=0;b<32;b++)check(b,0,b);end
  frame();for(integer b=0;b<32;b++)check(b,0,b==0?0:b-1);
  repeat(3)begin frame();check(31,0,30);end
  frame();check(31,0,29);
  levels[31*8+:8]=8'd248;frame();check(31,31,31);
  levels=0;repeat(160)frame();for(integer b=0;b<32;b++)check(b,0,0);
  levels={32{8'd248}};frame();check(0,31,31);
  // A short inactive pulse between frames must clear the previous album.
  @(negedge clk);active=0;repeat(2)@(negedge clk);active=1;levels=0;
  frame();for(integer b=0;b<32;b++)check(b,0,0);
  $display("PASS FFT peaks: all bands, attack, 30-frame hold, four-frame decay, silence and replacement");$finish;
 end
endmodule
