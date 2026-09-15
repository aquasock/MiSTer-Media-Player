#!/usr/bin/env python3
"""Check the complete viewport/waveform/UI pipeline and export RTL previews."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
sources=['rtl/media_audio_viewport.sv','rtl/media_waveform_visualizer.sv','rtl/media_player_overlay.sv','rtl/media_subtitle_cdc.sv','rtl/media_ui_scene.sv','rtl/media_ui_divider.sv','rtl/media_overlay_compositor.sv','rtl/video_config_cdc.sv']
for top in ['test_media_audio_viewport','test_media_player_overlay']:
 with (out/(top+'-compile.log')).open('w') as log:
  subprocess.run(['verilator','--binary','--timing','-j','4','-Wno-fatal','--top-module',top,'--Mdir',str(out/top),'tools/'+top+'.sv',*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
def render(top,name,args):
 path=out/(name+'.ppm')
 r=subprocess.run([str(out/top/('V'+top)),f'+OUT={path}',*args],cwd=root,capture_output=True,text=True,timeout=180)
 (out/(name+'.log')).write_text(r.stdout+r.stderr);r.check_returncode();assert 'OVERLAY_RENDER_PASS' in r.stdout
 im=np.array(Image.open(path));Image.fromarray(im).save(out/(name+'.png'));return im
results={}
for w,h in [(720,480),(1280,720),(1920,1080)]:
 for ax,ay in [(4,3),(16,9)]:
  vw=min(w,h*ax//ay);vh=min(h,w*ay//ax);x=(w-vw)//2;y=(h-vh)//2
  name=f'audio-{w}x{h}-{ax}x{ay}'
  args=[f'+W={w}',f'+H={h}',f'+X={x}',f'+Y={y}',f'+VW={vw}',f'+VH={vh}']
  im=render('test_media_audio_viewport',name,args)
  ref=render('test_media_player_overlay',name+'-local-ui',[f'+W={vw}',f'+H={vh}','+BACKGROUND=030810'])
  inside=np.zeros((h,w),dtype=bool);inside[y:y+vh,x:x+vw]=True
  assert np.all(im[~inside]==[32,48,64]),'drawing escaped viewport'
  # Waveforms occupy the upper picture; the complete lower UI must match
  # the independently verified renderer at the viewport's local resolution.
  local=im[y:y+vh,x:x+vw];assert np.array_equal(local[vh*4//5:],ref[vh*4//5:]),'UI placement/scale mismatch'
  changed=np.any(local[:vh*4//5]!=[3,8,16],axis=2)
  assert changed.sum()>vw,'waveform absent'
  results[name]={'viewport':[x,y,vw,vh],'checks':'full HDMI sync/DE, renderer dimensions, border clipping, local UI pixels and waveform presence'}
  print('PASS '+name+' viewport='+str([x,y,vw,vh]),flush=True)
 # Audio viewport must be completely bypassed for movies, including UI geometry.
 args=[f'+W={w}',f'+H={h}','+MUSIC=0','+X=100','+Y=40','+VW=400','+VH=300','+PATTERN=1']
 movie=render('test_media_audio_viewport',f'movie-{w}x{h}',args)
 ref=render('test_media_player_overlay',f'movie-reference-{w}x{h}',[f'+W={w}',f'+H={h}','+PATTERN=1'])
 assert np.array_equal(movie,ref),'movie changed'
 print(f'PASS movie bypass {w}x{h}',flush=True)
 results[f'movie-{w}x{h}']='pixel-exact full-frame bypass'
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
