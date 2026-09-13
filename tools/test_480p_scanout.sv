`timescale 1ns/1ps
// End-to-end raster/cache check with an ideal dual-clock RAM model and
// variable DDR response stalls and a bank reset during vertical blanking.
// No H.262 decoding or HDMI scaler capture is simulated here.
module test_480p_scanout;
`ifdef TEST_REFRESH_50
localparam TEST_50=1;
`else
localparam TEST_50=0;
`endif
localparam HT=TEST_50?864:858, VT=TEST_50?625:525;
localparam HS_BEGIN=TEST_50?732:736, HS_END=TEST_50?796:798;
wire applied_50;
reg vc=0,mc=0,reset=1,complete=0,swap_reset=0;
wire fb_reset=reset|swap_reset;
always #18.518519 vc=~vc;
always #8.333333 mc=~mc;
wire [11:0] h,v;wire en,hs,vs;
mpeg2_video_720x480p #(.ENABLE_REFRESH_SELECTION(1)) timing(.clk(vc),.reset(reset),.h_pos(h),.v_pos(v),
 .pixel_en(en),.h_sync(hs),.v_sync(vs),.refresh_50_request(TEST_50!=0),.refresh_50_active(applied_50));
wire [7:0] burst;wire [28:0] addr;wire rd;reg [63:0] data=0;reg valid=0;
integer remaining=0,cyc=0;reg [28:0] next_addr;
wire busy=(remaining!=0)||(cyc%7==0);
wire ready,seen,error;wire [7:0] r,g,b;wire de,oh,ov;
mpeg2_luma_framebuffer fb(.reset(fb_reset),.mem_clk(mc),.picture_complete(complete),
 .horizontal_size(14'd720),.vertical_size(14'd480),.ddram_busy(busy),
 .ddram_dout(data),.ddram_dout_ready(valid),.ddram_burstcnt(burst),
 .ddram_addr(addr),.ddram_rd(rd),.cache_ready(ready),.read_seen(seen),.cache_error(error),
 .rd_clk(vc),.h_pos(h),.v_pos(v),.pixel_en(en),.h_sync(hs),.v_sync(vs),
 .video_r(r),.video_g(g),.video_b(b),.video_de(de),.video_hs(oh),.video_vs(ov));
function [7:0] luminance(input integer x,input integer y);
 luminance=16+((x/8+y)%200);
endfunction
integer j,offset;
always @(posedge mc) begin
 cyc<=cyc+1;valid<=0;
 if(fb_reset)remaining<=0;
 else if(rd&&!busy)begin remaining<=burst;next_addr<=addr;end
 else if(remaining>0 && cyc%5!=0)begin
  for(j=0;j<8;j=j+1)begin
   if(next_addr<29'h0600a8c0)begin
    offset=(next_addr-29'h06000000)*8+j;
    data[j*8+:8]<=luminance(offset%720,offset/720);
   end else data[j*8+:8]<=128;
  end
  valid<=1;next_addr<=next_addr+1;remaining<=remaining-1;
 end
end
reg swap_tested=0;
always @(negedge vc) begin
 if(check && v==480 && h==16)begin swap_reset=1;swap_tested=1;end
 if(v==480 && h==24)swap_reset=0;
end
integer x,y,n=0,pixels=0,lines=0,hs_ticks=0,vs_ticks=0;
integer eh=0,ev=0,gray;reg last_en=0,last_hs=1,last_vs=1,check=0;
always @(posedge vc) begin
 x=h;y=v;
 if(!reset)begin
  if(x!=eh||y!=ev)$fatal(1,"raster counter mismatch");
  eh=eh+1;if(eh==(applied_50?864:858))begin eh=0;ev=ev+1;if(ev==(applied_50?625:525))ev=0;end
  if(en!=(x<720&&y<480)||hs!=!(x>=(applied_50?732:736)&&x<(applied_50?796:798))||vs!=!(y>=489&&y<495))$fatal(1,"timing geometry");
  if(x==0&&y==0&&fb.picture_present_rd&&(applied_50==TEST_50))check=1;
  #1;
  if(check)begin
   if(de!=last_en||oh!=last_hs||ov!=last_vs)$fatal(1,"sync/data pipeline alignment");
   if(de)begin
    gray=(298*(luminance((x==0?HT-1:x-1),(x==0?(y==0?VT-1:y-1):y))-16)+128)>>>8;
    if(r!==gray[7:0]||g!==gray[7:0]||b!==gray[7:0])$fatal(1,"pixel at h=%0d v=%0d rgb=%0d,%0d,%0d expected %0d",x,y,r,g,b,gray);
    pixels=pixels+1;
   end
   n=n+1;
   if(n==HT*VT)begin
    if(pixels!=720*480||error)$fatal(1,"pixel count/cache error %0d",pixels);
    if(!swap_tested)$fatal(1,"missing frame-bank reset");
    $display("PASS frame-bank reset preserves continuous sync/DE; 480p: exact frame pixel clocks, 345600 exact pixels, negative sync, stalled DDR, line refills and edge alignment");$finish;
   end
  end
  last_en=(x<720&&y<480);last_hs=!(x>=(applied_50?732:736)&&x<(applied_50?796:798));last_vs=!(y>=489&&y<495);
 end
end
initial begin repeat(6)@(negedge vc);reset=0;repeat(4)@(negedge mc);complete=1;@(negedge mc);complete=0;#100000000;$fatal(1,"timeout");end
endmodule

module altsyncram #(
 parameter operation_mode="DUAL_PORT",width_a=64,widthad_a=8,numwords_a=180,
 width_b=64,widthad_b=8,numwords_b=180,outdata_reg_b="UNREGISTERED",
 address_reg_b="CLOCK1",read_during_write_mode_mixed_ports="DONT_CARE",
 ram_block_type="M10K",intended_device_family="Cyclone V"
)(input clock0,clock1,input [widthad_a-1:0] address_a,input [width_a-1:0] data_a,
 input wren_a,input [widthad_b-1:0] address_b,output [width_b-1:0] q_b,
 input aclr0,aclr1,addressstall_a,addressstall_b,byteena_a,byteena_b,
 input [width_b-1:0] data_b,input wren_b,output [width_a-1:0] q_a);
reg [width_a-1:0] mem[0:numwords_a-1];reg [widthad_b-1:0] ra;
always @(posedge clock0)if(wren_a)mem[address_a]<=data_a;
always @(posedge clock1)ra<=address_b;
assign q_b=mem[ra];assign q_a=0;
endmodule
