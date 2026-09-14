`timescale 1ns/1ps
module test_media_hdmi_audio_control;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,want_cd=0,movie_96k=0;
 wire clients_idle=1,clock_ready=1,clock_applied_cd=clock_cd;
 wire clock_cd,mute,cd_ready,error,drive_scl_low,drive_sda_low,hps_scl_in,hps_sda_in;
 reg hps_scl_low=0,hps_sda_low=0,slave_scl_low=0,slave_sda_low=0,nack=0,bad_readback=0;
 wire pad_scl=!(drive_scl_low||slave_scl_low),pad_sda=!(drive_sda_low||slave_sda_low);
 media_hdmi_audio_control #(.QUIET_CYCLES(32),.BUS_FREE_CYCLES(8),.QUARTER_CYCLES(4),.STRETCH_LIMIT(200),.GRANT_LIMIT(10000)) dut(.*);
 wire readback_pass=dut.config_controller.pass==2;
 `include "i2c_register_model.svh"
 task step;begin @(posedge clk);#1;@(negedge clk);end endtask
 task settle;begin repeat(8)step;end endtask
 task wait_running(input cd);begin
  k=0;while((mute||clock_cd!=cd)&&k<100000)begin step;k=k+1;end
  if(mute||clock_cd!=cd||error||cd_ready!=cd)$fatal(1,"platform did not reach selected mode");
 end endtask
 task hps_byte(input[7:0] value);integer j;begin
  for(j=7;j>=0;j=j-1)begin hps_scl_low=1;hps_sda_low=!value[j];settle;hps_scl_low=0;settle;end
  hps_scl_low=1;hps_sda_low=0;settle;hps_scl_low=0;settle;
  if(pad_sda)$fatal(1,"modeled Main write was not ACKed");hps_scl_low=1;settle;
 end endtask
 initial begin
  for(k=0;k<256;k=k+1)registers[k]=0;
  registers[21]=8'h2b;registers[2]=8'h18;
  step;reset=0;settle;
  if(mute||starts!=0)$fatal(1,"changed movie startup");
  want_cd=1;wait_running(1);
  if(registers[21]!=8'h0b||registers[2]!=8'h18||registers[3]!=8'h80)$fatal(1,"native setup");
  // Model Main rewriting its 48 kHz sampling-rate register during playback.
  hps_sda_low=1;settle;hps_scl_low=1;settle;
  hps_byte(8'h72);hps_byte(8'h15);hps_byte(8'h2b);
  hps_sda_low=1;settle;hps_scl_low=0;settle;hps_sda_low=0;settle;
  if(!mute)$fatal(1,"Main write did not trigger mute/reapply");wait_running(1);
  if(registers[21]!=8'h0b)$fatal(1,"Main write not corrected");
  want_cd=0;movie_96k=1;wait_running(0);
  if(registers[21]!=8'hab||registers[2]!=8'h30||registers[3]!=0)$fatal(1,"movie restoration");
  want_cd=1;bad_readback=1;k=0;while(!error&&k<100000)begin step;k=k+1;end
  if(!error||!mute||cd_ready)$fatal(1,"readback failure not muted");
  bad_readback=0;want_cd=0;movie_96k=0;wait_running(0);
  if(registers[21]!=8'h2b||registers[2]!=8'h18||registers[3]!=0)$fatal(1,"movie recovery");
  $display("PASS connected HDMI control: native entry, Main overwrite/reapply, movie restoration, fault recovery");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
