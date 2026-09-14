// Conservative continuous-timeline PS endpoint observer. It consumes only the
// bounded preflight windows, never decoder bytes or playback bank ownership.
module media_duration_window(
 input wire clk,reset,
 input wire [7:0] in_data,input wire in_valid,output wire in_ready,
 input wire origin_valid,input wire [32:0] origin,
 output reg [32:0] first_pts=0,
 output wire valid,output wire [34:0] end_q,
 output reg have_origin=0,
 output wire healthy,output wire [7:0] video_stream_id
);
// Tail windows can start inside an arbitrary payload. Align to a pack prefix
// before feeding the production demux, replaying that prefix without buffering.
reg [23:0] sync=24'hffffff;
reg aligned=0;
reg [2:0] inject=0;
wire demux_ready,timeline_ready;
reg picture_event=0,gop_event=0;
wire observer_ready=timeline_ready && !picture_event && !gop_event;
assign in_ready=observer_ready && inject==0 && (!aligned || demux_ready);
wire [7:0] es;
wire es_valid,pts_valid,demux_error,packet_boundary;
wire [32:0] pts;
mpeg2_h262_program_stream_demux #(.STRICT_TIMESTAMPS(1)) demux(
 .clk(clk),.reset(reset),.in_data(inject!=0 ? (inject==1?8'hba:inject==2?8'h01:8'h00):in_data),
 .in_valid(observer_ready && aligned && (inject!=0 || in_valid)),.in_ready(demux_ready),
 .video_data(es),.video_valid(es_valid),.video_ready(observer_ready),.video_pts(pts),.video_pts_valid(pts_valid),
 .audio_data(),.audio_valid(),.audio_ready(1'b1),.audio_pts(),.audio_pts_valid(),
 .stream_end(),.demux_error(demux_error),.input_file_position(41'd0),
 .video_file_position(),.video_pack_position(),.packet_boundary(packet_boundary),.selected_video_id(video_stream_id));
reg [23:0] prefix=24'hffffff;
reg [3:0] header_count=0;
reg [7:0] header_code=0;
reg [3:0] ext_id=0;
reg pending=0,sequence_seen=0,bad=0,picture_seen=0,slice_seen=0;
reg picture_has_pts=0;
reg [32:0] picture_pts=0;
reg [9:0] picture_tr=0;
reg [2:0] picture_type=0;
wire timeline_known,timeline_bad;
media_duration_timeline timeline(
 .clk(clk),.reset(reset),.gop(gop_event),.picture(picture_event),
 .temporal_reference(picture_tr),.picture_type(picture_type),.period_q(period_q),
 .pts_valid(picture_has_pts && origin_valid),.pts(picture_pts),.origin(origin),
 .ready(timeline_ready),.known(timeline_known),.bad(timeline_bad),.end_q(end_q));
reg [32:0] pending_pts=0;
reg [2:0] pts_age=0;
reg [14:0] period_q=0;

// Half a 33-bit wrap is the unambiguous comparison domain (~13.25 hours).
// Unknown is intentional for longer/discontinuous timelines.
assign healthy=aligned && !demux_error;
assign valid=origin_valid && picture_seen && slice_seen && period_q!=0 &&
 !bad && !timeline_bad && timeline_known && observer_ready && !demux_error &&
 packet_boundary && header_count==0 && end_q!=0;
always @(posedge clk) begin
 picture_event<=0;gop_event<=0;
 if(reset) begin
  sync<=24'hffffff;aligned<=0;inject<=0;prefix<=24'hffffff;
  header_count<=0;pending<=0;sequence_seen<=0;bad<=0;picture_seen<=0;
  slice_seen<=0;period_q<=0;have_origin<=0;pts_age<=0;picture_has_pts<=0;
 end else begin
  if(!aligned && in_valid && in_ready) begin
   sync<={sync[15:0],in_data};
   if(sync==24'h000001 && in_data==8'hba) begin aligned<=1;inject<=4;end
  end
  if(inject!=0 && demux_ready && observer_ready) inject<=inject-1'b1;
  if(es_valid && observer_ready) begin
   prefix<={prefix[15:0],es};
   if(pending && pts_age!=7) pts_age<=pts_age+1'b1;
   if(pts_valid) begin
    pending<=1;pending_pts<=pts;pts_age<=0;
    if(!have_origin) begin have_origin<=1;first_pts<=pts;end
   end
   if(header_count!=0) begin
    header_count<=header_count-1'b1;
    if(header_code==0) begin
     if(header_count==2) picture_tr[9:2]<=es;
     if(header_count==1) begin
      picture_tr[1:0]<=es[7:6];picture_type<=es[5:3];
      if(sequence_seen) begin picture_event<=1;picture_seen<=1;slice_seen<=0;end
     end
    end
    if(header_code==8'hb3 && header_count==1) begin
     case(es[3:0])
      1:period_q<=15015;2:period_q<=15000;3:period_q<=14400;
      4:period_q<=12012;5:period_q<=12000;
      default:begin period_q<=0;bad<=1;end
     endcase
    end
    if(header_code==8'hb5) begin
     if(header_count==6) ext_id<=es[7:4];
     // Only progressive, unextended-rate pictures are in this player's scope.
     if(ext_id==1 && header_count==5 && !es[3]) bad<=1;
     if(ext_id==1 && header_count==1 && es[6:0]!=0) bad<=1;
     if(ext_id==8 && header_count==3 && es[1]) bad<=1; // repeat_first_field
     if(ext_id==8 && header_count==4 && es[1:0]!=3) bad<=1;
    end
   end
   if(prefix==24'h000001) begin
    header_code<=es;
    if(es==8'hb3) begin sequence_seen<=1;header_count<=4;end
    if(es==8'hb5) begin header_count<=6;ext_id<=0;end
    if(es==8'hb8) begin gop_event<=1;header_count<=4;end
    if(es==0) begin
     header_count<=2;
     picture_has_pts<=pending && pts_age>=2 && !pts_valid;
     picture_pts<=pending_pts;
     if(pending && pts_age>=2 && !pts_valid) pending<=0;
    end
    if(es>=1 && es<=8'haf && picture_seen) slice_seen<=1;
   end
  end
 end
end
endmodule
