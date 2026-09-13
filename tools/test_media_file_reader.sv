`timescale 1ns/1ps
module test_media_file_reader;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0,cancel=0,suspend=0;
reg [63:0] file_size=0,start_offset=0;
wire [31:0] lba;wire [5:0] blocks;wire rd;
reg ack=0,bwr=0;reg [12:0] addr=0;reg [15:0] data=0;
wire [8:0] stream;wire valid,idle;reg ready=0;
wire [63:0] position;wire [31:0] requests,completions,max_wait;wire [3:0] error;
media_file_reader #(.TIMEOUT_CYCLES(200000)) dut(
 .clk(clk),.reset(reset),.start(start),.cancel(cancel),.suspend(suspend),
 .file_size(file_size),.start_offset(start_offset),.sd_lba(lba),.sd_blk_cnt(blocks),
 .sd_rd(rd),.sd_ack(ack),.sd_buff_wr(bwr),.sd_buff_addr(addr),.sd_buff_dout(data),
 .stream_data(stream),.stream_valid(valid),.stream_ready(ready),.idle(idle),
 .byte_position(position),.requests(requests),.completions(completions),.max_wait(max_wait),.error(error));
integer cycle=0,expected=0,ends=0,checked=0,host_words=0,host_base=0,j;
reg host_enable=1,force_stall=0,checking=0,short_response=0;
function [7:0] pattern(input integer offset);pattern=(offset*17+(offset>>8)+29)%251;endfunction
always @(negedge clk) begin
 cycle=cycle+1;
 ready=!force_stall && cycle%11<7;
end
always @(posedge clk) if(!reset && valid && ready) begin
 if(!checking) $fatal(1,"unexpected output");
 if(stream[8]) begin
  if(expected!=file_size) $fatal(1,"premature EOF %0d/%0d",expected,file_size);
  ends=ends+1;
 end else begin
  if(expected>=file_size || stream[7:0]!==pattern(expected))
   $fatal(1,"byte mismatch at %0d got %h expected %h",expected,stream,pattern(expected));
  expected=expected+1;checked=checked+1;
 end
end
// Host transfer includes a delayed acknowledgement and a final write AFTER
// ack falls, as hps_io's registered write pipeline can do.
initial forever begin
 wait(rd && host_enable);
 host_words=(blocks+1)*256;host_base=lba*512;
 repeat(17) @(negedge clk);
 ack=1;
 for(j=0;j<host_words;j=j+1) begin
  @(negedge clk);bwr=0;
  repeat(j%3) @(negedge clk);
  if(j==host_words-1) ack=0;
  @(negedge clk);
  addr=j;data={pattern(host_base+j*2+1),pattern(host_base+j*2)};
  bwr=!(short_response && j==host_words-1);
 end
 @(negedge clk);bwr=0;ack=0;
 repeat(8) @(negedge clk);
end
task launch(input integer size,input integer offset);
begin
 wait(idle);@(negedge clk);file_size=size;start_offset=offset;
 expected=offset;ends=0;checking=1;start=1;
 @(negedge clk);start=0;
end endtask
task replay(input integer size,input integer offset);
begin
 launch(size,offset);wait(ends==1);wait(idle);repeat(10) @(negedge clk);
 if(error || position!=size || requests!=completions) $fatal(1,"completion counters/error");
 checking=0;
end endtask
initial begin
 repeat(5) @(negedge clk);reset=0;
 replay(0,0);replay(1,0);replay(2,0);replay(511,0);replay(512,0);
 replay(513,0);replay(4095,0);replay(4096,0);replay(4097,0);replay(24013,0);
 replay(12003,1);replay(12003,511);replay(12003,513);replay(12003,4097);
 // Stop new requests while retaining the current position; resume later.
 suspend=1;launch(8193,0);repeat(200) @(negedge clk);
 if(rd || requests!=0 || valid) $fatal(1,"suspend issued a request");
 suspend=0;wait(ends==1);wait(idle);checking=0;
 // Decoder cannot stall an already accepted host transfer.
 force_stall=1;launch(8193,0);wait(completions==1);
 repeat(100) @(negedge clk);
 if(rd || ack || requests!=1) $fatal(1,"response was not fully staged");
 force_stall=0;wait(ends==1);wait(idle);checking=0;
 // Cancel before ack, then during data. Drain response and suppress old bytes.
 launch(9001,0);wait(rd);@(negedge clk);cancel=1;checking=0;
 wait(idle);@(negedge clk);cancel=0;replay(1031,0);
 launch(9001,0);wait(ack);repeat(50) @(negedge clk);cancel=1;checking=0;
 wait(idle);@(negedge clk);cancel=0;replay(5003,511);
 short_response=1;launch(513,0);wait(error==2);wait(idle);checking=0;
 short_response=0;replay(99,0);
 // No request or wrap for unsupported addresses.
 @(negedge clk);file_size=64'h20000000001;start_offset=0;start=1;
 @(negedge clk);start=0;repeat(10) @(negedge clk);
 if(error!=3 || rd) $fatal(1,"LBA overflow not rejected");
 // A timed-out transaction stays quarantined until its late response arrives.
 host_enable=0;launch(513,0);wait(error==1);
 if(idle || !rd || valid) $fatal(1,"timeout recycled an outstanding request");
 cancel=1;checking=0;host_enable=1;wait(idle);
 @(negedge clk);cancel=0;replay(19,0);
 $display("PASS: %0d exact bytes, tails, offset restart, suspension, stalls, cancellation, malformed response, timeout quarantine",checked);
 $finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
