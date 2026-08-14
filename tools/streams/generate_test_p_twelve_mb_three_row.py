#!/usr/bin/env python3
"""Generate a controlled 64x48 / 4x3 / twelve-macroblock MPEG-2 P regression."""
from __future__ import annotations
import argparse, hashlib, shutil, subprocess, tempfile
from pathlib import Path

WIDTH=64
HEIGHT=48
FPS=25
SLICE_CODES=(0x01,0x02,0x03)
SLICE_PAYLOAD=bytes.fromhex('12 79 e7 9c')
SEQ_END=bytes.fromhex('00 00 01 b7')


def require_tool(name:str)->str:
    p=shutil.which(name)
    if p is None:
        raise SystemExit(f'required tool not found in PATH: {name}')
    return p


def start_codes(data:bytes|bytearray)->list[tuple[int,int]]:
    out=[]; pos=0; marker=b'\x00\x00\x01'
    while True:
        pos=data.find(marker,pos)
        if pos<0: return out
        if pos+3<len(data): out.append((pos,data[pos+3]))
        pos+=4


def picture_types(ffprobe:str,path:Path)->list[str]:
    r=subprocess.run([ffprobe,'-v','error','-select_streams','v:0','-show_entries','frame=pict_type','-of','csv=p=0',str(path)],check=True,text=True,capture_output=True)
    return [x.strip().strip(',') for x in r.stdout.replace('\r','').splitlines() if x.strip()]


def make_source_frame()->bytes:
    vals=((40,80,120,160),(56,96,136,176),(72,112,152,208))
    y=bytearray(WIDTH*HEIGHT)
    for yy in range(HEIGHT):
        for xx in range(WIDTH):
            y[yy*WIDTH+xx]=vals[yy//16][xx//16]
    cw,ch=WIDTH//2,HEIGHT//2
    cb=bytes([96])*(cw*ch)
    cr=bytes([160])*(cw*ch)
    return bytes(y)+cb+cr


def generate_skeleton(ffmpeg:str,raw_path:Path,out:Path)->None:
    frame=make_source_frame(); raw_path.write_bytes(frame*3)
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','yuv420p','-s',f'{WIDTH}x{HEIGHT}','-r',str(FPS),'-i',str(raw_path),'-frames:v','3','-an','-c:v','mpeg2video','-pix_fmt','yuv420p','-bf','0','-q:v','2','-g','12','-force_key_frames','0.08','-f','mpeg2video',str(out)],check=True)
    b=out.read_bytes()
    if not b.endswith(SEQ_END): out.write_bytes(b+SEQ_END)


def patch_controlled_p_picture(data:bytes)->bytes:
    codes=start_codes(data)
    pics=[o for o,c in codes if c==0x00]
    if len(pics)!=3: raise SystemExit(f'expected 3 pictures, got {len(pics)}')
    p_pic,next_pic=pics[1],pics[2]
    patched=bytearray(data)
    pce=None
    for o,c in codes:
        if p_pic<o<next_pic and c==0xB5 and o+5<len(patched) and (patched[o+4]>>4)==0x8:
            pce=o; break
    if pce is None: raise SystemExit('P picture_coding_extension() not found')
    patched[pce+4]=(patched[pce+4]&0xF0)|0x02
    patched[pce+5]=0x20|(patched[pce+5]&0x0F)

    codes=start_codes(patched)
    region=[(i,o,c) for i,(o,c) in enumerate(codes) if p_pic<o<next_pic and 0x01<=c<=0xAF]
    got=tuple(c for _,_,c in region)
    if got!=SLICE_CODES: raise SystemExit(f'expected P slices {SLICE_CODES}, got {got}')
    reps=[]
    for i,o,_ in region:
        reps.append((o+4,codes[i+1][0]))
    for a,b in reversed(reps): patched[a:b]=SLICE_PAYLOAD
    return bytes(patched)


def verify_output(ffmpeg:str,ffprobe:str,path:Path)->None:
    if picture_types(ffprobe,path)!=['I','P','I']:
        raise SystemExit(f'unexpected picture order: {picture_types(ffprobe,path)!r}')
    b=path.read_bytes(); codes=start_codes(b); pics=[o for o,c in codes if c==0x00]
    p_pic,next_pic=pics[1],pics[2]
    pce=None; slices=[]
    for i,(o,c) in enumerate(codes):
        if not (p_pic<o<next_pic): continue
        end=codes[i+1][0]
        if c==0xB5 and (b[o+4]>>4)==0x8: pce=b[o+4:end]
        elif c in SLICE_CODES: slices.append((c,b[o+4:end]))
    if pce is None or len(pce)<2: raise SystemExit('missing P coding extension')
    if (pce[0]&0x0F)!=2 or (pce[1]>>4)!=2: raise SystemExit('forward f_code != (2,2)')
    expected=[(c,SLICE_PAYLOAD) for c in SLICE_CODES]
    if slices!=expected: raise SystemExit(f'unexpected slices: {slices!r}')
    decoded=subprocess.run([ffmpeg,'-v','error','-i',str(path),'-f','rawvideo','-pix_fmt','yuv420p','-'],check=True,capture_output=True).stdout
    n=WIDTH*HEIGHT*3//2
    if len(decoded)!=n*3: raise SystemExit(f'decoded bytes {len(decoded)}, expected {n*3}')
    if decoded[:n]!=decoded[n:2*n]: raise SystemExit('decoded P frame differs from I reference')


def main()->None:
    ap=argparse.ArgumentParser(); ap.add_argument('-o','--output',type=Path,default=Path(__file__).resolve().parent/'test_p_twelve_mb_three_row.m2v'); args=ap.parse_args()
    ffmpeg=require_tool('ffmpeg'); ffprobe=require_tool('ffprobe'); args.output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mister_h262_twelvemb_') as td:
        td=Path(td); raw=td/'twelve_mb.yuv'; skel=td/'twelve_mb_skeleton.m2v'
        generate_skeleton(ffmpeg,raw,skel)
        st=picture_types(ffprobe,skel)
        if st!=['I','P','I']: raise SystemExit(f'FFmpeg skeleton picture order changed: {st!r}')
        args.output.write_bytes(patch_controlled_p_picture(skel.read_bytes()))
    verify_output(ffmpeg,ffprobe,args.output)
    digest=hashlib.sha256(args.output.read_bytes()).hexdigest()
    version=subprocess.run([ffmpeg,'-version'],check=True,text=True,capture_output=True).stdout.splitlines()[0]
    print(f'generated: {args.output}')
    print(f'bytes: {args.output.stat().st_size}')
    print(f'sha256: {digest}')
    print(f'ffmpeg: {version}')
    print('picture order: I P I')
    print('P slices: 01/02/03 payload 12 79 e7 9c')
    print('forward f_code: (2,2)')

if __name__=='__main__': main()
