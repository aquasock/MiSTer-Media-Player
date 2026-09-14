#!/usr/bin/env python3
"""Native digital output/control tests; not a stock Main hardware qualification."""
import argparse,subprocess,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);root=Path(__file__).resolve().parents[1]
cases={
 'media_hdmi_audio_control':[str(s.relative_to(root)) for s in (root/'rtl/platform').glob('*.sv')],
 'media_pcm_i2s':['rtl/audio/media_pcm_i2s.sv','rtl/audio/media_pcm_sink.sv'],
 'hdmi_audio_config':['rtl/platform/hdmi_audio_config.sv','rtl/platform/i2c_register_master.sv','rtl/platform/hdmi_i2c_owner.sv'],
 'hdmi_i2c_write_watch':['rtl/platform/hdmi_i2c_write_watch.sv'],
 'media_audio_rate_control':['rtl/platform/media_audio_rate_control.sv'],
}
results={}
for case,sources in cases.items():
 with (out/f'{case}-compile.log').open('w') as log:
  subprocess.run(['iverilog','-g2012','-I',str(root/'tools'),'-s','test_'+case,'-o',str(out/case),str(root/f'tools/test_{case}.sv'),*[str(root/s) for s in sources]],stdout=log,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run(['vvp',str(out/case)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=30)
 (out/f'{case}.log').write_text(r.stdout)
 if r.returncode or 'PASS ' not in r.stdout:raise RuntimeError(case+': '+r.stdout)
 results[case]=r.stdout;print(r.stdout,flush=True)
# Strict lint includes the connected platform-control hierarchy.
with (out/'lint.log').open('w') as log:
 for top,sources in [('media_hdmi_audio_control',list((root/'rtl/platform').glob('*.sv'))),('media_pcm_i2s',[root/s for s in cases['media_pcm_i2s']])]:
  subprocess.run(['verilator','--lint-only','-Wall','-Wno-PINCONNECTEMPTY','--top-module',top,*map(str,sources)],stdout=log,stderr=subprocess.STDOUT,check=True)
(out/'summary.json').write_text(json.dumps({'scope':'standalone serial-wire and platform-control simulation; no physical HPS or HDMI receiver','cases':results},indent=2)+'\n')
