`timescale 1ns/1ps
module test_shared_idct;
reg clk=0;always #5 clk=~clk;
reg reset=1;
reg [62:0] requests=0;
wire [74:0] responses;
mpeg2_h262_shared_idct dut(.*);
wire [2:0] rv,rc,re;
wire [5:0] ri[0:2];wire signed[15:0] rs[0:2];
reg signed[15:0] expected[0:2][0:63];
integer captured[0:2],received[0:2];integer total=0;reg allow_error=0;
for(genvar c=0;c<3;c=c+1)begin: reference_client
 mpeg2_h262_idct reference_idct(.clk(clk),.reset(reset),
 .coeff_block_start(requests[c*21+20]),.coeff_valid(requests[c*21+19]),
 .coeff_index(requests[c*21+13+:6]),.coeff_value(requests[c*21+1+:12]),
 .coeff_block_end(requests[c*21]),.block_complete(rc[c]),.idct_error(re[c]),
 .sample_valid(rv[c]),.sample_index(ri[c]),.sample_value(rs[c]),
 .first_luma_sample00(),.first_luma_sample77());
 always @(posedge clk)begin
  if(reset)begin captured[c]=0;received[c]=0;end
  else begin
   if(requests[c*21+20])begin captured[c]=0;received[c]=0;end
   if(rv[c])begin expected[c][ri[c]]=rs[c];captured[c]=captured[c]+1;end
   if(!allow_error && (responses[c*25+23] || re[c]))$fatal(1,"unexpected error client %0d",c);
   if(responses[c*25+22])begin
    if(captured[c]<=received[c] || responses[c*25+16+:6]!=received[c] ||
       $signed(responses[c*25+:16])!==expected[c][received[c]])
      $fatal(1,"sample mismatch client=%0d index=%0d captured=%0d",c,received[c],captured[c]);
    if(received[c]==63 && !responses[c*25+24])$fatal(1,"completion not aligned");
    received[c]=received[c]+1;total=total+1;
   end
  end
 end
end
integer group,k,c,seed=32'h1248;reg[31:0] random_value;
task send_group(input integer pattern);begin
 @(negedge clk);requests=0;
 for(c=0;c<3;c=c+1)requests[c*21+20]=1;
 @(negedge clk);requests=0;
 for(k=0;k<64;k=k+1)begin
  for(c=0;c<3;c=c+1)begin
   random_value=$random(seed);
   requests[c*21+:21]={1'b0,(pattern%3==0 || random_value[3:0]!=0),k[5:0],random_value[11:0],1'b0};
  end
  @(negedge clk);
 end
 requests=0;for(c=0;c<3;c=c+1)requests[c*21]=1;
 @(negedge clk);requests=0;
end endtask
task automatic exercise_client(input integer id,input integer blocks);
 integer b,j,random_seed;reg[31:0] v;
 begin
  random_seed=1234+id;
  repeat(id*11+1)@(negedge clk);
  for(b=0;b<blocks;b=b+1)begin
   @(negedge clk);requests[id*21+:21]={1'b1,20'd0};
   @(negedge clk);requests[id*21+:21]=0;
   for(j=0;j<64;j=j+1)begin
    v=$random(random_seed);
    requests[id*21+:21]={1'b0,v[1:0]!=0,j[5:0],v[11:0],j==63};
    @(negedge clk);
   end
   requests[id*21+:21]=0;
   wait(received[id]==64);
  end
 end
endtask
initial begin
 repeat(3)@(negedge clk);reset=0;
 for(group=0;group<128;group=group+1)begin
  send_group(group);
  wait(received[0]==64 && received[1]==64 && received[2]==64);
 end
 // Independent producers immediately reuse their own slots while peers wait.
 fork
  exercise_client(0,37);
  exercise_client(1,31);
  exercise_client(2,29);
 join
 // Sparse single-cycle start+coefficient+end and round-robin handoffs.
 for(group=0;group<12;group=group+1)begin
  @(negedge clk);
  for(c=0;c<3;c=c+1)begin
   random_value=$random(seed);
   requests[c*21+:21]={1'b1,1'b1,random_value[17:12],random_value[11:0],1'b1};
  end
  @(negedge clk);requests=0;
  wait(received[0]==64 && received[1]==64 && received[2]==64);
 end
 // Reset with queued clients and an active engine at each pipeline phase.
 for(group=0;group<220;group=group+1)begin
  send_group(group);repeat(group)@(negedge clk);reset=1;requests=0;
  repeat(2)@(negedge clk);reset=0;
  send_group(group);wait(received[0]==64 && received[1]==64 && received[2]==64);
 end
 // Invalid strobes report a functional error; reset must clear it.
 @(negedge clk);allow_error=1;requests=0;requests[19]=1;
 @(negedge clk);requests=0;
 if(!responses[23])$fatal(1,"orphan coefficient was not rejected");
 reset=1;repeat(2)@(negedge clk);reset=0;allow_error=0;
 send_group(0);wait(received[0]==64 && received[1]==64 && received[2]==64);
 $display("SHARED_IDCT_PASS compared_samples=%0d",total);$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
