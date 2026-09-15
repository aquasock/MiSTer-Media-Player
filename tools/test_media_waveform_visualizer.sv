`timescale 1ns/1ps
module test_media_waveform_visualizer;
 reg audio_clk=0,video_clk=0;
 always #22 audio_clk=~audio_clk;
 always #3 video_clk=~video_clk;
 reg audio_active=0,sample_tick=0;
 reg signed [15:0] sample_left=0,sample_right=0;
 reg [23:0] rgb=24'h315579;
 reg hs=0,vs=0,de=0;
 wire [23:0] rgb_out;wire hs_out,vs_out,de_out;
 media_waveform_visualizer dut(.layout_de(de),.*);
`ifdef WAVEFORM_BASELINE
 wire [23:0] baseline_rgb;
 wire baseline_hs,baseline_vs,baseline_de;
 media_waveform_visualizer_baseline baseline(
  .audio_clk(audio_clk),.video_clk(video_clk),.audio_active(audio_active),.sample_tick(sample_tick),
  .sample_left(sample_left),.sample_right(sample_right),.rgb(rgb),.hs(hs),.vs(vs),.de(de),
  .rgb_out(baseline_rgb),.hs_out(baseline_hs),.vs_out(baseline_vs),.de_out(baseline_de));
 reg [26:0] baseline_delay0=0,baseline_delay1=0;
 integer compared=0;
 always @(posedge video_clk)begin
  baseline_delay0<={baseline_hs,baseline_vs,baseline_de,baseline_rgb};baseline_delay1<=baseline_delay0;
  #1;
  if(cycles>12)begin
   if({hs_out,vs_out,de_out,rgb_out}!==baseline_delay1)$fatal(1,"original waveform mismatch at cycle %0d",cycles);
   compared=compared+1;
  end
 end
`endif
 integer mode=0,n=0,phase=0;
 always @(negedge audio_clk)begin
  sample_tick=phase==0;phase=(phase+1)%512;
  if(sample_tick)begin
   n=n+1;
   if(mode==0)begin sample_left=0;sample_right=0;end
   else if(mode==1)begin sample_left=16384;sample_right=-16384;end
   else begin
    sample_left=16'($rtoi(20000.0*$sin(real'(n)*0.061)+6500.0*$sin(real'(n)*0.137)));
    sample_right=16'($rtoi(24000.0*$sin(real'(n)*0.046)));
   end
  end
 end
 reg [26:0] expected[0:8];integer p;integer cycles=0;
 reg check_bypass=1;
 always @(posedge video_clk)begin
  for(p=8;p>0;p=p-1)expected[p]=expected[p-1];
  expected[0]={hs,vs,de,rgb};cycles=cycles+1;
  #1;
  if(cycles>8)begin
   if({hs_out,vs_out,de_out}!==expected[8][26:24])$fatal(1,"sync latency");
   if(check_bypass&&rgb_out!==expected[8][23:0])$fatal(1,"bypass pixel");
  end
 end
 integer width=720,height=480,fd=0,pixels=0,bright=0;
 string output_name;
 reg capture=0,check_constant=0;
 integer check_x=0,check_y=0,constant_pixels=0;
 integer dl,dr,thick,cy_l,cy_r;
 reg [23:0] oracle;
 always @(negedge video_clk)if(check_constant&&de_out)begin
  cy_l=(height/4)+(height/8)-(height/8)/2;
  cy_r=(height/2)+(height/8)-((height/8)+1)/2;
  dl=check_y-cy_l;if(dl<0)dl=-dl;
  dr=check_y-cy_r;if(dr<0)dr=-dr;
  thick=height>=900?3:height>=600?2:1;
  oracle=24'h030810;
  if(dl<=thick*4)oracle=24'h083340;
  if(dr<=thick*4)oracle=24'h402010;
  if(dl<=thick*2)oracle=24'h127a90;
  if(dr<=thick*2)oracle=24'h904020;
  if(dl<=thick)oracle=24'h60bfff;
  if(dr<=thick)oracle=24'hffa050;
  if(rgb_out!==oracle)$fatal(1,"constant pixel x=%d y=%d got=%h expected=%h",check_x,check_y,rgb_out,oracle);
  constant_pixels=constant_pixels+1;
  if(check_x==width-1)begin check_x=0;check_y=check_y+1;end else check_x=check_x+1;
 end
 always @(negedge video_clk)if(capture&&de_out)begin
  $fwrite(fd,"%c%c%c",rgb_out[23:16],rgb_out[15:8],rgb_out[7:0]);pixels=pixels+1;
  if(rgb_out[23:16]>80||rgb_out[15:8]>100)bright=bright+1;
 end
 task tick(input bit v,input bit d,input bit h);begin
  @(negedge video_clk);vs=v;de=d;hs=h;
 end endtask
 task frame;integer xx,yy;begin
  repeat(12)tick(1,0,0);
  repeat(300)tick(0,0,0);
  for(yy=0;yy<height;yy=yy+1)begin
   for(xx=0;xx<width;xx=xx+1)tick(0,1,0);
   repeat(12)tick(0,0,1);
  end
  repeat(16)tick(0,0,0);
 end endtask
 integer j;
 initial begin
  if($value$plusargs("WIDTH=%d",width))begin end
  if($value$plusargs("HEIGHT=%d",height))begin end
  if(!$value$plusargs("OUTPUT=%s",output_name))output_name="waveform.ppm";
  frame();frame();
  if(dut.width!=12'(width)||dut.height!=12'(height))$fatal(1,"raster measurement");
  check_bypass=0;mode=1;audio_active=1;
  // A full ring of constant samples checks averaging, stereo order and CDC.
  repeat(540000)@(negedge audio_clk);
  if(dut.count!=256)$fatal(1,"history fill");
  for(j=0;j<256;j=j+1)if(dut.history[j]!==32'h40c040c0)$fatal(1,"history %d=%h",j,dut.history[j]);
  check_constant=1;frame();check_constant=0;
  if(constant_pixels!=width*height)$fatal(1,"constant render incomplete");
  mode=0;repeat(540000)@(negedge audio_clk);
  for(j=0;j<256;j=j+1)if(dut.history[j]!==0)$fatal(1,"silence did not retire history");
  if(dut.envelope!=0)$fatal(1,"envelope did not decay");
  audio_active=0;repeat(100)@(negedge audio_clk);
  if(dut.count!=0)$fatal(1,"replacement did not clear history");
  check_bypass=1;frame();check_bypass=0;
  mode=2;audio_active=1;repeat(540000)@(negedge audio_clk);
  fd=$fopen(output_name,"wb");$fwrite(fd,"P6\n%0d %0d\n255\n",width,height);
  capture=1;frame();capture=0;$fclose(fd);
  if(pixels!=width*height||bright<width)$fatal(1,"render output pixels=%0d bright=%0d",pixels,bright);
  $display("PASS waveform %0dx%0d: constant stereo samples, silence, epoch reset, movie bypass, sync alignment, %0d rendered pixels",width,height,pixels);$finish;
 end
 initial begin #500000000;$fatal(1,"timeout");end
endmodule
