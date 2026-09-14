`timescale 1ns/1fs
module test_mpg_audio_playback;
reg aclk=0;always #12.20703125 aclk=~aclk;
reg clk=0;always #5 clk=~clk;
reg reset=1,iv=0,ie=0;reg [7:0] ib;
wire ir,ve,vv,vr,apv,av,ar,vpv,ps,de;
wire [7:0] vb,ab;wire [32:0] vp,ap;
reg [7:0] bytes[0:16777215];integer size,fd,vfd,afd,pfd,idx=0,cycles=0,n=0;
reg [1023:0] path,outpath;reg [31:0] rng=32'h795137ba;
// Actual mounted-file reader at 20 MHz, with an ideal bounded byte/EOF CDC
// reservoir. Host service includes periodic 2 ms scheduling delays.
reg sys_clk=0;always #25 sys_clk=~sys_clk;
reg source_start=0,host_ack=0,host_wr=0;
reg [12:0] host_addr=0;reg [15:0] host_data=0;
wire [31:0] host_lba;wire [5:0] host_blocks;wire host_rd;
wire [8:0] source_data;wire source_valid;wire [3:0] source_error;
reg [8:0] source_queue[0:32767];integer source_head=0,source_tail=0;
reg source_prefill=0;
media_file_reader source_reader(.clk(sys_clk),.reset(reset),.start(source_start),
 .cancel(1'b0),.suspend(1'b0),.file_size({32'd0,size[31:0]}),.start_offset(64'd0),
 .sd_lba(host_lba),.sd_blk_cnt(host_blocks),.sd_rd(host_rd),.sd_ack(host_ack),
 .sd_buff_wr(host_wr),.sd_buff_addr(host_addr),.sd_buff_dout(host_data),
 .stream_data(source_data),.stream_valid(source_valid),
 .stream_ready(source_tail-source_head<32768),.error(source_error));
always @(posedge sys_clk) if(!reset && source_valid && source_tail-source_head<32768) begin
 source_queue[source_tail%32768]<=source_data;source_tail<=source_tail+1;
 if(source_tail-source_head>=4095 || source_data[8]) source_prefill<=1;
end
always @* begin
 iv=!reset && source_prefill && source_head<source_tail && !source_queue[source_head%32768][8];
 ib=source_queue[source_head%32768][7:0];
end
always @(posedge clk) if(!reset && source_prefill && source_head<source_tail) begin
 if(source_queue[source_head%32768][8]) begin ie<=1;source_head<=source_head+1;end
 else if(ir) begin source_head<=source_head+1;idx<=idx+1;end
end
integer host_n,host_base,host_j,host_requests=0;
initial forever begin
 wait(host_rd);
 host_n=(host_blocks+1)*256;host_base=host_lba*512;host_requests=host_requests+1;
 repeat(host_requests%10==0 ? 40000 : 200) @(negedge sys_clk);
 host_ack=1;
 for(host_j=0;host_j<host_n;host_j=host_j+1) begin
  @(negedge sys_clk);host_wr=0;
  @(negedge sys_clk);host_addr=host_j;
  host_data={host_base+host_j*2+1<size?bytes[host_base+host_j*2+1]:8'd0,
             host_base+host_j*2<size?bytes[host_base+host_j*2]:8'd0};host_wr=1;
 end
 @(negedge sys_clk);host_wr=0;host_ack=0;
 repeat(10) @(negedge sys_clk);
end
mpeg2_program_stream_ingress #(.ENABLE_AUDIO(1)) ingress(clk,reset,ib,iv,ir,ie,vb,vv,vr,ve,vp,vpv,ab,av,ar,ap,apv,ps,de);
wire [41:0] aq;wire aqv,aqr,ae;
av_stream_fifo audio_fifo(clk,reset,{apv,ap,ab},av,ar,aq,aqv,aqr,ae);
wire pv,pe,pi;wire signed [15:0] pl,pr;wire [32:0] pp;wire ppv;wire [31:0] frames;
reg [66:0] pcm_mem[0:4095];
integer pcm_wr=0,pcm_rd_index=0;
wire ready=pcm_wr-pcm_rd_index<4096;
reg pcm_end_written=0,origin_sent=0;
reg [32:0] origin_value;
wire pcm_pop,under,terr,finished;
reg playback_pause=0,playback_seek=0;
reg [32:0] playback_target=0;
integer skipped_frames=0;
always @(posedge clk) if(!reset && decoder.state==decoder.BEGIN_FRAME && decoder.discard_frame) skipped_frames<=skipped_frames+1;
wire signed [15:0] output_l,output_r;
wire [31:0] played;
wire [66:0] pcm_q=pcm_mem[pcm_rd_index%4096];
mp2_pcm_output #(.ENABLE_PLAYBACK_CONTROL(1)) sink(aclk,reset,playback_pause,playback_seek,playback_target,origin_sent,origin_value,pcm_q,pcm_wr==pcm_rd_index,
    pcm_pop,output_l,output_r,under,terr,finished,played);
initial begin
 if($test$plusargs("seek")) begin
  wait(played>=4800);@(negedge aclk);
  playback_target=origin_value+9000+54000;playback_seek=1;
  // Independent video metadata consumption must reach the destination while
  // the actual demux, bounded audio queues, decoder and PCM sink run together.
  wait(bpv && bp>=playback_target);
  wait(!sink.sample_distance[35] && pcm_wr>pcm_rd_index);
  @(negedge aclk);playback_seek=0;
 end
 if($test$plusargs("pause")) begin
  wait(played>=4800);@(negedge aclk);playback_pause=1;
  repeat(2457600) @(negedge aclk);
  playback_pause=0;
 end
end
always @(posedge aclk) if(!reset&&pcm_pop) begin
    if(!pcm_q[66]&&!sink.skipping) $fwrite(afd,"%d %d\n",$signed(pcm_q[31:16]),$signed(pcm_q[15:0]));
    pcm_rd_index<=pcm_rd_index+1;
end
always @(posedge clk) if(!reset) begin
    if(mv&&!origin_sent) begin origin_sent<=1;origin_value<=mp-33'd9000;end
    if(pv&&ready) begin pcm_mem[pcm_wr%4096]<={1'b0,ppv,pp,pl,pr};pcm_wr<=pcm_wr+1;end
    else if(ve&&ae&&pi&&!pcm_end_written&&ready) begin
        pcm_mem[pcm_wr%4096]<={1'b1,66'd0};pcm_wr<=pcm_wr+1;pcm_end_written<=1;
    end
end
mp2_decoder #(.ENABLE_SEEK_SKIP(1)) decoder(clk,reset,aq[7:0],aqv,aqr,ve&&ae,aq[40:8],aq[41],pv,ready,pl,pr,pp,ppv,pe,frames,pi,playback_seek,playback_target);
wire [42:0] vq;wire vqv,vqr,memrd,memwr;wire [28:0] addr;wire [63:0] din;
reg [63:0] mem[0:1048575],dq;reg dqv=0;
wire mb=rng[4:3]==0;
reg eof_written=0;
wire vin_ready;assign vr=vin_ready;
mpeg2_av_ddr_fifo vfifo(clk,reset,{ve,vpv,vp,vb},vv||(ve&&!eof_written),vin_ready,vq,vqv,vqr,addr,din,memrd,memwr,mb,dq,dqv);
always @(posedge clk) begin
 dqv<=0;
 if(reset) eof_written<=0;
 else begin
  if(ve&&!eof_written&&vin_ready) eof_written<=1;
  if(memwr&&!mb) mem[addr[19:0]]<=din;
  if(memrd&&!mb) begin dq<=mem[addr[19:0]];dqv<=1;end
 end
end
wire [7:0] eb,sb;wire ev,er,ee,sv,mv,bpv;wire [32:0] mp,bp;
mpeg2_pes_metadata_expand expand(clk,reset,vq,vqv,vqr,eb,ev,er,ee);
mpeg2_h262_inband_metadata metadata(.clk(clk),.reset(reset),.input_data(eb),.input_valid(ev),.input_ready(er),.input_end(ee),
.stream_data(sb),.stream_valid(sv),.stream_ready(cycles%200==0),.metadata_valid(mv),.pts_90k(mp),
.picture_structure(),.top_field_first(),.repeat_first_field(),.progressive_frame(),.metadata_count());
mpeg2_pes_picture_pts bind_pts(clk,reset,sb,sv,mv,mp,bpv,bp);
integer voffset=0;
always @(posedge clk) if(!reset) begin
 cycles<=cycles+1;
 if(cycles>100000000) $fatal(1,"timeout input %0d/%0d frames %0d",idx,size,frames);
 if(source_error) $fatal(1,"mounted source error %d",source_error);
 if(de||pe) $fatal(1,"error demux %d audio %d",de,pe);
 if(pv&&ready) n<=n+1;
 if(sv) begin $fwrite(vfd,"%c",sb);voffset<=voffset+1;end
 if(bpv) $fwrite(pfd,"%d %d\n",voffset-4,bp);
end
always @(negedge clk) rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
initial begin
 if(!$value$plusargs("input=%s",path)||!$value$plusargs("output=%s",outpath)) $fatal;
 fd=$fopen(path,"rb");size=$fread(bytes,fd);$fclose(fd);
 vfd=$fopen({$sformatf("%0s",outpath),".m2v"},"wb");afd=$fopen({$sformatf("%0s",outpath),".pcm.txt"},"w");pfd=$fopen({$sformatf("%0s",outpath),".pts.txt"},"w");
 repeat(5) @(negedge clk);reset=0;
 @(negedge sys_clk);source_start=1;@(negedge sys_clk);source_start=0;
 wait(ve&&ae&&pi&&ee&&finished);repeat(2000) @(negedge clk);
 if(under||terr||(!$test$plusargs("seek") && played!=frames*1152)) $fatal(1,"playback errors underrun=%d timestamp=%d played=%0d frames=%0d",under,terr,played,frames);
 if($test$plusargs("seek") && (skipped_frames==0 || playback_seek)) $fatal(1,"seek did not bypass frames or complete");
 $display("AUDIO SEEK skipped_frames=%0d played=%0d",skipped_frames,played);
 $fclose(vfd);$fclose(afd);$fclose(pfd);
 $display("MPG TIMED AUDIO PLAYBACK PASS samples=%0d frames=%0d video_bytes=%0d cycles=%0d",n,frames,voffset,cycles);$finish;
end
endmodule
