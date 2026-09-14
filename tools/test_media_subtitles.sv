`timescale 1ns/1ps
module test_media_subtitles;
reg clk=0,vclk=0;always #5 clk=~clk;always #7 vclk=~vclk;
reg reset=1,new_movie=0,mount=0,loaded=1,seeking=0,enabled=1,suspended=1;
reg [34:0] elapsed=0;reg [15:0] epoch=1;reg [63:0] size=0;
wire [31:0] lba;wire [5:0] blocks;wire rd;reg ack=0,wr=0;reg [12:0] addr=0;reg [15:0] data=0;
wire [34:0] command;wire echo,warn;
wire text_we,commit,visible;wire [7:0] text_addr,text_data;wire [15:0] cue_epoch;wire [6:0] n0,n1;
media_subtitles dut(.clk(clk),.reset(reset),.new_movie(new_movie),.mount(mount),.mount_size(size),
 .loaded(loaded),.seeking(seeking),.enabled(enabled),.suspend(suspended),.elapsed_q(elapsed),.epoch(epoch),
 .sd_lba(lba),.sd_blocks(blocks),.sd_rd(rd),.sd_ack(ack),.sd_wr(wr),.sd_addr(addr),.sd_data(data),
 .command(command),.command_ack(echo),.warning(warn));
media_subtitle_cdc bridge(.control_clk(clk),.video_clk(vclk),.command(command),.command_ack(echo),
 .text_we(text_we),.text_addr(text_addr),.text_data(text_data),.commit(commit),.epoch(cue_epoch),.visible(visible),.length0(n0),.length1(n1));
reg [7:0] chars[0:255];
always @(posedge vclk)if(text_we)chars[text_addr]<=text_data;
string source;integer k,base,words,requests=0;
function [7:0] getbyte(input integer at);begin getbyte=at<source.len()?source[at]:0;end endfunction
initial forever begin
 wait(rd);@(negedge clk);base=lba*512;words=(blocks+1)*256;requests=requests+1;
 repeat(13)@(negedge clk);ack=1;
 for(k=0;k<words;k=k+1)begin
  @(negedge clk);addr=k;data={getbyte(base+k*2+1),getbyte(base+k*2)};wr=1;
  @(negedge clk);wr=0;
 end
 ack=0;
end
task wait_visible(input bit desired);integer ticks;begin
 ticks=0;while((visible!==desired || cue_epoch!=epoch) && ticks<50000)begin @(negedge clk);ticks=ticks+1;end
 if(ticks==50000)$fatal(1,"visibility timeout want %d visible %d state %d cv %d parser %d reader %d pending %d",desired,visible,dut.state,dut.cue_valid,dut.parser.state,dut.reader.state,dut.restart_pending);
end endtask
task load;begin @(negedge clk);mount=1;repeat(2)@(negedge clk);mount=0;end endtask
initial begin
 source="1\n00:00:01,000 --> 00:00:03,000\nFirst cue\n\n2\n00:00:05,000 --> 00:00:07,000\nSecond cue\nLine two\n\n";size=source.len();
 repeat(8)@(negedge clk);reset=0;load();
 repeat(100)@(negedge clk);if(rd || requests)$fatal(1,"subtitle read ignored video priority");suspended=0;
 repeat(10000)@(negedge clk);if(visible)$fatal(1,"future cue shown early");
 elapsed=360000;wait_visible(1);if(n0!=9 || chars[0]!="F")$fatal(1,"first cue transfer");
 repeat(5000)@(negedge clk);if(!visible)$fatal(1,"paused clock cue lost");
 enabled=0;wait_visible(0);enabled=1;wait_visible(1);
 elapsed=1080000;wait_visible(0);elapsed=1800000;wait_visible(1);if(n0!=10 || n1!=8 || chars[0]!="S" || chars[64]!="L")$fatal(1,"second cue transfer");
 seeking=1;epoch=epoch+1;wait_visible(0);repeat(100)@(negedge clk);elapsed=540000;seeking=0;
 wait_visible(1);if(chars[0]!="F" || n1!=0 || requests<2)$fatal(1,"backward seek stale cue");
 seeking=1;epoch=epoch+1;wait_visible(0);elapsed=2160000;repeat(100)@(negedge clk);seeking=0;wait_visible(1);if(chars[0]!="S")$fatal(1,"forward seek stale cue");
 elapsed=2520000;wait_visible(0);repeat(5000)@(negedge clk);if(!dut.parse_eof)$fatal(1,"SRT EOF");
 // Loading another subtitle file during a live transfer must retire commands
 // already in flight and never publish the old text as the replacement.
 elapsed=360000;load();wait(rd);@(negedge clk);new_movie=1;epoch=epoch+1;@(negedge clk);new_movie=0;
 wait_visible(0);repeat(10000)@(negedge clk);if(dut.associated || visible)$fatal(1,"new movie retained SRT");
 load();wait_visible(1);if(chars[0]!="F")$fatal(1,"reload");
 $display("SUBTITLES_PASS manual load cue boundaries pause Off/On backward/forward seeks EOF new movie in-flight cancel and reload with asynchronous applied-command acknowledgements");$finish;
end
initial begin #20000000;$fatal(1,"subtitles timeout");end
endmodule
