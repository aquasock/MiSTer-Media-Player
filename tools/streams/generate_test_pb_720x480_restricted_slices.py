#!/usr/bin/env python3
"""Generate deterministic 720x480 restricted-slice P/B regression.

Coded order is I / P / B / P / B; display order is I / B / P / B / P.
Selected P and B macroblock rows are split into three same-vertical-position
slices covering columns 0..11, 12..33 and 34..44. The later slices therefore
start with MBA 13 and MBA 35 (macroblock_escape + 2) respectively. B slices
also contain legal internal skipped macroblocks while every slice begins and
ends on a coded macroblock. Generated .m2v stays local-only.
"""
from __future__ import annotations
import hashlib, shutil, subprocess, tempfile
from pathlib import Path

W,H,FPS=720,480,25
MBW,MBH=45,30
SEQ_END=bytes.fromhex('00 00 01 b7')
MCODE={
 -16:'00000011001',-15:'00000011011',-14:'00000011101',-13:'00000011111',-12:'00000100001',-11:'00000100011',-10:'0000010011',-9:'0000010101',-8:'0000010111',-7:'00000111',-6:'00001001',-5:'00001011',-4:'0000111',-3:'00011',-2:'0011',-1:'011',
 0:'1',1:'010',2:'0010',3:'00010',4:'0000110',5:'00001010',6:'00001000',7:'00000110',8:'0000010110',9:'0000010100',10:'0000010010',11:'00000100010',12:'00000100000',13:'00000011110',14:'00000011100',15:'00000011010',16:'00000011000'}
BTYPE={(3,0):'10',(3,1):'11',(2,0):'010',(2,1):'011',(1,0):'0010',(1,1):'0011'}
MBA={
 1:'1',2:'011',3:'010',4:'0011',5:'0010',6:'00011',7:'00010',8:'0000111',9:'0000110',10:'00001011',11:'00001010',12:'00001001',13:'00001000',14:'00000111',15:'00000110',16:'0000010111',17:'0000010110',18:'0000010101',19:'0000010100',20:'0000010011',21:'0000010010',22:'00000100011',23:'00000100010',24:'00000100001',25:'00000100000',26:'00000011111',27:'00000011110',28:'00000011101',29:'00000011100',30:'00000011011',31:'00000011010',32:'00000011001',33:'00000011000'}
MBA_ESCAPE='00000001000'
CBP={63:'001100',3:'001101',48:'10010'}
SLICE_Q=tuple(8+(r%12) for r in range(MBH))
FULL_B_COLS=(0,34,44)
SPLIT_ROWS=(4,8,18,22)
SPLIT_PARTS=((0,11,(0,5,11)),(12,33,(12,20,33)),(34,44,(34,39,44)))
B_RES=(
 {(4,34):63,(18,34):3,(23,44):48},
 {(8,34):63,(22,34):3,(12,44):48},
)

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

def pictures(data:bytes):
 return [(o,(data[o+5]>>3)&7) for o,c in start_codes(data) if c==0]

def bits_to_bytes(bits:str)->bytes:
 bits+='0'*((-len(bits))%8)
 return int(bits,2).to_bytes(len(bits)//8,'big')

def enc_mba(n:int)->str:
 if n<1: raise ValueError(n)
 bits=''
 while n>33:
  bits+=MBA_ESCAPE;n-=33
 return bits+MBA[n]

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

def safe_vec(v:int,r:int,c:int,backward:bool=False):
 if r==0 or r==MBH-1 or c==0 or c==MBW-1:return 0,0
 phase=(r*3+c*5+v*7+(2 if backward else 0))%7
 return ((0,0),(1,0),(0,1),(-1,0),(0,-1),(1,1),(-1,1))[phase]

def b_kind(v:int,r:int,c:int):
 coded=(r,c) in B_RES[v]
 return 1+((r+c+v)%3),1 if coded else 0

def escape(run:int,level:int)->str:
 if not (0<=run<=63):raise ValueError(run)
 if level==0 or not (-2047<=level<=2047):raise ValueError(level)
 return '000001'+format(run,'06b')+format(level & 0xfff,'012b')

def block_coeff_bits(v:int,r:int,c:int,b:int)->str:
 mode=(v+r+c+b)%3
 if mode==0:return '10'+'111'+'10'
 if mode==1:return '11'+escape(2,5)+'10'
 return '10'+'0110'+'10'

def residual_bits(v:int,r:int,c:int,cbp:int)->str:
 bits=CBP[cbp]
 for b in range(6):
  if cbp & (1<<(5-b)):bits+=block_coeff_bits(v,r,c,b)
 return bits

def p_slice(r:int,start:int,end:int)->bytes:
 bits=format(SLICE_Q[r],'05b')+'0'
 for c in range(start,end+1):
  bits+=enc_mba(c+1 if c==start else 1)+'001'+'1'+'1'
 return bits_to_bytes(bits)

def b_slice(v:int,r:int,cols:tuple[int,...])->bytes:
 bits=format(SLICE_Q[r],'05b')+'0';fp=[0,0];bp=[0,0];prev=-1
 for c in cols:
  bits+=enc_mba(c+1 if prev<0 else c-prev)
  direction,coded=b_kind(v,r,c);bits+=BTYPE[(direction,coded)]
  if direction in (1,3):
   tx,ty=safe_vec(v,r,c,False);bits+=enc_comp(tx,fp[0])+enc_comp(ty,fp[1]);fp=[tx,ty]
  if direction in (2,3):
   tx,ty=safe_vec(v,r,c,True);bits+=enc_comp(tx,bp[0])+enc_comp(ty,bp[1]);bp=[tx,ty]
  if coded:bits+=residual_bits(v,r,c,B_RES[v][(r,c)])
  prev=c
 return bits_to_bytes(bits)

def p_groups():
 out=[]
 for r in range(MBH):
  if r in SPLIT_ROWS:out.append(tuple(p_slice(r,a,b) for a,b,_ in SPLIT_PARTS))
  else:out.append((p_slice(r,0,MBW-1),))
 return tuple(out)

def b_groups(v:int):
 out=[]
 for r in range(MBH):
  if r in SPLIT_ROWS:out.append(tuple(b_slice(v,r,cols) for _,_,cols in SPLIT_PARTS))
  else:out.append((b_slice(v,r,FULL_B_COLS),))
 return tuple(out)

def source_frames()->bytes:
 out=bytearray();cw,ch=W//2,H//2
 for k in range(5):
  y=bytearray(W*H);cb=bytearray(cw*ch);cr=bytearray(cw*ch)
  for yy in range(H):
   for xx in range(W):y[yy*W+xx]=24+((xx*3+yy*5+k*7)%200)
  for yy in range(ch):
   for xx in range(cw):
    cb[yy*cw+xx]=64+((xx*5+yy*3+k*3)%128);cr[yy*cw+xx]=72+((xx*2+yy*7+k*5)%112)
  out+=y+cb+cr
 return bytes(out)

def make_skeleton(ffmpeg:str,raw:Path,out:Path):
 raw.write_bytes(source_frames())
 subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','yuv420p','-s',f'{W}x{H}','-r',str(FPS),'-i',str(raw),'-frames:v','5','-an','-c:v','mpeg2video','-pix_fmt','yuv420p','-bf','1','-g','12','-sc_threshold','1000000000','-q:v','2','-f','mpeg2video',str(out)],check=True)
 d=out.read_bytes()
 if not d.endswith(SEQ_END):out.write_bytes(d+SEQ_END)

def packed_row(code:int,payloads:tuple[bytes,...])->bytes:
 b=bytearray(payloads[0])
 for p in payloads[1:]:b+=b'\x00\x00\x01'+bytes([code])+p
 return bytes(b)

def patch_picture(data:bytes,pic_index:int,groups:tuple[tuple[bytes,...],...])->bytes:
 b=bytearray(data);pics=pictures(b);po,ptype=pics[pic_index];pe=pics[pic_index+1][0] if pic_index+1<len(pics) else len(b)
 pce=None
 for o,c in start_codes(b):
  if po<o<pe and c==0xb5 and o+8<len(b) and (b[o+4]>>4)==8:pce=o;break
 if pce is None:raise SystemExit(f'picture {pic_index} type {ptype}: missing picture coding extension')
 b[pce+4]=(b[pce+4]&0xf0)|3
 if ptype==2:b[pce+5]=0x30|(b[pce+5]&0x0f)
 else:b[pce+5]=0x33;b[pce+6]=(b[pce+6]&0x0f)|0x30
 b[pce+7]=(b[pce+7]|0x40)&~(0x20|0x10|0x04)
 codes=start_codes(b);pics=pictures(b);po,_=pics[pic_index];pe=pics[pic_index+1][0] if pic_index+1<len(pics) else len(b)
 rows=[(i,o,c) for i,(o,c) in enumerate(codes) if po<o<pe and 1<=c<=MBH]
 if tuple(c for _,_,c in rows)!=tuple(range(1,MBH+1)):raise SystemExit(f'picture {pic_index} type {ptype}: unexpected skeleton slice layout')
 repl=[(o+4,codes[i+1][0],packed_row(c,groups[row])) for row,(i,o,c) in enumerate(rows)]
 for s,e,payload in reversed(repl):b[s:e]=payload
 return bytes(b)

def patch(data:bytes)->bytes:
 if [t for _,t in pictures(data)]!=[1,2,3,2,3]:raise SystemExit(f'expected coded I/P/B/P/B, found {pictures(data)}')
 pg=p_groups();b0=b_groups(0);b1=b_groups(1)
 b=data;b=patch_picture(b,4,b1);b=patch_picture(b,3,pg);b=patch_picture(b,2,b0);b=patch_picture(b,1,pg)
 return b

def expected_slice_codes():
 out=[]
 for r in range(MBH):out.extend([r+1]*(3 if r in SPLIT_ROWS else 1))
 return out

def verify(ffmpeg:str,ffprobe:str,path:Path):
 d=path.read_bytes();coded=[t for _,t in pictures(d)]
 if coded!=[1,2,3,2,3]:raise SystemExit(f'coded order mismatch: {coded}')
 codes=start_codes(d);pics=pictures(d);exp=expected_slice_codes()
 for pi in range(1,5):
  po=pics[pi][0];pe=pics[pi+1][0] if pi+1<len(pics) else len(d)
  got=[c for o,c in codes if po<o<pe and 1<=c<=MBH]
  if got!=exp:raise SystemExit(f'picture {pi}: restricted-slice layout mismatch')
 r=subprocess.run([ffprobe,'-v','error','-select_streams','v:0','-show_entries','frame=pict_type','-of','csv=p=0',str(path)],check=True,text=True,capture_output=True)
 display=[x.strip().strip(',') for x in r.stdout.replace('\r','').splitlines() if x.strip()]
 if display!=['I','B','P','B','P']:raise SystemExit(f'display order mismatch: {display}')
 s=subprocess.run([ffprobe,'-v','error','-show_entries','stream=width,height,pix_fmt','-of','default=nw=1',str(path)],check=True,text=True,capture_output=True)
 if 'width=720' not in s.stdout or 'height=480' not in s.stdout or 'pix_fmt=yuv420p' not in s.stdout:raise SystemExit(f'unexpected stream geometry: {s.stdout}')
 subprocess.run([ffmpeg,'-v','error','-i',str(path),'-f','null','-'],check=True)

if __name__=='__main__':
 ffmpeg=req('ffmpeg');ffprobe=req('ffprobe')
 dst=Path(__file__).resolve().parent/'test_pb_720x480_restricted_slices.m2v'
 with tempfile.TemporaryDirectory(prefix='mister_h262_pbslice_') as td:
  td=Path(td);raw=td/'in.yuv';sk=td/'skeleton.m2v';make_skeleton(ffmpeg,raw,sk);dst.write_bytes(patch(sk.read_bytes()))
 verify(ffmpeg,ffprobe,dst)
 h=hashlib.sha256(dst.read_bytes()).hexdigest()
 print(f'{dst.name}: {dst.stat().st_size} bytes')
 print(f'SHA256 {h}')
 print('geometry: 45x30 macroblocks (720x480)')
 print('coded order: I P B P B; display order: I B P B P')
 print(f'split rows (0-based): {SPLIT_ROWS}; three same-row slices each')
 print('slice coverage: 0..11, 12..33, 34..44; first MBA values 1, 13, 35 (escape + 2)')
 print('B split slices contain internal skipped macroblocks; every slice endpoint is coded')
