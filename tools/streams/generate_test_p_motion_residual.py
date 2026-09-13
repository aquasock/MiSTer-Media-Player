#!/usr/bin/env python3
"""Generate the 720x480 P forward motion + residual + quantiser regression.

Single P picture, 45x30 macroblocks, referencing the preceding I picture.
Row 3 exercises all four half-sample motion phases (integer, horizontal-half,
vertical-half, both-half) plus a coded macroblock at the last column (44).
Row 8 exercises every validated coded_block_pattern value (single block,
multi-block and all-block) with a mix of DC-only, AC and Escape-coded
coefficients, combined with nonzero motion. Row 15 exercises three
mid-slice quantiser_scale_code changes, each with a residual whose decoded
magnitude depends on the new scale actually taking effect. Every other
macroblock in every row is explicitly re-targeted to (0,0) motion with no
residual, tracking the real motion-vector predictor rather than assuming it
resets on its own, since only a slice start or an address-increment gap
resets the P-picture predictor.

Verified pixel-exact against FFmpeg's decode via h262common's reference
motion-compensation + dequantization/IDCT model.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

MOTION_ROW = 3
MOTION_COLS = {5: (4, 0), 15: (3, 0), 25: (4, -3), 35: (-3, 3), 44: (0, 0)}

RESIDUAL_ROW = 8
# col -> (cbp, {block_index: coeffs})
RESIDUAL_COLS = {
    5: (32, {0: [(0, 7)]}),
    12: (48, {0: [(0, 1), (1, -3), (0, 2)], 1: [(0, -1), (0, 3)]}),
    19: (12, {2: [(0, 1), (7, 1)], 3: [(0, -2)]}),
    26: (21, {1: [(0, -1)], 3: [(0, 2), (1, 1)], 5: [(0, 1)]}),
    33: (3, {4: [(0, 1)], 5: [(0, -3), (0, 1)]}),
    40: (63, {b: [(0, 1 if b % 2 == 0 else -1)] for b in range(6)}),
}
RESIDUAL_VECTOR = (2, 2)

QUANT_ROW = 15
# col -> (quantiser_scale_code, coeffs for a single Y0 residual block)
QUANT_COLS = {10: (5, [(0, 5)]), 25: (15, [(0, 5)]), 38: (25, [(0, 5)])}
SLICE_QSCALE = 10


def build_row(row: int):
    """Returns (payload_bytes, mb_specs) where mb_specs[col] describes the
    decoded macroblock for verification: (vector, cbp, coeffs_per_block, scale)."""
    bits = format(SLICE_QSCALE, "05b") + "0"
    pred = [0, 0]
    scale = h.quantiser_scale(SLICE_QSCALE)
    specs: dict[int, tuple] = {}

    for col in range(h.MB_WIDTH):
        bits += "1"  # macroblock_address_increment = 1 (every macroblock coded)

        if row == MOTION_ROW and col in MOTION_COLS:
            tx, ty = MOTION_COLS[col]
            bits += h.P_MC_NOT_CODED + h.enc_comp(tx, pred[0]) + h.enc_comp(ty, pred[1])
            pred = [tx, ty]
            specs[col] = ((tx, ty), None, None, scale)
        elif row == RESIDUAL_ROW and col in RESIDUAL_COLS:
            cbp, coeffs_per_block = RESIDUAL_COLS[col]
            tx, ty = RESIDUAL_VECTOR
            bits += h.P_MC_CODED + h.enc_comp(tx, pred[0]) + h.enc_comp(ty, pred[1])
            pred = [tx, ty]
            bits += h.CBP_VLC[cbp]
            for block in range(6):
                if cbp & (1 << (5 - block)):
                    bits += h.emit_block(coeffs_per_block[block])
            specs[col] = ((tx, ty), cbp, coeffs_per_block, scale)
        elif row == QUANT_ROW and col in QUANT_COLS:
            code, coeffs = QUANT_COLS[col]
            scale = h.quantiser_scale(code)
            bits += h.P_MC_CODED_QUANT + format(code, "05b")
            bits += h.enc_comp(0, pred[0]) + h.enc_comp(0, pred[1])
            pred = [0, 0]
            bits += h.CBP_VLC[32]
            bits += h.emit_block(coeffs)
            specs[col] = ((0, 0), 32, {0: coeffs}, scale)
        else:
            bits += h.P_MC_NOT_CODED + h.enc_comp(0, pred[0]) + h.enc_comp(0, pred[1])
            pred = [0, 0]
            specs[col] = ((0, 0), None, None, scale)

    return h.bits_to_bytes(bits), specs


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_p_motion_residual.m2v"

    rows_bits = []
    rows_specs = []
    for r in range(h.MB_HEIGHT):
        payload, specs = build_row(r)
        rows_bits.append(payload)
        rows_specs.append(specs)

    with tempfile.TemporaryDirectory(prefix="mister_h262_pmr_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=2, gop=12, bframes=0)
        skeleton_types = h.picture_types(ffprobe, sk)
        if skeleton_types != ["I", "P"]:
            raise SystemExit(f"FFmpeg skeleton picture order changed: {skeleton_types!r}")
        row_groups = tuple((payload,) for payload in rows_bits)
        data = h.patch_pictures(sk.read_bytes(), [1, 2], {1: (False, row_groups)})
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "P"]:
        raise SystemExit("verification failed: picture order is not I/P")

    frames = h.decode_planes(ffmpeg, out, 2)
    iframe, pframe = frames[0], frames[1]

    expected = h.blank_frame()
    residual_mask = bytearray(len(expected))
    for r in range(h.MB_HEIGHT):
        for c in range(h.MB_WIDTH):
            vector, cbp, coeffs_per_block, scale = rows_specs[r][c]
            h.apply_macroblock(expected, r, c, iframe, vector, cbp=cbp, coeffs_per_block=coeffs_per_block, scale=scale)
            h.mark_residual(residual_mask, r, c, cbp)

    problem = h.compare_frames(bytes(expected), pframe, bytes(residual_mask))
    if problem:
        raise SystemExit(f"verification failed: {problem}")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("picture order: I P")
    print(f"row {MOTION_ROW}: half-sample motion phases at columns {sorted(MOTION_COLS)}")
    print(f"row {RESIDUAL_ROW}: CBP coverage {sorted(RESIDUAL_COLS)} -> CBP values {[v[0] for v in RESIDUAL_COLS.values()]}")
    print(f"row {QUANT_ROW}: mid-slice quantiser_scale_code changes at columns {sorted(QUANT_COLS)}")
    print("verification: pixel-exact against FFmpeg decode via h262common reference model")


if __name__ == "__main__":
    main()
