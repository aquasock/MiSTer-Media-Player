#!/usr/bin/env python3
"""Generate the broad Commit-123 H.262 progressive P-picture regression.

The patched 128x96 I/P/I elementary stream exercises signed horizontal and
vertical frame motion, half-sample interpolation, predictor reuse/reset through
an internal skipped macroblock, P no-motion coded macroblocks, macroblock-level
quantiser changes, q_scale_type=1, alternate_scan=1, sparse Y/Cb/Cr residuals,
and ordinary/escape Table-B.14 non-intra coefficient syntax.
"""
from __future__ import annotations
import hashlib, shutil, subprocess, tempfile
from pathlib import Path

FPS=25
MB_WIDTH=8; MB_HEIGHT=6; WIDTH=128; HEIGHT=96
SEQ_END=bytes.fromhex('00 00 01 b7')
MBA_VLC={1:'1',2:'011',3:'010',4:'0011',5:'0010',6:'00011',7:'00010',8:'0000111',9:'0000110',10:'00001011',11:'00001010',12:'00001001',13:'00001000',14:'00000111',15:'00000110',16:'0000010111',17:'0000010110',18:'0000010101',19:'0000010100',20:'0000010011',21:'0000010010',22:'00000100011',23:'00000100010',24:'00000100001',25:'00000100000',26:'00000011111',27:'00000011110',28:'00000011101',29:'00000011100',30:'00000011011',31:'00000011010',32:'00000011001',33:'00000011000'}
MCODE={
 -16:'00000011001',-15:'00000011011',-14:'00000011101',-13:'00000011111',-12:'00000100001',-11:'00000100011',-10:'0000010011',-9:'0000010101',-8:'0000010111',-7:'00000111',-6:'00001001',-5:'00001011',-4:'0000111',-3:'00011',-2:'0011',-1:'011',
 0:'1',1:'010',2:'0010',3:'00010',4:'0000110',5:'00001010',6:'00001000',7:'00000110',8:'0000010110',9:'0000010100',10:'0000010010',11:'00000100010',12:'00000100000',13:'00000011110',14:'00000011100',15:'00000011010',16:'00000011000'}
CBP_VLC={32:'1010',3:'001101',12:'10011',21:'00011001'}
SLICE_QSCALE=(9,10,11,12,13,14)
# Sparse residual block selection, bits 5..0 -> Y0,Y1,Y2,Y3,Cb,Cr.
RESIDUALS={(0,0):32,(1,4):3,(2,2):12,(4,3):21}
NO_MOTION={(1,4),(4,3)}
QUANT_MB={(2,2):15,(4,3):17}
SKIPPED={(0,2)}

# Desired reconstructed luminance vectors in half-sample units.
VECTORS=(
 ((1,1),(5,3),(0,0),(-3,1),(-3,1),(0,0),(2,0),(-1,0)),
 ((0,-1),(3,-3),(3,-3),(-2,2),(0,0),(1,1),(0,0),(-3,1)),
 ((1,0),(1,3),(-3,3),(-3,3),(4,-2),(0,0),(5,1),(-1,-1)),
 ((0,1),(7,3),(7,3),(2,-3),(-5,2),(-5,2),(1,0),(-3,-1)),
 ((2,-1),(5,1),(-3,-3),(0,0),(1,-1),(1,-1),(4,2),(-1,0)),
 ((1,-1),(3,-3),(3,-3),(-2,-1),(4,-4),(0,-1),(2,-2),(-3,-1)),
)

# Coefficient bitstrings include first-coefficient syntax through EOB.
# EOB=10; ordinary B.14 examples: run1/level1=011 s, run0/level2=0100 s,
# run0/level3=00101 s, run7/level1=000100 s; Escape=000001 + run6 + level12.
def esc(run:int, level:int)->str:
    if not (0<=run<64 and -2047<=level<=2047 and level!=0): raise ValueError((run,level))
    return '000001'+format(run,'06b')+format(level & 0xfff,'012b')
COEFF={
 (0,0,0): '10'+'10',                              # special first +1
 (1,4,4): '11'+'10',                              # special first -1
 (1,4,5): '10'+'011'+'0'+'10',                    # +1, run1/+1
 (2,2,2): '0100'+'0'+'10',                        # ordinary first run0/+2
 (2,2,3): '10'+'0100'+'1'+'10',                   # +1, then run0/-2
 (4,3,1): '10'+esc(2,-3)+'10',                    # +1, escape run2/-3
 (4,3,3): '00101'+'0'+'10',                       # ordinary first run0/+3
 (4,3,5): '10'+'000100'+'0'+'10',                 # +1, run7/+1
}

def req(name:str)->str:
    p=shutil.which(name)
    if not p: raise SystemExit(f'required tool not found in PATH: {name}')
    return p

def start_codes(data:bytes):
    out=[]; p=0
    while True:
        p=data.find(b'\x00\x00\x01',p)
        if p<0:return out
        if p+3<len(data):out.append((p,data[p+3]))
        p+=4

def pict_types(ffprobe,path):
    r=subprocess.run([ffprobe,'-v','error','-select_streams','v:0','-show_entries','frame=pict_type','-of','csv=p=0',str(path)],check=True,text=True,capture_output=True)
    return [x.strip().strip(',') for x in r.stdout.replace('\r','').splitlines() if x.strip()]

def bits_to_bytes(bits:str)->bytes:
    bits += '0'*((-len(bits))%8)
    return int(bits,2).to_bytes(len(bits)//8,'big')

def delta_for(target:int,pred:int)->int:
    d=target-pred
    while d>63:d-=128
    while d<-64:d+=128
    return d

def encode_component(target:int,pred:int)->str:
    d=delta_for(target,pred)
    if d==0:return MCODE[0]
    a=abs(d); mc=(a-1)//4+1; residual=(a-1)%4
    if d<0:mc=-mc
    return MCODE[mc]+format(residual,'02b')

def row_payload(row:int)->bytes:
    bits=format(SLICE_QSCALE[row],'05b')+'0' # quantiser_scale_code + extra_bit_slice terminator
    prev=-1; predx=0; predy=0
    for col in range(MB_WIDTH):
        if (row,col) in SKIPPED: continue
        inc=col-prev
        if inc>1: predx=predy=0
        bits+=MBA_VLC[inc]
        cbp=RESIDUALS.get((row,col))
        no_motion=(row,col) in NO_MOTION
        quant=QUANT_MB.get((row,col))
        if cbp is None:
            mbtype='001' # MC,Not Coded
        elif no_motion and quant is not None:
            mbtype='00001' # No MC,Coded,Quant
        elif no_motion:
            mbtype='01' # No MC,Coded
        elif quant is not None:
            mbtype='00010' # MC,Coded,Quant
        else:
            mbtype='1' # MC,Coded
        bits+=mbtype
        if quant is not None:bits+=format(quant,'05b')
        if no_motion:
            tx=ty=0; predx=predy=0
        else:
            tx,ty=VECTORS[row][col]
            bits+=encode_component(tx,predx)+encode_component(ty,predy)
            predx,predy=tx,ty
        if cbp is not None:
            bits+=CBP_VLC[cbp]
            for block in range(6):
                if cbp&(1<<(5-block)):
                    try:bits+=COEFF[(row,col,block)]
                    except KeyError as e:raise AssertionError(f'missing coefficient shape {e.args[0]}')
        prev=col
    return bits_to_bytes(bits)

ROW_PAYLOADS=tuple(row_payload(r) for r in range(MB_HEIGHT))

def source_frame()->bytes:
    y=bytearray(WIDTH*HEIGHT)
    for yy in range(HEIGHT):
        for xx in range(WIDTH):
            y[yy*WIDTH+xx]=32+((yy*3+xx*5+(yy//16)*17+(xx//16)*11)%176)
    cw,ch=WIDTH//2,HEIGHT//2; cb=bytearray(cw*ch);cr=bytearray(cw*ch)
    for yy in range(ch):
        for xx in range(cw):
            cb[yy*cw+xx]=48+((yy*5+xx*7+(yy//8)*13)%144)
            cr[yy*cw+xx]=64+((yy*9+xx*3+(xx//8)*19)%128)
    return bytes(y)+bytes(cb)+bytes(cr)

def skeleton(ffmpeg,raw,out):
    raw.write_bytes(source_frame()*3)
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','yuv420p','-s',f'{WIDTH}x{HEIGHT}','-r',str(FPS),'-i',str(raw),'-frames:v','3','-an','-c:v','mpeg2video','-pix_fmt','yuv420p','-bf','0','-q:v','2','-g','12','-force_key_frames','0.08','-f','mpeg2video',str(out)],check=True)
    d=out.read_bytes()
    if not d.endswith(SEQ_END):out.write_bytes(d+SEQ_END)

def patch(data:bytes)->bytes:
    codes=start_codes(data);pics=[o for o,c in codes if c==0]
    if len(pics)!=3:raise SystemExit(f'expected 3 pictures, found {len(pics)}')
    pp,np=pics[1],pics[2];b=bytearray(data);pce=None
    for o,c in codes:
        if pp<o<np and c==0xb5 and o+8<len(b) and (b[o+4]>>4)==8:pce=o;break
    if pce is None:raise SystemExit('P picture_coding_extension not found')
    # forward f_code=(3,3), frame_pred_frame_dct=1, concealment=0,
    # q_scale_type=1 and alternate_scan=1.
    b[pce+4]=(b[pce+4]&0xf0)|3
    b[pce+5]=0x30|(b[pce+5]&0x0f)
    b[pce+7]=(b[pce+7]|0x40|0x10|0x04)&~0x20
    codes=start_codes(b)
    rows=[(i,o,c) for i,(o,c) in enumerate(codes) if pp<o<np and 1<=c<=MB_HEIGHT]
    if tuple(c for _,_,c in rows)!=tuple(range(1,MB_HEIGHT+1)):raise SystemExit('unexpected P slice layout')
    repl=[(o+4,codes[i+1][0]) for i,o,_ in rows]
    for row,(s,e) in reversed(list(enumerate(repl))):b[s:e]=ROW_PAYLOADS[row]
    return bytes(b)

def trunc2(v:int)->int:
    return -(abs(v)//2) if v<0 else v//2

def sample_plane(src:bytes,base:int,stride:int,w:int,h:int,x:int,y:int,vx:int,vy:int)->int:
    ix=vx//2;iy=vy//2 # Python // is floor, matching H.262 DIV 2
    hx=vx-2*ix;hy=vy-2*iy
    sx=x+ix;sy=y+iy
    if not(0<=sx<w and 0<=sy<h and sx+hx<w and sy+hy<h):raise AssertionError((x,y,vx,vy,sx,sy,w,h))
    p00=src[base+sy*stride+sx]
    if not hx and not hy:return p00
    if hx and not hy:return (p00+src[base+sy*stride+sx+1]+1)//2
    if hy and not hx:return (p00+src[base+(sy+1)*stride+sx]+1)//2
    return (p00+src[base+sy*stride+sx+1]+src[base+(sy+1)*stride+sx]+src[base+(sy+1)*stride+sx+1]+2)//4

def pure_prediction(frame:bytes)->bytes:
    out=bytearray(len(frame));ys=WIDTH*HEIGHT;cw=WIDTH//2;ch=HEIGHT//2;cs=cw*ch
    for mr in range(MB_HEIGHT):
        for mc in range(MB_WIDTH):
            vx,vy=(0,0) if (mr,mc) in SKIPPED or (mr,mc) in NO_MOTION else VECTORS[mr][mc]
            for yy in range(mr*16,(mr+1)*16):
                for xx in range(mc*16,(mc+1)*16):out[yy*WIDTH+xx]=sample_plane(frame,0,WIDTH,WIDTH,HEIGHT,xx,yy,vx,vy)
            cvx,cvy=trunc2(vx),trunc2(vy)
            for plane in (ys,ys+cs):
                for yy in range(mr*8,(mr+1)*8):
                    for xx in range(mc*8,(mc+1)*8):out[plane+yy*cw+xx]=sample_plane(frame,plane,cw,cw,ch,xx,yy,cvx,cvy)
    return bytes(out)

def residual_mask()->bytearray:
    mask=bytearray(WIDTH*HEIGHT*3//2);ys=WIDTH*HEIGHT;cw=WIDTH//2;cs=cw*(HEIGHT//2)
    for (mr,mc),cbp in RESIDUALS.items():
        for block in range(6):
            if not(cbp&(1<<(5-block))):continue
            if block<4:
                bx=mc*16+(block&1)*8;by=mr*16+((block>>1)&1)*8
                for yy in range(by,by+8):mask[yy*WIDTH+bx:yy*WIDTH+bx+8]=b'\x01'*8
            else:
                plane=ys if block==4 else ys+cs;bx=mc*8;by=mr*8
                for yy in range(by,by+8):mask[plane+yy*cw+bx:plane+yy*cw+bx+8]=b'\x01'*8
    return mask

def verify(ffmpeg,ffprobe,out):
    if pict_types(ffprobe,out)!=['I','P','I']:raise SystemExit('picture order is not I/P/I')
    data=out.read_bytes();codes=start_codes(data);pics=[o for o,c in codes if c==0];pp,np=pics[1],pics[2];pce=None;slices=[]
    for i,(o,c) in enumerate(codes):
        if not(pp<o<np):continue
        e=codes[i+1][0]
        if c==0xb5 and (data[o+4]>>4)==8:pce=data[o+4:e]
        elif 1<=c<=MB_HEIGHT:slices.append((c,data[o+4:e]))
    if pce is None or len(pce)<4:raise SystemExit('P picture_coding_extension missing/short')
    if (pce[0]&0xf)!=3 or (pce[1]>>4)!=3:raise SystemExit('forward f_code is not (3,3)')
    if not(pce[3]&0x10) or not(pce[3]&0x04):raise SystemExit('q_scale_type/alternate_scan patch missing')
    if slices!=[(i+1,ROW_PAYLOADS[i]) for i in range(MB_HEIGHT)]:raise SystemExit(f'unexpected P slices: {slices!r}')
    dec=subprocess.run([ffmpeg,'-v','error','-i',str(out),'-f','rawvideo','-pix_fmt','yuv420p','-'],check=True,capture_output=True).stdout
    fb=WIDTH*HEIGHT*3//2
    if len(dec)!=3*fb:raise SystemExit(f'unexpected decoded size {len(dec)}')
    iframe=dec[:fb];pframe=dec[fb:2*fb];pred=pure_prediction(iframe);mask=residual_mask()
    for i,(got,want,m) in enumerate(zip(pframe,pred,mask)):
        if not m and got!=want:raise SystemExit(f'motion prediction mismatch outside residual blocks at byte {i}: decoded {got}, predicted {want}')
    # Every selected residual block must actually alter at least one pel.
    ys=WIDTH*HEIGHT;cw=WIDTH//2;cs=cw*(HEIGHT//2)
    changed=[]
    for key in sorted(COEFF):
        mr,mc,block=key;idx=[]
        if block<4:
            bx=mc*16+(block&1)*8;by=mr*16+((block>>1)&1)*8
            idx=[yy*WIDTH+xx for yy in range(by,by+8) for xx in range(bx,bx+8)]
        else:
            plane=ys if block==4 else ys+cs;bx=mc*8;by=mr*8
            idx=[plane+yy*cw+xx for yy in range(by,by+8) for xx in range(bx,bx+8)]
        diffs=[pframe[i]-pred[i] for i in idx]
        if not any(diffs):raise SystemExit(f'residual block {key} produced no decoded difference')
        changed.extend(diffs)
    if not any(d>0 for d in changed) or not any(d<0 for d in changed):raise SystemExit('expected both positive and negative residual effects')

def main():
    ffmpeg=req('ffmpeg');ffprobe=req('ffprobe');out=Path(__file__).resolve().parent/'test_p_general_decode.m2v'
    with tempfile.TemporaryDirectory(prefix='mister_h262_general_decode_') as td:
        t=Path(td);sk=t/'skeleton.m2v';skeleton(ffmpeg,t/'source.yuv',sk)
        if pict_types(ffprobe,sk)!=['I','P','I']:raise SystemExit('FFmpeg skeleton picture order changed')
        out.write_bytes(patch(sk.read_bytes()))
    verify(ffmpeg,ffprobe,out)
    print(f'generated: {out}')
    print('geometry: 8x6 macroblocks (128x96, 48 total)')
    print(f'bytes: {out.stat().st_size}')
    print(f'sha256: {hashlib.sha256(out.read_bytes()).hexdigest()}')
    print('picture order: I P I; f_code=(3,3); q_scale_type=1; alternate_scan=1')
    for n,p in enumerate(ROW_PAYLOADS,1):print(f'P slice {n:02x}: payload {p.hex(" ")}')
    print('skipped macroblocks:',sorted(SKIPPED))
    print('no-motion coded macroblocks:',sorted(NO_MOTION))
    print('macroblock quantiser changes:',sorted(QUANT_MB.items()))
    print('residual coefficient shapes:')
    for key,bits in sorted(COEFF.items()):print(f'  {key}: {bits}')

if __name__=='__main__':main()
