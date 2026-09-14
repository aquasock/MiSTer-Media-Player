`timescale 1ns/1ps
module test_flac_stream;
 reg clk=0;always #5 clk=~clk;
 reg reset=1;
 byte unsigned bytes[0:2000000],pcm[0:1000000];
 integer length,pcm_length,ptr=0,cycle=0,committed=0,frames=0,c0=0,c1=0;
 integer fd,n,i,expected_error=0,reset_at=0,inject_store=0;reg replayed=0;
 string input_path,pcm_path;
 wire store_error=inject_store!=0&&dut.state==23;
 wire input_ready,metadata_valid,begin_valid,sample_valid,sample_channel,commit_valid,finished;
 wire[35:0] total_samples,frame_position;wire[15:0] frame_size,sample_index;
 wire[3:0] channel_assignment,error;wire signed[16:0] sample_data;
 wire input_valid=ptr<length && cycle%7!=0;
 wire begin_ready=cycle%5!=0,sample_ready=cycle%11!=0,commit_ready=cycle%13!=0;
 reg signed[16:0] first_channel[0:65535];
 reg signed[15:0] left_frame[0:65535],right_frame[0:65535];
 wire signed[15:0] left_sample,right_sample;wire stereo_error;
 flac_stereo stereo(.assignment_code(channel_assignment),.channel0(first_channel[sample_index]),
  .channel1(sample_data),.left(left_sample),.right(right_sample),.error(stereo_error));
 flac_stream_decoder dut(.clk(clk),.reset(reset),.input_data(bytes[ptr]),.input_valid(input_valid),
  .input_end(ptr==length),.input_ready(input_ready),.metadata_valid(metadata_valid),.total_samples(total_samples),
  .begin_valid(begin_valid),.begin_ready(begin_ready),.frame_size(frame_size),.channel_assignment(channel_assignment),
  .frame_position(frame_position),.sample_valid(sample_valid),.sample_ready(sample_ready),
  .sample_channel(sample_channel),.sample_index(sample_index),.sample_data(sample_data),
  .commit_valid(commit_valid),.commit_ready(commit_ready),.store_error(store_error),.finished(finished),.error(error));
 initial begin
  if(!$value$plusargs("input=%s",input_path)||!$value$plusargs("pcm=%s",pcm_path))$fatal(1,"paths required");
  n=$value$plusargs("store_error=%d",inject_store);n=$value$plusargs("error=%d",expected_error);n=$value$plusargs("reset_at=%d",reset_at);
  fd=$fopen(input_path,"rb");if(fd==0)$fatal(1,"input open");length=$fread(bytes,fd);$fclose(fd);
  fd=$fopen(pcm_path,"rb");if(fd==0)$fatal(1,"PCM open");pcm_length=$fread(pcm,fd);$fclose(fd);
  if(length==$size(bytes)||pcm_length==$size(pcm))$fatal(1,"test buffer too small");
  repeat(3)@(negedge clk);reset=0;
 end
 always @(posedge clk)begin
  if(reset)begin ptr<=0;committed=0;frames=0;c0=0;c1=0;end
  else begin
   cycle<=cycle+1;
   if(cycle>100000000)$fatal(1,"timeout ptr=%0d state=%0d",ptr,dut.state);
   if(input_valid&&input_ready)ptr<=ptr+1;
   if(begin_valid&&begin_ready)begin
    if(frame_position!=36'(committed))$fatal(1,"begin position");c0=0;c1=0;
   end
   if(sample_valid&&sample_ready)begin
    if(!sample_channel)begin
     if(sample_index!=16'(c0))$fatal(1,"channel0 order");
     first_channel[sample_index]=sample_data;c0=c0+1;
    end else begin
     if(sample_index!=16'(c1)||c0!=int'(frame_size))$fatal(1,"channel1 order");
     if(stereo_error)$fatal(1,"stereo overflow");
     left_frame[sample_index]=left_sample;right_frame[sample_index]=right_sample;c1=c1+1;
    end
   end
   if(commit_valid&&commit_ready)begin
    if(c0!=int'(frame_size)||c1!=int'(frame_size))$fatal(1,"incomplete frame commit");
    for(i=0;i<int'(frame_size);i=i+1)begin
     n=(committed+i)*4;
     if(n+3>=pcm_length)$fatal(1,"extra PCM");
     if(left_frame[i]!==$signed({pcm[n+1],pcm[n]})||right_frame[i]!==$signed({pcm[n+3],pcm[n+2]}))
      $fatal(1,"PCM mismatch sample=%0d got=%0d,%0d expected=%0d,%0d",committed+i,left_frame[i],right_frame[i],$signed({pcm[n+1],pcm[n]}),$signed({pcm[n+3],pcm[n+2]}));
    end
    committed=committed+int'(frame_size);frames=frames+1;
   end
   if(error!=0)begin
    if(expected_error==0||int'(error)!=expected_error)$fatal(1,"unexpected error=%0d ptr=%0d state=%0d",error,ptr,dut.state);
    $display("PASS rejected error=%0d committed=%0d",error,committed);$finish;
   end
   if(finished)begin
    if(expected_error!=0)$fatal(1,"accepted damaged input");
    if(committed*4!=pcm_length||!metadata_valid||(total_samples!=0&&total_samples!=36'(committed)))$fatal(1,"final sample count");
    if(reset_at!=0&&!replayed)$fatal(1,"reset not exercised");
    $display("PASS samples=%0d frames=%0d reset=%0d cycles=%0d",committed,frames,replayed,cycle);$finish;
   end
  end
 end
 always @(negedge clk)begin
  if(!reset&&reset_at!=0&&!replayed&&ptr>=reset_at)begin
   reset=1;replayed=1;
  end else if(reset&&replayed)reset=0;
 end
endmodule
