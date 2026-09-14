`timescale 1ns/1ps
module test_media_ui_state;
reg clk=0;always #5 clk=~clk;
reg reset=1,new_file=0,loaded=0,paused=0,seeking=0;
reg [34:0] elapsed=0,target=0;
wire [90:0] state_out;
media_ui_state #(.CLOCK_HZ(4)) dut(.clk(clk),.reset(reset),.new_file(new_file),.loaded(loaded),
 .paused(paused),.seeking(seeking),.elapsed_q(elapsed),.target_q(target),
 .duration_q(35'd36000000),.duration_valid(1'b1),.scene_state(state_out));
initial begin
 repeat(3) @(negedge clk);reset=0;new_file=1;
 @(negedge clk);new_file=0;loaded=1;
 @(negedge clk);if(!state_out[73]) $fatal(1,"first playback hidden");
 elapsed=3600000;paused=1;@(negedge clk);
 if(state_out[72:71]!=0 || state_out[34:0]!=elapsed) $fatal(1,"pause state");
 repeat(41) @(negedge clk);if(state_out[73]) $fatal(1,"paused wall-clock timeout");
 target=7200000;seeking=1;@(negedge clk);
 if(!state_out[73] || state_out[34:0]!=target || state_out[90:75]!=2) $fatal(1,"seek preview/epoch");
 repeat(80) @(negedge clk);if(!state_out[73]) $fatal(1,"seek hid early");
 target=10800000;@(negedge clk);if(state_out[90:75]!=3) $fatal(1,"repeat seek epoch");
 seeking=0;elapsed=10780000;@(negedge clk);
 if(state_out[34:0]!=elapsed || !state_out[73]) $fatal(1,"actual landing");
 repeat(41) @(negedge clk);if(state_out[73]) $fatal(1,"landing timeout");
 elapsed=37000000;repeat(2) @(negedge clk);if(state_out[70]) $fatal(1,"contradictory endpoint retained");
 new_file=1;@(negedge clk);new_file=0;elapsed=0;
 if(!state_out[70] || state_out[90:75]!=4) $fatal(1,"session invalidation reset");
 $display("UI_STATE_PASS");$finish;
end
endmodule
