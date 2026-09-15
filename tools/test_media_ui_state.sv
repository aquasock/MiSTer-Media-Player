`timescale 1ns/1ps
module test_media_ui_state;
reg clk=0;always #5 clk=~clk;
reg reset=1,new_file=0,loaded=0,paused=0,seeking=0;
reg [34:0] elapsed=0,target=0;
wire [90:0] state_out;
reg music_mode=0,track_changed=0,track_valid=1;
reg [34:0] track_origin=3600000;
reg [34:0] track_elapsed=360000,track_duration=3600000;
wire album_duration_known;
media_ui_state #(.CLOCK_HZ(4)) dut(.clk(clk),.reset(reset),.new_file(new_file),.loaded(loaded),
 .paused(paused),.seeking(seeking),.elapsed_q(elapsed),.target_q(target),
 .music_mode(music_mode),.track_changed(track_changed),.track_valid(track_valid),
 .track_elapsed_q(track_elapsed),.track_origin_q(track_origin),.track_duration_q(track_duration),.album_duration_known(album_duration_known),
 .duration_q(35'd36000000),.duration_valid(1'b1),.scene_state(state_out));
initial begin
 repeat(3) @(negedge clk);reset=0;new_file=1;
 @(negedge clk);new_file=0;loaded=1;
 @(negedge clk);if(!state_out[73]) $fatal(1,"first playback hidden");
 elapsed=3600000;paused=1;@(negedge clk);
 if(state_out[72:71]!=0 || state_out[34:0]!=elapsed) $fatal(1,"pause state");
 repeat(11) @(negedge clk);if(!state_out[73]) $fatal(1,"UI hid before three seconds");
 @(negedge clk);if(state_out[73]) $fatal(1,"paused wall-clock timeout");
 target=7200000;seeking=1;@(negedge clk);
 if(!state_out[73] || state_out[34:0]!=target || state_out[90:75]!=2) $fatal(1,"seek preview/epoch");
 repeat(80) @(negedge clk);if(!state_out[73]) $fatal(1,"seek hid early");
 target=10800000;@(negedge clk);if(state_out[90:75]!=3) $fatal(1,"repeat seek epoch");
 seeking=0;elapsed=10780000;@(negedge clk);
 if(state_out[34:0]!=elapsed || !state_out[73]) $fatal(1,"actual landing");
 repeat(11) @(negedge clk);if(!state_out[73]) $fatal(1,"UI hid before three seconds");
 @(negedge clk);if(state_out[73]) $fatal(1,"landing timeout");
 elapsed=37000000;repeat(2) @(negedge clk);if(state_out[70]) $fatal(1,"contradictory endpoint retained");
 new_file=1;@(negedge clk);new_file=0;elapsed=0;
 if(!state_out[70] || state_out[90:75]!=4) $fatal(1,"session invalidation reset");
 // Audio sequence: exactly three seconds of track, then three of album.
 music_mode=1;loaded=0;@(negedge clk);loaded=1;@(negedge clk);
 if(!state_out[73]||state_out[69:35]!=track_duration||state_out[34:0]!=track_elapsed)$fatal(1,"initial track phase");
 repeat(11)@(negedge clk);if(state_out[69:35]!=track_duration)$fatal(1,"early album phase");
 @(negedge clk);if(!state_out[73]||state_out[69:35]!=36000000)$fatal(1,"album phase");
 if(!album_duration_known)$fatal(1,"album validity lost");
 repeat(11)@(negedge clk);if(!state_out[73])$fatal(1,"audio hid before six seconds");
 @(negedge clk);if(state_out[73])$fatal(1,"audio not hidden after six seconds");
 track_changed=1;@(negedge clk);track_changed=0;
 if(!state_out[73]||state_out[69:35]!=track_duration)$fatal(1,"natural transition track first");
 repeat(12)@(negedge clk);if(state_out[69:35]!=36000000)$fatal(1,"natural transition album second");
 // Pause interrupts the album phase with only three seconds of track values.
 paused=!paused;@(negedge clk);
 if(state_out[69:35]!=track_duration)$fatal(1,"pause not track-only");
 repeat(11)@(negedge clk);if(!state_out[73]||state_out[69:35]!=track_duration)$fatal(1,"pause timeout early");
 @(negedge clk);if(state_out[73])$fatal(1,"pause reopened album");
 paused=!paused;@(negedge clk);repeat(12)@(negedge clk);
 if(state_out[73])$fatal(1,"resume reopened album");
 // Active seek holds a relative preview with endpoint clamps.
 seeking=1;target=5400000;repeat(40)@(negedge clk);
 if(!state_out[73]||state_out[34:0]!=1800000||state_out[69:35]!=track_duration)$fatal(1,"relative seek preview");
 target=0;@(negedge clk);if(state_out[34:0]!=0)$fatal(1,"negative track preview");
 target=36000000;@(negedge clk);if(state_out[34:0]!=track_duration)$fatal(1,"track preview beyond endpoint");
 // Metadata is republished after landing. This is not a natural transition.
 track_valid=0;loaded=0;seeking=0;@(negedge clk);
 if(state_out[70])$fatal(1,"stale track duration marked known");
 repeat(3)@(negedge clk);loaded=1;track_changed=1;@(negedge clk);track_changed=0;
 repeat(2)@(negedge clk);track_valid=1;@(negedge clk);
 if(state_out[69:35]!=track_duration)$fatal(1,"landing reopened album phase");
 repeat(4)@(negedge clk);if(!state_out[73])$fatal(1,"landing hid early");
 @(negedge clk);if(state_out[73])$fatal(1,"landing extended beyond three seconds");
 // A later natural boundary still gets both phases.
 track_changed=1;@(negedge clk);track_changed=0;repeat(12)@(negedge clk);
 if(!state_out[73]||state_out[69:35]!=36000000)$fatal(1,"natural event suppressed after seek");
 new_file=1;loaded=0;music_mode=0;@(negedge clk);new_file=0;
 if(state_out[73])$fatal(1,"replacement retained audio UI");
 $display("UI_STATE_PASS");$finish;
end
endmodule
