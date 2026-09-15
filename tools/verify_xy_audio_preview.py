#!/usr/bin/env python3
"""Render the same audio segment through baseline and current XY RTL."""
import argparse,subprocess,json
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('audio',type=Path);p.add_argument('--start',type=float,default=0)
p.add_argument('--baseline',default='06256f8');p.add_argument('--output',type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
raw=subprocess.check_output(['ffmpeg','-v','error','-ss',str(a.start),'-i',str(a.audio.resolve()),'-t','1','-map','0:a:0','-af','aresample=44100:filter_size=64','-ar','44100','-ac','2','-c:a','pcm_s16le','-f','s16le','-'])
pcm=np.frombuffer(raw,dtype='<u2').reshape(-1,2)
assert 0<len(pcm)<=65536
hexfile=out/'audio.hex';hexfile.write_text(''.join(f'{int(l):04x}{int(r):04x}\n' for l,r in pcm))
sources=['rtl/media_audio_fft.sv','rtl/media_fire_renderer.sv','rtl/media_audio_visualizers.sv','rtl/media_audio_viewport.sv','rtl/media_waveform_visualizer.sv','rtl/media_player_overlay.sv','rtl/media_subtitle_cdc.sv','rtl/media_ui_scene.sv','rtl/media_ui_divider.sv','rtl/media_overlay_compositor.sv','rtl/video_config_cdc.sv']
old=out/'baseline_xy.sv';old.write_bytes(subprocess.check_output(['git','show',a.baseline+':rtl/media_xy_visualizer.sv'],cwd=root))
for tag,xy in [('before',str(old)),('after','rtl/media_xy_visualizer.sv')]:
 obj=out/tag
 with (out/(tag+'-compile.log')).open('w') as log:
  subprocess.run(['verilator','--binary','--timing','-j','4','-Wno-fatal','--top-module','test_media_fire_visualizers','--Mdir',str(obj),'tools/test_media_fire_visualizers.sv',xy,*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
 for w,h in [(720,480),(1280,720),(1920,1080)]:
  path=out/f'{tag}-{w}x{h}.ppm'
  with (out/f'{tag}-{w}x{h}.log').open('w') as log:
   subprocess.run([str(obj/'Vtest_media_fire_visualizers'),f'+OUT={path}',f'+W={w}',f'+H={h}',f'+VW={w}',f'+VH={h}','+FIRE=2','+SHOWN=0',f'+PCM={hexfile}',f'+PCM_SAMPLES={len(pcm)}'],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
  Image.open(path).save(path.with_suffix('.png'))
(out/'source.json').write_text(json.dumps({'audio':str(a.audio.resolve()),'start_seconds':a.start,'baseline':a.baseline,'samples':len(pcm),'note':'RTL previews use identical PCM stimulus and synthetic bench video timing; not HDMI captures.'},indent=2)+'\n')
print('PASS identical-audio previews at 480p, 720p and 1080p: '+str(out))
