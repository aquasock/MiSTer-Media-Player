`timescale 1ns/1ps
module test_media_subtitle_hps_io;
reg clk=0;always #5 clk=~clk;
tri [45:0] bus;tri [35:0] ext;
reg [15:0] command_data=0;reg enable=0,strobe=0;
assign bus[31:16]=command_data;assign bus[33]=strobe;
assign bus[34]=enable;assign bus[35]=0;assign bus[45:38]=0;
assign ext[32]=0;
wire [1:0] host_rd,reader_wr;
wire [31:0] lba[2];wire [5:0] blocks[2];wire [1:0] rd,ack;
wire [12:0] addr;wire [15:0] data;wire wr;wire [15:0] unused_data[2];assign unused_data[0]=0;assign unused_data[1]=0;
localparam CONF={"MediaPlayer;;S0,MPGFL*,Load media;",
`include "MediaPlayer_subtitle_menu.svh"
"v,2;"};
localparam CONF_LEN=$bits(CONF)/8;
hps_io #(.CONF_STR(CONF),.CONF_STR_BRAM(1),.WIDE(1),.VDNUM(2)) hps(
 .clk_sys(clk),.HPS_BUS(bus),.EXT_BUS(ext),.ioctl_wait(1'b0),
 .sd_lba(lba),.sd_blk_cnt(blocks),.sd_rd(host_rd),.sd_wr(2'b0),.sd_ack(ack),
 .sd_buff_addr(addr),.sd_buff_dout(data),.sd_buff_wr(wr),.sd_buff_din(unused_data));
reg reset=1,start=0;wire [8:0] stream;wire valid,idle;wire [3:0] error;
media_file_reader dut(.clk(clk),.reset(reset),.start(start),.cancel(1'b0),.suspend(1'b0),
 .file_size(64'd4099),.start_offset(64'd0),.sd_lba(lba[0]),.sd_blk_cnt(blocks[0]),.sd_rd(rd[0]),
 .sd_ack(ack[0]),.sd_buff_wr(reader_wr[0]),.sd_buff_addr(addr),.sd_buff_dout(data),
 .stream_data(stream),.stream_valid(valid),.stream_ready(1'b1),.idle(idle),.error(error));
media_sd_owner owner(.clk(clk),.reset(reset),.request(rd),.ack(ack),.buff_wr(wr),.host_request(host_rd),.reader_wr(reader_wr));
wire [8:0] sub_stream;wire sub_valid,sub_idle;wire [3:0] sub_error;
media_file_reader sub_reader(.clk(clk),.reset(reset),.start(start),.cancel(1'b0),.suspend(1'b0),
 .file_size(64'd1301),.start_offset(64'd0),.sd_lba(lba[1]),.sd_blk_cnt(blocks[1]),.sd_rd(rd[1]),
 .sd_ack(ack[1]),.sd_buff_wr(reader_wr[1]),.sd_buff_addr(addr),.sd_buff_dout(data),
 .stream_data(sub_stream),.stream_valid(sub_valid),.stream_ready(1'b1),.idle(sub_idle),.error(sub_error));
integer sub_count=0,sub_ends=0,drive;
always @(posedge clk)if(sub_valid)begin
 if(sub_stream[8])begin if(sub_count!=1301)$fatal(1,"SRT EOF");sub_ends=sub_ends+1;end
 else begin if(sub_stream[7:0]!==pattern(sub_count+77))$fatal(1,"SRT contamination %d",sub_count);sub_count=sub_count+1;end
end
integer count=0,ends=0,k,n,base;
function [7:0] pattern(input integer i);pattern=(i*31+3)%251;endfunction
always @(posedge clk) if(valid) begin
 if(stream[8]) begin if(count!=4099) $fatal(1,"EOF at %0d",count);ends=ends+1;end
 else begin if(stream[7:0]!==pattern(count)) $fatal(1,"HPS byte %0d mismatch",count);count=count+1;end
end
task send(input [15:0] value);
begin
 @(negedge clk);command_data=value;strobe=1;
 @(negedge clk);strobe=0;
 repeat(3) @(negedge clk);
end endtask
initial begin
 repeat(8) @(negedge clk);reset=0;
 enable=1;send(16'h0014);
 for(k=0;k<CONF_LEN;k=k+1)begin
  send(0);
  if(bus[7:0]!==CONF[(CONF_LEN-k)*8-1 -:8])$fatal(1,"block-RAM menu byte %0d got %h",k,bus[7:0]);
 end
 @(negedge clk);enable=0;repeat(5)@(negedge clk);
 start=1;@(negedge clk);start=0;
 while(ends==0 || sub_ends==0) begin
  wait(|host_rd || (ends && sub_ends));if(|host_rd) begin
   drive=host_rd[1]?1:0;
   n=(blocks[drive]+1)*256;base=lba[drive]*512+(drive?77:0);
   @(negedge clk);enable=1;send(16'h0016);
   if(bus[15:0]!=={1'b1,blocks[drive],3'd2,drive[3:0],1'b0,1'b1}) $fatal(1,"SD status encoding");
   @(negedge clk);enable=0;repeat(5) @(negedge clk);
   enable=1;send(drive?16'h0117:16'h0017);
   for(k=0;k<n;k=k+1) send({pattern(base+2*k+1),pattern(base+2*k)});
   @(negedge clk);enable=0;repeat(10) @(negedge clk);
  end
 end
 if(error || sub_error) $fatal(1,"reader error %0d",error);
 $display("SUBTITLE_HPS_PASS complete block-RAM menu readback, simultaneous movie/SRT requests, actual hps_io drive isolation, trailing writes, byte order and EOF");$finish;
end
initial begin #10000000;$fatal(1,"timeout error=%d count=%d",error,count);end
endmodule
