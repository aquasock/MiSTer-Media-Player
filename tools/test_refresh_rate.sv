`timescale 1ns/1ps
// Full-frame geometry and asynchronous requests, including requests during
// active pixels, sync and frame-end blanking. No truncated line/frame allowed.
module test_refresh_rate;
reg clk_sys=0,clk_video=0,clk_mpeg2=0,reset_video=1;
always #7 clk_sys=~clk_sys;
always #5 clk_video=~clk_video;
always #3 clk_mpeg2=~clk_mpeg2;
reg [127:0] status=0;
wire [11:0] display_h_pos,display_v_pos;
wire display_pixel_en,display_h_sync,display_v_sync;
// The verifier inserts the actual top-level configuration and raster wiring.
`include "refresh_wiring.svh"
integer eh=0,ev=0,frame_clocks=0,pixels=0,frames=0,switches=0;
reg mode=0;
integer ht,vt;
always @(posedge clk_video) begin
 if(reset_video)begin eh=0;ev=0;frame_clocks=0;pixels=0;mode=0;end
 else begin
  if(display_h_pos!==eh || display_v_pos!==ev)
   $fatal(1,"truncated raster h=%0d v=%0d expected %0d,%0d",display_h_pos,display_v_pos,eh,ev);
  if(eh==0&&ev==0)begin
   if(mode!=refresh_50_video_active)switches=switches+1;
   mode=refresh_50_video_active;
  end
  if(refresh_50_video_active!==mode)$fatal(1,"mode changed within a frame");
  ht=mode?864:858;vt=mode?625:525;
  if(display_pixel_en!==(eh<720&&ev<480)||
     display_h_sync!==!(eh>=(mode?732:736)&&eh<(mode?796:798))||
     display_v_sync!==!(ev>=489&&ev<495))$fatal(1,"geometry/sync mismatch");
  // Applied-mode mailbox must settle well before the presentation window.
  if(eh==0&&ev==480&&refresh_50_decoder!==mode)
   $fatal(1,"decoder mode not settled by swap window");
  frame_clocks=frame_clocks+1;if(display_pixel_en)pixels=pixels+1;
  eh=eh+1;
  if(eh==ht)begin eh=0;ev=ev+1;end
  if(ev==vt)begin
   if(frame_clocks!=ht*vt||pixels!=345600)$fatal(1,"frame size/pixel count");
   frames=frames+1;ev=0;frame_clocks=0;pixels=0;
  end
 end
end
task request_at(input integer y,input integer x,input bit requested);
 begin
  wait(display_v_pos==y&&display_h_pos==x);
  @(negedge clk_sys);status[6]=requested;
 end
endtask
initial begin
 repeat(8)@(negedge clk_video);reset_video=0;
 request_at(123,321,1);
 wait(refresh_50_video_active);
 request_at(490,743,0);
 wait(!refresh_50_video_active);
 request_at(524,840,1);
 wait(refresh_50_video_active);
 // Several rapid menu changes coalesce without tearing the active raster.
 request_at(250,17,0);
 repeat(3)begin repeat(9)@(negedge clk_sys);status[6]=~status[6];end
 repeat(9)@(negedge clk_sys);status[6]=0;
 wait(!refresh_50_video_active);
 wait(frames>=6);
 if(switches!=4)$fatal(1,"missing mode transitions %0d",switches);
 $display("PASS six complete rasters, 345600 active pixels each, four live mode switches, coherent applied-mode CDC before presentation");
 $finish;
end
initial begin #40000000;$fatal(1,"refresh test timeout");end
endmodule
