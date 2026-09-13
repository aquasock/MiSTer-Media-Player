#!/usr/bin/env python3
"""Exercise the actual core aspect wiring and platform rectangle calculation."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
core = (root/'MediaPlayer_top_00.svh').read_text()
assert 'O[121],Aspect ratio,4:3,16:9;' in core
wiring = core[core.index('wire ar;'):core.index('`include "build_id.v"')]
assert 'mpeg2_new_aspect' not in wiring
platform = (root/'sys/sys_top.v').read_text()
calc = platform[platform.index('reg  ar_md_start;'):platform.index('`ifndef MISTER_DEBUG_NOHDMI', platform.index('reg  ar_md_start;'))]
# Quartus powers this FSM up at zero. Give the extracted simulation the same
# starting state; all arithmetic and configuration logic is otherwise verbatim.
calc, count = re.subn(r'reg\s+\[2:0\] state;', 'reg [2:0] state = 0;', calc)
assert count == 1
bench = '''module test_manual_aspect;
reg clk_sys=0, clk_video=0;
wire clk_vid=clk_video;
always #25 clk_sys=~clk_sys;
always #10 clk_video=~clk_video;
reg [127:0] status=0;
wire [12:0] VIDEO_ARX,VIDEO_ARY;
wire [12:0] ARX=VIDEO_ARX, ARY=VIDEO_ARY;
reg [11:0] WIDTH=1920,HEIGHT=1080;
wire [11:0] HSET=0,VSET=0,LFB_HMIN=0,LFB_HMAX=0,LFB_VMIN=0,LFB_VMAX=0;
wire HDMI_PR=0,FREESCALE=0,LFB_EN=0;
wire [12:0] arc1x=0,arc1y=0,arc2x=0,arc2y=0;
''' + wiring + calc + '''
task check_shape(input bit wide, input integer left_edge, right_edge, top_edge, bottom_edge);
begin
 @(negedge clk_sys); status[121]=wide;
 // Also exercise the retired second selection bit: it must have no effect.
 status[122]=~wide;
 repeat(500) @(negedge clk_video);
 if ({VIDEO_ARX,VIDEO_ARY} !== (wide ? {13'd16,13'd9}:{13'd4,13'd3}))
   $fatal(1,"core ratio selection failed");
 if (hmin!==left_edge || hmax!==right_edge || vmin!==top_edge || vmax!==bottom_edge)
   $fatal(1,"rectangle mismatch wide=%0d got %0d,%0d %0d,%0d",wide,hmin,hmax,vmin,vmax);
end
endtask
initial begin
 check_shape(0,240,1679,0,1079);
 check_shape(1,0,1919,0,1079);
 check_shape(0,240,1679,0,1079);
 @(negedge clk_sys); WIDTH=1280; HEIGHT=1024;
 check_shape(1,0,1279,152,871);
 check_shape(0,0,1279,32,991);
 check_shape(1,0,1279,152,871);
 $display("PASS manual aspect: 6 live switches, 1080p and 5:4 output, actual scaler bounds");
 $finish;
end
endmodule
'''
with tempfile.TemporaryDirectory(prefix='manual-aspect-') as tmp:
    tb=Path(tmp)/'test.sv'; tb.write_text(bench)
    binary=Path(tmp)/'test'
    subprocess.run(['iverilog','-g2012','-s','test_manual_aspect','-o',str(binary),str(tb),'rtl/video_config_cdc.sv','sys/math.sv'],cwd=root,check=True)
    subprocess.run(['vvp',str(binary)],cwd=root,check=True)
