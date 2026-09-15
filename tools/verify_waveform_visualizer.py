#!/usr/bin/env python3
"""Verify the read-only waveform renderer and export deterministic RTL previews."""
import argparse,json,subprocess,os
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--synthesize',action='store_true',help='run standalone Quartus mapping, not a full RBF build')
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[1]
sources=['tools/test_media_waveform_visualizer.sv','rtl/media_waveform_visualizer.sv','rtl/video_config_cdc.sv']
with (out/'compile.log').open('w') as log:
 subprocess.run(['verilator','--binary','--timing','-Wno-fatal','--top-module','test_media_waveform_visualizer','--Mdir',str(out/'obj'),'-j','4',*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
results={}
for w,h in [(720,480),(1280,720),(1920,1080)]:
 stem=f'waveform-{w}x{h}';ppm=out/(stem+'.ppm')
 r=subprocess.run([str(out/'obj/Vtest_media_waveform_visualizer'),f'+WIDTH={w}',f'+HEIGHT={h}',f'+OUTPUT={ppm}'],capture_output=True,text=True,timeout=120)
 (out/(stem+'.log')).write_text(r.stdout+r.stderr);r.check_returncode()
 assert 'PASS waveform' in r.stdout
 Image.open(ppm).save(out/(stem+'.png'));results[stem]=r.stdout;print(r.stdout,flush=True)
with (out/'lint.log').open('w') as log:
 subprocess.run(['verilator','--lint-only','-Wall','-Wno-PINCONNECTEMPTY','--top-module','media_waveform_visualizer',*sources[1:]],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')

if a.synthesize:
 synth=out/'synthesis';synth.mkdir(exist_ok=True)
 qsf='set_global_assignment -name FAMILY "Cyclone V"\nset_global_assignment -name DEVICE 5CSEBA6U23I7\nset_global_assignment -name TOP_LEVEL_ENTITY media_waveform_visualizer\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 2\n'
 for source in sources[1:]:qsf+=f'set_global_assignment -name SYSTEMVERILOG_FILE "{root/source}"\n'
 (synth/'waveform.qsf').write_text(qsf)
 env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus-compat-libs'+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
 with (synth/'map.log').open('w') as log:
  subprocess.run(['/home/vash/intelFPGA_lite/17.0/quartus/bin/quartus_map','waveform'],cwd=synth,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
 print((synth/'waveform.map.summary').read_text())
