// A random-access I-picture in an open GOP can be followed in coding order
// by leading B-pictures requiring the reference before that GOP. Discard
// those pictures until the next I/P reference; keep sequence/extension data.
// Six bytes of lookahead identify picture_coding_type before emitting any
// part of that picture. PTS markers remain associated with accepted bytes.
module media_seek_video_filter(
 input wire clk,reset,resync_start,
 input wire [41:0] input_data,
 input wire input_valid,input_end,
 output wire input_ready,
 output wire [41:0] output_data,
 output wire output_valid,output_end,
 input wire output_ready
);
reg [7:0] bytes[0:7];
// One asynchronous read port; use distributed RAM for the wide PTS queue.
(* ramstyle = "MLAB, no_rw_check" *) reg [33:0] markers[0:7];
reg [2:0] rd=0,wr=0;
reg [3:0] count=0;
reg warmup=0,reference_seen=0,dropping=0,pending_valid=0;
reg [32:0] pending_pts=0;
wire [2:0] r1=rd+3'd1,r2=rd+3'd2,r3=rd+3'd3,r5=rd+3'd5;
wire picture=count>=6 && {bytes[rd],bytes[r1],bytes[r2],bytes[r3]}==32'h00000100;
wire boundary=count>=4 && {bytes[rd],bytes[r1],bytes[r2]}==24'h000001 &&
 (bytes[r3]==8'hb3 || bytes[r3]==8'hb7 || bytes[r3]==8'hb8);
wire is_b=bytes[r5][5:3]==3;
wire discard=boundary ? 1'b0 : (picture ? (warmup && is_b) : dropping);
wire available=count>=6 || (input_end && count!=0);
wire consume=available && (discard || output_ready);
wire accept=input_valid && input_ready;
assign input_ready=count<8 || consume;
assign output_valid=available && !discard;
assign output_end=input_end && count==0;
assign output_data={(markers[rd][33] || (picture && pending_valid)),
 (markers[rd][33] ? markers[rd][32:0] : pending_pts),bytes[rd]};
always @(posedge clk) begin
 if(accept) begin bytes[wr]<=input_data[7:0];markers[wr]<=input_data[41:8];end
 if(reset) begin
  rd<=0;wr<=0;count<=0;warmup<=resync_start;reference_seen<=0;dropping<=0;pending_valid<=0;
 end else begin
  case({accept,consume})
   2'b10:count<=count+1'b1;
   2'b01:count<=count-1'b1;
   default:;
  endcase
  if(accept) wr<=wr+1'b1;
  if(consume) begin
   rd<=rd+1'b1;
   if(discard && markers[rd][33]) begin pending_valid<=1;pending_pts<=markers[rd][32:0];end
   if(boundary) dropping<=0;
   if(picture) begin
    dropping<=warmup && is_b;pending_valid<=0;
    if(!is_b) begin
     reference_seen<=1;
     if(reference_seen) warmup<=0;
    end
   end
  end
 end
end
endmodule
