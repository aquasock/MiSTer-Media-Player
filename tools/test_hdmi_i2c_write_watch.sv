`timescale 1ns/1ps
module test_hdmi_i2c_write_watch;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,pad_scl=1,pad_sda=1,local_grant=0;wire changed;
 hdmi_i2c_write_watch dut(.*);
 integer changes=0,k;
 always @(posedge clk)if(changed)changes=changes+1;
 task delay;begin repeat(8)@(negedge clk);end endtask
 task start_bus;begin pad_sda=1;pad_scl=1;delay;pad_sda=0;delay;pad_scl=0;delay;end endtask
 task stop_bus;begin pad_scl=0;pad_sda=0;delay;pad_scl=1;delay;pad_sda=1;delay;end endtask
 task put(input[7:0] b,input ack);begin
  for(k=7;k>=0;k=k-1)begin pad_scl=0;pad_sda=b[k];delay;pad_scl=1;delay;end
  pad_scl=0;pad_sda=!ack;delay;pad_scl=1;delay;pad_scl=0;delay;
 end endtask
 initial begin
  delay;reset=0;delay;
  start_bus;put(8'h72,1);put(8'h15,1);put(8'h20,1);put(8'h21,1);stop_bus;
  if(changes!=2)$fatal(1,"ACKed writes missed");
  start_bus;put(8'h72,1);put(8'h15,1);start_bus;put(8'h73,1);put(8'h20,0);stop_bus;
  start_bus;put(8'h72,1);put(8'h15,1);put(8'h20,0);stop_bus;
  start_bus;put(8'h74,1);put(8'h15,1);put(8'h20,1);stop_bus;
  if(changes!=2)$fatal(1,"read/NACK/foreign address marked changed");
  local_grant=1;start_bus;put(8'h72,1);put(8'h15,1);put(8'h00,1);stop_bus;local_grant=0;delay;
  if(changes!=2)$fatal(1,"own write retriggered");
  $display("PASS HDMI HPS-write watch ACK/data/read/NACK/address/local ownership");$finish;
 end
endmodule
