`timescale 1ns/1ps
module test_picture_color;
reg clk=0,reset=1,valid=0,start=0,is_b=0,scratch=0,complete=0;
reg [7:0] matrix=2;
reg [1:0] active=0,display_bank=0;
reg display_scratch=0,display_scratch_bank=0;
wire selected;
always #5 clk=~clk;
mpeg2_h262_picture_color dut(clk,reset,valid,matrix,start,is_b,scratch,
 complete,active,display_bank,display_scratch,display_scratch_bank,selected);
task tick; begin @(posedge clk);#1;@(negedge clk);end endtask
task header(input bit b,input bit has_tag,input [7:0] m);
begin is_b=b;valid=has_tag;matrix=m;start=1;tick;start=0;end endtask
task check(input bit wanted); begin #1;if(selected!==wanted)$fatal(1,"wrong picture color");end endtask
initial begin
 tick;reset=0;
 header(0,1,1);active=1;tick;check(1); // I in bank 0: 709
 header(0,1,6);active=2;tick;check(1); // future P: 601, I still displayed
 header(1,1,1);scratch=0;complete=1;tick;complete=0;tick;
 display_scratch=1;check(1);
 // Next header changes color while the retained B is still displayed.
 header(1,1,5);scratch=1;complete=1;tick;complete=0;tick;check(1);
 display_scratch_bank=1;check(0);
 display_scratch=0;display_bank=1;check(0);
 // Reference bank 2 completion shares an edge with the following B header.
 header(0,1,1);active=0;is_b=1;valid=0;matrix=1;start=1;tick;start=0;
 display_bank=2;check(1);
 scratch=0;complete=1;tick;complete=0;tick;
 display_scratch=1;display_scratch_bank=0;check(0);
 // Missing/unspecified/reserved tags all use compatibility 601.
 for(integer m=0;m<256;m=m+1)begin
  header(1,1,m);complete=1;tick;complete=0;tick;check(m==1);
 end
 reset=1;tick;check(0);
 $display("PASS picture color: three reference banks, both scratch banks, queued display, simultaneous header/commit, all matrix tags and reset");$finish;
end
endmodule
