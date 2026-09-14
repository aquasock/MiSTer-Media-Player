#!/usr/bin/env python3
"""Full FLAC-to-DDR-to-PCM regression, with bus stalls and cancellation."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--corpus',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);corpus=a.corpus.resolve();root=Path(__file__).resolve().parents[1]
sources=sorted((root/'rtl/audio/flac').glob('*.sv'))+[root/'rtl/audio/media_pcm_sink.sv',root/'tools/test_flac_ddr.sv']
with (out/'compile.log').open('w') as log:
 subprocess.run(['verilator','--binary','--timing','-Wno-TIMESCALEMOD','-j','6','--top-module','test_flac_ddr','--Mdir',str(out/'obj'),*map(str,sources)],stdout=log,stderr=subprocess.STDOUT,check=True)
results=[]
def run(name,path,pcm,cancel=0,sink=0,error=0,immediate=0):
 r=subprocess.run([str(out/'obj/Vtest_flac_ddr'),f'+input={path}',f'+pcm={pcm}',f'+cancel={cancel}',f'+sink={sink}',f'+error={error}',f'+immediate={immediate}'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
 (out/f'{name}.log').write_text(r.stdout)
 if r.returncode or 'PASS ' not in r.stdout:raise RuntimeError(name+': '+r.stdout)
 print(name+': '+r.stdout.splitlines()[0],flush=True);results.append({'name':name,'result':r.stdout.splitlines()[0]})
for item in json.loads((corpus/'manifest.json').read_text())['files']:
 run(Path(item['file']).stem,corpus/item['file'],corpus/item['reference_pcm'])
for mode in range(1,6):run(f'cancel-{mode}',corpus/'tones-level5.flac',corpus/'tones.pcm',cancel=mode)
run('zero-latency',corpus/'tones-level5.flac',corpus/'tones.pcm',immediate=1)
run('shared-sink',corpus/'tones-level5.flac',corpus/'tones.pcm',sink=1)
base=(corpus/'tones-level5.flac').read_bytes();bad=out/'bad-final-crc.flac';bad.write_bytes(base[:-1]+bytes([base[-1]^1]))
run('bad-final-crc',bad,corpus/'tones.pcm',error=4)
(out/'summary.json').write_text(json.dumps({'scope':'RTL external frame store plus modeled DDR port and shared PCM sink; no production bus mux/CDC/HDMI','cases':results},indent=2)+'\n')
