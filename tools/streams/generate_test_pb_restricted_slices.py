#!/usr/bin/env python3
"""Generate the 720x480 restricted same-row P/B slice-partitioning regression.

Coded order I/P/B/P/B (display order I/B/P/B/P), 45x30 macroblocks. Rows 4,
8, 18 and 22 are split into three same-row slices covering columns 0..11,
12..33 and 34..44 on every P and B picture - the second slice therefore
starts with macroblock_address_increment 13 and the third with 35 (one
macroblock_escape + remainder 2), exactly as accepted under H262-025. Every
other row is a single ordinary slice.

Each slice segment starts its own motion-vector predictor fresh (a new
slice is always a predictor-reset point, unlike an in-slice skip); one
macroblock near the middle of every segment carries real motion (and, on
one split row, residual) so the pixel-exact reference model actually
exercises slice-boundary correctness rather than only checking structure -
this is the exact verification gap the retired tools/streams generator for
this feature had (see core-log Commit-175).
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
SPLIT_ROWS = (4, 8, 18, 22)
SEGMENTS = ((0, 11), (12, 33), (34, 44))
RESIDUAL_ROW = 8  # one of the split rows also carries a residual macroblock per segment


def build_p_segment(start: int, end: int, feature_col: int, with_residual: bool):
    bits = ""
    fp = [0, 0]
    prev = -1
    spec = {}
    for col in range(start, end + 1):
        bits += h.enc_mba(col - prev)
        prev = col
        if col == feature_col:
            tx, ty = (3, -2)
            if with_residual:
                bits += h.P_MC_CODED + h.enc_comp(tx, fp[0]) + h.enc_comp(ty, fp[1])
                bits += h.CBP_VLC[32] + h.emit_block([(0, 5)])
                spec[col] = ((tx, ty), 32, {0: [(0, 5)]})
            else:
                bits += h.P_MC_NOT_CODED + h.enc_comp(tx, fp[0]) + h.enc_comp(ty, fp[1])
                spec[col] = ((tx, ty), None, None)
            fp = [tx, ty]
        else:
            bits += h.P_MC_NOT_CODED + h.enc_comp(0, fp[0]) + h.enc_comp(0, fp[1])
            fp = [0, 0]
            spec[col] = ((0, 0), None, None)
    return bits, spec


def build_b_segment(start: int, end: int, feature_col: int, with_residual: bool):
    bits = ""
    fp, bp = [0, 0], [0, 0]
    prev = -1
    spec = {}
    for col in range(start, end + 1):
        bits += h.enc_mba(col - prev)
        prev = col
        if col == feature_col:
            fv, bv = (2, -2), (-3, 2)
            cbp = 32 if with_residual else None
            coeffs = {0: [(0, -4)]} if with_residual else None
            bits += h.BTYPE[(3, 1 if with_residual else 0)]
            bits += h.enc_comp(fv[0], fp[0]) + h.enc_comp(fv[1], fp[1])
            bits += h.enc_comp(bv[0], bp[0]) + h.enc_comp(bv[1], bp[1])
            if with_residual:
                bits += h.CBP_VLC[32] + h.emit_block([(0, -4)])
            fp, bp = list(fv), list(bv)
            spec[col] = (fv, bv, cbp, coeffs)
        else:
            bits += h.BTYPE[(3, 0)] + h.enc_comp(0, fp[0]) + h.enc_comp(0, fp[1]) + h.enc_comp(0, bp[0]) + h.enc_comp(0, bp[1])
            fp, bp = [0, 0], [0, 0]
            spec[col] = ((0, 0), (0, 0), None, None)
    return bits, spec


def plain_p_row():
    bits = format(SLICE_QSCALE, "05b") + "0"
    for _ in range(h.MB_WIDTH):
        bits += "1" + h.P_MC_NOT_CODED + "1" + "1"
    return h.bits_to_bytes(bits), {c: ((0, 0), None, None) for c in range(h.MB_WIDTH)}


def plain_b_row():
    bits = format(SLICE_QSCALE, "05b") + "0"
    for _ in range(h.MB_WIDTH):
        bits += "1" + h.BTYPE[(3, 0)] + "1" * 4
    return h.bits_to_bytes(bits), {c: ((0, 0), (0, 0), None, None) for c in range(h.MB_WIDTH)}


def split_p_row(row: int):
    header = format(SLICE_QSCALE, "05b") + "0"
    payloads = []
    spec = {}
    for start, end in SEGMENTS:
        feature_col = (start + end) // 2
        body, seg_spec = build_p_segment(start, end, feature_col, with_residual=(row == RESIDUAL_ROW))
        payloads.append(h.bits_to_bytes(header + body))
        spec.update(seg_spec)
    return tuple(payloads), spec


def split_b_row(row: int):
    header = format(SLICE_QSCALE, "05b") + "0"
    payloads = []
    spec = {}
    for start, end in SEGMENTS:
        feature_col = (start + end) // 2
        body, seg_spec = build_b_segment(start, end, feature_col, with_residual=(row == RESIDUAL_ROW))
        payloads.append(h.bits_to_bytes(header + body))
        spec.update(seg_spec)
    return tuple(payloads), spec


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_pb_restricted_slices.m2v"

    p_groups, p_specs = [], []
    b_groups, b_specs = [], []
    for r in range(h.MB_HEIGHT):
        if r in SPLIT_ROWS:
            pg, ps = split_p_row(r)
            bg, bs = split_b_row(r)
        else:
            single_p, ps = plain_p_row()
            single_b, bs = plain_b_row()
            pg, bg = (single_p,), (single_b,)
        p_groups.append(pg)
        p_specs.append(ps)
        b_groups.append(bg)
        b_specs.append(bs)

    with tempfile.TemporaryDirectory(prefix="mister_h262_pbslices_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=5, gop=12, bframes=1)
        if [t for _, t in h.pictures(sk.read_bytes())] != [1, 2, 3, 2, 3]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        data = h.patch_pictures(sk.read_bytes(), [1, 2, 3, 2, 3], {
            1: (False, tuple(p_groups)), 2: (True, tuple(b_groups)),
            3: (False, tuple(p_groups)), 4: (True, tuple(b_groups)),
        })
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "B", "P", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P/B/P")

    # confirm the split-slice layout actually landed as three same-row slices
    data = out.read_bytes()
    codes = h.start_codes(data)
    pics = h.pictures(data)
    for pi in (1, 2, 3, 4):
        po = pics[pi][0]
        pe = pics[pi + 1][0] if pi + 1 < len(pics) else len(data)
        got = [c for o, c in codes if po < o < pe and 1 <= c <= h.MB_HEIGHT]
        expected = []
        for r in range(h.MB_HEIGHT):
            expected.extend([r + 1] * (3 if r in SPLIT_ROWS else 1))
        if got != expected:
            raise SystemExit(f"verification failed: picture {pi} slice layout mismatch")

    frames = h.decode_planes(ffmpeg, out, 5)
    iframe, b0frame, p1frame, b1frame, p2frame = frames

    def verify_p(specs, ref, pframe, label):
        expected = h.blank_frame()
        residual_mask = bytearray(len(expected))
        for r in range(h.MB_HEIGHT):
            for c in range(h.MB_WIDTH):
                vec, cbp, coeffs = specs[r][c]
                h.apply_macroblock(expected, r, c, ref, vec, cbp=cbp, coeffs_per_block=coeffs, scale=h.quantiser_scale(SLICE_QSCALE))
                h.mark_residual(residual_mask, r, c, cbp)
        problem = h.compare_frames(bytes(expected), pframe, bytes(residual_mask))
        if problem:
            raise SystemExit(f"verification failed ({label}): {problem}")

    def verify_b(specs, fwd_ref, bwd_ref, bframe, label):
        expected = h.blank_frame()
        residual_mask = bytearray(len(expected))
        for r in range(h.MB_HEIGHT):
            for c in range(h.MB_WIDTH):
                fv, bv, cbp, coeffs = specs[r][c]
                h.apply_macroblock(expected, r, c, fwd_ref, fv, bwd_ref=bwd_ref, bwd_vec=bv, cbp=cbp, coeffs_per_block=coeffs, scale=h.quantiser_scale(SLICE_QSCALE))
                h.mark_residual(residual_mask, r, c, cbp)
        problem = h.compare_frames(bytes(expected), bframe, bytes(residual_mask))
        if problem:
            raise SystemExit(f"verification failed ({label}): {problem}")

    verify_p(p_specs, iframe, p1frame, "P1")
    verify_p(p_specs, p1frame, p2frame, "P2")
    verify_b(b_specs, iframe, p1frame, b0frame, "B0")
    verify_b(b_specs, p1frame, p2frame, b1frame, "B1")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("coded order: I P B P B; display order: I B P B P")
    print(f"split rows (0-based): {SPLIT_ROWS}; three same-row slices each: {SEGMENTS}")
    print("second/third slice first MBA values: 13, 35 (macroblock_escape + 2)")
    print(f"row {RESIDUAL_ROW} additionally carries a residual macroblock in every segment")
    print("verification: pixel-exact (motion) / +-1 IDCT tolerance (residual) against FFmpeg decode, all four P/B pictures")


if __name__ == "__main__":
    main()
