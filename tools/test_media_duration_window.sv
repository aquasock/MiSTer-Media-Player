`timescale 1ns/1ps
module test_media_duration_window;
reg clk=0;always #5 clk=~clk;
reg reset=1,iv=0,ov=0;
reg [7:0] data;
wire ready,valid,have_origin;
wire [32:0] first;
reg [32:0] origin=0;
wire [34:0] endq;
media_duration_window dut(.clk(clk),.reset(reset),.in_data(data),.in_valid(iv),.in_ready(ready),
 .origin_valid(ov),.origin(origin),.first_pts(first),.valid(valid),.end_q(endq),.have_origin(have_origin));
always @(posedge clk) if($test$plusargs("DEBUG") && dut.es_valid) begin
 if(dut.prefix==24'h000001 && dut.es==0) $display("PIC pending=%d age=%d samepts=%d pts=%d relative=%d seq=%d rate=%d bad=%d",dut.pending,dut.pts_age,dut.pts_valid,dut.pending_pts,dut.relative,dut.sequence_seen,dut.period_q,dut.bad);
 if(dut.header_code==8'hb5 && dut.header_count!=0) $display("EXT id=%d count=%d byte=%h",dut.ext_id,dut.header_count,dut.es);
end
reg [7:0] bytes[0:4194303];
string path;integer length,expect_valid;reg [34:0] expect_q;
initial begin
 if(!$value$plusargs("HEX=%s",path) || !$value$plusargs("LEN=%d",length)) $fatal(1,"args");
 if($value$plusargs("ORIGIN=%d",origin)) ov=1;
 if(!$value$plusargs("VALID=%d",expect_valid)) expect_valid=-1;
 if(!$value$plusargs("END=%d",expect_q)) expect_q=0;
 $readmemh(path,bytes,0,length-1);
 repeat(3) @(negedge clk);reset=0;
 for(integer i=0;i<length;i=i+1) begin
  data=bytes[i];iv=1;
  @(posedge clk);while(!ready) @(posedge clk);
  @(negedge clk);
 end
 iv=0;repeat(8) @(negedge clk);
 $display("RESULT valid=%0d origin_valid=%0d first=%0d end=%0d bad=%0d demux_error=%0d boundary=%0d",valid,have_origin,first,endq,dut.bad,dut.demux_error,dut.packet_boundary);
 if(expect_valid>=0 && valid!=expect_valid) $fatal(1,"validity");
 if(expect_valid==1 && endq!=expect_q) $fatal(1,"endpoint got %0d expected %0d",endq,expect_q);
 $finish;
end
endmodule
