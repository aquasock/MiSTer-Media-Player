`timescale 1ns/1ps
module test_srt_file;
reg clk=0;always #5 clk=~clk;
reg reset=1,valid=0,consume=0;reg [8:0] data=0;
wire ready,cv,eof,warn;wire [36:0] first,last;
reg [6:0] addr=0;wire [7:0] charq;wire [6:0] n0,n1;
media_srt_parser dut(.clk(clk),.reset(reset),.data(data),.valid(valid),.ready(ready),
 .cue_valid(cv),.cue_ready(consume),.start_q(first),.end_q(last),.length0(n0),.length1(n1),
 .text_addr(addr),.text_q(charq),.eof(eof),.warning(warn));
reg [8:0] bytes_in[0:262143];reg [36:0] expected[0:262143];
string input_file,expect_file;integer byte_count,word_count,cue_count;
integer i,c,j,k=0,l0,l1;
initial begin
 if(!$value$plusargs("INPUT=%s",input_file)||!$value$plusargs("EXPECTED=%s",expect_file)||
    !$value$plusargs("BYTES=%d",byte_count)||!$value$plusargs("WORDS=%d",word_count)||
    !$value$plusargs("CUES=%d",cue_count))$fatal(1,"missing arguments");
 $readmemh(input_file,bytes_in,0,byte_count-1);$readmemh(expect_file,expected,0,word_count-1);
 repeat(3)@(negedge clk);reset=0;
 fork
  begin
   for(i=0;i<byte_count;i=i+1)begin
    @(negedge clk);while(!ready)@(negedge clk);
    data=bytes_in[i];valid=1;@(negedge clk);valid=0;
   end
  end
  begin
   for(c=0;c<cue_count;c=c+1)begin
    wait(cv);
    if(first!==expected[k] || last!==expected[k+1] || n0!=expected[k+2] || n1!=expected[k+3])
     $fatal(1,"cue %d header/length mismatch",c);
    l0=integer'(expected[k+2]);l1=integer'(expected[k+3]);k=k+4;
    for(j=0;j<l0+l1;j=j+1)begin
     addr=7'(j<l0?j:64+j-l0);repeat(2)@(negedge clk);
     if(charq!==expected[k][7:0])$fatal(1,"cue %d character %d got %h expected %h",c,j,charq,expected[k][7:0]);
     k=k+1;
    end
    consume=1;@(negedge clk);consume=0;
   end
  end
 join
 wait(eof);if(k!=word_count || cv)$fatal(1,"unexpected trailing cue");
 $display("SRT_FILE_PASS cues=%0d input_bytes=%0d expected_words=%0d warning=%b",cue_count,byte_count-1,word_count,warn);$finish;
end
initial begin #1000000000;$fatal(1,"timeout cue=%d input=%d state=%d",c,i,dut.state);end
endmodule
