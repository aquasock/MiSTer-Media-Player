#!/usr/bin/env python3
"""Concurrent shared-IDCT differential samples, sparse blocks and reset sweeps."""
import argparse,subprocess,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
with (out/'compile.log').open('w') as f:
 subprocess.run(['iverilog','-g2012','-s','test_shared_idct','-o',str(out/'test'),
 'tools/test_shared_idct.sv','rtl/mpeg2_new/mpeg2_h262_shared_idct.sv',
 'rtl/mpeg2_new/mpeg2_h262_idct.sv'],stdout=f,stderr=subprocess.STDOUT,check=True)
with (out/'run.log').open('w') as f:
 subprocess.run(['vvp',str(out/'test')],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=120)
lines=[l for l in (out/'run.log').read_text().splitlines() if l.startswith('SHARED_IDCT_PASS')]
if len(lines)!=1:raise RuntimeError('Missing shared transform completion')
(out/'summary.json').write_text(json.dumps({'passed':True,'result':lines[0]},indent=2)+'\n')
print(lines[0])
