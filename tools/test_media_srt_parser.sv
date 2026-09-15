`timescale 1ns/1ps
module test_media_srt_parser;
reg clk=0;always #5 clk=~clk;
reg reset=1,valid=0,consume=0;reg [8:0] data=0;wire ready,cv,eof,warn;wire [36:0] first,last;
reg [6:0] addr=0;wire [7:0] charq;wire [6:0] n0,n1;
media_srt_parser dut(.clk(clk),.reset(reset),.data(data),.valid(valid),.ready(ready),
 .cue_valid(cv),.cue_ready(consume),.start_q(first),.end_q(last),.length0(n0),.length1(n1),
 .text_addr(addr),.text_q(charq),.eof(eof),.warning(warn));
task byte_in(input [8:0] value);begin
 @(negedge clk);while(!ready)@(negedge clk);data=value;valid=1;@(negedge clk);valid=0;
end endtask
task send(input string s);integer i;begin for(i=0;i<s.len();i=i+1)byte_in({1'b0,s[i]});end endtask
task restart;begin @(negedge clk);reset=1;repeat(3)@(negedge clk);reset=0;end endtask
task check(input [36:0] a,b,input string x,y);integer i;begin
 wait(cv);if(first!==a || last!==b || n0!=x.len() || n1!=y.len())$fatal(1,"cue %d %d len %d %d",first,last,n0,n1);
 for(i=0;i<x.len();i=i+1)begin addr=i;repeat(2)@(negedge clk);if(charq!==x[i])$fatal(1,"line0 %d %h expected %h",i,charq,x[i]);end
 for(i=0;i<y.len();i=i+1)begin addr=64+i;repeat(2)@(negedge clk);if(charq!==y[i])$fatal(1,"line1 %d",i);end
 repeat(20)@(negedge clk);if(!cv || ready)$fatal(1,"cue backpressure");
 consume=1;@(negedge clk);consume=0;
end endtask
task smart(input [7:0] last_byte);begin byte_in(9'he2);byte_in(9'h80);byte_in({1'b0,last_byte});end endtask
string long_line;
initial begin
 restart();
 send("1\015\n00:00:01,250 --> 00:00:03,500\015\nHello, world!\015\n<i>Second line.</i>\015\n\015\n");
 check(450000,1260000,"Hello, world!","Second line.");
 send("2\n01:02:03,004 --> 01:02:05,006\nLast cue");byte_in(9'h100);
 check(1340281440,1341002160,"Last cue","");wait(eof);
 restart();
 send("bad\n00:99:01,000 --> 00:99:02,000\nbad\n\n3\n00:00:05,000 --> 00:00:04,000\nwrong\n\n4\n00:00:09,000 --> 00:00:10,000\nOK\n\n");
 check(3240000,3600000,"OK","");
 restart();send("1\n00:00:00,000 --> 00:00:01,001\nCaf");byte_in(9'h0c3);byte_in(9'h0a9);send("\n\n");check(0,360360,"Caf?","");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\nIt's already ASCII.\n\n");check(0,360000,"It's already ASCII.","");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\nIt");smart(8'h99);send("s ");smart(8'h98);send("quoted");smart(8'h99);send(".\n\n");check(0,360000,"It's 'quoted'.","");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\n");byte_in(9'h91);send("It's legacy");byte_in(9'h92);send("\n\n");check(0,360000,"'It's legacy'","");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\n");smart(8'h93);send(" ");smart(8'h9c);send("Hello");smart(8'h9d);smart(8'h94);send("\n\n");check(0,360000,"- \"Hello\"-","");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\n");byte_in(9'h96);byte_in(9'h93);send("Hello");byte_in(9'h94);byte_in(9'h97);send("\n\n");check(0,360000,"-\"Hello\"-","");
 // Unsupported three-byte characters still occupy exactly one fallback cell.
 restart();send("1\n00:00:00,000 --> 00:00:01,000\nA");smart(8'h9a);send("B");byte_in(9'he2);byte_in(9'h81);byte_in(9'h99);send("C\n\n");check(0,360000,"A?B?C","");
 // A truncated character cannot consume or rewrite the next line.
 restart();send("1\n00:00:00,000 --> 00:00:01,000\nA");byte_in(9'he2);byte_in(9'h80);send("\n");byte_in(9'h99);send("B\n\n");check(0,360000,"A?","?B");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\nA");byte_in(9'he2);byte_in(9'h80);send("<i>X</i>");byte_in(9'h99);send("\n\n");check(0,360000,"A?X?","");
 long_line="";repeat(62)long_line={long_line,"A"};
 restart();send("1\n00:00:00,000 --> 00:00:01,000\n");send(long_line);smart(8'h99);send("\n\n");check(0,360000,{long_line,"'"},"");
 long_line={long_line,"A"};
 restart();send("1\n00:00:00,000 --> 00:00:01,000\n");send(long_line);smart(8'h99);send("\n\n");check(0,360000,long_line,"");if(!warn)$fatal(1,"missing overflow warning");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\n");repeat(70)send("A");send("\nB\nC\n\n");wait(cv);if(n0!=63 || n1!=1 || !warn)$fatal(1,"bounds");
 restart();send("1\n00:00:00,000 --> 00:00:01,000\nCancelled");restart();if(cv || eof)$fatal(1,"stale cue after reset");
 $display("SRT_PARSER_PASS timestamps CRLF LF final EOF tags ASCII/UTF-8/Windows-1252 apostrophes Unicode fallback/truncation bounds invalid headers reset backpressure");$finish;
end
initial begin #5000000;$fatal(1,"parser timeout state %d",dut.state);end
endmodule
