#!/usr/bin/env python3
"""Independent synthetic FLAC subframe encoder versus streamed RTL decoding."""
import argparse,json,random,subprocess,struct
from flac_reference import frames
from pathlib import Path
class Bits:
 def __init__(self):self.data=[]
 def put(self,v,n):self.data += [(v>>i)&1 for i in reversed(range(n))]
 def unary(self,n):self.data += [0]*n+[1]
def encode(samples,bps,kind,order=0,wasted=0,method=0,partition_order=0,escape=False,coeff=None,shift=0):
 b=Bits();b.put((kind<<1)|bool(wasted),8)
 if wasted:b.unary(wasted-1)
 values=[s>>wasted for s in samples];width=bps-wasted
 if kind==0:b.put(values[0],width);return b.data
 if kind==1:
  for v in values:b.put(v,width)
  return b.data
 fixed={0:[],1:[1],2:[2,-1],3:[3,-3,1],4:[4,-6,4,-1]}
 c=coeff if kind>=32 else fixed[order]
 for v in values[:order]:b.put(v,width)
 if kind>=32:
  precision=max(2,max(abs(x).bit_length()+1 for x in c));assert precision<=15
  b.put(precision-1,4);b.put(shift,5)
  for x in c:b.put(x,precision)
 b.put(method,2);b.put(partition_order,4);size=len(values)>>partition_order
 for part in range(1<<partition_order):
  start=max(order,part*size);end=(part+1)*size
  residuals=[values[i]-(sum(c[j]*values[i-j-1] for j in range(order))>>shift) for i in range(start,end)]
  if escape:
   width=max((abs(r).bit_length()+1 for r in residuals),default=0) if any(residuals) else 0
   assert width<=31;b.put(31 if method else 15,5 if method else 4);b.put(width,5)
   for r in residuals:b.put(r,width)
  else:
   folded=[2*r if r>=0 else -2*r-1 for r in residuals]
   rice=min(30 if method else 14,max(0,max(folded,default=0).bit_length()-1))
   b.put(rice,5 if method else 4)
   for u in folded:b.unary(u>>rice);b.put(u&((1<<rice)-1),rice)
 return b.data
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
p.add_argument('--frames-per-file',type=int,default=1,help='0 tests all frames')
p.add_argument('--corpus',type=Path);p.add_argument('--verilator',action='store_true')
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
rng=random.Random(9639);cases=[]
def add(label,samples,bps,kind,**kw):cases.append((label,encode(samples,bps,kind,**kw),samples,bps,False))
for bps in (16,17):
 for wasted in (0,1,bps-1):
  unit=1<<wasted;lo=-(1<<(bps-1));hi=(1<<(bps-1))-unit
  add(f'constant-{bps}-{wasted}',[lo]*37,bps,0,wasted=wasted)
  add(f'verbatim-{bps}-{wasted}',[lo,hi,0,-unit]*17,bps,1,wasted=wasted)
 for order in range(5):
  for method in (0,1):
   for escape in (False,True):
    samples=[rng.randrange(-(1<<(bps-2)),1<<(bps-2))*2 for _ in range(128)]
    add(f'fixed-{bps}-{order}-{method}-{escape}',samples,bps,8+order,order=order,wasted=1,method=method,partition_order=2,escape=escape)
 for order in (1,2,8,12,16,32):
  for method in (0,1):
   c=[rng.randrange(-7,8) for _ in range(order)];c[0]=-7
   samples=[rng.randrange(-10000,10000) for _ in range(256)]
   add(f'lpc-{bps}-{order}-{method}',samples,bps,31+order,order=order,coeff=c,shift=3,method=method,partition_order=1,escape=bool(method))
add('maximum-block',[12345]*65535,16,0)
add('one-sample',[-32768],16,1)
add('zero-width-escape',[0]*64,16,8,order=0,escape=True)
# Malformed header, forbidden wasted-bit count, truncation and bad LPC shift.
cases += [('reserved-type',[0,0,0,0,0,1,0,0],[],16,True),('wasted-overflow',[0]*7+[1]+[0]*16,[],16,True)]
valid=encode([1,2,3,4],16,1);cases.append(('truncated',valid[:-5],[],16,True))
b=Bits();b.put(32<<1,8);b.put(0,16);b.put(1,4);b.put(31,5)
cases.append(('negative-shift',b.data,[],16,True))
if a.corpus:
 manifest=json.loads((a.corpus/'manifest.json').read_text())
 for item in manifest['files']:
  data=(a.corpus/item['file']).read_bytes()
  oracle=list(struct.iter_unpack('<hh',(a.corpus/item['reference_pcm']).read_bytes()))
  sample_offset=0
  for frame_index,(sf,stereo,metadata) in enumerate(frames(data)):
   if stereo!=oracle[sample_offset:sample_offset+len(stereo)]:raise RuntimeError('Offline FLAC oracle disagrees with original PCM: '+item['file'])
   sample_offset+=len(stereo)
   for channel,part in enumerate(sf):
    bits=[(data[i//8]>>(7-i%8))&1 for i in range(part['start'],part['end'])]
    cases.append((item['file']+f'-frame{frame_index}-ch{channel}',bits,part['samples'],part['bps'],False))
   if a.frames_per_file and frame_index+1>=a.frames_per_file:break
  if not a.frames_per_file and sample_offset!=len(oracle):raise RuntimeError('Wrong decoded length')
with (out/'vectors.txt').open('w') as f:
 for label,bits,samples,bps,error in cases:
  # Error cases provide a legal declared block length independent of oracle list.
  size=64 if error else len(samples)
  f.write(f'{len(bits)} {size} {bps} {int(error)}\n')
  f.write(' '.join(map(str,bits))+'\n')
  if not error:f.write(' '.join(map(str,samples))+'\n')
sources=['tools/test_flac_subframe.sv','rtl/audio/flac/flac_subframe.sv','rtl/audio/flac/flac_predict_mac.sv']
with (out/'compile.log').open('w') as f:
 if a.verilator:
  subprocess.run(['verilator','--binary','--timing','-Wno-fatal','--top-module','test_flac_subframe','--Mdir',str(out/'obj'),'-j','6']+sources,stdout=f,stderr=subprocess.STDOUT,check=True)
 else:
  subprocess.run(['iverilog','-g2012','-s','test_flac_subframe','-o',str(out/'sim')]+sources,stdout=f,stderr=subprocess.STDOUT,check=True)
command=[str(out/'obj/Vtest_flac_subframe')] if a.verilator else ['vvp',str(out/'sim')]
r=subprocess.run(command+['+vectors='+str(out/'vectors.txt')],capture_output=True,text=True,timeout=300)
(out/'run.log').write_text(r.stdout+r.stderr)
if r.returncode or f'FLAC_SUBFRAME_PASS {len(cases)}' not in r.stdout:raise RuntimeError(r.stdout+r.stderr)
(out/'summary.json').write_text(json.dumps({'passed':True,'cases':[c[0] for c in cases],'samples':sum(len(c[2]) for c in cases)},indent=2)+'\n')
print(r.stdout.strip())
