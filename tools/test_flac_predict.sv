`timescale 1ns/1ps
module test_flac_predict;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0,tap_valid=0,result_ready=0,side_channel=0;
reg [5:0] order=0;reg[3:0] shift=0;
reg signed[31:0] residual=0;reg signed[16:0] history=0;reg signed[15:0] coefficient=0;
wire tap_ready,busy,result_valid,error;wire signed[16:0] result;
flac_predict_mac dut(.*);
string path;integer fd,rc,o,s,side,res,expected,err,h,c,n=0,k,j;
initial begin
 if(!$value$plusargs("vectors=%s",path))$fatal;
 fd=$fopen(path,"r");if(!fd)$fatal;
 repeat(3)@(negedge clk);reset=0;
 while(!$feof(fd))begin
  rc=$fscanf(fd,"%d %d %d %d %d %d\n",o,s,side,res,expected,err);
  if(rc!=6)$fatal(1,"bad vector");
  order=o;shift=s;side_channel=side;residual=res;start=1;
  @(negedge clk);start=0;
  if(o<=32)for(k=0;k<o;k=k+1)begin
   rc=$fscanf(fd,"%d %d\n",h,c);if(rc!=2)$fatal;
   repeat((n+k)%3)@(negedge clk);
   if(!tap_ready)$fatal(1,"tap not ready");
   history=h;coefficient=c;tap_valid=1;
   @(negedge clk);tap_valid=0;
  end
  j=0;while(!result_valid&&j<4)begin @(negedge clk);j=j+1;end
  if(!result_valid||result!==expected[16:0]||error!==err[0])
   $fatal(1,"mismatch vector %0d got %0d/%0d expected %0d/%0d",n,result,error,expected,err);
  repeat(n%5+1)begin
   @(negedge clk);
   if(!result_valid||result!==expected[16:0]||error!==err[0])$fatal(1,"backpressure stability");
  end
  result_ready=1;@(negedge clk);result_ready=0;
  if(busy||result_valid)$fatal(1,"not released");n=n+1;
 end
 // Cancel at every possible tap boundary; no stale completion may escape.
 for(k=0;k<33;k=k+1)begin
  order=32;start=1;@(negedge clk);start=0;
  repeat(k)begin tap_valid=1;history=123;coefficient=-3;@(negedge clk);end
  tap_valid=0;reset=1;@(negedge clk);reset=0;
  repeat(4)begin @(negedge clk);if(busy||result_valid||error)$fatal(1,"reset leakage");end
 end
 $display("FLAC_PREDICT_PASS %0d vectors; 33 cancellation points",n);$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
