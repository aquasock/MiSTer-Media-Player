`timescale 1ns/1ps
module test_mp2_timestamp_tolerance;
reg clk=0;always #5 clk=~clk;
reg reset=1,origin_valid=0;
reg [32:0] origin,first_pts;
reg [66:0] data;
wire rd,underrun,timestamp_error,finished;
wire signed [15:0] audio_l,audio_r;
wire [31:0] count;
integer index=0,cycle=0,last_cycle=0,test,late_ticks;
mp2_pcm_output dut(.clk(clk),.reset(reset),.pause(1'b0),.seek(1'b0),.seek_target(33'd0),
 .origin_valid(origin_valid),.origin_pts(origin),.fifo_data(data),.fifo_empty(1'b0),
 .fifo_rd(rd),.audio_l(audio_l),.audio_r(audio_r),.underrun(underrun),
 .timestamp_error(timestamp_error),.finished(finished),.samples_played(count));
always @(negedge clk)begin
 // The first four MP2 frames establish an exact grid; frame five carries
 // the observed backward timestamp step. Inferred subsequent stamps follow it.
 data={index==6912,index%1152==0,
  33'(first_pts+(index/1152)*2160-(index>=4608?late_ticks:0)),
  16'(index),16'(-index)};
end
always @(posedge clk)if(!reset)begin
 cycle=cycle+1;
 if(cycle>4000000)$fatal(1,"timeout");
 if(rd && index<6912)begin
  if(index!=0 && cycle-last_cycle!=512)$fatal(1,"warning tolerance altered sample cadence");
  last_cycle=cycle;
 end
 if(rd)index=index+1;
end
always @(negedge clk)if(!reset && count!=0 && !finished)begin
 if(audio_l!==16'(count-1) || audio_r!==16'(-(count-1)))
  $fatal(1,"warning tolerance changed PCM samples");
end
initial begin
 for(test=0;test<7;test=test+1)begin
  case(test)
   0:late_ticks=0;
   1:late_ticks=2;
   2:late_ticks=15;
   3:late_ticks=90;
   4:late_ticks=91;
   5:late_ticks=900;
   6:late_ticks=15;
  endcase
  reset=1;index=0;cycle=0;
  // Final case crosses the 33-bit timestamp wrap before the backward step.
  first_pts=test==6?33'h1fffff000:33'd47852;origin=first_pts-90;
  repeat(5)@(negedge clk);reset=0;origin_valid=1;
  @(negedge clk);origin_valid=0;
  wait(finished);@(negedge clk);
  if(underrun || timestamp_error!=(late_ticks>90) || count!=6912)
   $fatal(1,"lateness=%0d warning=%b underrun=%b count=%d",late_ticks,timestamp_error,underrun,count);
  $display("TIMESTAMP TOLERANCE PASS lateness=%0d warning=%b samples=%0d",late_ticks,timestamp_error,count);
 end
 $finish;
end
endmodule
