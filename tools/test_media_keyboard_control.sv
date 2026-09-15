`timescale 1ns/1ps
module test_media_keyboard_control;
reg clk=0;always #5 clk=~clk;
reg reset=1,new_file=0,enabled=1,osd_open=0,seek_done=0,restart_complete=0;
reg [10:0] key=0;
reg [34:0] elapsed_q=35'd36000000;
reg seek_enabled=1,duration_valid=1;
reg [34:0] duration_q=35'd288000000;
wire paused,seek_active,restart;
integer restarts=0;
always @(posedge clk) if(restart) restarts<=restarts+1;
wire [34:0] seek_target_q;
media_keyboard_control #(.ENABLE_SEEK_GATE(1)) dut(.*);
task event_key(input [8:0] code,input down);
 begin @(negedge clk);key={!key[10],down,code};repeat(3) @(negedge clk);end
endtask
task finish_seek;
 begin restart_complete=1;repeat(3) @(negedge clk);restart_complete=0;
 seek_done=1;repeat(3) @(negedge clk);seek_done=0;repeat(3) @(negedge clk);end
endtask
task check_jump(input [8:0] code,input [34:0] expected);
 integer before_restarts;
 begin before_restarts=restarts;event_key(code,1);if(!seek_active||seek_target_q!=expected) $fatal(1,"jump %h got %d expected %d",code,seek_target_q,expected);
 event_key(code,0);
 if(restarts-before_restarts!=(code==9'h16b ? 1 : 0)) $fatal(1,"wrong restart direction");
 finish_seek();end
endtask
function [8:0] fkey(input integer n);
 case(n)
  0:fkey=9'h005;1:fkey=9'h006;2:fkey=9'h004;3:fkey=9'h00c;
  4:fkey=9'h003;5:fkey=9'h00b;6:fkey=9'h083;7:fkey=9'h00a;
 endcase
endfunction
task section_jump(input integer n);
 reg [63:0] expected;
 integer before_restarts;
 begin
  expected=({29'd0,duration_q}*n)/8;before_restarts=restarts;
  event_key(fkey(n),1);
  if(!seek_active||seek_target_q!=expected[34:0]) $fatal(1,"section %d target %d expected %d",n,seek_target_q,expected);
  if(restarts-before_restarts!=(expected<elapsed_q?1:0)) $fatal(1,"section restart direction");
  event_key(fkey((n+1)%8),1);event_key(fkey((n+1)%8),0);
  if(seek_target_q!=expected[34:0]) $fatal(1,"busy section replaced target");
  finish_seek();event_key(fkey(n),1);
  if(seek_active) $fatal(1,"held function key repeated");
  event_key(fkey(n),0);
 end
endtask
integer i,j;
initial begin
 repeat(3) @(negedge clk);reset=0;
 event_key(9'h029,1);if(!paused) $fatal(1,"space pause");
 event_key(9'h029,1);if(!paused) $fatal(1,"typematic toggled pause");
 event_key(9'h029,0);event_key(9'h029,1);if(paused) $fatal(1,"space resume");
 event_key(9'h029,0);
 check_jump(9'h174,35'd39600000);check_jump(9'h16b,35'd32400000);
 event_key(9'h014,1);check_jump(9'h174,35'd46800000);check_jump(9'h16b,35'd25200000);
 event_key(9'h111,1);check_jump(9'h174,35'd57600000);check_jump(9'h16b,35'd14400000);
 elapsed_q=35'd3600000;check_jump(9'h16b,0);elapsed_q=35'd36000000;
 event_key(9'h014,0);event_key(9'h111,0);
 // Both sides of each modifier; releasing one Ctrl must retain the other.
 event_key(9'h014,1);event_key(9'h114,1);event_key(9'h014,0);
 event_key(9'h011,1);check_jump(9'h174,35'd57600000);
 event_key(9'h114,0);event_key(9'h011,0);
 osd_open=1;event_key(9'h029,1);event_key(9'h174,1);
 if(paused||seek_active) $fatal(1,"OSD command leaked");
 osd_open=0;event_key(9'h174,1);if(seek_active) $fatal(1,"held OSD arrow leaked");
 event_key(9'h174,0);event_key(9'h029,0);
 event_key(9'h029,1);event_key(9'h029,0);
 check_jump(9'h174,35'd39600000);if(!paused) $fatal(1,"seek lost pause");
 event_key(9'h174,1);event_key(9'h174,0);
 event_key(9'h16b,1);if(seek_target_q!=39600000) $fatal(1,"busy seek accepted");
 event_key(9'h16b,0);finish_seek();
 new_file=1;@(negedge clk);new_file=0;if(paused) $fatal(1,"new file retained pause");
 seek_enabled=0;event_key(9'h174,1);event_key(9'h174,0);
 if(seek_active||restart)$fatal(1,"music seek gate");
 event_key(9'h029,1);event_key(9'h029,0);if(!paused)$fatal(1,"music pause blocked");
 new_file=1;@(negedge clk);new_file=0;
 seek_enabled=1;
 // All targets, including very short, uneven and maximum durations.
 for(j=0;j<4;j=j+1) begin
  case(j) 0:duration_q=288000000;1:duration_q=7;2:duration_q=288000003;3:duration_q={35{1'b1}};endcase
  for(i=0;i<8;i=i+1)section_jump(i);
 end
 if(paused)$fatal(1,"section seek changed playing state");
 event_key(9'h029,1);event_key(9'h029,0);section_jump(4);
 if(!paused)$fatal(1,"section seek lost pause");
 duration_valid=0;event_key(fkey(2),1);
 if(seek_active)$fatal(1,"unknown duration accepted");
 duration_valid=1;event_key(fkey(2),1);
 if(seek_active)$fatal(1,"held unknown key accepted");event_key(fkey(2),0);
 duration_q=0;event_key(fkey(2),1);event_key(fkey(2),0);
 if(seek_active)$fatal(1,"zero duration accepted");duration_q=288000000;
 osd_open=1;event_key(fkey(3),1);osd_open=0;event_key(fkey(3),1);
 if(seek_active)$fatal(1,"OSD function key leaked");event_key(fkey(3),0);
 seek_enabled=0;event_key(fkey(4),1);event_key(fkey(4),0);
 if(seek_active)$fatal(1,"section seek gate ignored");seek_enabled=1;
 new_file=1;event_key(fkey(5),1);new_file=0;event_key(fkey(5),1);
 if(seek_active||paused)$fatal(1,"replacement function key leaked");event_key(fkey(5),0);
 enabled=0;event_key(fkey(6),1);event_key(fkey(6),0);
 if(seek_active)$fatal(1,"empty section seek accepted");
 enabled=0;event_key(9'h029,1);event_key(9'h174,1);
 if(paused||seek_active) $fatal(1,"empty player accepted control");
 $display("PASS: keyboard modifiers, direction, bounds, typematic, OSD, busy and pause retention");$finish;
end
endmodule
