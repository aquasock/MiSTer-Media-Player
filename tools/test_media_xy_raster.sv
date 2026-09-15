`timescale 1ns/1ps
// Independent coordinate/palette oracle; fill a stationary asymmetric map so
// every output pixel can be checked, including noninteger scaling and borders.
module test_media_xy_raster;
 reg clk=0;always #5 clk=~clk;
 reg active=1,hs=0,vs=0,de=0;
 wire [23:0] out;wire ho,vo,deo;
 media_xy_visualizer dut(.clk(clk),.active(active),.sample_toggle(1'b0),
 .sample_left(16'sd0),.sample_right(16'sd0),.rgb(24'h123456),.hs(hs),.vs(vs),.de(de),.layout_de(de),
 .rgb_out(out),.hs_out(ho),.vs_out(vo),.de_out(deo));
 integer w=640,h=480,s,ox,oy,frame,xx,yy,checks=0;
 reg [26:0] expected[0:8];reg checking=0;
 reg [23:0] want;
 integer px,py,level;
 function automatic [23:0] color(input integer v);
  reg [2:0] t;
  begin t=3'(v);color={2'b00,t,t,t,t,t[2:1],2'b00,t,t};end
 endfunction
 always @(posedge clk)begin
  expected[0]<={hs,vs,de,want};
  for(integer i=1;i<9;i=i+1)expected[i]<=expected[i-1];
  #1;
  if(checking&&expected[8][24])begin
   if({ho,vo,deo,out}!==expected[8])$fatal(1,"XY pixel got %h expected %h",{ho,vo,deo,out},expected[8]);
   checks=checks+1;
  end
 end
 initial begin
  if($value$plusargs("W=%d",w))begin end
  if($value$plusargs("H=%d",h))begin end
  s=w<h?w:h;ox=(w-s)/2;oy=(h-s)/2;
  repeat(65560)@(negedge clk);
  // Freeze only fading; production read/mapping/palette pipeline runs intact.
  force dut.fade_busy=0;
  for(integer y=0;y<256;y=y+1)for(integer x=0;x<256;x=x+1)begin
   level=((x/3)^(y/5))&7;
   {dut.phosphor2[y*256+x],dut.phosphor1[y*256+x],dut.phosphor0[y*256+x]}=3'(level);
  end
  for(frame=0;frame<4;frame=frame+1)begin
   for(yy=-10;yy<h+10;yy=yy+1)for(xx=-20;xx<w+20;xx=xx+1)begin
    vs=yy<-8;hs=xx<-12;de=yy>=0&&yy<h&&xx>=0&&xx<w;
    want=24'h123456;
    if(de)begin
     want=0;
     if(xx>=ox&&xx<ox+s&&yy>=oy&&yy<oy+s)begin
      px=(xx-ox)*256/s;py=(yy-oy)*256/s;
      want=color(((px/3)^(py/5))&7);
     end
    end
    checking=frame==3;
    @(negedge clk);
   end
  end
  if(checks!=w*h)$fatal(1,"pixel count %d expected %d",checks,w*h);
  $display("PASS XY raster %0dx%0d, all %0d pixels match independent coordinate and palette oracle",w,h,checks);$finish;
 end
endmodule
