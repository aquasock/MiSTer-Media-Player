`timescale 1ns/1ps
module test_media_session_control;
reg sys=0,mpeg=0;always #11 sys=~sys;always #5 mpeg=~mpeg;
reg reset=1,restart=0,reader_idle=1;
wire cancel,flush,start,quiesce,decoder_reset,ddr_idle;
wire [31:0] generation;
reg read_req=0,response=0;wire busy,ddr_rd,ddr_we;reg stream_write=0;
media_session_control session(.clk_sys(sys),.clk_mpeg2(mpeg),.reset(reset),
 .restart(restart),.reader_idle(reader_idle),.ddr_idle(ddr_idle),
 .reader_cancel(cancel),.fifo_reset(flush),.reader_start(start),
 .quiesce(quiesce),.decoder_reset(decoder_reset),.generation(generation));
mpeg2_h262_ddram_arbiter #(.ENABLE_QUIESCE(1)) arbiter(
 .clk(mpeg),.reset(reset||decoder_reset),.quiesce(quiesce),.idle(ddr_idle),
 .writer_burstcnt(8'd1),.writer_addr(29'd0),.writer_rd(1'b0),.writer_din(64'd0),.writer_be(8'hff),.writer_we(1'b0),
 .reader_burstcnt(8'd4),.reader_addr(29'd0),.reader_rd(read_req),.reader_busy(busy),
 .prediction_burstcnt(8'd1),.prediction_addr(29'd0),.prediction_rd(1'b0),
 .stream_addr(29'd0),.stream_din(64'd0),.stream_rd(1'b0),.stream_we(stream_write),
 .ddram_busy(1'b0),.ddram_dout_ready(response),.ddram_rd(ddr_rd),.ddram_we(ddr_we));
integer starts=0,k;
always @(posedge sys) if(start) begin
 if(flush || cancel || decoder_reset || !reader_idle) $fatal(1,"premature session start");
 starts=starts+1;
end
initial begin
 repeat(6) @(negedge sys);reset=0;wait(starts==1);
 @(negedge mpeg);read_req=1;@(negedge mpeg);read_req=0;
 if(ddr_idle) $fatal(1,"missing outstanding DDR descriptor");
 @(negedge sys);restart=1;reader_idle=0;
 @(negedge sys);restart=0;
 wait(quiesce);repeat(8) @(negedge mpeg);
 if(decoder_reset || !flush || !cancel) $fatal(1,"reset before DDR drain");
 read_req=1;repeat(8) @(negedge mpeg);
 if(ddr_rd || !busy) $fatal(1,"accepted a request while quiescing");
 read_req=0;
 for(k=0;k<4;k=k+1) begin
  @(negedge mpeg);response=1;@(negedge mpeg);response=0;
  if(k<3 && decoder_reset) $fatal(1,"discarded pending response ownership");
 end
 wait(decoder_reset);stream_write=1;
 repeat(8) @(negedge mpeg);if(ddr_we) $fatal(1,"stream write during quiesce");stream_write=0;
 repeat(60) @(negedge sys);
 if(starts!=1 || !flush) $fatal(1,"did not wait for host response");
 reader_idle=1;wait(starts==2);
 if(generation!=1) $fatal(1,"generation mismatch");
 // Back-to-back restart requests during release must not publish stale start.
 @(negedge sys);restart=1;@(negedge sys);restart=0;
 wait(!flush);@(negedge sys);restart=1;
 @(negedge sys);restart=0;wait(starts==3);
 if(generation!=3) $fatal(1,"restart lost");
 $display("PASS: DDR drain, grant exclusion, host retirement, FIFO reset, restart acknowledgement and generation");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
