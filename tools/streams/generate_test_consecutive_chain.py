#!/usr/bin/env python3
"""Generate the 720x480 consecutive-P reference-chain regression.

I followed by six consecutive P pictures (P1..P6), 45x30 macroblocks. Every
P picture references the immediately preceding *decoded* P picture, not I -
each generation moves a designated feature macroblock (row 15, column 20)
by a distinct motion vector and leaves every other macroblock at zero
motion, so a decoder that (incorrectly) kept referencing I throughout, or
dropped a generation from the reference chain, would diverge from the
expected pixels at generation 2 onward. This extends the deepest
previously-validated P-reference chain (2 generations) to 6, stressing
reference-buffer/DDR continuity over a longer sequence than any single
retired tools/streams generator did.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
CHAIN_LEN = 6
FEATURE_ROW = 15
FEATURE_COL = 20
# distinct, safe (col 20 is well interior) vector per generation
GEN_VECTORS = [(4, 0), (0, 4), (-4, 4), (4, -4), (-2, -2), (3, 3)]


def build_row(row: int, vector):
    bits = format(SLICE_QSCALE, "05b") + "0"
    pred = [0, 0]
    spec = {}
    for col in range(h.MB_WIDTH):
        bits += "1"
        if row == FEATURE_ROW and col == FEATURE_COL:
            tx, ty = vector
            bits += h.P_MC_NOT_CODED + h.enc_comp(tx, pred[0]) + h.enc_comp(ty, pred[1])
            pred = [tx, ty]
            spec[col] = (tx, ty)
        else:
            bits += h.P_MC_NOT_CODED + h.enc_comp(0, pred[0]) + h.enc_comp(0, pred[1])
            pred = [0, 0]
            spec[col] = (0, 0)
    return h.bits_to_bytes(bits), spec


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_consecutive_chain.m2v"

    generations = []  # list of (row_groups, specs) per P picture
    for gen in range(CHAIN_LEN):
        rows_bits, rows_spec = [], []
        for r in range(h.MB_HEIGHT):
            payload, spec = build_row(r, GEN_VECTORS[gen] if r == FEATURE_ROW else (0, 0))
            rows_bits.append(payload)
            rows_spec.append(spec)
        generations.append((tuple((p,) for p in rows_bits), rows_spec))

    frame_count = CHAIN_LEN + 1
    with tempfile.TemporaryDirectory(prefix="mister_h262_chain_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=frame_count, gop=frame_count + 1, bframes=0)
        skeleton_types = h.picture_types(ffprobe, sk)
        if skeleton_types != ["I"] + ["P"] * CHAIN_LEN:
            raise SystemExit(f"FFmpeg skeleton picture order changed: {skeleton_types!r}")
        specs = {gen + 1: (False, generations[gen][0]) for gen in range(CHAIN_LEN)}
        data = h.patch_pictures(sk.read_bytes(), [1] + [2] * CHAIN_LEN, specs)
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I"] + ["P"] * CHAIN_LEN:
        raise SystemExit("verification failed: picture order changed after patching")

    frames = h.decode_planes(ffmpeg, out, frame_count)
    ref = frames[0]
    for gen in range(CHAIN_LEN):
        expected = h.blank_frame()
        rows_spec = generations[gen][1]
        for r in range(h.MB_HEIGHT):
            for c in range(h.MB_WIDTH):
                h.apply_macroblock(expected, r, c, ref, rows_spec[r][c])
        actual = frames[gen + 1]
        if bytes(expected) != actual:
            mismatches = sum(1 for a, b in zip(expected, actual) if a != b)
            first = next(i for i, (a, b) in enumerate(zip(expected, actual)) if a != b)
            raise SystemExit(f"verification failed at generation P{gen + 1}: {mismatches} mismatches, first at byte {first}")
        ref = actual  # chain: next generation references this decoded P, not I

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"picture order: I + {CHAIN_LEN} consecutive P pictures, each referencing the previous decoded P")
    print(f"feature macroblock: row {FEATURE_ROW} column {FEATURE_COL}, per-generation vectors {GEN_VECTORS}")
    print("verification: pixel-exact against FFmpeg decode, chained generation by generation")


if __name__ == "__main__":
    main()
