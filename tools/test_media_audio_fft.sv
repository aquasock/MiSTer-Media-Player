`timescale 1ns/1ps
module test_media_audio_fft;
 reg clk=0;always #5 clk=~clk;
 reg active=0,sample_tick=0;reg signed [15:0] sample_left=0,sample_right=0;
 wire [255:0] levels;wire published;
 media_audio_fft dut(.*);
 reg [31:0] input_samples[0:255];integer fd,j,pass,cancel=0;string source,dest;
 initial begin
  if(!$value$plusargs("INPUT=%s",source)||!$value$plusargs("OUT=%s",dest))$fatal(1,"paths");
  if($value$plusargs("CANCEL=%d",cancel))begin end
  $readmemh(source,input_samples);repeat(10)@(negedge clk);active=1;
  for(pass=0;pass<(cancel!=0?2:1);pass=pass+1)begin
  for(j=0;j<256;j=j+1)begin
   {sample_left,sample_right}=input_samples[j];sample_tick=1;@(negedge clk);sample_tick=0;repeat(511)@(negedge clk);
  end
  if(cancel!=0&&pass==0)begin wait(dut.state==9);@(negedge clk);active=0;repeat(3)@(negedge clk);active=1;end
  end
  wait(published);@(negedge clk);fd=$fopen(dest,"w");
  for(j=0;j<256;j=j+1)$fwrite(fd,"%05x %05x\n",dut.work[j][35:18],dut.work[j][17:0]);
  $fwrite(fd,"%064x\n",levels);$fclose(fd);
  active=0;repeat(3)@(negedge clk);if(levels!=0||dut.state!=0)$fatal(1,"reset retained FFT output");
  // Cancel a partially captured window and verify the next capture starts fresh.
  active=1;sample_tick=1;@(negedge clk);sample_tick=0;repeat(5)@(negedge clk);active=0;repeat(3)@(negedge clk);
  if(dut.capture!=0||levels!=0)$fatal(1,"partial window leaked");
  $display("FFT_PASS exact output dumped, reset and cancellation");$finish;
 end
 initial begin #3000000;$fatal(1,"FFT timeout state=%d stage=%d base=%d j=%d",dut.state,dut.stage,dut.base,dut.j);end
endmodule
