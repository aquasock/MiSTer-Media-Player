`timescale 1ns/1ps
module test_media_xy_visualizer;
 reg clk=0;always #5 clk=~clk;
 reg active=0,sample_toggle=0,hs=0,vs=0,de=0,layout_de=0;
 reg signed [15:0] sample_left=0,sample_right=0;
 wire [23:0] rgb_out;wire hs_out,vs_out,de_out;
 media_xy_visualizer dut(.clk(clk),.active(active),.sample_toggle(sample_toggle),.sample_left(sample_left),.sample_right(sample_right),
 .rgb(24'h123456),.hs(hs),.vs(vs),.de(de),.layout_de(layout_de),.rgb_out(rgb_out),.hs_out(hs_out),.vs_out(vs_out),.de_out(de_out));
 reg expected[0:16383];integer marked=0;
 task clear_trace;begin
  active=0;repeat(3)@(negedge clk);active=1;repeat(16400)@(negedge clk);
  for(integer i=0;i<16384;i=i+1)begin expected[i]=0;if(dut.phosphor[i]!=0)$fatal(1,"clear failed");end
 end endtask
 task sample(input integer x,y);begin
  @(negedge clk);sample_left=16'((x-64)*512);sample_right=16'((63-y)*512);sample_toggle=!sample_toggle;
  repeat(300)@(negedge clk);
 end endtask
 task line(input integer x0,y0,x1,y1);
 integer x,y,dx,dy,sx,sy,err,e2;
 begin
  x=x0;y=y0;dx=x1>x0?x1-x0:x0-x1;dy=-(y1>y0?y1-y0:y0-y1);sx=x0<x1?1:-1;sy=y0<y1?1:-1;err=dx+dy;
  while(1)begin
   expected[y*128+x]=1;
   if(x==x1&&y==y1)break;
   e2=2*err;
   if(e2>dy)begin err=err+dy;x=x+sx;end
   if(e2<dx)begin err=err+dx;y=y+sy;end
  end
 end endtask
 task check_trace;begin
  for(integer i=0;i<16384;i=i+1)
   if(dut.phosphor[i]!=(expected[i]?4'd15:4'd0))$fatal(1,"trace mismatch at %d",i);
 end endtask
 initial begin
  clear_trace();sample(0,0);sample(127,127);line(0,0,127,127);check_trace();
  sample(0,127);line(127,127,0,127);check_trace();
  sample(127,0);line(0,127,127,0);check_trace();
  sample(127,127);line(127,0,127,127);check_trace();
  sample(20,70);line(127,127,20,70);check_trace();
  sample(25,5);line(20,70,25,5);check_trace();
  sample(25,5);check_trace();
  for(integer level=14;level>=0;level=level-1)begin
   vs=1;repeat(2)@(negedge clk);vs=0;repeat(50000)@(negedge clk);
   for(integer i=0;i<16384;i=i+1)
    if(dut.phosphor[i]!=(expected[i]?4'(level):4'd0))$fatal(1,"fade mismatch level %d address %d got %d",level,i,dut.phosphor[i]);
  end
  sample(64,64);active=0;repeat(2)@(negedge clk);active=1;repeat(16400)@(negedge clk);
  for(integer i=0;i<16384;i=i+1)if(dut.phosphor[i]!=0)$fatal(1,"replacement retained trace");
  $display("PASS XY line octants, endpoints, stationary samples, all phosphor decay levels and replacement clear");$finish;
 end
 initial begin #20000000;$fatal(1,"timeout");end
endmodule
