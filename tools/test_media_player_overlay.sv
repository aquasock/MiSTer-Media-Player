`timescale 1ns/1ps
module test_media_player_overlay;
reg control_clk=0,clk=0;always #7 control_clk=~control_clk;always #5 clk=~clk;
reg [90:0] state_in=0;
reg [23:0] rgb=24'h203040;
reg hs=0,vs=0,de=0;
wire [23:0] out;
wire ho,vo,deo;
media_player_overlay dut(.control_clk(control_clk),.video_clk(clk),.control_state(state_in),
 .rgb(rgb),.hs(hs),.vs(vs),.de(de),.rgb_out(out),.hs_out(ho),.vs_out(vo),.de_out(deo));
reg [26:0] expected[0:5];
integer cycles=0;
always @(posedge clk) begin
 expected[0]<={hs,vs,de,rgb};
 for(integer k=1;k<6;k=k+1) expected[k]<=expected[k-1];
 cycles<=cycles+1;
 #1;
 if(cycles>8 && {ho,vo,deo}!==expected[5][26:24]) $fatal(1,"timing pipeline mismatch");
end
integer w=720,h=480,known=1,shown=1,paused=0,seeking=0;
integer fd,frame_no=0,pixels=0;
reg [34:0] position=1340400000,total=2629890000;
string path;
initial begin
 if(!$value$plusargs("OUT=%s",path)) $fatal(1,"OUT");
 if($value$plusargs("W=%d",w)) begin end
 if($value$plusargs("H=%d",h)) begin end
 if($value$plusargs("KNOWN=%d",known)) begin end
 if($value$plusargs("SHOWN=%d",shown)) begin end
 if($value$plusargs("PAUSED=%d",paused)) begin end
 if($value$plusargs("SEEK=%d",seeking)) begin end
 if($value$plusargs("POSITION=%d",position)) begin end
 if($value$plusargs("TOTAL=%d",total)) begin end
 state_in={16'd1,1'b1,shown[0],paused[0],seeking[0],known[0],total,position};
 fd=$fopen(path,"wb");$fwrite(fd,"P6\n%0d %0d\n255\n",w,h);
 repeat(12) @(negedge clk);
 for(frame_no=0;frame_no<5;frame_no=frame_no+1) begin
  for(integer y=0;y<h+20;y=y+1) begin
   for(integer x=0;x<w+40;x=x+1) begin
    vs=y<2;hs=x<8;de=y>=10 && y<h+10 && x>=20 && x<w+20;
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
