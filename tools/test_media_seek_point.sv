`timescale 1ns/1ps
module test_media_seek_point;
reg clk=0; always #5 clk=~clk;
reg clear=0,reset=0,valid=0,pts_valid=0;
reg [7:0] data=0;
reg [32:0] pts=0;
reg [40:0] file_position=41'h100000000,pack_position=41'h100000000;
wire origin_valid,found;
wire [32:0] origin,point_pts;
wire [40:0] point_pack,point_sequence;
media_seek_point dut(.*);
task byte_in(input [7:0] b,input bit marker,input [32:0] timestamp);
 begin
  @(negedge clk);valid=1;data=b;pts_valid=marker;pts=timestamp;
  @(negedge clk);valid=0;pts_valid=0;file_position=file_position+1;
  // Idle bus changes must not affect the accepted stream.
  data=8'hff;pts=33'h1ffffffff;
 end
endtask
task prefix(input [7:0] code,input bit marker,input [32:0] timestamp);
 begin byte_in(0,marker,timestamp);byte_in(0,0,0);byte_in(1,0,0);byte_in(code,0,0);end
endtask
task restart(input bit movie);
 begin @(negedge clk);reset=1;clear=movie;@(negedge clk);reset=0;clear=0;end
endtask
reg [40:0] expected_sequence,expected_pack;
reg [32:0] expected_pts;
integer n;
initial begin
 restart(1);
 // A non-I candidate must not publish a result.
 prefix(8'hb3,1,33'h1ffff0000);prefix(0,0,0);byte_in(0,0,0);byte_in(8'h10,0,0);
 if(found || !origin_valid || origin!=33'h1ffff0000) $fatal(1,"non-I/origin");
 expected_sequence=file_position;expected_pack=pack_position;expected_pts=33'd12345;
 prefix(8'hb3,1,expected_pts);prefix(0,0,0);
 // Another PES timestamp during the picture header belongs to later data.
 byte_in(0,1,33'd99999);byte_in(8'h08,0,0);
 if(!found || point_sequence!=expected_sequence || point_pack!=expected_pack || point_pts!=expected_pts)
  $fatal(1,"candidate fields not associated with I-picture");
 for(n=0;n<8;n=n+1) begin
  pack_position=pack_position+4096;
  prefix(8'hb3,1,n);prefix(0,0,0);byte_in(0,0,0);byte_in(8'h08,0,0);
  if(!found || point_sequence!=expected_sequence || point_pack!=expected_pack || point_pts!=expected_pts)
   $fatal(1,"published result changed");
 end
 restart(0);
 if(found || !origin_valid || origin!=33'h1ffff0000) $fatal(1,"probe reset lost origin");
 // PTS beginning inside a picture prefix cannot timestamp that picture.
 prefix(8'hb3,0,0);byte_in(0,0,0);byte_in(0,1,7);byte_in(1,0,0);byte_in(0,0,0);
 byte_in(0,0,0);byte_in(8'h08,0,0);
 if(found) $fatal(1,"late PTS accepted");
 expected_sequence=file_position;expected_pack=pack_position;
 prefix(8'hb3,1,42);prefix(0,0,0);byte_in(0,0,0);byte_in(8'h08,0,0);
 if(!found || point_sequence!=expected_sequence || point_pack!=expected_pack || point_pts!=42)
  $fatal(1,"fresh candidate after reset");
 restart(1);
 if(found || origin_valid) $fatal(1,"new movie retained valid result");
 $display("PASS: seek-point association, stalls, stable publication, reset, late PTS and >4GiB addresses");
 $finish;
end
endmodule
