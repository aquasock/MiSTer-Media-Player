#!/usr/bin/env python3
"""Generate the 720x480 P macroblock_address_increment / escape regression.

Single P picture, 45x30 macroblocks. Every "coded" row below has real gaps
(implicit skipped macroblocks) before each explicitly coded macroblock, so
the motion-vector predictor legitimately resets to (0,0) before every one of
them (a skip is the only in-slice predictor reset besides the slice start) -
every coded macroblock therefore carries a distinct, directly verifiable
vector rather than one that could be confused with an inherited predictor.

Row 4: ordinary skip runs of varying length (4, 9, 14, 13) between coded
       macroblocks, including the rightmost column (44).
Row 10: leading skip - the first coded macroblock of the slice is not at
        column 0 (columns 0..11 are implicitly skipped).
Row 16: a mid-slice gap of 40 macroblocks requiring one macroblock_escape.
Row 20: the *first* coded macroblock of the slice itself requires an escape
        (columns 0..39 implicitly skipped in one gap).
Row 24: a single coded macroblock at the last column (44), the largest
        possible single-row gap (45), reached by one escape.
All other rows are a plain increment=1, zero-motion baseline.

No residual coefficients anywhere in this stream, so verification against
FFmpeg's decode is exact-match (no IDCT rounding-tolerance needed) -
addressing correctness is the only thing under test here.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10

ROW_SKIPS = 4
ROW_LEADING_SKIP = 10
ROW_ESCAPE_MID = 16
ROW_ESCAPE_LEADING = 20
ROW_LAST_COLUMN_ONLY = 24

CODED = {
    ROW_SKIPS: {0: (2, 0), 5: (3, -2), 15: (-3, 3), 30: (2, 2), 44: (-2, 2)},
    ROW_LEADING_SKIP: {12: (3, -2), 25: (-2, 3), 44: (-3, 0)},
    ROW_ESCAPE_MID: {0: (1, 1), 40: (-3, 2), 44: (-2, -1)},
    ROW_ESCAPE_LEADING: {40: (-2, 2), 44: (-1, -1)},
    ROW_LAST_COLUMN_ONLY: {44: (-2, 2)},
}


def build_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    vectors = {c: (0, 0) for c in range(h.MB_WIDTH)}
    coded = CODED.get(row)
    if coded is None:
        for _ in range(h.MB_WIDTH):
            bits += "1" + h.P_MC_NOT_CODED + "1" + "1"
        return h.bits_to_bytes(bits), vectors

    prev = -1
    for col in sorted(coded):
        gap = col - prev
        bits += h.enc_mba(gap)
        tx, ty = coded[col]
        bits += h.P_MC_NOT_CODED + h.enc_comp(tx, 0) + h.enc_comp(ty, 0)
        vectors[col] = (tx, ty)
        prev = col
    return h.bits_to_bytes(bits), vectors


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_p_mba_escape.m2v"

    rows_bits, rows_vectors = [], []
    for r in range(h.MB_HEIGHT):
        payload, vectors = build_row(r)
        rows_bits.append(payload)
        rows_vectors.append(vectors)

    with tempfile.TemporaryDirectory(prefix="mister_h262_pmba_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=2, gop=12, bframes=0)
        if h.picture_types(ffprobe, sk) != ["I", "P"]:
            raise SystemExit("FFmpeg skeleton picture order changed")
        row_groups = tuple((payload,) for payload in rows_bits)
        data = h.patch_pictures(sk.read_bytes(), [1, 2], {1: (False, row_groups)})
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "P"]:
        raise SystemExit("verification failed: picture order is not I/P")

    frames = h.decode_planes(ffmpeg, out, 2)
    iframe, pframe = frames[0], frames[1]

    expected = h.blank_frame()
    for r in range(h.MB_HEIGHT):
        for c in range(h.MB_WIDTH):
            h.apply_macroblock(expected, r, c, iframe, rows_vectors[r][c])

    if bytes(expected) != pframe:
        mismatches = sum(1 for a, b in zip(expected, pframe) if a != b)
        first = next(i for i, (a, b) in enumerate(zip(expected, pframe)) if a != b)
        raise SystemExit(f"verification failed: {mismatches} pixel mismatches, first at byte {first}")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("picture order: I P")
    print(f"row {ROW_SKIPS}: ordinary skip runs, columns {sorted(CODED[ROW_SKIPS])}")
    print(f"row {ROW_LEADING_SKIP}: leading skip, first coded column {min(CODED[ROW_LEADING_SKIP])}")
    print(f"row {ROW_ESCAPE_MID}: mid-slice macroblock_escape, gap 40 at column {40}")
    print(f"row {ROW_ESCAPE_LEADING}: leading macroblock_escape, first coded column {min(CODED[ROW_ESCAPE_LEADING])}")
    print(f"row {ROW_LAST_COLUMN_ONLY}: single coded macroblock at last column (44), gap 45")
    print("verification: pixel-exact against FFmpeg decode (no residual coefficients in this stream)")


if __name__ == "__main__":
    main()
