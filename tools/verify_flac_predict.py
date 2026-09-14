#!/usr/bin/env python3
"""Verify serial prediction against Python unbounded signed integer arithmetic."""
import argparse, json, random, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
rng=random.Random(9639);vectors=[]
for i in range(4096):
 order=i%33;shift=rng.randrange(16);side=i%2
 history=[rng.randrange(-65536,65536) for _ in range(order)]
 coeff=[rng.randrange(-16384,16384) for _ in range(order)]
 prediction=sum(x*y for x,y in zip(history,coeff))>>shift
 target=rng.randrange(-(1<<(15+side)),1<<(15+side))
 residual=target-prediction
 if not -(1<<31)<=residual<(1<<31): residual=rng.randrange(-(1<<31),1<<31)
 if i%7==0: residual=rng.randrange(-(1<<31),1<<31)
 result=prediction+residual;error=not -(1<<(15+side))<=result<(1<<(15+side))
 vectors.append((order,shift,side,residual,result&0x1ffff,int(error),history,coeff))
# Invalid order must produce a held error response without requesting taps.
vectors.append((33,0,0,0,0,1,[],[]))
with (out/'vectors.txt').open('w') as f:
 for order,shift,side,residual,result,error,h,c in vectors:
  f.write(f'{order} {shift} {side} {residual} {result} {error}\n')
  for x,y in zip(h,c): f.write(f'{x} {y}\n')
with (out/'compile.log').open('w') as f:
 subprocess.run(['iverilog','-g2012','-s','test_flac_predict','-o',str(out/'sim'),
  'tools/test_flac_predict.sv','rtl/audio/flac/flac_predict_mac.sv'],stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run(['vvp',str(out/'sim'),'+vectors='+str(out/'vectors.txt')],capture_output=True,text=True,timeout=60)
(out/'run.log').write_text(r.stdout+r.stderr)
if r.returncode or 'FLAC_PREDICT_PASS 4097' not in r.stdout: raise RuntimeError(r.stdout+r.stderr)
(out/'summary.json').write_text(json.dumps({'passed':True,'vectors':len(vectors),'reference':'Python integer arithmetic','seed':9639},indent=2)+'\n')
print(r.stdout.strip())
