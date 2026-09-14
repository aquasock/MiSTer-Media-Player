`timescale 1ns/1ps
module test_media_seek_diagnostics;
reg clk=0;always #5 clk=~clk;
reg clear=1,seeking=0,paused=0,progress=0;
reg [15:0] errors=0;
wire valid;wire [447:0] snapshot;
media_seek_diagnostics #(.STALL_CYCLES(8)) dut(
 .clk(clk),.clear(clear),.seeking(seeking),.paused(paused),.progress(progress),
 .state_flags(12'habc),.errors(errors),.subcodes(32'h12345678),.scheduler(32'hfedcba98),
 .elapsed_q(35'h512345678),.target_q(35'h623456789),.display_pts(33'h198765432),
 .picture(18'h23456),.video_level(21'd12345),.audio_level(11'd123),
 .pcm_level(13'd4096),.reservoir_min(16'd42),.valid(valid),.snapshot(snapshot));
reg [447:0] first;
reg [11:0] h=0,v=0;
wire overlay,bit_value;
media_seek_overlay renderer(.clk(clk),.reset(clear),.valid(valid),.de(1'b1),
 .snapshot(snapshot),.h(h),.v(v),.enable(overlay),.pixel(bit_value));
integer x,y,ppm;
integer fd,i;reg [31:0] checksum;
task step;begin @(negedge clk);end endtask
initial begin
 step();clear=0;errors=4;repeat(12)step();if(valid)$fatal(1,"armed before seek");
 seeking=1;step();if(!valid||snapshot[95:92]!=2)$fatal(1,"entry fault absent");
 first=snapshot;errors=16'h3004;seeking=0;paused=1;repeat(12)step();
 seeking=1;repeat(12)step();if(snapshot!==first)$fatal(1,"first fault overwritten");
 clear=1;step();clear=0;errors=0;seeking=0;paused=0;step();seeking=1;progress=1;
 repeat(12)step();if(valid)$fatal(1,"progress timeout");
 errors=4;step();if(!valid||snapshot[95:92]!=1)$fatal(1,"seek error missing");
 checksum=0;for(i=0;i<13;i=i+1)checksum=checksum^snapshot[i*32+:32];
 if(checksum!==snapshot[416+:32])$fatal(1,"checksum");
 fd=$fopen("/tmp/seek-diagnostic-words.hex","w");
 for(i=0;i<14;i=i+1)$fdisplay(fd,"%08x",snapshot[i*32+:32]);$fclose(fd);
 ppm=$fopen("/tmp/seek-diagnostic.ppm","w");$fwrite(ppm,"P3\n720 480\n255\n");
 for(y=0;y<480;y=y+1)begin
  for(x=0;x<720;x=x+1)begin
   h=x;v=y;#1;
   if(overlay)$fwrite(ppm,"%0d %0d %0d\n",bit_value?255:0,bit_value?255:0,bit_value?255:0);
   else $fwrite(ppm,"18 52 86\n");
   step();
  end
 end
 $fclose(ppm);
 clear=1;step();clear=0;errors=0;seeking=0;progress=0;paused=1;
 repeat(12)step();if(valid)$fatal(1,"ordinary pause timeout");
 seeking=1;repeat(12)step();if(!valid||snapshot[95:92]!=3)$fatal(1,"paused seek timeout absent");
 $display("SEEK_DIAGNOSTICS_PASS");$finish;
end
endmodule
