// Controls visibility uses wall time; the cue clock remains presentation time.
// Session changes invalidate all future cue-provider state. Seeking invalidates
// cue selection; a future provider must reselect at the actual landing position.
module media_ui_state #(parameter integer CLOCK_HZ=20000000)(
 input wire clk,reset,new_file,loaded,paused,seeking,
 input wire [34:0] elapsed_q,target_q,duration_q,
 input wire duration_valid,
 input wire music_mode,track_changed,track_valid,
 input wire [34:0] track_elapsed_q,track_duration_q,
 output wire album_duration_known,
 output wire [90:0] scene_state
);
reg [15:0] session=0;
reg paused_d=0,seeking_d=0,loaded_d=0;
reg [34:0] target_d=0;
reg [31:0] hide_count=0;
reg invalid_duration=0;
wire activity=paused!=paused_d || seeking!=seeking_d || (seeking && target_q!=target_d) || (loaded&&!loaded_d);
wire known=duration_valid && !invalid_duration;
assign album_duration_known=known;
wire track_phase=music_mode&&!seeking&&hide_count!=0&&hide_count<=CLOCK_HZ*3;
wire [34:0] display_duration=track_phase&&track_valid?track_duration_q:duration_q;
wire [34:0] display_elapsed=track_phase&&track_valid?track_elapsed_q:(seeking?target_q:elapsed_q);
// Bits 72:71 are reserved after removal of playback-status labels.
assign scene_state={session,loaded,loaded&&(seeking||hide_count!=0),2'b00,known,
 display_duration,display_elapsed};
always @(posedge clk) begin
 paused_d<=paused;seeking_d<=seeking;loaded_d<=loaded;target_d<=target_q;
 if(reset) begin session<=0;hide_count<=0;invalid_duration<=0;end
 else if(new_file) begin session<=session+1'b1;hide_count<=0;invalid_duration<=0;end
 else begin
  if(seeking && (!seeking_d || target_q!=target_d)) session<=session+1'b1;
  if(activity || seeking || (music_mode&&track_changed)) hide_count<=music_mode?CLOCK_HZ*6:CLOCK_HZ*3;
  else if(hide_count!=0) hide_count<=hide_count-1'b1;
  // A presented timestamp beyond the qualified endpoint contradicts the
  // continuous-timeline probe. Seek previews are not evidence of discontinuity.
  if(loaded && !seeking && duration_valid && elapsed_q>duration_q+35'd360000)
   invalid_duration<=1;
 end
end
endmodule
