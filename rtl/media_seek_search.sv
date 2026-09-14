// Bounded byte-space search. Probes consume container bytes only; codecs stay
// empty. Both directions use the same timestamp comparison and restart path.
module media_seek_search #(
 parameter integer MAX_PROBES=18,
 parameter [40:0] PROBE_BYTES=41'd4194304
)(
 input wire clk,reset,new_file,request,program_stream,origin_valid,
 input wire [32:0] origin,
 input wire [34:0] target_q,
 input wire [63:0] file_size,
 input wire reader_start,
 input wire [63:0] reader_position,
 input wire [7:0] response_tag,
 input wire point_found,probe_end,
 input wire [32:0] point_pts,
 input wire [40:0] point_pack,point_sequence,
 output reg busy=0,probing=0,restart=0,
 output reg [7:0] tag=0,
 output reg [40:0] start_offset=0,video_start=0
);
localparam IDLE=0,START_PROBE=1,WAIT_PROBE=2,DECIDE=3,FINAL_START=4;
reg [2:0] state=IDLE;
reg [40:0] low=0,high=0,best_pack=0,best_sequence=0;
reg [32:0] target=0,movie_origin=0;
reg [5:0] attempts=0;
wire [32:0] relative_pts=point_pts-movie_origin;
wire [32:0] distance=target-relative_pts;
wire [40:0] midpoint=low+((high-low)>>1);
wire [63:0] scanned=reader_position-{23'd0,start_offset};
always @(posedge clk) begin
 restart<=0;
 if(reset || new_file) begin
  state<=IDLE;busy<=0;probing<=0;start_offset<=0;video_start<=0;
  tag<=reset ? 8'd0 : tag+1'b1;
 end else case(state)
 IDLE: if(request) begin
  busy<=1;best_pack<=0;best_sequence<=0;attempts<=0;
  target<=target_q[34:2];movie_origin<=origin;
  low<=0;high<=file_size[40:0];
  if(program_stream && origin_valid && target_q!=0 && file_size[63:41]==0) begin
   probing<=1;state<=DECIDE;
  end else begin
   start_offset<=0;video_start<=0;probing<=0;
   tag<=tag+1'b1;restart<=1;state<=FINAL_START;
  end
 end
 DECIDE: begin
  if(attempts==MAX_PROBES[5:0] || high<=low+41'd4096) begin
   start_offset<=best_pack;video_start<=best_sequence;probing<=0;
   tag<=tag+1'b1;restart<=1;state<=FINAL_START;
  end else begin
   start_offset<=midpoint;video_start<=0;
   tag<=tag+1'b1;attempts<=attempts+1'b1;restart<=1;state<=START_PROBE;
  end
 end
 START_PROBE: if(reader_start) state<=WAIT_PROBE;
 WAIT_PROBE: if(response_tag==tag) begin
  if(point_found) begin
   if(!relative_pts[32] && relative_pts<=target) begin
    best_pack<=point_pack;best_sequence<=point_sequence;
    low<=point_sequence+41'd4;
    if(distance<=33'd180000) begin
     start_offset<=point_pack;video_start<=point_sequence;probing<=0;
     tag<=tag+1'b1;restart<=1;state<=FINAL_START;
    end else state<=DECIDE;
   end else begin high<=start_offset;state<=DECIDE;end
  end else if(probe_end || (scanned>={23'd0,PROBE_BYTES} && !scanned[63])) begin
   high<=start_offset;state<=DECIDE;
  end
 end
 FINAL_START: if(reader_start) begin busy<=0;state<=IDLE;end
 default: state<=IDLE;
 endcase
end
endmodule
