module test_mp2_pcm_output;
reg clk=0;always #5 clk=~clk;
reg reset=1,origin_valid=0,empty=0;
reg [32:0] origin;
reg [66:0] data;
wire rd;wire signed [15:0] l,r;wire under,err,finished;wire [31:0] count;
integer index=0,cycle=0,first_cycle=0,last_cycle=0,test;
reg [32:0] first_pts;
mp2_pcm_output dut(clk,reset,1'b0,1'b0,33'd0,origin_valid,origin,data,empty,rd,l,r,under,err,finished,count);
always @(negedge clk) begin
 data={index==2304,index%1152==0,33'(first_pts+(index/1152)*2160),16'h1234,16'hfedc};
end
always @(posedge clk) if(!reset) begin
 cycle=cycle+1;
 if(cycle>1300000) $fatal(1,"timeout");
 if(rd&&index<2304) begin
  if(index==0) first_cycle=cycle;
  else if(cycle-last_cycle!=512) $fatal(1,"sample cadence %0d",cycle-last_cycle);
  last_cycle=cycle;
 end
 if(rd) index=index+1;
end
initial begin
 for(test=0;test<2;test=test+1) begin
  reset=1;index=0;cycle=0;first_pts=test==0?33'd90000:33'd30;
  origin=first_pts-33'd90;
  repeat(5) @(negedge clk);reset=0;origin_valid=1;
  @(negedge clk);origin_valid=0;
  wait(finished);@(negedge clk);
  if(under||err||count!=2304||first_cycle<24576||first_cycle>24580) $fatal(1,"PCM result %d %d %d first %0d",under,err,count,first_cycle);
  $display("PCM PASS test=%0d count=%0d start=%0d",test,count,first_cycle);
 end
 $finish;
end
endmodule
