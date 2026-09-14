`timescale 1ns/1ps
module test_flac_subframe;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0,bit_valid=0,bit_data=0,bit_end=0,sample_ready=0;
reg[15:0] block_size=0;reg[4:0] channel_bits=0;
wire bit_ready,sample_valid,done,error;wire signed[16:0] sample_data;
flac_subframe dut(.*);
reg bits[0:2500000];integer expected[0:65535];
string path;integer fd,rc,nb,ns,bps,bad,i,j,cycle,received,n=0,total=0,temp;
reg injected;integer resets=0;
reg in_take,out_take;reg signed[16:0] captured;
initial begin
 if(!$value$plusargs("vectors=%s",path))$fatal;fd=$fopen(path,"r");if(!fd)$fatal;
 while(!$feof(fd))begin
  rc=$fscanf(fd,"%d %d %d %d\n",nb,ns,bps,bad);if(rc!=4)$fatal;
  for(i=0;i<nb;i=i+1)begin rc=$fscanf(fd,"%d ",temp);bits[i]=temp[0];end
  if(!bad)for(i=0;i<ns;i=i+1)rc=$fscanf(fd,"%d ",expected[i]);
  reset=1;bit_valid=0;bit_end=0;sample_ready=0;@(negedge clk);reset=0;
  block_size=ns;channel_bits=bps;start=1;@(negedge clk);start=0;
  i=0;received=0;cycle=0;injected=0;
  while(!done&&!error&&cycle<20000000)begin
   if(!bad&&!injected&&cycle==100+n%503)begin
    reset=1;bit_valid=0;sample_ready=0;@(negedge clk);reset=0;
    if(sample_valid||done||error)$fatal(1,"cancel leakage");
    start=1;@(negedge clk);start=0;i=0;received=0;cycle=0;injected=1;resets=resets+1;
   end
   bit_valid=i<nb&&cycle%7!=0;bit_data=i<nb?bits[i]:0;bit_end=i==nb;
   sample_ready=cycle%5!=0;
   #1;in_take=bit_valid&&bit_ready;out_take=sample_valid&&sample_ready;captured=sample_data;
   @(posedge clk);#1;
   if(in_take)i=i+1;
   if(out_take)begin
    if(!bad&&(received>=ns||captured!==expected[received][16:0]))
     $fatal(1,"case %0d sample %0d got %0d expected %0d bits %0d",n,received,captured,expected[received],i);
    received=received+1;total=total+1;
   end
   @(negedge clk);cycle=cycle+1;
  end
  if(bad?!error:(error||!done||received!=ns||i!=nb))
   $fatal(1,"case %0d completion error=%0d done=%0d got=%0d/%0d bits=%0d/%0d",n,error,done,received,ns,i,nb);
  n=n+1;
 end
 $display("FLAC_SUBFRAME_PASS %0d cases; %0d provisional samples; %0d reset/replays",n,total,resets);$finish;
end
endmodule
