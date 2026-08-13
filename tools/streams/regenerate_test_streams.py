#!/usr/bin/env python3
"""Regenerate the MiSTer-Media-Player diagnostic MPEG-2 elementary streams.

Regression-vector reset: 2026-08-13. These files are a new controlled baseline;
they are not claimed to be byte-identical to the earlier ad-hoc test artifacts.

Encoder used to establish the checked-in GitHub baseline:
  ffmpeg 6.1.1-3ubuntu5, native mpeg2video encoder
"""
from pathlib import Path
import subprocess, hashlib, json

# This file is intentionally deterministic at the source-frame level. The
# checked-in binaries are the baseline; reruns with another FFmpeg version may
# produce different encoded bytes and therefore require an explicit re-baseline.
ROOT = Path(__file__).resolve().parent
TMP = ROOT / ".regen_tmp"
TMP.mkdir(exist_ok=True)
W,H = 352,288
CW,CH = W//2,H//2
SEQ_END = b"\x00\x00\x01\xb7"


def base_planes(w=W,h=H):
    y=bytearray(w*h)
    for yy in range(h):
        for xx in range(w):
            mbx,mby=xx//16,yy//16
            sub=((xx//8)&1) | (((yy//8)&1)<<1)
            v=32 + ((mbx*11 + mby*17 + sub*29) % 192)
            if xx%16==0 or yy%16==0: v=220
            y[yy*w+xx]=v
    cb=bytearray((w//2)*(h//2)); cr=bytearray(len(cb))
    for yy in range(h//2):
        for xx in range(w//2):
            i=yy*(w//2)+xx
            cb[i]=64 + ((xx//8)*13 + (yy//8)*7)%128
            cr[i]=64 + ((xx//8)*5 + (yy//8)*19)%128
    return bytes(y),bytes(cb),bytes(cr)


def shift_left(plane,w,h,n):
    o=bytearray(len(plane))
    for yy in range(h):
        row=plane[yy*w:(yy+1)*w]
        for xx in range(w): o[yy*w+xx]=row[min(w-1,xx+n)]
    return bytes(o)


def half_left_1p5(plane,w,h):
    o=bytearray(len(plane))
    for yy in range(h):
        row=plane[yy*w:(yy+1)*w]
        for xx in range(w):
            a=row[min(w-1,xx+1)]; b=row[min(w-1,xx+2)]
            o[yy*w+xx]=(a+b+1)//2
    return bytes(o)


def raw(name,frames,w=W,h=H):
    p=TMP/(name+".yuv")
    with p.open("wb") as f:
        for Y,Cb,Cr in frames: f.write(Y); f.write(Cb); f.write(Cr)
    return p


def encode(src,out,size,frames,extra):
    cmd=["ffmpeg","-hide_banner","-loglevel","error","-y",
         "-f","rawvideo","-pix_fmt","yuv420p","-s",size,"-r","25","-i",str(src),
         "-frames:v",str(frames),"-an","-c:v","mpeg2video","-pix_fmt","yuv420p",
         "-bf","0","-q:v","2","-g","12"] + extra + ["-f","mpeg2video",str(ROOT/out)]
    subprocess.run(cmd,check=True)
    p=ROOT/out
    b=p.read_bytes()
    if not b.endswith(SEQ_END): p.write_bytes(b+SEQ_END)


def pict_types(path):
    r=subprocess.run(["ffprobe","-v","error","-select_streams","v:0",
        "-show_entries","frame=pict_type","-of","csv=p=0",str(path)],
        check=True,text=True,capture_output=True)
    return [x.strip().strip(",") for x in r.stdout.replace("\r","").splitlines() if x.strip()]


def first_slice_after_second_picture(b):
    starts=[]; i=0
    while True:
        j=b.find(b"\x00\x00\x01",i)
        if j<0: break
        if j+3<len(b): starts.append((j,b[j+3]))
        i=j+4
    pics=[o for o,c in starts if c==0]
    if len(pics)<2: return b""
    return next((b[o+4:o+12] for o,c in starts if o>pics[1] and 1<=c<=0xAF),b"")

Y,Cb,Cr=base_planes(); base=(Y,Cb,Cr)
all_i=[]
for k in range(4):
    yy=bytearray(Y); val=48+k*48
    for y in range(8,32):
        for x in range(8,32): yy[y*W+x]=val
    all_i.append((bytes(yy),Cb,Cr))
y2=bytearray(Y); y3=bytearray(Y)
for y in range(24,56):
    for x in range(24,56): y2[y*W+x]=40
for y in range(40,72):
    for x in range(40,72): y3[y*W+x]=200
Y2=shift_left(Y,W,H,2); Cb1=shift_left(Cb,CW,CH,1); Cr1=shift_left(Cr,CW,CH,1)
motion=(Y2,Cb1,Cr1)
Yh=half_left_1p5(Y,W,H)

encode(raw("all_i",all_i),"test_all_i.m2v","352x288",4,["-g","1"])
encode(raw("ipii",[base,base,(bytes(y2),Cb,Cr),(bytes(y3),Cb,Cr)]),"test_ipii.m2v","352x288",4,["-force_key_frames","0.08,0.12"])
encode(raw("motion",[base,motion,base]),"test_ip_motion_end.m2v","352x288",3,["-force_key_frames","0.08"])
encode(raw("nores",[base,base,base]),"test_ip_motion_nores_end.m2v","352x288",3,["-force_key_frames","0.08"])
encode(raw("halfpel",[base,(Yh,Cb,Cr),base]),"test_ip_halfpel_end.m2v","352x288",3,["-force_key_frames","0.08"])

w,h=32,16; cw,ch=16,8
Yt=bytearray(w*h)
for yy in range(h):
    for xx in range(w): Yt[yy*w+xx]=64 if xx<16 else 192
static=(bytes(Yt),bytes([96]*(cw*ch)),bytes([160]*(cw*ch)))
encode(raw("two_mb",[static,static,static],w,h),"test_ip_two_mb_static.m2v","32x16",3,["-force_key_frames","0.08"])

expected={
 "test_all_i.m2v":["I","I","I","I"],
 "test_ipii.m2v":["I","P","I","I"],
 "test_ip_motion_end.m2v":["I","P","I"],
 "test_ip_motion_nores_end.m2v":["I","P","I"],
 "test_ip_halfpel_end.m2v":["I","P","I"],
 "test_ip_two_mb_static.m2v":["I","P","I"],
}
manifest={}
for name,types in expected.items():
    p=ROOT/name; got=pict_types(p)
    if got!=types: raise SystemExit(f"{name}: picture order {got}, expected {types}")
    b=p.read_bytes()
    if not b.endswith(SEQ_END): raise SystemExit(f"{name}: missing sequence_end_code")
    manifest[name]={"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest(),"picture_types":got}

sig=first_slice_after_second_picture((ROOT/"test_ip_two_mb_static.m2v").read_bytes())
if sig[:3] != bytes.fromhex("12 79 c0"):
    raise SystemExit(f"two-MB signature changed: {sig[:3].hex(' ')}")
manifest["test_ip_two_mb_static.m2v"]["first_p_slice_prefix"]="12 79 c0"
print(json.dumps(manifest,indent=2))
