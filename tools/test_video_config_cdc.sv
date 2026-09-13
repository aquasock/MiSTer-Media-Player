`timescale 1ns/1ps
module test_video_config_cdc;
reg src_clk=0,dst_clk=0;
always #25 src_clk=~src_clk;
always #18.518519 dst_clk=~dst_clk;
reg [31:0] src_data=0;
wire [31:0] dst_data;
video_config_cdc #(.WIDTH(32)) dut(.*);
integer updates=0,i;
reg [31:0] previous=0,previous_held=0;
reg previous_request=0,previous_ack=0;
always @(posedge src_clk) begin
 #1;
 if(previous_request!=previous_ack && dut.held_data!==previous_held)
  $fatal(1,"source changed an unacknowledged snapshot");
 previous_request=dut.request;previous_ack=dut.ack_sync[2];
 previous_held=dut.held_data;
end
always @(posedge dst_clk) begin
 #1;
 if(dst_data!==previous) begin
  if(dst_data[31:16]!==~dst_data[15:0])$fatal(1,"torn configuration word");
  if(dst_data[15:0]<=previous[15:0])$fatal(1,"duplicate or reordered configuration");
  previous=dst_data;updates=updates+1;
 end
end
initial begin
 for(i=1;i<=300;i=i+1)begin
  @(negedge src_clk);src_data={~16'(i),16'(i)};
 end
 repeat(40)@(negedge src_clk);
 if(dst_data!==src_data||updates<10)$fatal(1,"mailbox failed to settle %h %h",dst_data,src_data);
 $display("PASS: asynchronous 20/27 MHz configuration mailbox, %0d atomic updates, stable held snapshots and final value",updates);
 $finish;
end
endmodule
