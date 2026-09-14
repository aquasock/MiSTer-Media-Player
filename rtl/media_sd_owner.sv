// Serialize mounted-file requests and retain response ownership through hps_io's
// trailing buffer writes. Readers may both wait; only the owner sees writes.
module media_sd_owner(
 input wire clk,reset,input wire [1:0] request,ack,input wire buff_wr,
 output wire [1:0] host_request,reader_wr
);
reg busy=0,owner=0,seen=0,last=1;
reg [3:0] tail=0;
assign host_request=busy && !seen ? (owner?2'b10:2'b01)&request:2'b00;
assign reader_wr=busy && buff_wr ? (owner?2'b10:2'b01):2'b00;
always @(posedge clk) begin
 if(reset)begin busy<=0;owner<=0;seen<=0;last<=1;tail<=0;end
 else if(!busy)begin
  if(|request)begin owner<=request==3?!last:request[1];busy<=1;seen<=0;tail<=0;end
 end else if(ack[owner])begin seen<=1;tail<=6;end
 else if(seen)begin
  if(tail!=0)tail<=tail-1'b1;
  else begin busy<=0;last<=owner;end
 end
end
endmodule
