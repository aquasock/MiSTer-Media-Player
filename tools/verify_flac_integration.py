#!/usr/bin/env python3
"""Production PCM CDC/HDMI integration with vendor FIFO and functional PLL model."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--quartus',type=Path,default=Path('/home/vash/intelFPGA_lite/17.0/quartus'))
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
platform=[str(s.relative_to(root)) for s in (root/'rtl/platform').glob('*.sv') if s.name!='media_audio_clocks.sv']
cases={'media_native_audio':platform+['rtl/video_config_cdc.sv','rtl/audio/media_pcm_i2s.sv','rtl/audio/media_pcm_sink.sv','sys/spdif.v','sys/sigma_delta_dac.v',str(a.quartus/'eda/sim_lib/altera_mf.v')], 'media_music_time':['rtl/audio/media_music_time.sv']}
results={}
for name,sources in cases.items():
 with (out/(name+'-compile.log')).open('w') as log:
  subprocess.run(['iverilog','-g2012','-Itools','-s','test_'+name,'-o',str(out/name),'tools/test_'+name+'.sv',*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run(['vvp',str(out/name)],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
 (out/(name+'.log')).write_text(r.stdout);print(r.stdout,flush=True)
 r.check_returncode();assert 'PASS ' in r.stdout;results[name]=r.stdout
(out/'summary.json').write_text(json.dumps({'scope':'production native wrapper, vendor FIFO, functional PLL model; physical HDMI/clock/hardware qualification pending','results':results},indent=2)+'\n')
