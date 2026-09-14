`timescale 1ns/1ps
// Actual MPG bytes through the production random-position ingress and point
// observer. No codec is involved in finding a restart position.
module test_media_seek_probe;
reg clk=0;always #5 clk=~clk;
reg reset=1,clear=1;
reg [7:0] mem[0:16777215];
integer length=0,index=0,offset=0,cycle=0;
integer search_target=-1,probes=0,bytes_read=0;
reg search_request=0,reader_start=0;
wire search_busy,probing,restart;
wire [7:0] tag;
reg [7:0] response_tag=0;
wire [40:0] start_offset,video_start;
reg was_busy=0;
media_seek_search search(
 .clk(clk),.reset(clear),.new_file(1'b0),.request(search_request),.program_stream(ps),
 .origin_valid(ov),.origin(origin),.target_q(35'd360000*search_target),
 .file_size({32'd0,length[31:0]}),.reader_start(reader_start),
 .reader_position({32'd0,index[31:0]}),.response_tag(response_tag),
 .point_found(found),.probe_end(ve),.point_pts(pts),.point_pack(point_pack),.point_sequence(seq),
 .busy(search_busy),.probing(probing),.restart(restart),.tag(tag),
 .start_offset(start_offset),.video_start(video_start));
initial begin
 wait(!clear);
 if(search_target>=0) begin
  wait(found);@(negedge clk);search_request=1;@(negedge clk);search_request=0;
  forever begin
   wait(restart);@(negedge clk);reset=1;offset=start_offset;index=start_offset;
   response_tag=tag;probes=probes+probing;
   repeat(12) @(negedge clk);reset=0;reader_start=1;
   @(negedge clk);reader_start=0;
  end
 end
end
string path;
wire ready,vv,ve,pv,av,apv,ps,err;
wire vr=cycle%7!=0;
wire [7:0] vb,ab;wire [32:0] vp,ap;
wire [40:0] pos,pack;
wire found,ov;wire [32:0] pts,origin;wire [40:0] point_pack,seq;
mpeg2_program_stream_ingress #(.ENABLE_FILE_POSITION(1),.ENABLE_AUDIO(1)) ingress(
 .clk(clk),.reset(reset),.input_data(mem[index]),.input_valid(!reset && index<length && cycle%5!=0),
 .input_ready(ready),.input_end(index==length),.output_data(vb),.output_valid(vv),
 .output_ready(vr),.output_end(ve),.video_pts(vp),.video_pts_valid(pv),
 .audio_data(ab),.audio_valid(av),.audio_ready(1'b1),.audio_pts(ap),.audio_pts_valid(apv),
 .is_program_stream(ps),.demux_error(err),.force_program_stream(1'b1),
 .start_file_position({9'd0,offset[31:0]}),.video_file_position(pos),.video_pack_position(pack));
media_seek_point point(.clk(clk),.clear(clear),.reset(reset),.data(vb),.valid(vv&&vr),
 .pts_valid(pv),.pts(vp),.file_position(pos),.pack_position(pack),
 .origin_valid(ov),.origin(origin),.found(found),.point_pts(pts),.point_pack(point_pack),.point_sequence(seq));
always @(posedge clk) begin
 if(!reset && index<length && cycle%5!=0 && ready) begin index<=index+1;bytes_read<=bytes_read+1;end
 cycle<=cycle+1;
 was_busy<=search_busy;
 if(search_target>=0 && was_busy && !search_busy) begin
  $display("SEARCH_RESULT target=%0d pack=%0d sequence=%0d origin=%0d probes=%0d bytes=%0d",search_target,start_offset,video_start,origin,probes,bytes_read);
  $display("PASS: actual MPG timestamp-guided direct search");$finish;
 end
 if(found && search_target<0) begin
  if(point_pack<offset || seq<point_pack || seq>=length) $fatal(1,"invalid byte positions");
  if({mem[point_pack],mem[point_pack+1],mem[point_pack+2],mem[point_pack+3]}!=32'h000001ba)
   $fatal(1,"restart is not a pack");
  $display("POINT pack=%0d sequence=%0d pts=%0d origin=%0d consumed=%0d",point_pack,seq,pts,origin,index-offset);
  $display("PASS: actual file random-position pack/sequence/I-picture/PTS observation with stalls");$finish;
 end
 if(!reset && ve && search_target<0) begin $display("NO_POINT consumed=%0d",index-offset);$finish;end
end
initial begin
 if(!$value$plusargs("HEX=%s",path)||!$value$plusargs("LEN=%d",length)) $fatal(1,"input");
 if($value$plusargs("OFFSET=%d",offset)) begin end
 if($value$plusargs("SEARCH_TARGET=%d",search_target)) begin end
 $readmemh(path,mem,0,length-1);index=offset;
 repeat(5) @(negedge clk);clear=0;reset=0;
end
initial begin #2000000000;$fatal(1,"timeout");end
endmodule
