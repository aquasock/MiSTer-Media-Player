`timescale 1ns/1ps
module test_media_seek_video_filter;
reg clk=0;always #5 clk=~clk;
reg reset=1,resync_start=0,input_valid=0,input_end=0,output_ready=0;
reg [41:0] input_data;
wire input_ready,output_valid,output_end;wire [41:0] output_data;
media_seek_video_filter dut(.*);
reg [41:0] source[0:255],expected[0:255];
integer length=0,expected_len=0,rd=0,wr=0,cycle=0,session,k;
task byte_in(input [7:0] value,input keep);
 begin
  source[length]={1'b0,33'd0,value};length++;
  if(keep)begin expected[expected_len]={1'b0,33'd0,value};expected_len++;end
 end
endtask
task picture(input [2:0] kind,input keep);
 begin
  byte_in(0,keep);byte_in(0,keep);byte_in(1,keep);byte_in(0,keep);
  byte_in(8'h55,keep);byte_in({2'd0,kind,3'd7},keep);
  for(k=0;k<15;k++)byte_in(8'ha0+k,keep);
 end
endtask
always @(posedge clk) begin
 cycle<=cycle+1;
 if(!reset&&input_valid&&input_ready)wr<=wr+1;
 if(!reset&&output_valid&&output_ready)begin
  if(rd>=expected_len || output_data[7:0]!==expected[rd][7:0] ||
    output_data[41]!==expected[rd][41] || (output_data[41]&&output_data[40:8]!==expected[rd][40:8]))
   $fatal(1,"filter mismatch session=%0d byte=%0d actual=%h expected=%h",session,rd,output_data,expected[rd]);
  rd<=rd+1;
 end
end
always @(negedge clk)begin
 input_valid=!reset&&wr<length&&cycle%5!=0;
 input_data=source[wr];input_end=!reset&&wr==length;
 output_ready=cycle%11<7;
end
initial begin
 for(session=0;session<3;session++)begin
  reset=1;resync_start=session!=0;length=0;expected_len=0;wr=0;rd=0;
  byte_in(0,1);byte_in(0,1);byte_in(1,1);byte_in(8'hb3,1);byte_in(8'h55,1);
  picture(1,1);picture(3,session==0);picture(3,session==0);
  // A PTS inside a discarded B-picture belongs to the next picture.
  source[length-2][41:8]={1'b1,33'd99999};
  if(session==0)expected[expected_len-2][41:8]={1'b1,33'd99999};
  if(session!=2)begin
   picture(2,1);
   if(session==1)expected[expected_len-21][41:8]={1'b1,33'd99999};
   picture(3,1);
  end
  byte_in(0,1);byte_in(0,1);byte_in(1,1);byte_in(8'hb7,1);
  repeat(5)@(negedge clk);reset=0;
  wait(output_end);@(negedge clk);
  if(rd!=expected_len)$fatal(1,"truncated filter output %0d/%0d",rd,expected_len);
 end
 $display("PASS: normal byte/PTS fidelity, open-GOP leading B removal, retained later B, carried PTS, stalls and sequence-end flush");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
