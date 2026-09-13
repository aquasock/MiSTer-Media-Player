`timescale 1ns/1ps
module test_media_color_control;
reg sys=0,dec=0,vid=0,reset=1,display=0,frame=0;
reg [1:0] mode=0;
wire matrix;
always #25 sys=~sys;
always #8 dec=~dec;
always #18 vid=~vid;
media_color_control dut(sys,dec,vid,reset,mode,display,frame,matrix);
task settle;begin repeat(40)@(negedge vid);end endtask
task boundary(input bit expected_value);begin
 frame=1;@(negedge vid);frame=0;
 if(matrix!==expected_value)$fatal(1,"frame-boundary color mismatch");
end endtask
initial begin
 settle;reset=0;boundary(0);
 display=1;settle;if(matrix!==0)$fatal(1,"mid-frame seam");boundary(1);
 mode=1;settle;if(matrix!==1)$fatal(1,"mid-frame override seam");boundary(0);
 display=0;mode=2;settle;boundary(1);
 mode=0;settle;boundary(0);
 mode=3;display=1;settle;boundary(1);
 reset=1;@(negedge vid);if(matrix!==0)$fatal(1,"reset color");reset=0;
 settle;boundary(1);
 $display("PASS color control: async mailboxes, Auto/601/709, frame-only changes, reserved mode and reset");$finish;
end
endmodule
