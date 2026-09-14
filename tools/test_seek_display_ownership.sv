`timescale 1ns/1ps
module test_seek_display_ownership;
reg clk=0;always #5 clk=~clk;
reg reset=1,release_bank=0,reader_rd=0,pred_rd=0,stream_rd=0;
reg writer_we=0,busy=0,response=0;
reg [28:0] reader_addr=29'h06030000,writer_addr=29'h06030000;
reg [7:0] reader_burst=3;
wire writer_busy,rd,we,reader_q,pred_q,stream_q;
wire old_writer_busy,old_we;
// Twin arbiters receive the same command/response sequence; disabled release
// demonstrates that the regression catches the original stuck bank guard.
`define PORTS \
 .clk(clk),.reset(reset),.quiesce(1'b0),.release_display_bank(release_bank), \
 .writer_burstcnt(8'd1),.writer_addr(writer_addr),.writer_rd(1'b0), \
 .writer_din(64'd1),.writer_be(8'hff),.writer_we(writer_we), \
 .reader_burstcnt(reader_burst),.reader_addr(reader_addr),.reader_rd(reader_rd), \
 .prediction_burstcnt(8'd1),.prediction_addr(29'h06000000),.prediction_rd(pred_rd), \
 .stream_addr(29'h06080000),.stream_din(64'd0),.stream_rd(stream_rd),.stream_we(1'b0), \
 .ddram_busy(busy),.ddram_dout_ready(response)
mpeg2_h262_ddram_arbiter #(.ENABLE_DISPLAY_RELEASE(1)) dut(
 `PORTS,.writer_busy(writer_busy),.ddram_rd(rd),.ddram_we(we),
 .reader_dout_ready(reader_q),.prediction_dout_ready(pred_q),.stream_dout_ready(stream_q));
mpeg2_h262_ddram_arbiter legacy(
 `PORTS,.writer_busy(old_writer_busy),.ddram_we(old_we));
`undef PORTS
task step;begin @(negedge clk);#1;end endtask
task beat(input integer owner);begin
 response=1;#1;
 if({stream_q,pred_q,reader_q}!=(1<<owner))$fatal(1,"response owner changed while releasing");
 step();response=0;
end endtask
integer bank;
initial begin
 step();reset=0;
 // All three retained references and both scratch regions must stay protected
 // in normal playback and pause (no release request), then release during seek.
 for(bank=0;bank<5;bank=bank+1)begin
  reader_addr=29'h06000000+(bank<<16);writer_addr=reader_addr;reader_burst=1;reader_rd=1;
  step();reader_rd=0;beat(0);step();writer_we=1;
  repeat(8)begin step();if(!writer_busy||we)$fatal(1,"paused/displayed bank overwritten");end
  release_bank=1;step();
  if(writer_busy||!we||!old_writer_busy||old_we)$fatal(1,"stale bank not released, or legacy failure not exercised");
  release_bank=0;writer_we=0;step();
 end
 // A queued three-beat display burst followed by prediction and stream reads.
 reader_addr=29'h06030000;writer_addr=reader_addr;reader_burst=3;reader_rd=1;step();reader_rd=0;
 pred_rd=1;step();pred_rd=0;stream_rd=1;step();stream_rd=0;
 release_bank=1;writer_we=1;
 repeat(8)begin step();if(!writer_busy||we||!dut.reader_bank_valid)$fatal(1,"released before responses");end
 beat(0);beat(0);beat(0);
 if(!dut.reader_bank_valid||!writer_busy)$fatal(1,"lost guard before queued reads drain");
 beat(1);beat(2);
 busy=1;repeat(4)begin step();if(!dut.reader_bank_valid||we)$fatal(1,"released while DDR busy");end
 busy=0;step();if(writer_busy||!we||dut.reader_bank_valid)$fatal(1,"drained seek remains stuck");
 // A fresh reader acceptance on the release edge must retain its protection.
 writer_we=0;reader_rd=1;reader_burst=1;step();reader_rd=0;
 if(!dut.reader_bank_valid)$fatal(1,"release overrode accepted display read");
 release_bank=0;beat(0);step();writer_we=1;
 if(!writer_busy||we)$fatal(1,"resumed display not protected");
 // DDR backpressure cannot spuriously accept a display request or free its bank.
 release_bank=1;reader_rd=1;busy=1;repeat(4)step();
 if(!dut.reader_bank_valid)$fatal(1,"busy request released ownership");
 busy=0;step();reader_rd=0;beat(0);step();
 if(writer_busy||!we)$fatal(1,"repeat seek release failed");
 $display("PASS: old seek deadlock reproduced; five banks, pause protection, burst drain, response routing, busy DDR, simultaneous display acceptance and reacquisition");$finish;
end
endmodule
