#!/usr/bin/env python3
"""Compare complete RTL FLAC decoding with corpus original PCM, with CRC admission."""
import argparse,json,subprocess,hashlib,struct
from flac_reference import crc,frames
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',required=True,type=Path);p.add_argument('--corpus',required=True,type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);corpus=a.corpus.resolve()
root=Path(__file__).resolve().parents[1]
sources=[root/'rtl/audio/flac'/f'{n}.sv' for n in ['flac_predict_mac','flac_subframe','flac_stream_decoder','flac_stereo']]
with (out/'compile.log').open('w') as log:
 subprocess.run(['verilator','--binary','--timing','-j','6','--top-module','test_flac_stream','--Mdir',str(out/'obj'),str(root/'tools/test_flac_stream.sv'),*map(str,sources)],stdout=log,stderr=subprocess.STDOUT,check=True)
exe=out/'obj/Vtest_flac_stream';results=[]
def run(name,path,pcm,error=0,reset_at=0,store_error=0):
 r=subprocess.run([str(exe),f'+input={path}',f'+pcm={pcm}',f'+error={error}',f'+reset_at={reset_at}',f'+store_error={store_error}'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 (out/f'{name}.log').write_text(r.stdout)
 if r.returncode or 'PASS ' not in r.stdout:raise RuntimeError(f'{name}: {r.stdout}')
 print(name+': '+r.stdout.splitlines()[0],flush=True);results.append({'name':name,'result':r.stdout.splitlines()[0]})
manifest=json.loads((corpus/'manifest.json').read_text())
for item in manifest['files']:
 path=corpus/item['file'];pcm=corpus/item['reference_pcm']
 assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
 assert hashlib.sha256(pcm.read_bytes()).hexdigest()==item['pcm_sha256']
 run(path.stem,path,pcm,reset_at=min(9000,len(path.read_bytes())//2))
# Mutate known valid native stream. Metadata skipping and frame boundary are independent of the RTL.
base=(corpus/'tones-level5.flac').read_bytes();offset=4
while True:
 h=base[offset:offset+4];offset+=4+int.from_bytes(h[1:],'big')
 if h[0]&128:break
pcm=corpus/'tones.pcm'
first_sf,_,_=next(frames(base));header_end=first_sf[0]['start']//8
cases={
 'bad-magic':(bytes([base[0]^1])+base[1:],1),
 'bad-profile':(base[:18]+bytes([base[18]^16])+base[19:],2),
 'bad-frame-number':(base[:offset+4]+bytes([base[offset+4]^1])+base[offset+5:],7),
 'bad-header-crc':(base[:header_end-1]+bytes([base[header_end-1]^1])+base[header_end:],4),
 'bad-final-crc':(base[:-1]+bytes([base[-1]^1]),4),
 'truncated-crc':(base[:-1],6),
 'truncated-metadata':(base[:30],6),
}
for name,(data,error) in cases.items():
 path=out/f'{name}.flac';path.write_bytes(data);run(name,path,pcm,error)
# Independently construct verbatim frames exercising all stereo assignments,
# explicit rates, fixed/variable numbering, unknown totals and skipped metadata.
def number(v):
 if v<128:return bytes([v])
 n=next(n for n in range(2,8) if v<(1<<(5*n+1)))
 return bytes([(256-(1<<(8-n)))|(v>>(6*(n-1)))]+[128|((v>>(6*j))&63) for j in reversed(range(n-1))])
def make_frame(pairs,assignment,variable,index,rate):
 n=len(pairs);header=bytes([255,249 if variable else 248,0x60|rate,(assignment<<4)|8])+number(index)+bytes([n-1])
 if rate==13:header+=(44100).to_bytes(2,'big')
 if rate==14:header+=(4410).to_bytes(2,'big')
 header+=bytes([crc(header,8,7)]);bits=[]
 coded=[([l for l,r in pairs],[r for l,r in pairs]),([l for l,r in pairs],[l-r for l,r in pairs]),([l-r for l,r in pairs],[r for l,r in pairs]),([(l+r)>>1 for l,r in pairs],[l-r for l,r in pairs])][[1,8,9,10].index(assignment)]
 widths=[16,17] if assignment in (8,10) else [17,16] if assignment==9 else [16,16]
 for values,width in zip(coded,widths):
  bits.extend([0,0,0,0,0,0,1,0])
  for v in values:bits.extend((v>>j)&1 for j in reversed(range(width)))
 bits.extend([0]*(-len(bits)%8));body=bytes(sum(bits[i+j]<<(7-j) for j in range(8)) for i in range(0,len(bits),8))
 frame=header+body
 return frame+crc(frame,16,0x8005).to_bytes(2,'big')
def native(payload,total,minimum=17,maximum=17):
 info=minimum.to_bytes(2,'big')+maximum.to_bytes(2,'big')+bytes(6)+((44100<<44)|(1<<41)|(15<<36)|total).to_bytes(8,'big')+bytes(16)
 return b'fLaC'+bytes([0,0,0,34])+info+bytes([129,0,0,3])+b'xyz'+payload
pairs=[(-32768,32767),(32767,-32768),(-1,0),(0,-1),(1,0),(0,1),(32767,32767),(-32768,-32768),(0,0)]*2
pairs=pairs[:17]
for assignment in (1,8,9,10):
 for variable in (False,True):
  # 300 frames exercise one/two-byte frame numbers and one/two/three-byte sample numbers.
  payload=b''.join(make_frame(pairs,assignment,variable,i*17 if variable else i,[0,9,13,14][i%4]) for i in range(300))
  data=native(payload,0 if variable else 5100);name=f'stereo-{assignment}-variable-{int(variable)}'
  path=out/f'{name}.flac';path.write_bytes(data);pcm=out/f'{name}.pcm';pcm.write_bytes(b''.join(struct.pack('<hh',*pair) for pair in pairs)*300)
  run(name,path,pcm,reset_at=200)
# Damage an otherwise sample-identical frame: no sample from that frame may commit.
good=make_frame(pairs,8,False,0,9)
for name,payload,error in [('first-frame-crc',good[:-1]+bytes([good[-1]^1]),4),('subframe-truncation',good[:20],5)]:
 path=out/f'{name}.flac';path.write_bytes(native(payload,17));pcm=out/f'{name}.pcm';pcm.write_bytes(b''.join(struct.pack('<hh',*pair) for pair in pairs))
 run(name,path,pcm,error)
 if 'committed=0' not in results[-1]['result']:raise RuntimeError('invalid frame committed')
path=out/'store-error.flac';path.write_bytes(native(good,17))
run('store-error',path,pcm,8,store_error=1)
assert 'committed=0' in results[-1]['result']
(out/'summary.json').write_text(json.dumps({'scope':'complete native stream RTL with modeled provisional store; no DDR/HDMI integration','files':len(manifest['files']),'cases':results},indent=2)+'\n')
