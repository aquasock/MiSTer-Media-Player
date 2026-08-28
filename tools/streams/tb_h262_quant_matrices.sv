`timescale 1ns/1ps
module tb_h262_quant_matrices;
reg clk=0, reset=1, valid=0;
reg [7:0] data=0;
reg [5:0] index=0;
wire [7:0] iw,nw;
wire idef,ndef,error;
reg [7:0] pending=0;
integer bits=0,checks=0;
wire continuous_bytes=$test$plusargs("CONTINUOUS");
integer j,k;
reg [7:0] expect_i[0:63],expect_n[0:63];
reg [5:0] zz[0:63];
always #5 clk=~clk;
mpeg2_h262_quant_matrices dut(.clk(clk),.reset(reset),.stream_data(data),
 .stream_valid(valid),.read_index(index),.intra_weight(iw),.non_intra_weight(nw),
 .intra_default(idef),.non_intra_default(ndef),.syntax_error(error),.update_now());
task automatic byte_out(input [7:0] v);
 begin
  @(negedge clk); data=v; valid=1;
  if(!continuous_bytes) begin
   @(negedge clk); valid=0;
   // Deliberate gaps prove byte acceptance, not clock counting.
   repeat(v[1:0]) @(negedge clk);
  end
 end
endtask
task automatic bit_out(input bit v);
 begin
  pending={pending[6:0],v}; bits=bits+1;
  if(bits==8) begin byte_out(pending); bits=0; pending=0; end
 end
endtask
task automatic finish_bits;
 begin
  while(bits!=0) bit_out(0);
  if(continuous_bytes) begin @(negedge clk);valid=0;end
 end
endtask
task automatic start_code(input [7:0] v);
 begin finish_bits();byte_out(0);byte_out(0);byte_out(1);byte_out(v);end
endtask
task automatic reset_dut;
 begin @(negedge clk);reset=1;valid=0;repeat(3) @(negedge clk);reset=0;bits=0;pending=0;end
endtask
task automatic weights(input bit non_intra,input integer seed);
 integer a,b,v;
 begin
  bit_out(1);
  for(a=0;a<64;a=a+1) begin
   v=(a*37+seed)%255+1;
   if(!non_intra && a==0) v=8;
   if(non_intra) expect_n[zz[a]]=v;else expect_i[zz[a]]=v;
   for(b=7;b>=0;b=b-1) bit_out((v>>b)&1);
  end
 end
endtask
task automatic check_tables;
 integer a;
 begin
  finish_bits();repeat(3) @(negedge clk);
  for(a=0;a<64;a=a+1) begin
   index=a;#1;
   if(iw!==expect_i[a] || nw!==expect_n[a])
    $fatal(1,"matrix index=%0d got=%0d/%0d expected=%0d/%0d",a,iw,nw,expect_i[a],expect_n[a]);
   checks=checks+1;
  end
  if(error) $fatal(1,"unexpected matrix syntax error");
 end
endtask
task automatic extension;
 begin start_code(8'hb5);bit_out(0);bit_out(0);bit_out(1);bit_out(1);end
endtask
initial begin
 zz='{0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63};
 expect_i='{8,16,19,22,26,27,29,34,16,16,22,24,27,29,34,37,19,22,26,27,29,34,34,38,22,22,26,27,29,34,37,40,22,26,27,29,32,35,40,48,26,27,29,32,35,40,48,58,26,27,29,34,38,46,56,69,27,29,35,38,46,56,69,83};
 for(j=0;j<64;j=j+1) expect_n[j]=16;
 reset_dut();check_tables();
 // Sequence: first matrix begins at bit 63, second at bit 576.
 start_code(8'hb3);for(j=0;j<62;j=j+1) bit_out(1);
 weights(0,3);weights(1,9);check_tables();
 if(idef||ndef) $fatal(1,"loaded flags missing");
 // All combinations of extension load flags; no-load must retain values.
 for(k=0;k<4;k=k+1) begin
  extension();
  if(k&1) weights(0,11+k);else bit_out(0);
  if(k&2) weights(1,23+k);else bit_out(0);
  bit_out(0);bit_out(0);check_tables();
 end
 // Repeated sequence resets BOTH tables before either optional load.
 start_code(8'hb3);for(j=0;j<62;j=j+1) bit_out(1);
 bit_out(0);weights(1,29);finish_bits();repeat(3) @(negedge clk);
 if(!idef||ndef) $fatal(1,"sequence reset/default flags wrong");
 index=63;#1;if(iw!=83) $fatal(1,"default matrix not restored");
 // A truncated download is rejected at the following start code.
 reset_dut();extension();bit_out(1);for(j=0;j<8;j=j+1) bit_out(j==4);
 start_code(8'hb7);repeat(3) @(negedge clk);
 if(!error) $fatal(1,"truncated matrix accepted");
 // Forbidden zero and reserved first intra element fail closed.
 for(k=0;k<2;k=k+1) begin
  reset_dut();extension();bit_out(1);
  for(j=7;j>=0;j=j-1) bit_out(k && j==0);
  finish_bits();repeat(3) @(negedge clk);
  if(!error) $fatal(1,"invalid first weight accepted");
 end
 reset_dut();extension();bit_out(0);bit_out(0);bit_out(1);finish_bits();
 repeat(3) @(negedge clk);if(!error) $fatal(1,"4:2:0 chroma table accepted");
 $display("MATRIX_PARSER_PASS checked=%0d defaults,unaligned sequence,extension combinations,persistence,reset,invalid,truncated,gaps",checks);
 $finish;
end
endmodule
