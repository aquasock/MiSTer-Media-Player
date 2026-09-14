`timescale 1ns/1ps
module test_media_audio_rate_control;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,want_cd=0,movie_96k=0,clients_idle=0,clock_ready=0,hps_changed=0;
 reg config_ready=1,config_done=0,config_error=0;
 reg[2:0] echo=0;wire clock_applied_cd=echo[2];
 always @(posedge clk)echo<={echo[1:0],clock_cd};
 wire clock_cd,mute,cd_ready,config_request,error;wire[1:0] config_mode;
 media_audio_rate_control #(.QUIET_CYCLES(8)) dut(.*);
 integer k;
 task step;begin @(posedge clk);#1;@(negedge clk);end endtask
 task request_wait;begin k=0;while(!config_request&&k<100)begin step;k=k+1;end if(!config_request)$fatal(1,"configuration timeout");step;end endtask
 task finish_config;begin config_done=1;step;config_done=0;end endtask
 initial begin
  step;reset=0;step;if(mute||clock_cd)$fatal(1,"movie startup changed");
  want_cd=1;repeat(10)step;if(!mute||clock_cd||config_request)$fatal(1,"switched before drain");
  clients_idle=1;repeat(5)step;if(!clock_cd||config_request)$fatal(1,"clock handshake");
  clock_ready=1;repeat(5)step;hps_changed=1;repeat(20)step;
  if(config_request||!mute)$fatal(1,"configured during HPS activity");
  hps_changed=0;request_wait;if(config_mode!=1)$fatal(1,"CD mode");finish_config;
  if(!cd_ready||mute)$fatal(1,"CD not released");
  hps_changed=1;step;hps_changed=0;request_wait;
  if(!mute||cd_ready)$fatal(1,"Main reconfiguration not muted");
  // Change target during an outstanding configuration: stale success must
  // not release mute or alter the clock before the transaction completes.
  want_cd=0;movie_96k=1;repeat(5)step;
  if(!clock_cd||!mute)$fatal(1,"switched mid-transaction");finish_config;
  if(!mute)$fatal(1,"stale success released output");request_wait;
  if(clock_cd||config_mode!=2)$fatal(1,"movie 96 restoration");finish_config;
  if(mute)$fatal(1,"movie not released");
  want_cd=1;request_wait;config_error=1;finish_config;config_error=0;
  if(!error||!mute||cd_ready)$fatal(1,"failure not held muted");
  want_cd=0;movie_96k=0;request_wait;if(config_mode!=0)$fatal(1,"movie 48 restore");finish_config;
  if(error||mute)$fatal(1,"failed to recover movie mode");
  $display("PASS audio handoff drain/clock/HPS refresh/stale completion/failure/48 and 96 restoration");$finish;
 end
endmodule
