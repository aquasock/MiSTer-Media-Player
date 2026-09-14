`timescale 1ns/1ps
module test_media_duration_reader;
reg clk=0;always #5 clk=~clk;
reg reset=1,new_file=0;
reg [63:0] file_size=0;
wire busy,probe_start,probe_cancel,probe_ready,duration_valid;
wire [34:0] duration;
wire [63:0] probe_size,probe_offset;
wire idle,stream_valid;
wire [8:0] stream;
wire [3:0] error;
wire [31:0] lba;wire [5:0] blocks;wire rd;
reg ack=0,bwr=0;reg [12:0] addr=0;reg [15:0] data=0;
reg play_start=0,play_cancel=1;
wire playback_byte=stream_valid&&!busy&&!play_cancel;
media_duration_probe #(.HEAD_BYTES(512),.TAIL_BYTES(512),.TIMEOUT_CYCLES(20000)) probe(
 .clk(clk),.reset(reset),.new_file(new_file),.file_size(file_size),.reader_idle(idle),.reader_error(error),
 .stream_data(stream),.stream_valid(stream_valid),.stream_ready(probe_ready),.busy(busy),
 .reader_start(probe_start),.reader_cancel(probe_cancel),.read_size(probe_size),.read_offset(probe_offset),
 .duration_valid(duration_valid),.duration_q(duration),.origin());
media_file_reader #(.TIMEOUT_CYCLES(5000)) reader(
 .clk(clk),.reset(reset),.start(busy?probe_start:play_start),.cancel(busy?probe_cancel:play_cancel),.suspend(1'b0),
 .file_size(busy?probe_size:file_size),.start_offset(busy?probe_offset:64'd0),
 .sd_lba(lba),.sd_blk_cnt(blocks),.sd_rd(rd),.sd_ack(ack),.sd_buff_wr(bwr),.sd_buff_addr(addr),.sd_buff_dout(data),
 .stream_data(stream),.stream_valid(stream_valid),.stream_ready(busy?probe_ready:1'b1),.idle(idle),
 .byte_position(),.requests(),.completions(),.max_wait(),.error(error));
reg [7:0] fixture[0:511];
integer fixture_length=352;
string path;
reg host_enable=1,malformed=0,corrupt_head=0,different_tail=0;
reg [63:0] host_base,host_size;
integer host_words,j,request_count=0,play_bytes=0;
reg saw_high_lba=0;
function [7:0] file_byte(input [63:0] offset,input [63:0] size);
 reg [63:0] index;
 begin
  index=offset>=size-512?offset-(size-512):offset;
  file_byte=index<fixture_length?fixture[index]:8'hff;
  if(corrupt_head && offset<size-512 && index==18) file_byte=file_byte&8'hfe;
  if(different_tail && offset>=size-512 && index>=3 && index<fixture_length &&
     fixture[index]==8'he0 && fixture[index-1]==1 && fixture[index-2]==0 && fixture[index-3]==0)
   file_byte=8'he1;
 end
endfunction
initial forever begin
 wait(rd && host_enable);
 host_words=(blocks+1)*256;host_base={23'd0,lba,9'd0};host_size=file_size;
 request_count=request_count+1;
 if(lba>=8388608) saw_high_lba=1;
 repeat(17) @(negedge clk);ack=1;
 for(j=0;j<host_words;j=j+1) begin
  @(negedge clk);bwr=0;
  if(j==host_words-1) ack=0;
  @(negedge clk);addr=j;data={file_byte(host_base+j*2+1,host_size),file_byte(host_base+j*2,host_size)};
  bwr=!(malformed && j==host_words-1);
 end
 @(negedge clk);bwr=0;ack=0;repeat(8) @(negedge clk);
end
always @(posedge clk) if(playback_byte) begin
 if(stream[8]) $fatal(1,"unexpected playback end");
 if(stream[7:0]!==file_byte(play_bytes,file_size)) $fatal(1,"probe bytes leaked / wrong playback origin");
 play_bytes=play_bytes+1;
end
task mount(input [63:0] size);
 begin @(negedge clk);file_size=size;new_file=1;@(negedge clk);new_file=0;end
endtask
task done(input bit expect_known);
 begin wait(!busy);repeat(3) @(negedge clk);
 $display("READER_RESULT valid=%0d head=%0d window=%0d origin=%0d end=%0d bad=%0d demux=%0d boundary=%0d state=%0d err=%0d",duration_valid,probe.head_valid,probe.window_valid,probe.origin,probe.window.end_q,probe.window.bad,probe.window.demux_error,probe.window.packet_boundary,probe.state,error);
 if(duration_valid!==expect_known) $fatal(1,"duration validity got %d expected %d",duration_valid,expect_known);
 if(expect_known && duration!=84084) $fatal(1,"duration %d",duration);
 if(!idle || ack || rd) $fatal(1,"ownership released before retirement");
 end
endtask
initial begin
 if(!$value$plusargs("HEX=%s",path) || !$value$plusargs("LEN=%d",fixture_length)) $fatal(1,"fixture args");
 $readmemh(path,fixture,0,fixture_length-1);
 repeat(4) @(negedge clk);reset=0;
 mount(1024);done(1);
 if(request_count!=2) $fatal(1,"bounded windows did not issue exactly two requests");
 mount(64'h100000400);done(1);
 if(!saw_high_lba) $fatal(1,"large-file tail wrapped");
 // Resume normal playback at byte zero, after preflight response retirement.
 @(negedge clk);play_cancel=0;play_start=1;@(negedge clk);play_start=0;
 wait(play_bytes==200);@(negedge clk);play_cancel=1;wait(idle);
 // Remount while a response is outstanding: no early reuse or codec delivery.
 host_enable=0;mount(1024);wait(rd);mount(2048);
 repeat(100) @(negedge clk);if(!busy || idle) $fatal(1,"new mount recycled request");
 host_enable=1;done(1);
 // Missing storage acknowledgement remains quarantined past both timeouts.
 host_enable=0;mount(1024);wait(rd);repeat(22000) @(negedge clk);
 if(!busy || idle || duration_valid) $fatal(1,"timeout did not quarantine request");
 host_enable=1;done(0);
 // A new valid file recovers even when the previous reader error is sticky.
 mount(1024);done(1);
 malformed=1;mount(1024);done(0);malformed=0;
 mount(1024);done(1);
 corrupt_head=1;mount(1024);done(0);corrupt_head=0;
 different_tail=1;mount(1024);done(0);different_tail=0;
 mount(1024);done(1);
 $display("DURATION_READER_PASS requests=%0d playback_bytes=%0d",request_count,play_bytes);$finish;
end
initial begin #10000000;$fatal(1,"test timeout state=%0d reader=%0d",probe.state,reader.state);end
endmodule
