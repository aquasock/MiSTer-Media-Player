module test_av_ddr_fifo;
reg clk=0;always #5 clk=~clk;
reg reset=1,iv=0,ordy=0;
reg [42:0] idata;
wire ir,ov;wire [42:0] odata;
wire [28:0] addr;wire [63:0] din;wire rd,we,busy,qvalid;
reg dbusy=0,dqvalid=0;reg [63:0] dq;
wire [28:0] daddr;wire [63:0] ddin;wire drd,dwe;wire [7:0] burst,be;
reg rr=0,pr=0;wire rb,pb,rq,pq;
reg [63:0] mem[0:31];
reg [63:0] responses[0:1023];reg [1:0] owners[0:1023];
integer tail=0,head=0,sent=0,got=0,cycle=0,latency=0,j,extra=0;
reg [31:0] rng=32'h573ac9ef;
reg was_stalled=0;reg [42:0] held;
mpeg2_av_ddr_fifo #(.ADDRESS_BITS(5),.BASE(0)) fifo(clk,reset,idata,iv,ir,odata,ov,ordy,addr,din,rd,we,busy,dq,qvalid,);
mpeg2_h262_ddram_arbiter arb(
 .clk(clk),.reset(reset),.writer_burstcnt(8'd1),.writer_addr(29'd0),.writer_rd(1'b0),
 .writer_din(64'd0),.writer_be(8'hff),.writer_we(1'b0),.writer_busy(),
 .reader_burstcnt(8'd3),.reader_addr(29'h100),.reader_rd(rr),.reader_busy(rb),.reader_dout_ready(rq),
 .prediction_burstcnt(8'd2),.prediction_addr(29'h200),.prediction_rd(pr),.prediction_busy(pb),.prediction_dout_ready(pq),
 .stream_addr(addr),.stream_din(din),.stream_rd(rd),.stream_we(we),.stream_busy(busy),.stream_dout_ready(qvalid),
 .ddram_busy(dbusy),.ddram_dout_ready(dqvalid),.ddram_burstcnt(burst),.ddram_addr(daddr),
 .ddram_rd(drd),.ddram_din(ddin),.ddram_be(be),.ddram_we(dwe));
always @(posedge clk) if(!reset) begin
 cycle=cycle+1;
 if(cycle>300000) $fatal(1,"timeout sent %0d got %0d count %0d",sent,got,fifo.count);
 if(was_stalled&&(!ov||odata!==held)) $fatal(1,"stalled output changed");
 was_stalled=ov&&!ordy;held=odata;
 if(iv&&ir) sent=sent+1;
 if(ov&&ordy) begin if(odata!=={11'h531,32'(got)}) $fatal(1,"order %0d data %h",got,odata);got=got+1;end
 if(dqvalid) begin
  if((owners[head%1024]==0&&!qvalid)||(owners[head%1024]==1&&!rq)||(owners[head%1024]==2&&!pq)) $fatal(1,"response owner");
  if(owners[head%1024]!=0) extra=extra+1;
  head=head+1;
 end
 if(dwe&&!dbusy) mem[daddr[4:0]]=ddin;
 if(drd&&!dbusy) begin
  for(j=0;j<burst;j=j+1) begin
   responses[tail%1024]=daddr<32?mem[daddr[4:0]]:64'hfa;
   owners[tail%1024]=daddr<32?0:daddr==29'h100 ? 1 : 2;tail=tail+1;
  end
 end
end
initial begin
 repeat(4) @(negedge clk);reset=0;
 while(got<5000) begin
  @(negedge clk);rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  iv=sent<5000;idata={11'h531,32'(sent)};ordy=rng[0]||rng[2];
  dbusy=rng[4:3]==0;rr=rng[8:5]==0;pr=rng[12:9]==0;
  dqvalid=head<tail&&rng[13];dq=responses[head%1024];
 end
 $display("DDR FIFO PASS words=%0d competing_responses=%0d cycles=%0d",got,extra,cycle);$finish;
end
endmodule
