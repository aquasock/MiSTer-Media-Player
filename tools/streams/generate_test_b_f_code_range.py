#!/usr/bin/env python3
"""Generate a 720x480 B-picture f_code 1..4 regression.

Coded order is I/P/B/P/B.  B0 uses forward (1,2) and backward (3,4);
B1 uses forward (4,3) and backward (2,1), so every admitted value appears
in both B pictures across unequal horizontal/vertical and direction pairs.

Three rows in each B picture prove distinct boundaries:
  row 8  - signed components, nonzero residual bits, then predictor reuse;
  row 14 - forward-only, backward-only, then bidirectional predictor reuse;
  row 20 - all four component predictors cross their signed wrap boundary.

All other macroblocks use bidirectional zero motion.  Both decoded B frames
are checked pixel-exact against the shared software prediction model.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
ROW_COMPONENTS = 8
ROW_INDEPENDENT = 14
ROW_WRAP = 20

# coded picture index -> (forward H/V, backward H/V)
F_CODES = {
    2: ((1, 2), (3, 4)),
    4: ((4, 3), (2, 1)),
}


def emit_mb(bits: str, fp: list[int], bp: list[int], fwd_vec, bwd_vec,
            forward_f_code: tuple[int, int],
            backward_f_code: tuple[int, int]) -> str:
    if fwd_vec is not None and bwd_vec is not None:
        bits += h.BTYPE[(3, 0)]
    elif fwd_vec is not None:
        bits += h.BTYPE[(1, 0)]
    elif bwd_vec is not None:
        bits += h.BTYPE[(2, 0)]
    else:
        raise ValueError("B macroblock needs a prediction direction")

    if fwd_vec is not None:
        bits += h.enc_comp(fwd_vec[0], fp[0], forward_f_code[0])
        bits += h.enc_comp(fwd_vec[1], fp[1], forward_f_code[1])
        fp[:] = fwd_vec
    if bwd_vec is not None:
        bits += h.enc_comp(bwd_vec[0], bp[0], backward_f_code[0])
        bits += h.enc_comp(bwd_vec[1], bp[1], backward_f_code[1])
        bp[:] = bwd_vec
    return bits


def feature_vectors(pic_index: int):
    if pic_index == 2:
        signed_fwd, signed_bwd = (5, 2), (3, -6)
        independent_fwd, independent_bwd = (-7, 5), (9, -11)
        wrap_first = ((15, 31), (63, 127))
        wrap_second = ((-15, -31), (-63, -127))
    elif pic_index == 4:
        signed_fwd, signed_bwd = (-6, 3), (2, -5)
        independent_fwd, independent_bwd = (11, -9), (-13, 7)
        wrap_first = ((-128, -64), (-32, -16))
        wrap_second = ((127, 63), (31, 15))
    else:
        raise ValueError(pic_index)
    return signed_fwd, signed_bwd, independent_fwd, independent_bwd, wrap_first, wrap_second


def build_picture(pic_index: int):
    forward_f_code, backward_f_code = F_CODES[pic_index]
    signed_fwd, signed_bwd, independent_fwd, independent_bwd, wrap_first, wrap_second = feature_vectors(pic_index)
    payloads = []
    specs = []

    for row in range(h.MB_HEIGHT):
        bits = format(SLICE_QSCALE, "05b") + "0"
        fp, bp = [0, 0], [0, 0]
        row_spec = []
        for col in range(h.MB_WIDTH):
            bits += "1"
            fwd_vec = (0, 0)
            bwd_vec = (0, 0)
            if row == ROW_COMPONENTS and col in (10, 11):
                fwd_vec, bwd_vec = signed_fwd, signed_bwd
            elif row == ROW_INDEPENDENT and col == 15:
                fwd_vec, bwd_vec = independent_fwd, None
            elif row == ROW_INDEPENDENT and col == 16:
                fwd_vec, bwd_vec = None, independent_bwd
            elif row == ROW_INDEPENDENT and col == 17:
                fwd_vec, bwd_vec = independent_fwd, independent_bwd
            elif row == ROW_WRAP and col == 20:
                fwd_vec, bwd_vec = wrap_first
            elif row == ROW_WRAP and col == 21:
                fwd_vec, bwd_vec = wrap_second

            bits = emit_mb(bits, fp, bp, fwd_vec, bwd_vec,
                           forward_f_code, backward_f_code)
            row_spec.append((fwd_vec, bwd_vec))

        payloads.append(h.bits_to_bytes(bits))
        specs.append(row_spec)

    return tuple((payload,) for payload in payloads), specs


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_b_f_code_range.m2v"

    def p_row() -> bytes:
        bits = format(SLICE_QSCALE, "05b") + "0"
        for _ in range(h.MB_WIDTH):
            bits += "1" + h.P_MC_NOT_CODED + "1" + "1"
        return h.bits_to_bytes(bits)

    p_rows = tuple((p_row(),) for _ in range(h.MB_HEIGHT))
    b0_rows, b0_specs = build_picture(2)
    b1_rows, b1_specs = build_picture(4)

    with tempfile.TemporaryDirectory(prefix="mister_h262_bfcode_") as td:
        temp = Path(td)
        raw, skeleton = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=5, gop=12, bframes=1)
        data = h.patch_pictures(
            skeleton.read_bytes(), [1, 2, 3, 2, 3],
            {1: (False, p_rows), 2: (True, b0_rows),
             3: (False, p_rows), 4: (True, b1_rows)},
            forward_f_codes={2: F_CODES[2][0], 4: F_CODES[4][0]},
            backward_f_codes={2: F_CODES[2][1], 4: F_CODES[4][1]},
        )
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "B", "P", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P/B/P")

    iframe, b0frame, p1frame, b1frame, p2frame = h.decode_planes(ffmpeg, out, 5)

    def verify_b(fwd_ref: bytes, bwd_ref: bytes, actual: bytes, specs, label: str) -> None:
        expected = h.blank_frame()
        for row in range(h.MB_HEIGHT):
            for col in range(h.MB_WIDTH):
                fwd_vec, bwd_vec = specs[row][col]
                if fwd_vec is not None and bwd_vec is not None:
                    h.apply_macroblock(expected, row, col, fwd_ref, fwd_vec,
                                       bwd_ref=bwd_ref, bwd_vec=bwd_vec)
                elif fwd_vec is not None:
                    h.apply_macroblock(expected, row, col, fwd_ref, fwd_vec)
                else:
                    h.apply_macroblock(expected, row, col, bwd_ref, bwd_vec)
        problem = h.compare_frames(bytes(expected), actual, bytes(len(expected)))
        if problem:
            raise SystemExit(f"verification failed ({label}): {problem}")

    verify_b(iframe, p1frame, b0frame, b0_specs, "B0")
    verify_b(p1frame, p2frame, b1frame, b1_specs, "B1")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 per B picture)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("B0 f_code: forward=(1,2), backward=(3,4)")
    print("B1 f_code: forward=(4,3), backward=(2,1)")
    print("coverage: signed residuals, predictor reuse/independence, four-component wraparound")
    print("verification: both B pictures pixel-exact against the shared reference model")


if __name__ == "__main__":
    main()
