#!/usr/bin/env python3
"""Test H.262 color metadata, picture ownership, CDC, and both RGB matrices."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args()
results={}
def packed(fields):
    s=''.join(format(v,f'0{n}b') for v,n in fields)
    s+='0'*(-len(s)%8)
    return bytes(int(s[i:i+8],2) for i in range(0,len(s),8))
seq=b'\0\0\1\xb3'+packed([(720,12),(480,12),(3,4),(4,4),(10000,18),(1,1),(112,10),(0,1),(0,1),(0,1)])
seq+=b'\0\0\1\xb5'+packed([(1,4),(0x48,8),(1,1),(1,2),(0,2),(0,2),(0,12),(1,1),(0,8),(0,1),(0,2),(0,5)])
def display(matrix,desc=1,marker=1):
    fields=[(2,4),(5,3),(desc,1)]
    if desc: fields += [(1,8),(1,8),(matrix,8)]
    fields += [(720,14),(marker,1),(480,14)]
    return b'\0\0\1\xb5'+packed(fields)
commands=[]
def send(data,valid,matrix):
    commands.extend(f"send(8'h{x:02x});" for x in data)
    commands.append(f"check(1'b{valid},8'd{matrix});")
send(seq,0,2)
for m in (1,5,6,2,0,3,4,7,255):send(display(m),1,m)
send(display(1,desc=0),0,2)
send(display(1,marker=0),0,2)
send(display(1),1,1)
send(seq,0,2)
# Truncated metadata cannot become valid, and cannot leak into a new sequence.
send(display(1)[:7],0,2)
send(seq,0,2)
send(display(6),1,6)
frontend='''module test_color_frontend;
reg clk=0,reset=1,valid=0;
reg [7:0] data=0;
wire description;wire [7:0] matrix;
always #5 clk=~clk;
mpeg2_h262_frontend dut(.clk(clk),.reset(reset),.stream_valid(valid),
.stream_data(data),.colour_description_valid(description),.matrix_coefficients(matrix));
task send(input [7:0] byte_value);begin
 @(negedge clk);valid=1;data=byte_value;
 @(negedge clk);valid=0;
 repeat(2)@(negedge clk);
end endtask
task check(input bit expected_valid,input [7:0] expected_matrix);begin
 if(description!==expected_valid || matrix!==expected_matrix)
 $fatal(1,"metadata mismatch got %0d/%0d expected %0d/%0d",description,matrix,expected_valid,expected_matrix);
end endtask
initial begin
 repeat(3)@(negedge clk);reset=0;
'''+ '\n'.join(commands)+'''
 reset=1;@(negedge clk);check(0,2);
 $display("PASS color frontend: tagged, absent, flag-clear, malformed marker, truncated, repeated header, stalls and reset");$finish;
end
endmodule
'''
# Compare 601 to the pre-change RTL, and 709 to floating-point inverse matrix
# equations (Kr=0.2126, Kb=0.0722), with clipping and nearest-integer rounding.
arithmetic='''module test_color_arithmetic;
reg [7:0] y,cb,cr;reg mode=0;
wire [7:0] r,g,b,old_r,old_g,old_b;
mpeg2_ycbcr_to_rgb dut(mode,y,cb,cr,r,g,b);
color_baseline old(y,cb,cr,old_r,old_g,old_b);
integer rr,gg,bb,delta,max_delta=0;
real yy,u,v;
function integer reference_clip(input real value);
 if(value<0.0)reference_clip=0;
 else if(value>255.0)reference_clip=255;
 else reference_clip=$rtoi(value+0.5);
endfunction
function integer distance(input integer x,z);
 distance=(x>z)?x-z:z-x;
endfunction
initial begin
 for(integer yi=0;yi<256;yi++)begin
 for(integer ui=0;ui<256;ui++)begin
 for(integer vi=0;vi<256;vi++)begin
  y=yi;cb=ui;cr=vi;mode=0;#1;
  if({r,g,b}!=={old_r,old_g,old_b})$fatal(1,"601 compatibility changed");
  mode=1;#1;
  yy=(yi-16)*255.0/219.0;u=(ui-128)*255.0/224.0;v=(vi-128)*255.0/224.0;
  rr=reference_clip(yy+2.0*(1.0-0.2126)*v);
  gg=reference_clip(yy-2.0*0.0722*(1.0-0.0722)/(1.0-0.2126-0.0722)*u
                        -2.0*0.2126*(1.0-0.2126)/(1.0-0.2126-0.0722)*v);
  bb=reference_clip(yy+2.0*(1.0-0.0722)*u);
  delta=distance(r,rr);if(delta>max_delta)max_delta=delta;
  delta=distance(g,gg);if(delta>max_delta)max_delta=delta;
  delta=distance(b,bb);if(delta>max_delta)max_delta=delta;
  if(max_delta>1)$fatal(1,"709 error exceeds one code at %0d,%0d,%0d",yi,ui,vi);
 end end end
 $display("PASS color arithmetic: all 16777216 input triples, 601 exact, 709 maximum error %0d",max_delta);$finish;
end
endmodule
'''
with tempfile.TemporaryDirectory(prefix='color-regression-') as tmp:
    tmp=Path(tmp)
    def run(name,sources):
        binary=tmp/name
        subprocess.run(['iverilog','-g2012','-s',name,'-o',str(binary),*map(str,sources)],cwd=root,check=True)
        result=subprocess.check_output(['vvp',str(binary)],cwd=root,text=True)
        assert 'PASS' in result;print(result,end='',flush=True);results[name]=result
    front=tmp/'frontend.sv';front.write_text(frontend)
    run('test_color_frontend',[front,'rtl/mpeg2_new/mpeg2_h262_frontend.sv'])
    run('test_picture_color',['tools/test_picture_color.sv','rtl/mpeg2_new/mpeg2_h262_picture_color.sv'])
    run('test_media_color_control',['tools/test_media_color_control.sv','rtl/media_color_control.sv','rtl/video_config_cdc.sv'])
    # Reuse the stalled-DDR/line-cache raster test with colored chroma and
    # active 709 selection, checking exact output at every visible pixel.
    scan=(root/'tools/test_480p_scanout.sv').read_text()
    scan=scan.replace('module test_480p_scanout;', 'module test_color_scanout;')
    scan=scan.replace('mpeg2_luma_framebuffer fb(', 'mpeg2_luma_framebuffer #(.ENABLE_COLOR_MATRIX(1)) fb(.matrix_bt709(1\'b1),')
    scan=scan.replace("end else data[j*8+:8]<=128;", "end else data[j*8+:8]<=(next_addr<29'h0600d2f0)?8'd103:8'd80;")
    scan=scan.replace('integer x,y,n=0,', 'integer rr,gg,bb;\nfunction integer clip(input integer value);clip=value<0?0:value>255?255:value;endfunction\ninteger x,y,n=0,')
    scan=scan.replace('gray=(298*', 'gray=(298*')
    start=scan.index('    gray=(298*');end=scan.index('    pixels=pixels+1;',start)
    scan=scan[:start]+"""    gray=luminance((x==0?857:x-1),(x==0?(y==0?524:y-1):y))-16;
    rr=clip((298*gray+459*(-48)+128)>>>8);
    gg=clip((298*gray-55*(-25)-136*(-48)+128)>>>8);
    bb=clip((298*gray+541*(-25)+128)>>>8);
    if(r!==rr[7:0]||g!==gg[7:0]||b!==bb[7:0])$fatal(1,"709 raster RGB/position mismatch h=%0d v=%0d",x,y);
"""+scan[end:]
    scan=scan.replace('PASS frame-bank reset', 'PASS 709 colored scanout and frame-bank reset')
    scantb=tmp/'scanout.sv';scantb.write_text(scan)
    run('test_color_scanout',[scantb,'rtl/mpeg2_video_720x480p.sv',
        'rtl/mpeg2_luma_framebuffer.sv','rtl/mpeg2_progressive_geometry.sv',
        'rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv'])
    old=subprocess.check_output(['git','show','62baf08:rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv'],cwd=root,text=True)
    baseline=tmp/'baseline.sv';baseline.write_text(old.replace('module mpeg2_ycbcr_to_rgb_bt601','module color_baseline'))
    tb=tmp/'arithmetic.sv';tb.write_text(arithmetic)
    obj=tmp/'obj'
    compilation=subprocess.run(['verilator','--binary','--timing','-j','6','-Wno-fatal','--top-module','test_color_arithmetic','--Mdir',str(obj),str(tb),str(baseline),'rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv'],cwd=root,text=True,capture_output=True)
    if compilation.returncode:raise RuntimeError(compilation.stdout+compilation.stderr)
    result=subprocess.check_output([str(obj/'Vtest_color_arithmetic')],cwd=root,text=True)
    assert 'PASS' in result;print(result,end='',flush=True);results['arithmetic']=result
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(results,indent=2)+'\n')
