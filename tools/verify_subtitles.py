#!/usr/bin/env python3
"""Directed subtitle transport/controller tests and full-frame subtitle oracle."""
from pathlib import Path
import argparse, subprocess, json, re
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('results/subtitles'));a=p.parse_args();o=a.output.resolve();o.mkdir(parents=True,exist_ok=True)
tests={
 'test_media_srt_parser':['rtl/media_srt_parser.sv'],
 'test_media_subtitles':['rtl/media_subtitles.sv','rtl/media_srt_parser.sv','rtl/media_subtitle_cdc.sv','rtl/video_config_cdc.sv','rtl/media_file_reader.sv'],
 'test_media_subtitle_hps_io':['sys/hps_io.sv','rtl/media_file_reader.sv','rtl/media_sd_owner.sv'],
}
for top,sources in tests.items():
 with (o/(top+'-compile.log')).open('w') as f:subprocess.run(['iverilog','-g2012','-s',top,'-o',str(o/top),'tools/'+top+'.sv',*sources],stdout=f,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run(['vvp',str(o/top)],capture_output=True,text=True,timeout=60);(o/(top+'.log')).write_text(r.stdout+r.stderr);print(r.stdout,flush=True);r.check_returncode()
subprocess.run(['python3','tools/make_overlay_roms.py','--check'],check=True)
# Load the established player oracle and reuse its compiled renderer and checks.
import sys,runpy
sys.argv=['tools/verify_player_overlay.py','--output',str(o/'render')]
base=runpy.run_path('tools/verify_player_overlay.py');oracle=base['oracle'];glyphs=base['glyphs']
for w,h,shown,lines,epoch in [(720,480,0,1,1),(720,480,1,2,1),(1280,720,0,2,1),(1920,1080,0,2,1),(720,480,0,2,0)]:
 path=o/f'subtitles-{w}x{h}-hud{shown}-lines{lines}-epoch{epoch}.ppm'
 cmd=[str(o/'render/obj/Vtest_media_player_overlay'),f'+OUT={path}',f'+W={w}',f'+H={h}',f'+SHOWN={shown}',f'+SUBTITLES={lines}',f'+SUBEPOCH={epoch}']
 r=subprocess.run(cmd,capture_output=True,text=True,timeout=120);r.check_returncode();(path.with_suffix('.log')).write_text(r.stdout)
 expected=oracle(w,h,1,shown,0,0)
 if epoch==1:
  scale=9 if h>=1000 else 6 if h>=700 else 4
  for text,y in zip(['Hello, world!','Subtitle line two.'][:lines],[417,431] if lines==2 else [431]):
   x0=w//2-len(text)*6*scale//8;y0=h*y//480
   tw=(len(text)*6*scale+3)//4;th=(7*scale+3)//4
   # Existing dark-alpha palette behind the text, using reserved rectangles.
   region=expected[y0-2:y0+th+2,x0-2:x0+tw+2].astype(np.uint16)
   expected[y0-2:y0+th+2,x0-2:x0+tw+2]=((region*95+np.array([24,27,32],dtype=np.uint16)*160)//255).astype(np.uint8)
   for dy in range(th):
    for dx in range(tw):
     gx=dx*4//scale;gy=dy*4//scale;ch=gx//6;column=gx%6
     if ch<len(text) and column<5 and (glyphs[text[ch]][gy]>>(4-column))&1:expected[y0+dy,x0+dx]=[238,242,244]
 actual=np.frombuffer(path.read_bytes().split(b'\n',3)[3],dtype=np.uint8).reshape(h,w,3)
 bad=np.any(actual!=expected,axis=2);count=int(bad.sum());print(path.name,'mismatched pixels',count,flush=True)
 if count:
  yy,xx=np.where(bad);print('first',int(xx[0]),int(yy[0]),actual[yy[0],xx[0]],expected[yy[0],xx[0]]);raise RuntimeError('subtitle pixels differ')
print('SUBTITLE_SUITE_PASS')
