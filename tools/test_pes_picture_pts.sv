module test_pes_picture_pts;
reg clk=0;always #5 clk=~clk;
reg reset=1;reg [42:0] data;reg iv=0;wire ir;
wire [7:0] byte_data,stream_data;wire byte_valid,byte_ready,stream_valid,eof;
reg stream_ready=0;wire meta_valid;wire [32:0] meta_pts,bound_pts;wire bound_valid;
integer bound_count=0,byte_count=0;reg [31:0] rng=32'h352fa17d;
mpeg2_pes_metadata_expand expand(clk,reset,data,iv,ir,byte_data,byte_valid,byte_ready,eof);
mpeg2_h262_inband_metadata metadata(.clk(clk),.reset(reset),.input_data(byte_data),.input_valid(byte_valid),
.input_ready(byte_ready),.input_end(eof),.stream_data(stream_data),.stream_valid(stream_valid),.stream_ready(stream_ready),
.pts_90k(meta_pts),.metadata_valid(meta_valid),.picture_structure(),.top_field_first(),.repeat_first_field(),.progressive_frame(),.metadata_count());
mpeg2_pes_picture_pts bind_pts(clk,reset,stream_data,stream_valid,meta_valid,meta_pts,bound_valid,bound_pts);
always @(negedge clk) begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};stream_ready=rng[0]||rng[1];end
always @(posedge clk) begin
 if(stream_valid) byte_count=byte_count+1;
 if(bound_valid) begin
  if(bound_count==0&&(bound_pts!=90000||byte_count!=4)) $fatal(1,"first binding %d %d",bound_pts,byte_count);
  if(bound_count==1&&(bound_pts!=93003||byte_count!=16)) $fatal(1,"split prefix binding %d %d",bound_pts,byte_count);
  bound_count=bound_count+1;
 end
end
task send;
 input [7:0] b;input marked;input [32:0] pts;
 begin
  @(negedge clk);iv=1;data={1'b0,marked,pts,b};
  @(posedge clk);while(!ir) @(posedge clk);
  @(negedge clk);iv=0;
 end
endtask
initial begin
 repeat(4) @(negedge clk);reset=0;
 send(0,1,90000);send(0,0,0);send(1,0,0);send(0,0,0);
 send(8'h12,0,0);send(8'h34,0,0);send(8'h56,0,0);send(8'h78,0,0);
 send(0,0,0);send(0,0,0);send(1,1,93003);send(0,0,0);
 send(0,0,0);send(0,0,0);send(1,0,0);send(0,0,0);
 send(8'h12,0,0);send(8'h34,0,0);send(8'h56,0,0);send(8'h78,0,0);
 @(negedge clk);iv=1;data={1'b1,42'd0};
 repeat(40) @(negedge clk);
 if(bound_count!=2||byte_count!=20) $fatal(1,"counts %d %d",bound_count,byte_count);
 $display("PES picture PTS PASS split prefix, stalls, EOF");$finish;
end
endmodule
