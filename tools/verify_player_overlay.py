#!/usr/bin/env python3
"""Full-frame pixel oracle, independent of RTL glyph addressing and scene FSM."""
from pathlib import Path
import argparse,subprocess,re,json
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('results/ui-overlay/render'));a=p.parse_args();o=a.output.resolve();o.mkdir(parents=True,exist_ok=True)
src=['tools/test_media_player_overlay.sv','rtl/media_player_overlay.sv','rtl/media_subtitle_cdc.sv','rtl/media_ui_scene.sv','rtl/media_ui_divider.sv','rtl/media_overlay_compositor.sv','rtl/video_config_cdc.sv']
with (o/'compile.log').open('w') as log:subprocess.run(['verilator','--binary','--timing','-j','6','-Wno-fatal','--top-module','test_media_player_overlay','--Mdir',str(o/'obj'),*src],stdout=log,stderr=subprocess.STDOUT,check=True)
glyphs=json.loads(re.search(r'const glyphs=(\{.*?\});',Path('docs/ui/overlay-preview.html').read_text()).group(1))
colors={1:(24,27,32),2:(104,125,137),3:(238,242,244)}
def timestamp(s):return f'{s//3600:02}:{s//60%60:02}:{s%60:02}'
def oracle(w,h,known,shown,paused,seeking,pos=1340400000,total=2629890000,pattern=0):
 im=np.full((h,w,3),(32,48,64),dtype=np.uint8)
 if pattern:
  ys,xs=np.indices((h,w));im=np.stack((xs%256,(xs+ys)%256,(xs*7+ys)%256),axis=-1).astype(np.uint8)
 background=im.copy()
 if not shown:return im
 scale=9 if h>=1000 else 6 if h>=700 else 4
 labels=[timestamp(pos//360000),(timestamp((total+359999)//360000) if known else '--:--:--'),(timestamp((max(0,total-pos)+359999)//360000) if known else '--:--:--')]
 status='Seeking' if seeking else 'Paused' if paused else ''
 labels.append(status)
 im[h*452//480:h*466//480,w*32//720:w*688//720]=colors[2]
 x0=w*34//720;x1=w*686//720;y0=h*455//480;y1=h*463//480
 if known: im[y0:y1,x0:x0+(min(pos,total)*(x1-x0)//total)]=colors[3]
 else:
  for x in range(x0,x1):
   if x&8:im[y0:y1,x]=((background[y0:y1,x].astype(np.uint16)*95+np.array(colors[1],dtype=np.uint16)*160)//255).astype(np.uint8)
 for field,(label,center,y) in enumerate(zip(labels,[141,360,579,360],[469,469,469,455])):
  x0=w*center//720-len(label)*6*scale//8;y0=h*y//480
  for dy in range((7*scale+3)//4):
   gy=dy*4//scale
   for dx in range((len(label)*6*scale+3)//4):
    gx=dx*4//scale;char=gx//6;column=gx%6
    if gy<7 and char<len(label) and column<5 and (glyphs.get(label[char],[0]*7)[gy]>>(4-column))&1:im[y0+dy,x0+dx]=((0,0,0) if field==3 else colors[3])
 return im
cases=[(720,480,1,1,0,0),(1280,720,1,1,1,0),(1920,1080,1,1,0,1),(720,480,0,1,0,0),(720,480,1,0,0,0)]
cases=[(*c,1340400000,2629890000) for c in cases]+[(720,480,1,1,0,0,0,36000000),(720,480,1,1,0,0,40000000,36000000)]
cases=[(*c,0) for c in cases]+[(720,480,0,1,0,0,1340400000,2629890000,1),(720,480,1,0,0,0,1340400000,2629890000,1)]
cases += [(720,480,0,1,1,0,1340400000,2629890000,1),
          (720,480,1,1,0,1,0,36000000,1),
          (720,480,1,1,1,0,40000000,36000000,1)]
for w,h,known,shown,paused,seeking,pos,total,pattern in cases:
 name=f'{w}x{h}-k{known}-v{shown}-p{paused}-s{seeking}-q{pos}-r{pattern}';path=o/(name+'.ppm')
 r=subprocess.run([str(o/'obj/Vtest_media_player_overlay'),f'+OUT={path}',f'+W={w}',f'+H={h}',f'+KNOWN={known}',f'+SHOWN={shown}',f'+PAUSED={paused}',f'+SEEK={seeking}',f'+POSITION={pos}',f'+TOTAL={total}',f'+PATTERN={pattern}'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(o/(name+'.log')).write_text(r.stdout);r.check_returncode()
 pixels=path.read_bytes().split(b'\n',3)[3];actual=np.frombuffer(pixels,dtype=np.uint8).reshape(h,w,3);expected=oracle(w,h,known,shown,paused,seeking,pos,total,pattern)
 bad=np.any(actual!=expected,axis=2);count=int(bad.sum());print(name,'mismatched pixels',count,flush=True)
 if count:
  ys,xs=np.where(bad);print('first:',[(int(x),int(y),actual[y,x].tolist(),expected[y,x].tolist()) for x,y in zip(xs[:10],ys[:10])]);raise RuntimeError('pixel mismatch')
for top,extra in [('test_media_ui_lifetime',['rtl/media_ui_scene.sv','rtl/media_ui_divider.sv','rtl/media_overlay_compositor.sv']),('test_media_ui_state',['rtl/media_ui_state.sv']),('test_media_ui_divider',['rtl/media_ui_divider.sv'])]:
 subprocess.run(['iverilog','-g2012','-s',top,'-o',str(o/top),f'tools/{top}.sv',*extra],check=True)
 r=subprocess.run(['vvp',str(o/top)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (o/(top+'.log')).write_text(r.stdout);print(r.stdout);r.check_returncode()
print('PLAYER_OVERLAY_PIXEL_PASS')
