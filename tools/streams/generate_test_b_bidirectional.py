#!/usr/bin/env python3
"""Generate the 720x480 B forward/backward/bidirectional regression.

Coded order I/P/B/P/B (display order I/B/P/B/P), 45x30 macroblocks. B0
references I (forward) and the first P (backward); B1 references the first
P (forward) and the second P (backward) - each B picture exercises a
distinct reference pair.

Every macroblock in every row is explicitly coded (macroblock_address_
increment=1 throughout - no skips). B-picture skipped macroblocks were
empirically found (Commit-175/176 analysis) to repeat the *previous*
macroblock's full prediction rather than reset to zero motion like a
P-picture skip - a real, distinct behavior, but out of scope for this file;
it needs its own dedicated, separately-verified regression and is deferred
to the larger version-release suite. This file stays scoped to forward /
backward / bidirectional prediction correctness.

Row 3: forward-only prediction, all four half-sample phases.
Row 8: backward-only prediction, same phase coverage.
Row 13: bidirectional prediction with independently-phased forward and
        backward vectors.
Row 18: bidirectional prediction plus residual coverage across every
        validated CBP value (+/-1 IDCT tolerance applies here only).
Row 23: forward-only, backward-only and bidirectional macroblocks
        alternating in one row, proving fp only updates on a forward
        component and bp only on a backward component.
All other rows: uniform bidirectional zero-vector, no residual.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10

ROW_FWD = 3
ROW_BWD = 8
ROW_BIDIR = 13
ROW_RESIDUAL = 18
ROW_MIXED = 23

FWD_MBS = {5: (4, 0), 15: (3, 0), 25: (4, -3), 35: (-3, 3)}
BWD_MBS = {5: (4, 0), 15: (3, 0), 25: (4, -3), 35: (-3, 3)}
BIDIR_MBS = {10: ((2, 0), (3, 0)), 20: ((3, -2), (0, 3)), 30: ((-3, 3), (2, -2))}
RESIDUAL_MBS = {
    5: (32, {0: [(0, 7)]}),
    12: (48, {0: [(0, 1), (1, -3), (0, 2)], 1: [(0, -1), (0, 3)]}),
    19: (12, {2: [(0, 1), (7, 1)], 3: [(0, -2)]}),
    26: (21, {1: [(0, -1)], 3: [(0, 2), (1, 1)], 5: [(0, 1)]}),
    33: (3, {4: [(0, 1)], 5: [(0, -3), (0, 1)]}),
    40: (63, {b: [(0, 1 if b % 2 == 0 else -1)] for b in range(6)}),
}
RESIDUAL_BIDIR_VECTOR = ((2, 2), (-2, 2))
# col -> (fwd_vec_or_None, bwd_vec_or_None)
MIXED_MBS = {6: ((3, 0), None), 18: (None, (2, -2)), 30: ((-2, 3), (3, -2))}


def emit_mb(bits: str, fp: list[int], bp: list[int], fwd_vec, bwd_vec,
            cbp=None, coeffs=None) -> str:
    if fwd_vec is not None and bwd_vec is not None:
        bits += h.BTYPE[(3, 1 if cbp else 0)]
        bits += h.enc_comp(fwd_vec[0], fp[0]) + h.enc_comp(fwd_vec[1], fp[1])
        bits += h.enc_comp(bwd_vec[0], bp[0]) + h.enc_comp(bwd_vec[1], bp[1])
        fp[:] = fwd_vec
        bp[:] = bwd_vec
    elif fwd_vec is not None:
        bits += h.BTYPE[(1, 1 if cbp else 0)]
        bits += h.enc_comp(fwd_vec[0], fp[0]) + h.enc_comp(fwd_vec[1], fp[1])
        fp[:] = fwd_vec
    else:
        bits += h.BTYPE[(2, 1 if cbp else 0)]
        bits += h.enc_comp(bwd_vec[0], bp[0]) + h.enc_comp(bwd_vec[1], bp[1])
        bp[:] = bwd_vec
    if cbp:
        bits += h.CBP_VLC[cbp]
        for block in range(6):
            if cbp & (1 << (5 - block)):
                bits += h.emit_block(coeffs[block])
    return bits


def build_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    fp, bp = [0, 0], [0, 0]
    spec = {c: ((0, 0), (0, 0), None, None) for c in range(h.MB_WIDTH)}
    feature = {
        ROW_FWD: {c: (v, None) for c, v in FWD_MBS.items()},
        ROW_BWD: {c: (None, v) for c, v in BWD_MBS.items()},
        ROW_BIDIR: BIDIR_MBS,
        ROW_MIXED: MIXED_MBS,
    }.get(row, {})

    for col in range(h.MB_WIDTH):
        bits += "1"
        if row == ROW_RESIDUAL and col in RESIDUAL_MBS:
            cbp, coeffs = RESIDUAL_MBS[col]
            fv, bv = RESIDUAL_BIDIR_VECTOR
            bits = emit_mb(bits, fp, bp, fv, bv, cbp=cbp, coeffs=coeffs)
            spec[col] = (fv, bv, cbp, coeffs)
        elif col in feature:
            fv, bv = feature[col]
            bits = emit_mb(bits, fp, bp, fv, bv)
            spec[col] = (fv, bv, None, None)
        else:
            bits = emit_mb(bits, fp, bp, (0, 0), (0, 0))
            spec[col] = ((0, 0), (0, 0), None, None)

    return h.bits_to_bytes(bits), spec


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_b_bidirectional.m2v"

    def p_row():
        bits = format(SLICE_QSCALE, "05b") + "0"
        for _ in range(h.MB_WIDTH):
            bits += "1" + h.P_MC_NOT_CODED + "1" + "1"
        return h.bits_to_bytes(bits)

    b_bits, b_specs = [], []
    for r in range(h.MB_HEIGHT):
        payload, spec = build_row(r)
        b_bits.append(payload)
        b_specs.append(spec)

    p_rows = tuple((p_row(),) for _ in range(h.MB_HEIGHT))
    b_rows = tuple((p,) for p in b_bits)

    with tempfile.TemporaryDirectory(prefix="mister_h262_bbidir_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=5, gop=12, bframes=1)
        if [t for _, t in h.pictures(sk.read_bytes())] != [1, 2, 3, 2, 3]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        data = h.patch_pictures(sk.read_bytes(), [1, 2, 3, 2, 3], {
            1: (False, p_rows), 2: (True, b_rows), 3: (False, p_rows), 4: (True, b_rows),
        })
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "B", "P", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P/B/P")

    frames = h.decode_planes(ffmpeg, out, 5)
    iframe, b0frame, p1frame, b1frame, p2frame = frames

    def verify_b(fwd_ref, bwd_ref, bframe, label):
        expected = h.blank_frame()
        residual_mask = bytearray(len(expected))
        for r in range(h.MB_HEIGHT):
            for c in range(h.MB_WIDTH):
                fv, bv, cbp, coeffs = b_specs[r][c]
                scale = h.quantiser_scale(SLICE_QSCALE)
                if fv is not None and bv is not None:
                    h.apply_macroblock(expected, r, c, fwd_ref, fv, bwd_ref=bwd_ref, bwd_vec=bv, cbp=cbp, coeffs_per_block=coeffs, scale=scale)
                elif fv is not None:
                    h.apply_macroblock(expected, r, c, fwd_ref, fv, cbp=cbp, coeffs_per_block=coeffs, scale=scale)
                else:
                    h.apply_macroblock(expected, r, c, bwd_ref, bv, cbp=cbp, coeffs_per_block=coeffs, scale=scale)
                h.mark_residual(residual_mask, r, c, cbp)
        problem = h.compare_frames(bytes(expected), bframe, bytes(residual_mask))
        if problem:
            raise SystemExit(f"verification failed ({label}): {problem}")

    verify_b(iframe, p1frame, b0frame, "B0")
    verify_b(p1frame, p2frame, b1frame, "B1")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("coded order: I P B P B; display order: I B P B P")
    print(f"row {ROW_FWD}: forward-only, all four half-sample phases")
    print(f"row {ROW_BWD}: backward-only, all four half-sample phases")
    print(f"row {ROW_BIDIR}: bidirectional, independently-phased fwd/bwd")
    print(f"row {ROW_RESIDUAL}: bidirectional + full CBP coverage {sorted(v[0] for v in RESIDUAL_MBS.values())}")
    print(f"row {ROW_MIXED}: forward-only/backward-only/bidirectional mixed in one row (fp/bp independence)")
    print("verification: pixel-exact (motion) / +-1 IDCT tolerance (residual) against FFmpeg decode, both B0 and B1")


if __name__ == "__main__":
    main()
