#!/usr/bin/env python3
"""Generate Commit-128 progressive 4:2:0 I/P/B hardware regression.

The elementary stream is coded I / future-P / B and displays I / B / P.
The P reference is rewritten into the already-supported generalized 128x96
f_code=(3,3) path.  The B picture uses all six non-quantised non-intra Table
B.4 direction/pattern types, independent forward/backward signed frame vectors,
three Y0 residual blocks, and q_scale_type=0 / alternate_scan=0.
"""
from __future__ import annotations
import hashlib, shutil, subprocess, tempfile
from pathlib import Path

W,H,FPS=128,96,25
MBW,MBH=8,6
SEQ_END=bytes.fromhex('00 00 01 b7')
MCODE={
 -16:'00000011001',-15:'00000011011',-14:'00000011101',-13:'00000011111',-12:'00000100001',-11:'00000100011',-10:'0000010011',-9:'0000010101',-8:'0000010111',-7:'00000111',-6:'00001001',-5:'00001011',-4:'0000111',-3:'00011',-2:'0011',-1:'011',
 0:'1',1:'010',2:'0010',3:'00010',4:'0000110',5:'00001010',6:'00001000',7:'00000110',8:'0000010110',9:'0000010100',10:'0000010010',11:'00000100010',12:'00000100000',13:'00000011110',14:'00000011100',15:'00000011010',16:'00000011000'}
BTYPE={(3,0):'10',(3,1):'11',(2,0):'010',(2,1):'011',(1,0):'0010',(1,1):'0011'}
B_RES={(0,0),(2,3),(4,4)}
SLICE_Q=(9,10,11,12,13,14)

def req(n:str)->str:
 p=shutil.which(n)
 if not p: raise SystemExit(f'required tool not found: {n}')
 return p

def start_codes(data:bytes):
 out=[];p=0
 while True:
  p=data.find(b'\x00\x00\x01',p)
  if p<0:return out
  if p+3<len(data):out.append((p,data[p+3]))
  p+=4

def bits_to_bytes(bits:str)->bytes:
 bits+='0'*((-len(bits))%8)
 return int(bits,2).to_bytes(len(bits)//8,'big')

def delta_for(target:int,pred:int)->int:
 d=target-pred
 while d>63:d-=128
 while d<-64:d+=128
 return d

def enc_comp(target:int,pred:int)->str:
 d=delta_for(target,pred)
 if d==0:return '1'
 a=abs(d);mc=(a-1)//4+1;res=(a-1)%4
 if d<0:mc=-mc
 return MCODE[mc]+format(res,'02b')

def fvec(r,c):
 x=(1,2,-1,3,-2,1,2,-1)[c]
 y=(1,2,1,0,-1,-2)[r]
 return x,y

def bvec(r,c):
 x=(2,1,3,-1,1,-2,-1,-2)[c]
 y=(2,1,0,-1,-2,-1)[r]
 return x,y

def b_kind(r,c):
 if (r,c)==(0,0):return 3,1
 if (r,c)==(2,3):return 2,1
 if (r,c)==(4,4):return 1,1
 return (1+((r*MBW+c)%3)),0

def p_row(r):
 bits=format(SLICE_Q[r],'05b')+'0'
 for c in range(MBW):
  bits+='1'
  if (r,c)==(0,0):
   bits+='1'+'1'+'1'
   bits+='1010'
   bits+='1010'
  else:
   bits+='001'+'1'+'1'
 return bits_to_bytes(bits)

def b_row(r):
 bits=format(SLICE_Q[r],'05b')+'0'
 fp=[0,0];bp=[0,0]
 for c in range(MBW):
  direction,coded=b_kind(r,c)
  bits+='1'+BTYPE[(direction,coded)]
  if direction in (1,3):
   tx,ty=fvec(r,c);bits+=enc_comp(tx,fp[0])+enc_comp(ty,fp[1]);fp=[tx,ty]
  if direction in (2,3):
   tx,ty=bvec(r,c);bits+=enc_comp(tx,bp[0])+enc_comp(ty,bp[1]);bp=[tx,ty]
  if coded:
   bits+='1010'
   bits+=('1110' if (r,c)==(2,3) else '1010')
 return bits_to_bytes(bits)

P_ROWS=tuple(p_row(r) for r in range(MBH))
B_ROWS=tuple(b_row(r) for r in range(MBH))

def source_frames()->bytes:
 out=bytearray();cw,ch=W//2,H//2
 for k in range(3):
  y=bytearray(W*H);cb=bytearray(cw*ch);cr=bytearray(cw*ch)
  for yy in range(H):
   for xx in range(W):y[yy*W+xx]=32+((xx*3+yy*5+k*2)%176)
  for yy in range(ch):
   for xx in range(cw):
    cb[yy*cw+xx]=64+((xx*5+yy*3+k)%128)
    cr[yy*cw+xx]=72+((xx*2+yy*7+k)%112)
  out+=y+cb+cr
 return bytes(out)

def make_skeleton(ffmpeg: str, raw:Path, out:Path):
 raw.write_bytes(source_frames())
 subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','yuv420p','-s',f'{W}x{H}','-r',str(FPS),'-i',str(raw),'-frames:v','3','-an','-c:v','mpeg2video','-pix_fmt','yuv420p','-bf','1','-g','12','-sc_threshold','1000000000','-q:v','2','-f','mpeg2video',str(out)],check=True)
 d=out.read_bytes()
 if not d.endswith(SEQ_END):out.write_bytes(d+SEQ_END)

def patch(data:bytes)->bytes:
 b=bytearray(data);codes=start_codes(b);pics=[]
 for o,c in codes:
  if c==0:pics.append((o,(b[o+5]>>3)&7))
 if [t for _,t in pics]!=[1,2,3]:raise SystemExit(f'expected coded I/P/B, found {pics}')
 for pi,(po,ptype) in enumerate(pics):
  if ptype not in (2,3):continue
  pe=pics[pi+1][0] if pi+1<len(pics) else len(b)
  codes=start_codes(b)
  pce=None
  rows=[]
  for i,(o,c) in enumerate(codes):
   if not(po<o<pe):continue
   if c==0xb5 and o+8<len(b) and (b[o+4]>>4)==8:pce=o
   if 1<=c<=MBH:rows.append((i,o,c))
  if pce is None:raise SystemExit(f'picture type {ptype}: missing picture coding extension')
  b[pce+4]=(b[pce+4]&0xf0)|3
  if ptype==2:
   b[pce+5]=0x30|(b[pce+5]&0x0f)
  else:
   b[pce+5]=0x33
   b[pce+6]=(b[pce+6]&0x0f)|0x30
  b[pce+7]=(b[pce+7]|0x40)&~(0x20|0x10|0x04)
  codes=start_codes(b)
  rows=[(i,o,c) for i,(o,c) in enumerate(codes) if po<o<pe and 1<=c<=MBH]
  if tuple(c for _,_,c in rows)!=tuple(range(1,MBH+1)):raise SystemExit(f'picture type {ptype}: unexpected slices')
  payloads=P_ROWS if ptype==2 else B_ROWS
  repl=[]
  for row,(i,o,c) in enumerate(rows):repl.append((o+4,codes[i+1][0],payloads[row]))
  for s,e,payload in reversed(repl):b[s:e]=payload
  if ptype==2:return patch_b_only(bytes(b))
 return bytes(b)

def patch_b_only(data:bytes)->bytes:
 b=bytearray(data);codes=start_codes(b);pics=[]
 for o,c in codes:
  if c==0:pics.append((o,(b[o+5]>>3)&7))
 bp=next(o for o,t in pics if t==3);bi=[x[0] for x in pics].index(bp);be=pics[bi+1][0] if bi+1<len(pics) else len(b)
 pce=None
 for o,c in codes:
  if bp<o<be and c==0xb5 and o+8<len(b) and (b[o+4]>>4)==8:pce=o;break
 if pce is None:raise SystemExit('B picture coding extension missing')
 b[pce+4]=(b[pce+4]&0xf0)|3;b[pce+5]=0x33;b[pce+6]=(b[pce+6]&0x0f)|0x30
 b[pce+7]=(b[pce+7]|0x40)&~(0x20|0x10|0x04)
 codes=start_codes(b);rows=[(i,o,c) for i,(o,c) in enumerate(codes) if bp<o<be and 1<=c<=MBH]
 if tuple(c for _,_,c in rows)!=tuple(range(1,MBH+1)):raise SystemExit('unexpected B slices')
 repl=[(o+4,codes[i+1][0],B_ROWS[row]) for row,(i,o,c) in enumerate(rows)]
 for s,e,payload in reversed(repl):b[s:e]=payload
 return bytes(b)

def verify(ffprobe:str,path:Path):
 d=path.read_bytes();codes=start_codes(d);pics=[]
 for o,c in codes:
  if c==0:pics.append((o,(d[o+5]>>3)&7))
 if [t for _,t in pics]!=[1,2,3]:raise SystemExit(f'coded order mismatch: {pics}')
 r=subprocess.run([ffprobe,'-v','error','-select_streams','v:0','-show_entries','frame=pict_type','-of','csv=p=0',str(path)],check=True,text=True,capture_output=True)
 display=[x.strip().strip(',') for x in r.stdout.replace('\r','').splitlines() if x.strip()]
 if display!=['I','B','P']:raise SystemExit(f'display order mismatch: {display}')
 subprocess.run([ffprobe,'-v','error','-show_entries','stream=width,height,pix_fmt','-of','default=nw=1',str(path)],check=True)

if __name__=='__main__':
 ffmpeg=req('ffmpeg');ffprobe=req('ffprobe')
 dst=Path(__file__).resolve().parent/'test_b_core_decode.m2v'
 with tempfile.TemporaryDirectory() as td:
  td=Path(td);raw=td/'in.yuv';sk=td/'skeleton.m2v';make_skeleton(ffmpeg,raw,sk);dst.write_bytes(patch(sk.read_bytes()))
 verify(ffprobe,dst)
 h=hashlib.sha256(dst.read_bytes()).hexdigest()
 print(f'{dst.name}: {dst.stat().st_size} bytes')
 print(f'SHA256 {h}')
