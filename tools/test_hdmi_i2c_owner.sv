`timescale 1ns/1ps
module test_hdmi_i2c_owner;
reg clk=0;always #5 clk=~clk;
reg reset=1,hps_scl_low=0,hps_sda_low=0,local_request=0,local_done=0;
reg local_scl_low=0,local_sda_low=0,slave_scl_low=0,slave_sda_low=0;
wire drive_scl_low,drive_sda_low,local_grant,hps_scl_in,hps_sda_in;
wire pad_scl=!(drive_scl_low||slave_scl_low);
wire pad_sda=!(drive_sda_low||slave_sda_low);
hdmi_i2c_owner #(.BUS_FREE_CYCLES(8)) dut(.*);
integer k;
task step;begin @(posedge clk);#1;@(negedge clk);end endtask
task settle;begin repeat(10)step;end endtask
task acquire;begin
 local_request=1;k=0;
 while(!local_grant&&k<100)begin step;k=k+1;end
 if(!local_grant)$fatal(1,"grant timeout");local_request=0;
end endtask
initial begin
 step;reset=0;settle;
 // HPS START followed by SCL high/data high inside the transaction must not
 // look like a free bus, even when it lasts longer than the free-time guard.
 hps_sda_low=1;settle;hps_scl_low=1;settle;
 local_request=1;hps_sda_low=0;settle;hps_scl_low=0;settle;
 if(local_grant)$fatal(1,"interrupted HPS transaction");
 // A repeated START likewise retains HPS ownership.
 hps_sda_low=1;settle;hps_scl_low=1;settle;
 // Slave ACK and clock stretching pass back unmodified to HPS.
 hps_sda_low=0;slave_sda_low=1;slave_scl_low=1;hps_scl_low=0;settle;
 if(hps_scl_in||hps_sda_in||local_grant)$fatal(1,"slave response lost");
 hps_scl_low=1;slave_scl_low=0;slave_sda_low=0;hps_sda_low=1;settle;
 hps_scl_low=0;settle;hps_sda_low=0; // STOP
 acquire;
 if(hps_scl_in||!hps_sda_in)$fatal(1,"HPS not held busy");
 // Local START and repeated START; HPS driver activity cannot reach pins.
 local_sda_low=1;settle;local_scl_low=1;settle;
 hps_sda_low=1;hps_scl_low=1;local_sda_low=0;settle;
 local_scl_low=0;settle;
 if(!pad_scl||!pad_sda)$fatal(1,"HPS leaked into local transfer");
 local_sda_low=1;settle;local_scl_low=1;settle;
 local_done=1;step;local_done=0;settle;
 if(!local_grant)$fatal(1,"released without STOP");
 // Release HPS intents as a real controller waiting on bus-busy would do.
 hps_scl_low=0;hps_sda_low=0;
 local_scl_low=0;settle;local_sda_low=0; // STOP
 repeat(30)step;
 if(local_grant||!hps_scl_in||!hps_sda_in)$fatal(1,"release failed");
 // Reset restores pass-through and clears an acquired idle lease.
 acquire;reset=1;step;
 if(local_grant)$fatal(1,"reset grant");
 $display("HDMI_I2C_OWNER_PASS active/repeated-start/ACK/stretch/isolation/STOP/reset");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
