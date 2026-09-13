`timescale 1ns/1ps
module test_media_hps_io;
reg clk=0;always #5 clk=~clk;
tri [45:0] bus;tri [35:0] ext;
reg [15:0] command_data=0;reg enable=0,strobe=0;
assign bus[31:16]=command_data;assign bus[33]=strobe;
assign bus[34]=enable;assign bus[35]=0;assign bus[45:38]=0;
assign ext[32]=0;
wire [31:0] lba[2];wire [5:0] blocks[2];wire [1:0] rd,ack;
wire [12:0] addr;wire [15:0] data;wire wr;wire [15:0] unused_data[2];assign unused_data[0]=0;assign unused_data[1]=0;assign rd[1]=0;assign lba[1]=0;assign blocks[1]=0;
hps_io #(.CONF_STR("MediaPlayer;;S0,M2VMPG,Open MPEG-2 Video;"),.WIDE(1),.VDNUM(2)) hps(
 .clk_sys(clk),.HPS_BUS(bus),.EXT_BUS(ext),.ioctl_wait(1'b0),
 .sd_lba(lba),.sd_blk_cnt(blocks),.sd_rd(rd),.sd_wr(2'b0),.sd_ack(ack),
 .sd_buff_addr(addr),.sd_buff_dout(data),.sd_buff_wr(wr),.sd_buff_din(unused_data));
reg reset=1,start=0;wire [8:0] stream;wire valid,idle;wire [3:0] error;
media_file_reader dut(.clk(clk),.reset(reset),.start(start),.cancel(1'b0),.suspend(1'b0),
 .file_size(64'd4099),.start_offset(64'd0),.sd_lba(lba[0]),.sd_blk_cnt(blocks[0]),.sd_rd(rd[0]),
 .sd_ack(ack[0]),.sd_buff_wr(wr),.sd_buff_addr(addr),.sd_buff_dout(data),
 .stream_data(stream),.stream_valid(valid),.stream_ready(1'b1),.idle(idle),.error(error));
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
 repeat(8) @(negedge clk);reset=0;start=1;@(negedge clk);start=0;
 while(ends==0) begin
  wait(rd[0] || ends);if(ends==0) begin
   n=(blocks[0]+1)*256;base=lba[0]*512;
   @(negedge clk);enable=1;send(16'h0016);
   if(bus[15:0]!=={1'b1,blocks[0],3'd2,4'd0,1'b0,1'b1}) $fatal(1,"SD status encoding");
   @(negedge clk);enable=0;repeat(5) @(negedge clk);
   enable=1;send(16'h0017);
   for(k=0;k<n;k=k+1) send({pattern(base+2*k+1),pattern(base+2*k)});
   @(negedge clk);enable=0;repeat(10) @(negedge clk);
  end
 end
 if(error) $fatal(1,"reader error %0d",error);
 $display("PASS: actual hps_io status, acknowledgement, WIDE byte order and buffer-write pipeline, 4099 bytes");$finish;
end
initial begin #10000000;$fatal(1,"timeout error=%d count=%d",error,count);end
endmodule
