`timescale 1ns/1ps
module test_flac_ddr;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,cancel=0,start=0;
 byte unsigned bytes[0:2000000],pcm[0:1000000];
 reg[63:0] ram[0:131071];reg valid0[0:131071],valid1[0:131071];
 integer length,pcm_length,ptr=0,cycle=0,played=0,reads=0,writes=0;
 integer fd,n,i,expected_error=0,cancel_mode=0,sink_mode=0,immediate=0;
 integer delay_count=0,pending_address=0;
 reg replayed=0,restarting=0,pending_read=0;
 string input_path,pcm_path;
 wire input_ready,metadata_valid,start_ready,quiescent,pcm_valid,pcm_eof;
 wire[35:0] total_samples;wire[3:0] error;
 wire signed[15:0] pcm_left,pcm_right;
 wire[28:0] mem_addr;wire[63:0] mem_data;wire[7:0] mem_be;
 wire mem_read,mem_write;wire mem_busy=cycle%9<3;
 reg[63:0] delayed_q=0;reg delayed_valid=0;
 wire immediate_read=immediate!=0&&mem_read&&!mem_busy;
 wire[63:0] mem_q=immediate_read?ram[mem_addr[16:0]]:delayed_q;
 wire mem_q_valid=immediate_read||delayed_valid;
 wire input_valid=ptr<length && cycle%7!=0 && !restarting;
 wire tick=cycle%256==0;
 wire sink_ready,sink_active,sink_finished,sink_error;
 wire signed[15:0] audio_left,audio_right;wire[35:0] position;
 wire pcm_ready=sink_mode!=0?sink_ready:cycle%13!=0;
 flac_ddr_decoder dut(.*,.input_data(bytes[ptr]),.input_end(ptr==length));
 media_pcm_sink sink(.clk(clk),.reset(reset),.cancel(cancel),.start(start&&start_ready),.start_position(36'd0),
  .paused(1'b0),.sample_tick(tick),.input_valid(pcm_valid),.input_eof(pcm_eof),
  .input_left(pcm_left),.input_right(pcm_right),.input_ready(sink_ready),.audio_left(audio_left),.audio_right(audio_right),
  .position(position),.active(sink_active),.finished(sink_finished),.error(sink_error));
 reg held=0;reg[28:0] held_addr;reg[63:0] held_data;reg[7:0] held_be;reg held_read,held_write;
 reg check_sink=0,check_eof=0;reg signed[15:0] check_left,check_right;
 initial begin
  if(!$value$plusargs("input=%s",input_path)||!$value$plusargs("pcm=%s",pcm_path))$fatal(1,"paths required");
  n=$value$plusargs("immediate=%d",immediate);n=$value$plusargs("error=%d",expected_error);n=$value$plusargs("cancel=%d",cancel_mode);n=$value$plusargs("sink=%d",sink_mode);
  fd=$fopen(input_path,"rb");if(fd==0)$fatal(1,"input open");length=$fread(bytes,fd);$fclose(fd);
  fd=$fopen(pcm_path,"rb");if(fd==0)$fatal(1,"PCM open");pcm_length=$fread(pcm,fd);$fclose(fd);
  for(i=0;i<131072;i=i+1)begin ram[i]=64'hdeaddeaddeaddead;valid0[i]=0;valid1[i]=0;end
  repeat(3)@(negedge clk);#1;reset=0;start=1;
 end
 always @(posedge clk)begin
  cycle<=cycle+1;delayed_valid<=0;
  if(cycle>150000000)$fatal(1,"timeout state=%0d ptr=%0d played=%0d",dut.store.state,ptr,played);
  if(!reset)begin
   if(held&&{mem_read,mem_write,mem_addr,mem_data,mem_be}!={held_read,held_write,held_addr,held_data,held_be})$fatal(1,"held DDR command changed");
   held=mem_busy&&(mem_read||mem_write);held_addr=mem_addr;held_data=mem_data;held_be=mem_be;held_read=mem_read;held_write=mem_write;
   if(mem_read&&mem_write)$fatal(1,"read/write overlap");
   if((mem_read||mem_write)&&(mem_addr<29'h06080000||mem_addr>=29'h060a0000))$fatal(1,"DDR address escaped banks");
   if(mem_write&&!mem_busy)begin
    n=int'(mem_addr)-32'h06080000;
    if(dut.store.full[n>>16])$fatal(1,"overwrote committed bank");
    if(mem_be==8'h0f)begin ram[n][31:0]=mem_data[31:0];valid0[n]=1;end
    else if(mem_be==8'hf0)begin ram[n][63:32]=mem_data[63:32];valid1[n]=1;end
    else $fatal(1,"write byte enables");writes=writes+1;
   end
   if(mem_read&&!mem_busy)begin
    if(pending_read)$fatal(1,"multiple reads in flight");
    n=int'(mem_addr)-32'h06080000;
    if(!valid0[n]||!valid1[n]||(!dut.store.full[n>>16]&&!restarting))$fatal(1,"read uncommitted/incomplete frame");
    if(!immediate_read)begin pending_read=1;pending_address=n;delay_count=5+cycle%17;end
    reads=reads+1;
   end
   if(pending_read)begin
    if(delay_count==0)begin delayed_q<=ram[pending_address];delayed_valid<=1;pending_read=0;end
    else delay_count=delay_count-1;
   end
   if(start&&start_ready)begin ptr<=0;played=0;end
   else if(input_valid&&input_ready)ptr<=ptr+1;
   check_sink=0;
   if(cancel)played=0;
   else if(pcm_valid&&pcm_ready)begin
    if(pcm_eof)begin
     if(expected_error!=0||played*4!=pcm_length)$fatal(1,"wrong EOF");
     if(cancel_mode!=0&&!replayed)$fatal(1,"cancel not exercised");
     if(sink_mode==0)begin $display("PASS PCM pairs=%0d reads=%0d writes=%0d cancel=%0d cycles=%0d",played,reads,writes,replayed,cycle);$finish;end
     check_sink=1;check_eof=1;
    end else begin
     n=played*4;
     if(n+3>=pcm_length||pcm_left!==$signed({pcm[n+1],pcm[n]})||pcm_right!==$signed({pcm[n+3],pcm[n+2]}))$fatal(1,"PCM mismatch sample=%0d",played);
     played=played+1;check_sink=1;check_eof=0;check_left=pcm_left;check_right=pcm_right;
    end
   end
   if(error!=0)begin
    if(int'(error)!=expected_error)$fatal(1,"decoder error=%0d",error);
    $display("PASS rejected error=%0d played=%0d",error,played);$finish;
   end
  end
 end
 always @(negedge clk)begin
  if(!reset)begin
   if(sink_mode!=0&&check_sink)begin
    if(check_eof)begin
     if(!sink_finished||position!=36'(played))$fatal(1,"sink EOF/position");
     $display("PASS sink pairs=%0d position=%0d",played,position);$finish;
    end else if(audio_left!==check_left||audio_right!==check_right||position!=36'(played-1))$fatal(1,"sink sample/position");
   end
   if(sink_mode!=0&&sink_error)$fatal(1,"sink starved");
   if(start)begin start=0;restarting=0;end
   if(cancel)cancel=0;
   if(restarting&&start_ready)start=1;
   if(!replayed&&cancel_mode!=0&&
    ((cancel_mode==1&&mem_write&&mem_busy)||(cancel_mode==2&&mem_read&&mem_busy)||
     (cancel_mode==3&&dut.store.state==3)||(cancel_mode==4&&pcm_valid)||(cancel_mode==5&&mem_q_valid)))begin
    cancel=1;replayed=1;restarting=1;
   end
  end
 end
endmodule
