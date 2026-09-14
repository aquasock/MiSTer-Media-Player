#!/usr/bin/env python3
"""Exercise the future FLAC/WAV shared PCM boundary, without format decoding."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
with (out/'compile.log').open('w') as f:
 subprocess.run(['iverilog','-g2012','-s','test_media_pcm_sink','-o',str(out/'sim'),
 'tools/test_media_pcm_sink.sv','rtl/audio/media_pcm_sink.sv'],stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run(['vvp',str(out/'sim')],capture_output=True,text=True,timeout=60)
(out/'run.log').write_text(r.stdout+r.stderr)
if r.returncode or 'MEDIA_PCM_SINK_PASS 202' not in r.stdout:raise RuntimeError(r.stdout+r.stderr)
(out/'summary.json').write_text(json.dumps({'passed':True,'result':r.stdout.splitlines()[0]},indent=2)+'\n')
print(r.stdout.strip())
