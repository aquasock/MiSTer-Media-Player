`timescale 1ns/1ps
module test_media_seek_search;
reg clk=0;always #5 clk=~clk;
reg reset=1,new_file=0,request=0,program_stream=1,origin_valid=1;
reg [32:0] origin=33'h1ffff0000;
reg [34:0] target_q=0;
reg [63:0] file_size=64'd17179869184,reader_position=0;
reg reader_start=0,reader_idle=1,point_found=0,probe_end=0;
reg [7:0] response_tag=0;
reg [32:0] point_pts=0;
reg [40:0] point_pack=0,point_sequence=0;
wire busy,probing,restart;wire [7:0] tag;
wire [40:0] start_offset,video_start;
media_seek_search dut(.*);
integer probes=0,cycles=0;
reg no_points=0;
reg [40:0] sampled_offset;
reg sampled_probe;
reg [7:0] sampled_tag;
always @(posedge clk) cycles<=cycles+1;
// Delayed host retirement/configuration delivery, including stale responses.
initial forever begin
 wait(restart);sampled_offset=start_offset;sampled_probe=probing;sampled_tag=tag;
 repeat(15) @(negedge clk);
 point_found=0;probe_end=0;response_tag=sampled_tag;reader_position=sampled_offset;
 repeat(9) @(negedge clk);reader_start=1;
 @(negedge clk);reader_start=0;
 if(sampled_probe) begin
  probes=probes+1;repeat(19) @(negedge clk);
  // Variable density: 1 MiB/second in the first half, 2 MiB/second
  // in the second. The search must use observed timestamps, not CBR.
  point_pack=((sampled_offset>>20)+1)<<20;
  point_sequence=point_pack+41'd511;
  if(point_pack>=file_size || no_points) probe_end=1;
  else begin
   point_pts=origin+(point_pack<(file_size>>1) ? (point_pack>>20)*90000 :
    ((file_size>>21)+((point_pack-(file_size>>1))>>21))*90000);
   point_found=1;
  end
 end
end
task seek(input integer seconds);
 integer before_probes;
 reg [32:0] landed;
 begin
  before_probes=probes;@(negedge clk);target_q=35'd360000*seconds;request=1;
  @(negedge clk);request=0;wait(busy);wait(!busy);
  if(probing || probes-before_probes>18) $fatal(1,"unbounded search");
  if(program_stream && origin_valid && seconds!=0 && !no_points) begin
   landed=start_offset<(file_size>>1) ? (start_offset>>20) :
      (file_size>>21)+((start_offset-(file_size>>1))>>21);
   if(landed>seconds || (seconds<12000 && seconds-landed>3))
    $fatal(1,"bad landing target=%0d landed=%0d offset=%0d",seconds,landed,start_offset);
   if(start_offset!=0 && video_start!=start_offset+511) $fatal(1,"lost sequence position");
  end else if(start_offset!=0 || video_start!=0) $fatal(1,"fallback offset");
  $display("SEARCH target=%0d offset=%0d probes=%0d",seconds,start_offset,probes-before_probes);
 end
endtask
initial begin
 repeat(5) @(negedge clk);reset=0;
 seek(5000);seek(4990);seek(5290);seek(30);seek(10);seek(10000);seek(12000);
 seek(13000);seek(0);
 program_stream=0;seek(300);program_stream=1;
 origin_valid=0;seek(300);origin_valid=1;
 no_points=1;seek(300);no_points=0;
 @(negedge clk);request=1;target_q=360000000;
 @(negedge clk);request=0;wait(probing);@(negedge clk);new_file=1;
 @(negedge clk);new_file=0;
 if(busy || probing || start_offset!=0) $fatal(1,"new file failed to invalidate search");
 $display("PASS: bidirectional VBR search, long/unseen jumps, >4 GiB addresses, PTS wrap, bounded probes, EOF, raw/missing-PTS fallback and invalidation");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
