#!/usr/bin/env python3
"""Generate a syntax-derived 128x96 H.262 P motion-plan regression.

The P frame uses an irregular plan containing multiple +32 forward-motion
macroblocks in several rows. Every +32 macroblock is followed by a skipped
macroblock so the P-frame PMV reset rule returns the following coded macroblocks
to zero motion. The hardware observer must derive the 48-bit plan from decoded
MBA/macroblock/motion syntax; no accepted fixed map matches this stream.
"""
from __future__ import annotations
import hashlib, shutil, subprocess, tempfile
from pathlib import Path

FPS=25; MB_WIDTH=8; MB_HEIGHT=6; WIDTH=128; HEIGHT=96
SEQ_END=bytes.fromhex('00 00 01 b7')
MBA_VLC={1:'1',2:'011',3:'010',4:'0011',5:'0010',6:'00011',7:'00010',8:'0000111',9:'0000110',10:'00001011',11:'00001010',12:'00001001',13:'00001000',14:'00000111',15:'00000110',16:'0000010111',17:'0000010110',18:'0000010101',19:'0000010100',20:'0000010011',21:'0000010010',22:'00000100011',23:'00000100010',24:'00000100001',25:'00000100000',26:'00000011111',27:'00000011110',28:'00000011101',29:'00000011100',30:'00000011011',31:'00000011010',32:'00000011001',33:'00000011000'}
MCODE_POS8='0000010110'; MCODE_ZERO='1'
ROW_SHIFTS=((0,4),(1,5),(2,5),(3,),(4,),(5,))

def req(n):
 p=shutil.which(n)
 if not p: raise SystemExit(f'required tool not found in PATH: {n}')
 return p

def codes(data):
 out=[];p=0
 while True:
  p=data.find(b'\x00\x00\x01',p)
  if p<0:return out
  if p+3<len(data):out.append((p,data[p+3]))
  p+=4

def ptypes(ffprobe,path):
 r=subprocess.run([ffprobe,'-v','error','-select_streams','v:0','-show_entries','frame=pict_type','-of','csv=p=0',str(path)],check=True,text=True,capture_output=True)
 return [x.strip().strip(',') for x in r.stdout.replace('\r','').splitlines() if x.strip()]

def b2b(bits):
 bits+='0'*((-len(bits))%8)
 return int(bits,2).to_bytes(len(bits)//8,'big')

def row_payload(shifts):
 shifts=set(shifts); skipped={c+1 for c in shifts}
 if any(c>=MB_WIDTH-1 for c in shifts) or shifts & skipped: raise ValueError('invalid shift plan')
 bits='000100'; prev=-1
 for col in range(MB_WIDTH):
  if col in skipped: continue
  inc=col-prev
  if col in shifts: bits+=MBA_VLC[inc]+'001'+MCODE_POS8+'11'+MCODE_ZERO
  else: bits+=MBA_VLC[inc]+'001'+MCODE_ZERO+MCODE_ZERO
  prev=col
 return b2b(bits)
ROW_PAYLOADS=tuple(row_payload(s) for s in ROW_SHIFTS)

def plan_map():
 m=0
 for r,shifts in enumerate(ROW_SHIFTS):
  for c in shifts:m|=1<<(r*MB_WIDTH+c)
 return m
PLAN_MAP=plan_map()

def source_frame():
 y=bytearray(WIDTH*HEIGHT)
 for yy in range(HEIGHT):
  for xx in range(WIDTH):y[yy*WIDTH+xx]=32+(((yy//16)*29+(xx//16)*17)%176)
 cw,ch=WIDTH//2,HEIGHT//2;cb=bytearray(cw*ch);cr=bytearray(cw*ch)
 for yy in range(ch):
  for xx in range(cw):
   cb[yy*cw+xx]=48+(((yy//8)*19+(xx//8)*23)%144)
   cr[yy*cw+xx]=64+(((yy//8)*31+(xx//8)*13)%128)
 return bytes(y)+bytes(cb)+bytes(cr)

def skeleton(ffmpeg,raw,out):
 raw.write_bytes(source_frame()*3)
 subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','yuv420p','-s',f'{WIDTH}x{HEIGHT}','-r',str(FPS),'-i',str(raw),'-frames:v','3','-an','-c:v','mpeg2video','-pix_fmt','yuv420p','-bf','0','-q:v','2','-g','12','-force_key_frames','0.08','-f','mpeg2video',str(out)],check=True)
 d=out.read_bytes()
 if not d.endswith(SEQ_END):out.write_bytes(d+SEQ_END)

def patch(data):
 cs=codes(data);pics=[o for o,c in cs if c==0]
 if len(pics)!=3:raise SystemExit('expected I/P/I skeleton')
 pp,np=pics[1],pics[2];x=bytearray(data);pce=None
 for o,c in cs:
  if pp<o<np and c==0xb5 and o+5<len(x) and (x[o+4]>>4)==8:pce=o;break
 if pce is None:raise SystemExit('P PCE missing')
 x[pce+4]=(x[pce+4]&0xf0)|3;x[pce+5]=0x30|(x[pce+5]&0x0f)
 cs=codes(x);rows=[(i,o,c) for i,(o,c) in enumerate(cs) if pp<o<np and 1<=c<=MB_HEIGHT]
 if tuple(c for _,_,c in rows)!=tuple(range(1,7)):raise SystemExit('unexpected slice layout')
 repl=[(o+4,cs[i+1][0]) for i,o,_ in rows]
 for r,(a,b) in reversed(list(enumerate(repl))):x[a:b]=ROW_PAYLOADS[r]
 return bytes(x)

def expected(frame):
 cw=WIDTH//2;ys=WIDTH*HEIGHT;cs=cw*(HEIGHT//2);out=bytearray(frame)
 for r,shifts in enumerate(ROW_SHIFTS):
  for c in shifts:
   for yy in range(r*16,(r+1)*16):
    a=yy*WIDTH+c*16;out[a:a+16]=frame[a+16:a+32]
   for plane in (ys,ys+cs):
    for yy in range(r*8,(r+1)*8):
     a=plane+yy*cw+c*8;out[a:a+8]=frame[a+8:a+16]
 return bytes(out)

def verify(ffmpeg,ffprobe,out):
 if ptypes(ffprobe,out)!=['I','P','I']:raise SystemExit('picture order mismatch')
 d=out.read_bytes();cs0=codes(d);pics=[o for o,c in cs0 if c==0];pp,np=pics[1],pics[2];s=[];pce=None
 for i,(o,c) in enumerate(cs0):
  if not(pp<o<np):continue
  e=cs0[i+1][0]
  if c==0xb5 and (d[o+4]>>4)==8:pce=d[o+4:e]
  elif 1<=c<=6:s.append((c,d[o+4:e]))
 if pce is None or (pce[0]&15)!=3 or (pce[1]>>4)!=3:raise SystemExit('f_code mismatch')
 if s!=[(r+1,ROW_PAYLOADS[r]) for r in range(6)]:raise SystemExit('slice payload mismatch')
 raw=subprocess.run([ffmpeg,'-v','error','-i',str(out),'-f','rawvideo','-pix_fmt','yuv420p','-'],check=True,capture_output=True).stdout
 fb=WIDTH*HEIGHT*3//2
 if len(raw)!=fb*3:raise SystemExit('decoded size mismatch')
 i=raw[:fb];p=raw[fb:2*fb]
 if p!=expected(i):raise SystemExit('P output differs from irregular syntax-derived plan')

def main():
 ffmpeg=req('ffmpeg');ffprobe=req('ffprobe');out=Path(__file__).resolve().parent/'test_p_general_motion_plan.m2v'
 with tempfile.TemporaryDirectory(prefix='mister_h262_general_plan_') as td:
  t=Path(td);sk=t/'sk.m2v';skeleton(ffmpeg,t/'src.yuv',sk);out.write_bytes(patch(sk.read_bytes()))
 verify(ffmpeg,ffprobe,out);h=hashlib.sha256(out.read_bytes()).hexdigest()
 print(f'generated: {out}');print(f'bytes: {out.stat().st_size}');print(f'sha256: {h}');print('picture order: I P I')
 for r,(sh,p) in enumerate(zip(ROW_SHIFTS,ROW_PAYLOADS),1):print(f'P slice {r:02x}: shifts {sh}, payload {p.hex(" ")}')
 print(f'forward f_code: (3,3); syntax-derived shift-right map: 0x{PLAN_MAP:012x}')
if __name__=='__main__':main()
