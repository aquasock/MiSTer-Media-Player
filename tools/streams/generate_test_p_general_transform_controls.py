#!/usr/bin/env python3
"""Generate a focused generalized-P transform-controls regression.

This keeps motion at the already-proven zero-vector case and isolates the
Commit-125 functional fix: a generalized Y0 residual using nonlinear qscale,
alternate_scan and a non-legacy coefficient shape must not trip the old
Phase-1T Y0/+7/qscale=2 diagnostic key.
"""
from __future__ import annotations
import hashlib, tempfile
from pathlib import Path
import generate_test_p_general_decode as g

# Keep motion deliberately trivial; exercise only generalized transform controls.
g.VECTORS=tuple(tuple((0,0) for _ in range(g.MB_WIDTH)) for _ in range(g.MB_HEIGHT))
g.SKIPPED=set()
g.NO_MOTION=set()
g.QUANT_MB={}
g.RESIDUALS={(0,0):32}
g.COEFF={(0,0,0): '10'+'011'+'0'+'10'}  # +1, then run1/+1, EOB
g.SLICE_QSCALE=(9,9,9,9,9,9)
g.ROW_PAYLOADS=tuple(g.row_payload(r) for r in range(g.MB_HEIGHT))

def main():
    ffmpeg=g.req('ffmpeg'); ffprobe=g.req('ffprobe')
    out=Path(__file__).resolve().parent/'test_p_general_transform_controls.m2v'
    with tempfile.TemporaryDirectory(prefix='mister_h262_general_transform_') as td:
        t=Path(td); sk=t/'skeleton.m2v'; g.skeleton(ffmpeg,t/'source.yuv',sk)
        if g.pict_types(ffprobe,sk)!=['I','P','I']:
            raise SystemExit('FFmpeg skeleton picture order changed')
        out.write_bytes(g.patch(sk.read_bytes()))
    g.verify(ffmpeg,ffprobe,out)
    print(f'generated: {out}')
    print(f'bytes: {out.stat().st_size}')
    print(f'sha256: {hashlib.sha256(out.read_bytes()).hexdigest()}')
    print('profile: zero motion; Y0 +1, run1/+1; q_scale_type=1; alternate_scan=1')
    for n,p in enumerate(g.ROW_PAYLOADS,1): print(f'P slice {n:02x}: payload {p.hex(" ")}')

if __name__=='__main__': main()
