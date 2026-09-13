`timescale 1ns/1fs
module test_mpg_audio_playback;
reg aclk=0;always #12.20703125 aclk=~aclk;
reg clk=0;always #5 clk=~clk;
reg reset=1,iv=0,ie=0;reg [7:0] ib;
wire ir,ve,vv,vr,apv,av,ar,vpv,ps,de;
wire [7:0] vb,ab;wire [32:0] vp,ap;
reg [7:0] bytes[0:16777215];integer size,fd,vfd,afd,pfd,idx=0,cycles=0,n=0;
reg [1023:0] path,outpath;reg [31:0] rng=32'h795137ba;
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
wire signed [15:0] output_l,output_r;
wire [31:0] played;
wire [66:0] pcm_q=pcm_mem[pcm_rd_index%4096];
mp2_pcm_output sink(aclk,reset,origin_sent,origin_value,pcm_q,pcm_wr==pcm_rd_index,
    pcm_pop,output_l,output_r,under,terr,finished,played);
always @(posedge aclk) if(!reset&&pcm_pop) begin
    if(!pcm_q[66]) $fwrite(afd,"%d %d\n",$signed(pcm_q[31:16]),$signed(pcm_q[15:0]));
    pcm_rd_index<=pcm_rd_index+1;
end
always @(posedge clk) if(!reset) begin
    if(mv&&!origin_sent) begin origin_sent<=1;origin_value<=mp-33'd9000;end
    if(pv&&ready) begin pcm_mem[pcm_wr%4096]<={1'b0,ppv,pp,pl,pr};pcm_wr<=pcm_wr+1;end
    else if(ve&&ae&&pi&&!pcm_end_written&&ready) begin
        pcm_mem[pcm_wr%4096]<={1'b1,66'd0};pcm_wr<=pcm_wr+1;pcm_end_written<=1;
    end
end
mp2_decoder decoder(clk,reset,aq[7:0],aqv,aqr,ve&&ae,aq[40:8],aq[41],pv,ready,pl,pr,pp,ppv,pe,frames,pi);
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
 while(idx<size) begin
  @(negedge clk);iv=1;ib=bytes[idx];
  @(posedge clk);if(ir) idx=idx+1;
 end
 @(negedge clk);iv=0;ie=1;
 wait(ve&&ae&&pi&&ee&&finished);repeat(20) @(negedge clk);
 if(under||terr||played!=frames*1152) $fatal(1,"playback errors underrun=%d timestamp=%d played=%0d frames=%0d",under,terr,played,frames);
 $fclose(vfd);$fclose(afd);$fclose(pfd);
 $display("MPG TIMED AUDIO PLAYBACK PASS samples=%0d frames=%0d video_bytes=%0d cycles=%0d",n,frames,voffset,cycles);$finish;
end
endmodule
