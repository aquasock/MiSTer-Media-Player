`timescale 1ns/1ps
module test_hdmi_audio_config;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,request=0;reg[1:0] mode=0;
 wire ready,done,error,local_request,local_done,local_grant,local_scl_low,local_sda_low;
 wire drive_scl_low,drive_sda_low,hps_scl_in,hps_sda_in;
 reg slave_scl_low=0,slave_sda_low=0,deny_grant=0,nack=0,bad_readback=0;
 wire pad_scl=!(drive_scl_low||slave_scl_low),pad_sda=!(drive_sda_low||slave_sda_low);
 hdmi_i2c_owner #(.BUS_FREE_CYCLES(8)) owner(.clk(clk),.reset(reset),.pad_scl(pad_scl),.pad_sda(pad_sda),
  .hps_scl_low(1'b0),.hps_sda_low(1'b0),.hps_scl_in(hps_scl_in),.hps_sda_in(hps_sda_in),
  .local_request(local_request&&!deny_grant),.local_done(local_done),.local_grant(local_grant),
  .local_scl_low(local_scl_low),.local_sda_low(local_sda_low),.drive_scl_low(drive_scl_low),.drive_sda_low(drive_sda_low));
 hdmi_audio_config #(.QUARTER_CYCLES(4),.STRETCH_LIMIT(200),.GRANT_LIMIT(200)) dut(.*);
 wire readback_pass=dut.pass==2;
 `include "i2c_register_model.svh"
 task step;begin @(posedge clk);#1;@(negedge clk);end endtask
 task begin_config(input[1:0] next_mode);begin
  while(!ready)step;mode=next_mode;request=1;step;request=0;
 end endtask
 task finish_config(input expected_error);begin
  k=0;while(!done&&k<100000)begin step;k=k+1;end
  if(!done||error!=expected_error||local_grant)begin $display("pads=%b%b slave=%b%b starts=%0d stops=%0d owner_transaction=%b",pad_scl,pad_sda,slave_scl_low,slave_sda_low,starts,stops,owner.transaction);$fatal(1,"configuration result done=%b error=%b grant=%b state=%0d master=%0d",done,error,local_grant,dut.state,dut.master.state);end
  $display("mode=%0d expected_error=%0d done",mode,expected_error);step;
 end endtask
 initial begin
  for(k=0;k<256;k=k+1)registers[k]=0;
  registers[10]=8'h80;registers[21]=8'h2b;registers[1]=8'h90;registers[2]=8'h18;
  step;reset=0;repeat(20)step;
  begin_config(1);
  // A bounded slave clock stretch must delay, not corrupt, a transaction.
  while(!local_scl_low)step;slave_scl_low=1;repeat(70)step;slave_scl_low=0;
  finish_config(0);
  if(registers[10]!=0||registers[21]!=8'h0b||registers[1]!=8'h90||registers[2]!=8'h18||registers[3]!=8'h80)$fatal(1,"native register values");
  begin_config(2);finish_config(0);
  if(registers[21]!=8'hab||registers[2]!=8'h30||registers[3]!=0)$fatal(1,"96 kHz restoration");
  begin_config(0);finish_config(0);
  if(registers[21]!=8'h2b||registers[2]!=8'h18||registers[3]!=0)$fatal(1,"48 kHz restoration");
  bad_readback=1;begin_config(1);finish_config(1);bad_readback=0;
  nack=1;begin_config(1);finish_config(1);nack=0;
  deny_grant=1;begin_config(1);finish_config(1);deny_grant=0;
  begin_config(1);while(!local_scl_low)step;slave_scl_low=1;repeat(400)step;
  if(!local_grant)$fatal(1,"released ownership while bus stuck");
  slave_scl_low=0;finish_config(1);
  begin_config(3);finish_config(1);
  $display("PASS HDMI audio configuration modes/readback/NACK/stretch/timeout/ownership starts=%0d stops=%0d writes=%0d",starts,stops,writes);$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
