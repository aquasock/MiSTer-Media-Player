#!/usr/bin/env python3
"""Generate controlled 128x96 H.262 P motion+residual mixed-raster regression.

The first P macroblock is Table-B.3 MC+Coded with a controlled (+32,0)
forward vector, CBP=63, and six coded non-intra blocks.  Each block carries
one +7 coefficient followed by EOB.  Macroblock column 1 is skipped to reset
PMV; rows 2..6 retain the accepted per-row motion-dispatch shape.
"""
from __future__ import annotations
import hashlib, shutil, subprocess, tempfile
from pathlib import Path

FPS=25
MB_WIDTH=8; MB_HEIGHT=6; WIDTH=128; HEIGHT=96
SEQ_END=bytes.fromhex('00 00 01 b7')
MBA_VLC={1:'1',2:'011',3:'010',4:'0011',5:'0010',6:'00011',7:'00010',8:'0000111',9:'0000110',10:'00001011',11:'00001010',12:'00001001',13:'00001000',14:'00000111',15:'00000110',16:'0000010111',17:'0000010110',18:'0000010101',19:'0000010100',20:'0000010011',21:'0000010010',22:'00000100011',23:'00000100010',24:'00000100001',25:'00000100000',26:'00000011111',27:'00000011110',28:'00000011101',29:'00000011100',30:'00000011011',31:'00000011010',32:'00000011001',33:'00000011000'}
MCODE_POS8='0000010110'; MCODE_ZERO='1'
SHIFT_MAP=0x201008040201

def req(name):
    p=shutil.which(name)
    if not p: raise SystemExit(f'required tool not found in PATH: {name}')
    return p

def start_codes(data):
    out=[]; p=0
    while True:
        p=data.find(b'\x00\x00\x01',p)
        if p<0:return out
        if p+3<len(data): out.append((p,data[p+3]))
        p+=4

def pict_types(ffprobe,path):
    r=subprocess.run([ffprobe,'-v','error','-select_streams','v:0','-show_entries','frame=pict_type','-of','csv=p=0',str(path)],check=True,text=True,capture_output=True)
    return [x.strip().strip(',') for x in r.stdout.replace('\r','').splitlines() if x.strip()]

def bits_to_bytes(bits):
    bits += '0'*((-len(bits))%8)
    return int(bits,2).to_bytes(len(bits)//8,'big')

def motion_only_row(shift_col):
    bits='000100'; prev=-1
    for col in range(MB_WIDTH):
        if col==shift_col+1: continue
        inc=col-prev
        if col==shift_col:
            bits += MBA_VLC[inc]+'001'+MCODE_POS8+'11'+MCODE_ZERO
        else:
            bits += MBA_VLC[inc]+'001'+MCODE_ZERO+MCODE_ZERO
        prev=col
    return bits_to_bytes(bits)

def mixed_row0():
    bits='000100'                # qscale=2, extra_bit_slice=0
    bits+='1'                    # MBA increment 1
    bits+='1'                    # P macroblock_type: MC + Coded
    bits+=MCODE_POS8+'11'        # horizontal +32 at f_code=3
    bits+=MCODE_ZERO             # vertical 0
    bits+='001100'               # coded_block_pattern=63
    bits+=('0000001010'+'0'+'10')*6  # each block: run0/level+7, then EOB
    # col1 skipped; col2 is increment 2, then zero-vector coded MBs through col7
    prev=0
    for col in range(2,MB_WIDTH):
        inc=col-prev
        bits += MBA_VLC[inc]+'001'+MCODE_ZERO+MCODE_ZERO
        prev=col
    return bits_to_bytes(bits)

ROW_PAYLOADS=(mixed_row0(),)+tuple(motion_only_row(r) for r in range(1,MB_HEIGHT))

def source_frame():
    y=bytearray(WIDTH*HEIGHT)
    for yy in range(HEIGHT):
        my=yy//16
        for xx in range(WIDTH):
            mx=xx//16; y[yy*WIDTH+xx]=32+((my*29+mx*17)%176)
    cw,ch=WIDTH//2,HEIGHT//2; cb=bytearray(cw*ch); cr=bytearray(cw*ch)
    for yy in range(ch):
        my=yy//8
        for xx in range(cw):
            mx=xx//8
            cb[yy*cw+xx]=48+((my*19+mx*23)%144)
            cr[yy*cw+xx]=64+((my*31+mx*13)%128)
    return bytes(y)+bytes(cb)+bytes(cr)

def skeleton(ffmpeg,raw,out):
    raw.write_bytes(source_frame()*3)
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','yuv420p','-s',f'{WIDTH}x{HEIGHT}','-r',str(FPS),'-i',str(raw),'-frames:v','3','-an','-c:v','mpeg2video','-pix_fmt','yuv420p','-bf','0','-q:v','2','-g','12','-force_key_frames','0.08','-f','mpeg2video',str(out)],check=True)
    d=out.read_bytes()
    if not d.endswith(SEQ_END):out.write_bytes(d+SEQ_END)

def patch(data):
    codes=start_codes(data); pics=[o for o,c in codes if c==0]
    if len(pics)!=3: raise SystemExit(f'expected 3 pictures, found {len(pics)}')
    pp,np=pics[1],pics[2]; b=bytearray(data); pce=None
    for o,c in codes:
        if pp<o<np and c==0xb5 and o+5<len(b) and (b[o+4]>>4)==8:
            pce=o;break
    if pce is None: raise SystemExit('P picture_coding_extension not found')
    b[pce+4]=(b[pce+4]&0xf0)|3; b[pce+5]=0x30|(b[pce+5]&0x0f)
    codes=start_codes(b)
    rows=[(i,o,c) for i,(o,c) in enumerate(codes) if pp<o<np and 1<=c<=MB_HEIGHT]
    if tuple(c for _,_,c in rows)!=tuple(range(1,MB_HEIGHT+1)):raise SystemExit('unexpected P slice layout')
    repl=[(o+4,codes[i+1][0]) for i,o,_ in rows]
    for row,(s,e) in reversed(list(enumerate(repl))): b[s:e]=ROW_PAYLOADS[row]
    return bytes(b)

def pure_prediction(frame):
    cw,ch=WIDTH//2,HEIGHT//2; ys=WIDTH*HEIGHT; cs=cw*ch; out=bytearray(frame)
    for row,col in enumerate(range(MB_HEIGHT)):
        for yy in range(row*16,(row+1)*16):
            d=yy*WIDTH+col*16; out[d:d+16]=frame[d+16:d+32]
        for plane in (ys,ys+cs):
            for yy in range(row*8,(row+1)*8):
                d=plane+yy*cw+col*8; out[d:d+8]=frame[d+8:d+16]
    return bytes(out)

def verify(ffmpeg,ffprobe,out):
    if pict_types(ffprobe,out)!=['I','P','I']:raise SystemExit('picture order is not I/P/I')
    data=out.read_bytes(); codes=start_codes(data); pics=[o for o,c in codes if c==0]; pp,np=pics[1],pics[2]
    pce=None;slices=[]
    for i,(o,c) in enumerate(codes):
        if not(pp<o<np):continue
        e=codes[i+1][0]
        if c==0xb5 and (data[o+4]>>4)==8:pce=data[o+4:e]
        elif 1<=c<=MB_HEIGHT:slices.append((c,data[o+4:e]))
    if pce is None or len(pce)<2 or (pce[0]&0xf)!=3 or (pce[1]>>4)!=3:raise SystemExit('forward f_code is not (3,3)')
    if slices!=[(i+1,ROW_PAYLOADS[i]) for i in range(MB_HEIGHT)]:raise SystemExit(f'unexpected P slices: {slices!r}')
    dec=subprocess.run([ffmpeg,'-v','error','-i',str(out),'-f','rawvideo','-pix_fmt','yuv420p','-'],check=True,capture_output=True).stdout
    fb=WIDTH*HEIGHT*3//2
    if len(dec)!=3*fb:raise SystemExit('unexpected decoded size')
    iframe=dec[:fb]; pframe=dec[fb:2*fb]; pure=pure_prediction(iframe)
    # Outside MB0, coded result must equal the established motion-plan prediction.
    ys=WIDTH*HEIGHT; cw=WIDTH//2; cs=cw*(HEIGHT//2)
    mask=bytearray(b'\x01')*fb
    for yy in range(16): mask[yy*WIDTH:yy*WIDTH+16]=b'\x00'*16
    for off in (ys,ys+cs):
        for yy in range(8): mask[off+yy*cw:off+yy*cw+8]=b'\x00'*8
    for i,m in enumerate(mask):
        if m and pframe[i]!=pure[i]:raise SystemExit(f'outside-MB0 mismatch at byte {i}')
    for i,m in enumerate(mask):
        if not m and pframe[i] - pure[i] != 4:
            raise SystemExit(f'MB0 residual mismatch at byte {i}: expected +4, got {pframe[i]-pure[i]}')

def main():
    ffmpeg=req('ffmpeg');ffprobe=req('ffprobe')
    out=Path(__file__).resolve().parent/'test_p_motion_residual_mix.m2v'
    with tempfile.TemporaryDirectory(prefix='mister_h262_mix_') as td:
        t=Path(td); sk=t/'skeleton.m2v'; skeleton(ffmpeg,t/'source.yuv',sk)
        if pict_types(ffprobe,sk)!=['I','P','I']:raise SystemExit('FFmpeg skeleton picture order changed')
        out.write_bytes(patch(sk.read_bytes()))
    verify(ffmpeg,ffprobe,out)
    print(f'generated: {out}')
    print('geometry: 8x6 macroblocks (128x96, 48 total)')
    print(f'bytes: {out.stat().st_size}')
    print(f'sha256: {hashlib.sha256(out.read_bytes()).hexdigest()}')
    print('picture order: I P I')
    for n,p in enumerate(ROW_PAYLOADS,1):print(f'P slice {n:02x}: payload {p.hex(" ")}')
    print('P MB0: MC+Coded, forward (+32,0), CBP=63, six +7/EOB blocks; decoded residual +4/pel')
    print(f'shift-right execution map: 0x{SHIFT_MAP:012x}')

if __name__=='__main__':main()
