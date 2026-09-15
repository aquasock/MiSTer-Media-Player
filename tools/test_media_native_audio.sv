`timescale 1ns/1ps
// Functional PLL and hard clock-control primitive models only. The real
// production media_audio_clocks state machine is included in this test.
module altera_pll #(
 parameter fractional_vco_multiplier="",reference_clock_frequency="",operation_mode="",number_of_clocks=1,
 output_clock_frequency0="",phase_shift0="",duty_cycle0=50,pll_type="",pll_subtype=""
)(input refclk,rst,fbclk,output reg outclk=0,output locked,fboutclk);
 always #22.144274 outclk=~outclk;
 assign locked=!rst;assign fboutclk=0;
endmodule
module altclkctrl #(
 parameter clock_type="",number_of_clocks=4,width_clkselect=2,ena_register_mode="",use_glitch_free_switch_over_implementation=""
)(input[3:0] inclk,input[1:0] clkselect,input ena,output outclk);
 reg gate=0;wire selected=inclk[clkselect];
 always @(negedge selected)gate<=ena;
 assign outclk=selected&&gate;
 always @(clkselect)if(gate)$fatal(1,"clock selection changed while enabled");
 initial begin
  if(use_glitch_free_switch_over_implementation!="OFF"||ena_register_mode!="falling edge")$fatal(1,"primitive model supports the explicit gated handoff only");
 end
endmodule
module test_media_native_audio;
 reg refclk=0,config_clk=0,wr_clk=0,movie_clock=0;
 always #10 refclk=~refclk;
 always #25 config_clk=~config_clk;
 always #8.333 wr_clk=~wr_clk;
 always #20.345052 movie_clock=~movie_clock;
 reg reset=1,want_cd=0,paused=0,movie_96k=0,pcm_reset=1;
 reg[4:0] attenuation=0;
 integer sent=0,received=0,spdif_received=0;
 reg sending=0;
 wire pcm_valid=sending&&sent<=1024;
 wire[32:0] pcm_data={sent==1024,16'(sent+1),16'(65535-sent)};
 wire pcm_ready,cd_clock,finished,error;
 wire visual_active,visual_tick;
 wire signed [15:0] visual_left,visual_right;
 integer visual_received=0;
 always @(posedge cd_clock)if(visual_active&&visual_tick&&(visual_left!=0||visual_right!=0))begin
  if(visual_left!==16'(visual_received+1)||visual_right!==16'(65535-visual_received))$fatal(1,"visual tap sample order");
  visual_received=visual_received+1;
 end
 wire[35:0] position;
 reg[8:0] movie_phase=0;
 always @(posedge movie_clock)movie_phase<=movie_phase+1'b1;
 wire movie_lrclk=movie_phase[8],movie_bclk=movie_phase[3];
 wire movie_data=1,movie_spdif=1,movie_dac_l=1,movie_dac_r=0;
 wire output_mclk,output_bclk,output_lrclk,output_data,output_spdif,output_dac_l,output_dac_r;
 wire hps_scl_in,hps_sda_in,drive_scl_low,drive_sda_low;
 reg hps_scl_low=0,hps_sda_low=0,slave_scl_low=0,slave_sda_low=0,nack=0,bad_readback=0;
 wire pad_scl=!(drive_scl_low||slave_scl_low),pad_sda=!(drive_sda_low||slave_sda_low);
 wire readback_pass=dut.control.config_controller.pass==2;
 media_native_audio dut(.*);
 realtime last_clock_edge=0;
 always @(output_mclk)if(!reset)begin
  if(last_clock_edge!=0&&$realtime-last_clock_edge<20.0)$fatal(1,"short output clock pulse during handoff");
  last_clock_edge=$realtime;
 end
 `include "i2c_register_model.svh"
 always @(posedge wr_clk)if(pcm_valid&&pcm_ready)sent<=sent+1;
 reg[15:0] serial_shift=0,left_word=0,right_word=0;
 reg last_lr=1;integer serial_bits=0;
 always @(posedge dut.cd_bclk)if(!dut.rd_reset_sync[2])begin
  if(dut.cd_lrclk!=last_lr)begin
   if(serial_bits!=0)begin
    if(serial_bits!=15)$fatal(1,"I2S width");
    if(!last_lr)left_word={serial_shift[14:0],dut.cd_data};
    else begin
     right_word={serial_shift[14:0],dut.cd_data};
     if(left_word!=0||right_word!=0)begin
      if(left_word!==16'(received+1)||right_word!==16'(65535-received))$fatal(1,"CDC/I2S lost sample %0d got %h %h",received,left_word,right_word);
      received=received+1;
     end
    end
   end
   last_lr=dut.cd_lrclk;serial_shift=0;serial_bits=0;
  end else begin serial_shift={serial_shift[14:0],dut.cd_data};serial_bits=serial_bits+1;end
 end else begin last_lr=1;serial_bits=0;end
 // Check the pair actually captured by the independent SPDIF serializer.
 always @(posedge cd_clock)if(!dut.rd_reset_sync[2]&&dut.music_spdif.load_subframe_q&&!dut.music_spdif.subframe_count_q[0])begin
  if(dut.cd_left!=0||dut.cd_right!=0)begin
   if(dut.cd_left!==16'(spdif_received+1)||dut.cd_right!==16'(65535-spdif_received))$fatal(1,"SPDIF sample order %0d got %h %h",spdif_received,dut.cd_left,dut.cd_right);
   spdif_received=spdif_received+1;
  end
 end
 task settle;begin repeat(12)@(negedge refclk);end endtask
 task hps_byte(input[7:0] value);integer j;begin
  for(j=7;j>=0;j=j-1)begin hps_scl_low=1;hps_sda_low=!value[j];settle;hps_scl_low=0;settle;end
  hps_scl_low=1;hps_sda_low=0;settle;hps_scl_low=0;settle;
  if(pad_sda)$fatal(1,"Main write not ACKed");hps_scl_low=1;settle;
 end endtask
 initial begin
  wait(received==400);
  hps_sda_low=1;settle;hps_scl_low=1;settle;
  hps_byte(8'h72);hps_byte(8'h15);hps_byte(8'h20);
  hps_sda_low=1;settle;hps_scl_low=0;settle;hps_sda_low=0;settle;
  wait(!dut.cd_ready);wait(dut.cd_ready);
  if(registers[21]!=0)$fatal(1,"Main overwrite not restored to native rate");
 end
 initial begin
  for(k=0;k<256;k=k+1)registers[k]=0;
  registers[21]=8'h20;registers[2]=8'h18;
  #200;reset=0;#100000;
  want_cd=1;pcm_reset=0;sending=1;
  wait(received==200);paused=1;
  #200000;paused=0;
  wait(finished);#1;
  if(visual_received!=1024)$fatal(1,"visual tap count");
  if(error||received!=1024||spdif_received!=1024||position!=1024)$fatal(1,"native EOF received=%0d SPDIF=%0d pos=%0d err=%b",received,spdif_received,position,error);
  want_cd=0;pcm_reset=1;
  wait(!dut.select_cd&&!dut.mute);#100000;
  if(registers[21]!=8'h20||registers[3]!=0||error)$fatal(1,"movie restore");
  $display("PASS production native audio: independent CDC clocks, 1024 exact I2S/SPDIF pairs, pause, source position, drained EOF, HDMI restoration");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout state=%d selected=%b ready=%b idle=%b received=%d",dut.control.control.state,dut.select_cd,dut.cd_ready,dut.cd_idle,received);end
endmodule
