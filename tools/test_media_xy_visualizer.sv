`timescale 1ns/1ps
module test_media_xy_visualizer;
 reg clk=0;always #5 clk=~clk;
 reg active=0,sample_toggle=0,hs=0,vs=0,de=0,layout_de=0;
 reg signed [15:0] sample_left=0,sample_right=0;
 wire [23:0] rgb_out;wire hs_out,vs_out,de_out;
 media_xy_visualizer dut(.clk(clk),.active(active),.sample_toggle(sample_toggle),.sample_left(sample_left),.sample_right(sample_right),
 .rgb(24'h123456),.hs(hs),.vs(vs),.de(de),.layout_de(layout_de),.rgb_out(rgb_out),.hs_out(hs_out),.vs_out(vs_out),.de_out(de_out));
 reg expected[0:65535];integer marked=0;
 task clear_trace;begin
  active=0;repeat(3)@(negedge clk);active=1;repeat(65560)@(negedge clk);
  for(integer i=0;i<65536;i=i+1)begin expected[i]=0;if({dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]}!=0)$fatal(1,"clear failed");end
 end endtask
 task sample(input integer x,y);begin
  @(negedge clk);sample_left=16'((x-128)*256);sample_right=16'((127-y)*256);sample_toggle=!sample_toggle;
  repeat(300)@(negedge clk);
 end endtask
 task line(input integer x0,y0,x1,y1);
 integer x,y,dx,dy,sx,sy,err,e2;
 begin
  x=x0;y=y0;dx=x1>x0?x1-x0:x0-x1;dy=-(y1>y0?y1-y0:y0-y1);sx=x0<x1?1:-1;sy=y0<y1?1:-1;err=dx+dy;
  while(1)begin
   expected[y*256+x]=1;
   if(x==x1&&y==y1)break;
   e2=2*err;
   if(e2>dy)begin err=err+dy;x=x+sx;end
   if(e2<dx)begin err=err+dx;y=y+sy;end
  end
 end endtask
 task check_trace;begin
  for(integer i=0;i<65536;i=i+1)
   if({dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]}!=(expected[i]?3'd7:3'd0))$fatal(1,"trace mismatch at %d",i);
 end endtask
 initial begin
  clear_trace();sample(0,0);sample(255,255);line(0,0,255,255);check_trace();
  sample(0,255);line(255,255,0,255);check_trace();
  sample(255,0);line(0,255,255,0);check_trace();
  sample(255,255);line(255,0,255,255);check_trace();
  sample(20,70);line(255,255,20,70);check_trace();
  sample(25,5);line(20,70,25,5);check_trace();
  sample(25,5);check_trace();
  for(integer sweep=1;sweep<=7;sweep=sweep+1)begin
   integer level;level=7-sweep;
   vs=1;repeat(2)@(negedge clk);vs=0;repeat(200000)@(negedge clk);
   for(integer i=0;i<65536;i=i+1)
    if({dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]}!=(expected[i]?3'(level):3'd0))$fatal(1,"fade mismatch level %d address %d got %d",level,i,{dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]});
  end
  // Seed every stored intensity to verify saturating decay.
  for(integer i=0;i<8;i=i+1){dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]}=3'(i);
  vs=1;repeat(2)@(negedge clk);vs=0;repeat(200000)@(negedge clk);
  for(integer i=0;i<8;i=i+1)
   if({dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]}!=3'(i==0?0:i-1))$fatal(1,"saturating fade at intensity %d",i);
  sample(64,64);active=0;repeat(2)@(negedge clk);active=1;repeat(65560)@(negedge clk);
  for(integer i=0;i<65536;i=i+1)if({dut.phosphor2[i],dut.phosphor1[i],dut.phosphor0[i]}!=0)$fatal(1,"replacement retained trace");
  // At the slowest supported pixel clock, 44.1 kHz samples arrive every
  // ~571 cycles. Alternate full-span points while sweeping all 65536 cells.
  // An isolated untouched pixel must decay once per frame at 50 and 60 Hz.
  for(integer hz=50;hz<=60;hz=hz+10)begin
   clear_trace();sample(0,0);
   {dut.phosphor2[2580],dut.phosphor1[2580],dut.phosphor0[2580]}=3'd7;
   for(integer frame=1;frame<=7;frame=frame+1)begin
    for(integer tick=0;tick<25200000/hz;tick=tick+1)begin
     @(negedge clk);vs=tick<2;
     if(tick%571==0)begin
      sample_left=(tick/571)%2==0?16'sh8000:16'sh7fff;
      sample_right=(tick/571)%2==0?16'sh7fff:16'sh8000;
      sample_toggle=!sample_toggle;
     end
    end
    if(dut.fade_busy)$fatal(1,"fade deadline missed at %0d Hz",hz);
    if({dut.phosphor2[2580],dut.phosphor1[2580],dut.phosphor0[2580]}!=3'(7-frame))
     $fatal(1,"fade under continuous full-span input at %0d Hz frame %0d",hz,frame);
   end
  end
  $display("PASS XY line octants, endpoints, stationary samples, seven-frame decay, all intensity saturation cases replacement clear and continuous 44.1 kHz full-span fade deadlines at 50/60 Hz");$finish;
 end
 initial begin #120000000;$fatal(1,"timeout");end
endmodule
