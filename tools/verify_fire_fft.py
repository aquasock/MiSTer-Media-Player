#!/usr/bin/env python3
"""Independent fixed-point FFT oracle, stereo/tones, reset and analysis bounds."""
import argparse,math,json,subprocess
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
subprocess.run(['python3','tools/make_fire_tables.py','--check'],cwd=root,check=True)
with (out/'compile.log').open('w') as f:subprocess.run(['verilator','--binary','--timing','-Wno-TIMESCALEMOD','-j','4','--top-module','test_media_audio_fft','--Mdir',str(out/'obj'),'tools/test_media_audio_fft.sv','rtl/media_audio_fft.sv'],cwd=root,stdout=f,stderr=subprocess.STDOUT,check=True)
x=np.arange(256);zero=np.zeros(256,dtype=int);tone=lambda k:np.rint(26000*np.sin(2*np.pi*k*x/256)).astype(int)
cases={'silence':(zero,zero),'dc':(zero+16000,zero+16000),'left-low':(tone(2),zero),'right-mid':(zero,tone(20)),'stereo-high':(tone(80),tone(100)),'opposite-phase':(tone(20),-tone(20)),'same-phase':(tone(20),tone(20)),'near-nyquist':(tone(127),zero),'noise':(np.random.default_rng(123).integers(-32768,32768,256),np.random.default_rng(456).integers(-32768,32768,256))}
cases['cancel-analysis']=cases['noise']
window=[round(32767*(.5-.5*math.cos(2*math.pi*i/255))) for i in range(256)]
tw=[(round(32767*math.cos(-2*math.pi*i/256)),round(32767*math.sin(-2*math.pi*i/256))) for i in range(128)]
edges=list(range(1,14))+[round(13*(128/13)**(i/20)) for i in range(1,21)]
def expected(left,right):
 data=[(int(left[i])*window[i]>>15,int(right[i])*window[i]>>15) for i in range(256)]
 data=[data[int(f'{i:08b}'[::-1],2)] for i in range(256)]
 for stage in range(8):
  half=1<<stage
  for base in range(0,256,half*2):
   for j in range(half):
    ar,ai=data[base+j];br,bi=data[base+j+half];c,s=tw[j*(128//half)]
    tr=(br*c-bi*s)>>15;ti=(br*s+bi*c)>>15
    data[base+j]=((ar+tr)>>1,(ai+ti)>>1);data[base+j+half]=((ar-tr)>>1,(ai-ti)>>1)
 def level(k):
  mag=sum(abs(v) for idx in (k,256-k) for v in data[idx]);e=mag.bit_length()-1
  return 0 if mag<8 else min(255,e*16+((mag<<4)>>e & 15)-48)
 levels=[max(level(k) for k in range(lo,hi)) for lo,hi in zip(edges,edges[1:])]
 return data,levels
results={}
for name,(left,right) in cases.items():
 source=out/(name+'.hex');dest=out/(name+'.txt');source.write_text(''.join(f'{((int(l)&65535)<<16)|(int(r)&65535):08x}\n' for l,r in zip(left,right)))
 r=subprocess.run([str(out/'obj/Vtest_media_audio_fft'),f'+INPUT={source}',f'+OUT={dest}',f'+CANCEL={int(name=="cancel-analysis")}'],cwd=root,capture_output=True,text=True,timeout=30);(out/(name+'.log')).write_text(r.stdout+r.stderr);r.check_returncode()
 rows=dest.read_text().splitlines();signed=lambda v:v-(1<<18) if v&(1<<17) else v
 actual=[tuple(signed(int(v,16)) for v in row.split()) for row in rows[:256]];bits=int(rows[256],16);levels=[bits>>(i*8)&255 for i in range(32)]
 ref,reflevels=expected(left,right);assert actual==ref,(name,'FFT mismatch',next((i,a,b) for i,(a,b) in enumerate(zip(actual,ref)) if a!=b));assert levels==reflevels,(name,levels,reflevels)
 if name=='silence':assert max(levels)==0
 if name=='right-mid':assert np.argmax(levels)==next(i for i in range(32) if edges[i]<=20<edges[i+1])
 results[name]=levels;print('PASS '+name+' peak band='+str(np.argmax(levels)),flush=True)
assert np.argmax(results['opposite-phase'])==np.argmax(results['same-phase'])
assert abs(max(results['opposite-phase'])-max(results['same-phase']))<=1,'opposite-phase cancellation'
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
