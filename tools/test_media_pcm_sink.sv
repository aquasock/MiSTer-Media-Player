`timescale 1ns/1ps
module test_media_pcm_sink;
reg clk=0;always #5 clk=~clk;
reg reset=1,cancel=0,start=0,paused=0,sample_tick=0,input_valid=0,input_eof=0;
reg[35:0] start_position=0;
reg signed[15:0] input_left=0,input_right=0;
wire input_ready;wire signed[15:0] audio_left,audio_right;
wire[35:0] position;wire active,finished,error;
media_pcm_sink dut(.*);
integer samples=0,k,n,rate_div;
task step;begin @(posedge clk);#1;@(negedge clk);end endtask
task begin_file(input[35:0] base);begin
 start_position=base;start=1;step;start=0;
 if(!active||finished||error||position!=base)$fatal(1,"start");
end endtask
task tick;begin sample_tick=1;step;sample_tick=0;end endtask
task put_sample(input integer l,input integer r,input[35:0] expected_position);begin
 input_valid=1;input_left=l;input_right=r;tick;
 if(audio_left!==l[15:0]||audio_right!==r[15:0]||position!==expected_position||!active||finished||error)
  $fatal(1,"sample %0d got %0d/%0d position %0d expected %0d",samples,audio_left,audio_right,position,expected_position);
 samples=samples+1;
end endtask
initial begin
 step;reset=0;
 // Same sink accepts codec-independent PCM at either frame request cadence.
 // 512 cycles: 44.1 kHz with CD PLL or 48 kHz with movie PLL; 256: 96k output.
 for(n=0;n<2;n=n+1)begin
  rate_div=n==0?512:256;begin_file(36'd10000);
  input_valid=0;repeat(3)begin tick;if(error||position!=10000)$fatal(1,"prefill");end
  for(k=0;k<100;k=k+1)begin
   put_sample(k*317-16000,16000-k*311,10000+k);
   input_valid=0;
   repeat(rate_div-1)begin step;if(input_ready)$fatal(1,"off-tick consumption");end
   if(k%17==0)begin
    paused=1;input_valid=1;input_left=123;input_right=456;
    repeat(4)begin tick;if(input_ready||position!=10000+k||audio_left||audio_right)$fatal(1,"pause");end
    paused=0;input_valid=0;
   end
  end
  input_eof=1;input_valid=1;
  // EOF cannot erase the final sample before its next frame request.
  repeat(7)begin step;if(finished||!active||position!=10099)$fatal(1,"early EOF");end
  tick;if(!finished||active||error||position!=10100||audio_left||audio_right)$fatal(1,"EOF drain");
  repeat(3)tick;
  if(position!=10100||input_ready)$fatal(1,"EOF overrun");
  input_eof=0;input_valid=0;
 end
 // Cancel while paused with an EOF token pending. No stale finish or position.
 begin_file(36'd123456);put_sample(-32768,32767,123456);
 paused=1;input_eof=1;cancel=1;sample_tick=1;step;
 if(active||finished||error||position||input_ready)$fatal(1,"cancel");
 cancel=0;sample_tick=0;paused=0;input_eof=0;input_valid=0;
 begin_file(36'd20);put_sample(101,-102,20);
 input_valid=0;tick;
 if(!error||active||finished||position!=21||audio_left||audio_right)$fatal(1,"starvation");
 // Empty file and recovery from failed prior session.
 begin_file(0);input_valid=1;input_eof=1;tick;
 if(!finished||error||position)$fatal(1,"empty EOF");
 reset=1;step;if(active||finished||error||position)$fatal(1,"reset");
 $display("MEDIA_PCM_SINK_PASS %0d exact samples; prefill/pause/EOF/cancel/starvation",samples);$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
