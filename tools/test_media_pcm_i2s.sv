`timescale 1ns/1ps
module test_media_pcm_i2s;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,cancel=0,start=0,paused=0;
 integer sent=0,received=0,frames=0,read_frame=0,bits=0,cycles=0;
 wire input_valid=1,input_eof=sent==1024;
 wire signed[15:0] input_left=16'(sent*127+1234),input_right=16'(-sent*191-5678);
 wire input_ready,i2s_bclk,i2s_lrclk,i2s_data,finished,error;wire[35:0] position;
 media_pcm_i2s dut(.*,.start_position(36'd0));
 reg[15:0] expected_left[0:2047],expected_right[0:2047];
 reg[15:0] shift=0,word_value;reg last_lr=1;
 integer last_edge=-1,last_frame=-1;
 always @(posedge clk)begin
  cycles=cycles+1;
  if(!reset&&!start&&!cancel)begin
   if(dut.phase==0)begin
    expected_left[frames]=input_ready&&!input_eof?input_left:16'd0;
    expected_right[frames]=input_ready&&!input_eof?input_right:16'd0;
    frames=frames+1;
   end
   if(input_ready&&!input_eof)sent<=sent+1;
  end
 end
 // Decode the serial wire using I2S's one-bit delay after each LRCLK edge.
 always @(posedge i2s_bclk)if(!reset&&!start&&!cancel)begin
  if(last_edge>=0&&cycles-last_edge!=16)$fatal(1,"BCLK period");last_edge=cycles;
  if(i2s_lrclk!=last_lr)begin
   word_value={shift[14:0],i2s_data};
   if(bits!=0)begin
    if(bits!=15)$fatal(1,"word width %0d",bits);
    if(last_lr==0)begin if(word_value!==expected_left[read_frame])$fatal(1,"left mismatch %0d got=%h expected=%h",read_frame,word_value,expected_left[read_frame]);end
    else begin
     if(word_value!==expected_right[read_frame])$fatal(1,"right mismatch %0d",read_frame);
     read_frame=read_frame+1;received=received+1;
    end
   end
   if(i2s_lrclk==0)begin
    if(last_frame>=0&&cycles-last_frame!=512)$fatal(1,"sample period");last_frame=cycles;
   end
   last_lr=i2s_lrclk;shift=0;bits=0;
  end else begin shift={shift[14:0],i2s_data};bits=bits+1;end
 end
 initial begin
  repeat(3)@(negedge clk);#1;reset=0;start=1;
  @(negedge clk);start=0;
  wait(sent==200);@(negedge clk);paused=1;
  repeat(4096)@(negedge clk);paused=0;
  wait(finished);#1;
  if(error||sent!=1024||position!=1024||received<1024)$fatal(1,"EOF/position/serializer drain sent=%0d position=%0d received=%0d error=%b",sent,position,received,error);
  $display("PASS native I2S exact words, 512-clock sample cadence, pause, EOF drain: samples=%0d serial_frames=%0d",sent,received);$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
