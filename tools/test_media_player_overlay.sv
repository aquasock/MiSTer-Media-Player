`timescale 1ns/1ps
module test_media_player_overlay;
reg control_clk=0,clk=0;always #7 control_clk=~control_clk;always #5 clk=~clk;
reg [90:0] state_in=0;
reg [34:0] sub_command=0;wire sub_ack;
reg [23:0] rgb=24'h203040;
reg hs=0,vs=0,de=0;
wire [23:0] out;
wire ho,vo,deo;
media_player_overlay dut(.control_clk(control_clk),.video_clk(clk),.subtitle_command(sub_command),.subtitle_ack(sub_ack),.control_state(state_in),
 .rgb(rgb),.hs(hs),.vs(vs),.de(de),.rgb_out(out),.hs_out(ho),.vs_out(vo),.de_out(deo));
reg [26:0] expected[0:9];
integer cycles=0;
always @(posedge clk) begin
 expected[0]<={hs,vs,de,rgb};
 for(integer k=1;k<10;k=k+1) expected[k]<=expected[k-1];
 cycles<=cycles+1;
 #1;
 if(cycles>8 && {ho,vo,deo}!==expected[9][26:24]) $fatal(1,"timing pipeline mismatch");
end
integer w=720,h=480,known=1,shown=1,paused=0,seeking=0;
integer fd,frame_no=0,pixels=0,pattern=0;
reg [34:0] position=35'd1340400000,total=35'd2629890000;
string path;
integer subtitles=0,subepoch=1;
string sub0="Hello, world!",sub1="Subtitle line two.";
task sub_send(input [1:0] op,input [15:0] payload);begin
 @(negedge control_clk);while(sub_ack!=sub_command[34])@(negedge control_clk);
 sub_command={~sub_command[34],subepoch[15:0],op,payload};
 @(negedge control_clk);while(sub_ack!=sub_command[34])@(negedge control_clk);
end endtask
initial begin
 if(!$value$plusargs("OUT=%s",path)) $fatal(1,"OUT");
 if($value$plusargs("W=%d",w)) begin end
 if($value$plusargs("H=%d",h)) begin end
 if($value$plusargs("KNOWN=%d",known)) begin end
 if($value$plusargs("SHOWN=%d",shown)) begin end
 if($value$plusargs("PAUSED=%d",paused)) begin end
 if($value$plusargs("SEEK=%d",seeking)) begin end
 if($value$plusargs("PATTERN=%d",pattern)) begin end
 if($value$plusargs("POSITION=%d",position)) begin end
 if($value$plusargs("TOTAL=%d",total)) begin end
 if($value$plusargs("SUBTITLES=%d",subtitles))begin end
 if($value$plusargs("SUBEPOCH=%d",subepoch))begin end
 state_in={16'd1,1'b1,shown[0],paused[0],seeking[0],known[0],total,position};
 if(subtitles!=0)begin
  for(integer i=0;i<128;i=i+1) sub_send(0,{i[7:0],(i<sub0.len()?sub0[i]:(i>=64 && i<64+sub1.len() && subtitles==2?sub1[i-64]:8'd0))});
  sub_send(1,{(subtitles==2?8'd18:8'd0),8'h8d});
 end
 fd=$fopen(path,"wb");$fwrite(fd,"P6\n%0d %0d\n255\n",w,h);
 repeat(12) @(negedge clk);
 for(frame_no=0;frame_no<5;frame_no=frame_no+1) begin
  for(integer y=0;y<h+20;y=y+1) begin
   for(integer x=0;x<w+40;x=x+1) begin
    vs=y<2;hs=x<8;de=y>=10 && y<h+10 && x>=20 && x<w+20;
    if(pattern!=0) begin
     rgb[23:16]=(x-20)&255;rgb[15:8]=(x+y-30)&255;rgb[7:0]=((x-20)*7+y-10)&255;
    end
    @(negedge clk);
    if(frame_no==4 && deo) begin
     $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);pixels=pixels+1;
    end
   end
  end
 end
 $fclose(fd);
 if(pixels!=w*h) $fatal(1,"pixels %0d",pixels);
 $display("OVERLAY_RENDER_PASS pixels=%0d width=%0d height=%0d",pixels,dut.width,dut.height);$finish;
end
endmodule
