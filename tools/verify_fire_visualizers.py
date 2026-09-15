#!/usr/bin/env python3
"""Check FFT Fire, O-scope, viewport/UI alignment and export RTL previews."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
sources=['rtl/media_xy_visualizer.sv','rtl/media_audio_fft.sv','rtl/media_fire_renderer.sv','rtl/media_audio_visualizers.sv','rtl/media_audio_viewport.sv','rtl/media_waveform_visualizer.sv','rtl/media_player_overlay.sv','rtl/media_subtitle_cdc.sv','rtl/media_ui_scene.sv','rtl/media_ui_divider.sv','rtl/media_overlay_compositor.sv','rtl/video_config_cdc.sv']
for top in ['test_media_fft_peaks','test_media_xy_visualizer','test_media_fire_visualizers','test_media_player_overlay']:
 with (out/(top+'-compile.log')).open('w') as log:
  subprocess.run(['verilator','--binary','--timing','-j','4','-Wno-fatal','--top-module',top,'--Mdir',str(out/top),'tools/'+top+'.sv',*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(out/'test_media_xy_visualizer'/'Vtest_media_xy_visualizer')],capture_output=True,text=True,timeout=30)
(out/'xy-trace.log').write_text(r.stdout+r.stderr);r.check_returncode();assert 'PASS XY' in r.stdout
r=subprocess.run([str(out/'test_media_fft_peaks'/'Vtest_media_fft_peaks')],capture_output=True,text=True,timeout=30)
(out/'fft-peaks.log').write_text(r.stdout+r.stderr);r.check_returncode();assert 'PASS FFT peaks' in r.stdout
def render(top,name,args):
 path=out/(name+'.ppm')
 r=subprocess.run([str(out/top/('V'+top)),f'+OUT={path}',*args],cwd=root,capture_output=True,text=True,timeout=180)
 (out/(name+'.log')).write_text(r.stdout+r.stderr);r.check_returncode();assert 'OVERLAY_RENDER_PASS' in r.stdout
 im=np.array(Image.open(path));Image.fromarray(im).save(out/(name+'.png'));return im
results={}
for w,h in [(720,480),(1280,720),(1920,1080)]:
 for ax,ay in [(4,3),(16,9)]:
  vw=min(w,h*ax//ay);vh=min(h,w*ay//ax);x=(w-vw)//2;y=(h-vh)//2
  name=f'fire-{w}x{h}-{ax}x{ay}'
  args=[f'+W={w}',f'+H={h}',f'+X={x}',f'+Y={y}',f'+VW={vw}',f'+VH={vh}','+SHOWN=0']
  im=render('test_media_fire_visualizers',name,args)
  inside=np.zeros((h,w),dtype=bool);inside[y:y+vh,x:x+vw]=True
  assert np.all(im[~inside]==[32,48,64]),'drawing escaped viewport'
  local=im[y:y+vh,x:x+vw]
  changed=np.any(local[:vh*4//5]!=[3,8,16],axis=2)
  assert changed.sum()>vw,'waveform absent'
  # Independent hard-block contract: only two solid colors, with exactly
  # one orange cap above yellow blocks in each nonempty spectrum column.
  picture=local
  palette=np.unique(picture.reshape(-1,3),axis=0)
  assert all(tuple(c) in ((3,8,16),(255,136,0),(255,221,0),(255,48,48)) for c in palette),'blended color'
  for band in range(32):
   col=picture[:,((2*band+1)*vw)//64]
   reds=np.flatnonzero(np.all(col==[255,48,48],axis=1))
   if len(reds):
    assert len(reds)==max(1,(vh*3//4//32)//4),'peak cap thickness'
    assert np.all(np.diff(reds)==1),'split peak cap'
   lit=np.all(col==[255,136,0],axis=1)|np.all(col==[255,221,0],axis=1)
   ys=np.flatnonzero(lit)
   if not len(ys):continue
   assert not len(reds) or reds[0]<=ys[0],'peak below live band'
   assert ys[-1]==vh-1,'FFT did not reach bottom edge'
   groups=np.split(ys,np.where(np.diff(ys)>1)[0]+1)
   assert np.all(col[groups[0]]==[255,136,0]),'missing orange cap'
   for group in groups[1:]:assert np.all(col[group]==[255,221,0]),'non-yellow lower block'
  results[name]={'viewport':[x,y,vw,vh],'checks':'full HDMI sync/DE, renderer dimensions, border clipping, local UI pixels and waveform presence'}
  print('PASS '+name+' viewport='+str([x,y,vw,vh]),flush=True)
 # Audio viewport must be completely bypassed for movies, including UI geometry.
 args=[f'+W={w}',f'+H={h}','+MUSIC=0','+X=100','+Y=40','+VW=400','+VH=300','+PATTERN=1']
 movie=render('test_media_fire_visualizers',f'movie-{w}x{h}',args)
 ref=render('test_media_player_overlay',f'movie-reference-{w}x{h}',[f'+W={w}',f'+H={h}','+PATTERN=1'])
 assert np.array_equal(movie,ref),'movie changed'
 print(f'PASS movie bypass {w}x{h}',flush=True)
 results[f'movie-{w}x{h}']='pixel-exact full-frame bypass'
# Direct O-scope pixel comparison is also asserted inside the integration bench.
render('test_media_fire_visualizers','scope-regression',['+W=720','+H=480','+VW=640','+VH=480','+X=40','+FIRE=0'])
silence=render('test_media_fire_visualizers','silence',['+W=720','+H=480','+VW=640','+VH=480','+X=40','+SILENT=1','+SHOWN=0'])
assert np.all(silence[:400,40:680]==[3,8,16]),'silence creates flames'
render('test_media_fire_visualizers','live-switch',['+W=720','+H=480','+VW=640','+VH=480','+X=40','+SWITCH=1'])
results['live-switch']='frame-boundary changes, stable timing';results['scope']='pixel-exact original waveform';results['silence']='no flame energy'
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')

for w,h in [(720,480),(1280,720),(1920,1080)]:
 for ax,ay in [(4,3),(16,9)]:
  vw=min(w,h*ax//ay);vh=min(h,w*ay//ax);x=(w-vw)//2;y=(h-vh)//2
  name=f'xy-{w}x{h}-{ax}x{ay}'
  im=render('test_media_fire_visualizers',name,[f'+W={w}',f'+H={h}',f'+X={x}',f'+Y={y}',f'+VW={vw}',f'+VH={vh}','+FIRE=2','+SHOWN=0'])
  inside=np.zeros((h,w),dtype=bool);inside[y:y+vh,x:x+vw]=True
  assert np.all(im[~inside]==[32,48,64]),'XY escaped aspect viewport'
  local=im[y:y+vh,x:x+vw]
  assert np.count_nonzero(local[:,:,1])>vw,'XY trace missing'
  assert np.all(local[:,:,1]>=local[:,:,0]) and np.all(local[:,:,0]==local[:,:,2]),'XY phosphor palette'
  results[name]='XY phosphor, aspect clipping and full HDMI timing'
  print('PASS '+name,flush=True)
render('test_media_fire_visualizers','xy-live-switch',['+W=720','+H=480','+VW=640','+VH=480','+X=40','+SWITCH=2'])
results['xy-live-switch']='frame-boundary XY switching, stable HDMI timing'
render('test_media_fire_visualizers','xy-ui-preview',['+W=1280','+H=720','+VW=1280','+VH=720','+FIRE=2'])
render('test_media_fire_visualizers','fft-ui-preview',['+W=1280','+H=720','+VW=1280','+VH=720','+FIRE=1'])
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
