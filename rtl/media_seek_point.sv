// Observe accepted, demultiplexed video bytes, without decoding pictures.
// Only a sequence header followed by a timestamped I-picture is a candidate.
// Addresses are absolute source-file bytes, including container overhead.
module media_seek_point(
 input wire clk,clear,reset,
 input wire [7:0] data,
 input wire valid,pts_valid,
 input wire [32:0] pts,
 input wire [40:0] file_position,pack_position,
 output reg origin_valid=0,
 output reg [32:0] origin=0,
 output reg found=0,
 output reg [32:0] point_pts=0,
 output reg [40:0] point_pack=0,point_sequence=0
);
// Output fields also hold the candidate until found validates them. Once found,
// hold the complete result until reset so the CDC consumer sees a stable bundle.
reg [1:0] zeros=0,header=0;
reg code_next=0,sequence_seen=0,pending_valid=0,picture_valid=0;
reg [40:0] prefix_position=0,prefix_pack=0,marker=0;
reg [32:0] pending_pts=0;
wire [40:0] marker_distance=prefix_position-marker;
always @(posedge clk) begin
 if(clear) begin origin_valid<=0;origin<=0;end
 else if(!reset && valid && pts_valid && !origin_valid) begin origin_valid<=1;origin<=pts;end
 if(reset || clear) begin
  zeros<=0;code_next<=0;header<=0;sequence_seen<=0;
  pending_valid<=0;picture_valid<=0;found<=0;
 end else if(valid) begin
  if(pts_valid) begin pending_pts<=pts;pending_valid<=1;marker<=file_position;end
  if(header!=0) begin
   header<=header-1'b1;
   if(header==1 && data[5:3]==3'd1 && picture_valid && !found) begin
    found<=1;
   end
  end
  if(code_next) begin
   code_next<=0;zeros<=0;
   if(data==8'hb3) begin
    sequence_seen<=1;
    if(!found) begin point_sequence<=prefix_position;point_pack<=prefix_pack;end
   end
   if(data==0) begin
    // A PTS beginning inside this picture prefix belongs to a later picture.
    picture_valid<=sequence_seen && pending_valid && !marker_distance[40] && !pts_valid;
    if(!found) point_pts<=pending_pts;
    sequence_seen<=0;header<=2;
    if(!marker_distance[40] && !pts_valid) pending_valid<=0;
   end
  end else if(data==0) begin
   if(zeros==0) begin prefix_position<=file_position;prefix_pack<=pack_position;end
   if(zeros!=2) zeros<=zeros+1'b1;
  end else begin
   if(zeros==2 && data==1) code_next<=1;
   zeros<=0;
  end
 end
end
endmodule
