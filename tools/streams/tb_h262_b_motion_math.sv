`timescale 1ns/1ps
module tb_h262_b_motion_math;
reg clk=0,reset=1;
always #5 clk=~clk;
mpeg2_h262_b_core_probe parser(.clk(clk),.reset(reset),.stream_data(8'd0),.stream_valid(1'b0),.row_retired(1'b0));
mpeg2_h262_b_bidirectional_raster_engine raster(.clk(clk),.reset(reset));
integer fc,f,p,c,r,d,v,actual,checks=0;
initial begin
 for(fc=1;fc<=6;fc=fc+1)begin
  f=1<<(fc-1);
  for(p=-16*f;p<16*f;p=p+1)
   for(c=-16;c<=16;c=c+1)
    for(r=0;r<f;r=r+1)begin
     d=c==0?0:(((c<0?-c:c)-1)*f+r+1)*(c<0?-1:1);
     v=p+d;if(v< -16*f)v=v+32*f;if(v>=16*f)v=v-32*f;
     actual=$signed(parser.reconstruct_mv(p,c,r,fc));
     if(actual!=v)$fatal(1,"motion fc=%0d pred=%0d code=%0d res=%0d expected=%0d actual=%0d",fc,p,c,r,v,actual);
     checks=checks+1;
    end
 end
 for(p=-512;p<512;p=p+1)begin
  actual=$signed(raster.chroma_half_vector(p));
  if(actual!=p/2)$fatal(1,"chroma signed divide vector=%0d got=%0d",p,actual);
 end
 $display("B_MOTION_MATH_PASS combinations=%0d chroma=1024 full f_code=1..6 including vertical wrap",checks);$finish;
end
endmodule
