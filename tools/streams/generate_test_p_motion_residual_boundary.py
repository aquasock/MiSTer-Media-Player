#!/usr/bin/env python3
"""Generate an I/P-only diagnostic boundary variant of the mixed P regression.

The ordinary mixed regression is first regenerated and fully software-verified.
This diagnostic then removes the trailing I picture and replaces it with a fresh
sequence-header/sequence-extension boundary followed by sequence_end.  The FPGA
therefore sees the same post-P boundary used to release the mixed raster proof,
but no later picture can overwrite the displayed P destination.  If the mixed
P picture is published/presented, the screen must remain on that P frame.
"""
from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

import generate_test_p_motion_residual_mix as base


def decode_raw(ffmpeg: str, path: Path) -> bytes:
    return subprocess.run(
        [ffmpeg, '-v', 'error', '-i', str(path), '-f', 'rawvideo',
         '-pix_fmt', 'yuv420p', '-'],
        check=True, capture_output=True,
    ).stdout


def main() -> None:
    # Rebuild and validate the authoritative mixed I/P/I stream first.
    base.main()

    ffmpeg = base.req('ffmpeg')
    ffprobe = base.req('ffprobe')
    src = Path(base.__file__).resolve().parent / 'test_p_motion_residual_mix.m2v'
    out = Path(__file__).resolve().parent / 'test_p_motion_residual_boundary.m2v'

    data = src.read_bytes()
    codes = base.start_codes(data)
    pics = [o for o, c in codes if c == 0x00]
    seqs = [o for o, c in codes if c == 0xB3]
    if len(pics) != 3:
        raise SystemExit(f'expected source I/P/I picture count 3, found {len(pics)}')
    if not seqs or seqs[0] >= pics[0]:
        raise SystemExit('source sequence header not found before first picture')

    # Reuse the complete original sequence header/extension preamble.  Its B3
    # start code is the post-P boundary observed by the FPGA mixed proof.
    preamble = data[seqs[0]:pics[0]]
    diag = data[:pics[2]] + preamble + base.SEQ_END
    out.write_bytes(diag)

    if base.pict_types(ffprobe, out) != ['I', 'P']:
        raise SystemExit('diagnostic picture order is not I/P')
    out_codes = base.start_codes(diag)
    out_pics = [o for o, c in out_codes if c == 0x00]
    if len(out_pics) != 2:
        raise SystemExit(f'diagnostic contains {len(out_pics)} picture start codes, expected 2')
    if not any(o > out_pics[1] and c == 0xB3 for o, c in out_codes):
        raise SystemExit('diagnostic lacks post-P sequence-header boundary')
    if not diag.endswith(base.SEQ_END):
        raise SystemExit('diagnostic lacks sequence_end')

    fb = base.WIDTH * base.HEIGHT * 3 // 2
    src_raw = decode_raw(ffmpeg, src)
    diag_raw = decode_raw(ffmpeg, out)
    if len(diag_raw) != 2 * fb:
        raise SystemExit(f'unexpected diagnostic decoded size {len(diag_raw)}, expected {2*fb}')
    if diag_raw != src_raw[:2 * fb]:
        raise SystemExit('diagnostic I/P decode differs from authoritative mixed stream')

    print(f'generated: {out}')
    print('diagnostic picture order: I P')
    print('post-P boundary: repeated sequence header/extension, then sequence_end')
    print(f'bytes: {out.stat().st_size}')
    print(f'sha256: {hashlib.sha256(diag).hexdigest()}')
    print('expected hardware display if mixed P publication succeeds: P frame remains visible')


if __name__ == '__main__':
    main()
