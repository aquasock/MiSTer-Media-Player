`timescale 1ns/1ps
module test_osd_playback;
reg clk_sys=0,clk_video=0;
always #25 clk_sys=~clk_sys;
always #18.518519 clk_video=~clk_video;
reg hide_message=0,io_osd=0,io_strobe=0;
reg [15:0] io_din=0;
reg [11:0] x=0,y=0;
always @(posedge clk_video) begin
 if(x==857) begin x<=0;if(y==524)y<=0;else y<=y+1'b1;end
 else x<=x+1'b1;
end
wire de_in=x<720 && y<480;
wire hs_in=!(x>=736 && x<798),vs_in=!(y>=489 && y<495);
wire [23:0] din=24'h123456;
wire [23:0] dout;
wire de_out,hs_out,vs_out,osd_status;
osd dut(.*);
integer i,changed;
reg [3:0] de_pipe=0,hs_pipe=0,vs_pipe=0;
// The OSD must never change raster timing when hiding a message.
always @(posedge clk_video) begin
 de_pipe<={de_pipe[2:0],de_in};hs_pipe<={hs_pipe[2:0],hs_in};vs_pipe<={vs_pipe[2:0],vs_in};
end
task word(input [15:0] value);
 begin
 @(negedge clk_sys);io_din=value;io_strobe=0;
 repeat(2)@(negedge clk_sys);
 io_strobe=1;repeat(2)@(negedge clk_sys);io_strobe=0;
 end
endtask
task mode(input [7:0] command);
 begin
 @(negedge clk_sys);io_osd=1;word({8'd0,command});
 // Also provide geometry for info mode and an unrotated display.
 word(20);word(10);word(32);word(8);word(0);
 @(negedge clk_sys);io_osd=0;repeat(30)@(negedge clk_sys);
 end
endtask
task frame;
 begin
 @(negedge clk_video);while(x!=0||y!=0)@(negedge clk_video);
 repeat(858*525)@(negedge clk_video);
 end
endtask
task check(input integer visible,input [255:0] label_text);
 begin
 // Allow the geometry/pixel-size and OSD position counters to settle.
 frame;frame;frame;frame;frame;frame;
 changed=0;
 repeat(858*525)begin
  @(negedge clk_video);
  if({de_out,hs_out,vs_out}!=={de_pipe[3],hs_pipe[3],vs_pipe[3]})
   $fatal(1,"OSD changed sync/DE alignment");
  if(de_out && (^dout===1'bx))$fatal(1,"unknown visible output");
  if(de_out && dout!=din)changed=changed+1;
 end
 if(visible && changed==0)$fatal(1,"%s: overlay disappeared",label_text);
 if(!visible && changed!=0)$fatal(1,"%s: %0d overlay pixels leaked",label_text,changed);
 $display("PASS: %s (%0d overlay pixels)",label_text,changed);
 end
endtask
initial begin
 repeat(8)@(negedge clk_sys);
 io_osd=1;word(16'h0020);
 for(i=0;i<2048;i=i+1)word(16'h00ff);
 @(negedge clk_sys);io_osd=0;
 mode(8'h49);check(1,"loading before playback");
 hide_message=1;check(0,"loading during playback");
 mode(8'h49);check(0,"repeated progress update");
 mode(8'h43);check(1,"normal menu during playback");
 if(!osd_status)$fatal(1,"menu status lost");
 mode(8'h45);check(1,"info window during playback");
 mode(8'h49);hide_message=0;check(1,"loading after new session/reset");
 mode(8'h40);check(0,"OSD disabled");
 $display("PASS: playback message suppression preserves menu/info visibility and session recovery");
 $finish;
end
initial begin #2000000000;$fatal(1,"timeout");end
endmodule
