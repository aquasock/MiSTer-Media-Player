#!/usr/bin/env python3
"""Generate the 720x480 generalized-P f_code 1..4 regression.

The stream is I followed by four consecutive P pictures.  Their independently
signalled (horizontal, vertical) f_code pairs are (1,2), (2,3), (3,4), and
(4,1), covering every admitted value in both component positions without
assuming the fields are equal.  Four interior macroblocks per picture exercise
non-zero motion residuals, positive and negative vectors, predictor reuse, and
both directions of component wraparound.  Every other macroblock explicitly
returns to zero motion.

Each P is verified pixel-exact against FFmpeg using the preceding decoded P as
its reference, so the regression also retains consecutive-reference coverage.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
F_CODE_PAIRS = ((1, 2), (2, 3), (3, 4), (4, 1))
FEATURE_ROW = 15
FEATURE_COLS = (18, 19, 20, 21)


def component_limits(f_code: int) -> tuple[int, int, int]:
    f = 1 << (f_code - 1)
    return f, -16 * f, 16 * f - 1


def feature_vectors(f_code_h: int, f_code_v: int) -> dict[int, tuple[int, int]]:
    fh, low_h, high_h = component_limits(f_code_h)
    fv, low_v, high_v = component_limits(f_code_v)
    return {
        FEATURE_COLS[0]: (fh + 2, -(fv + 2)),
        FEATURE_COLS[1]: (high_h, low_v),
        FEATURE_COLS[2]: (low_h, high_v),
        FEATURE_COLS[3]: (0, 0),
    }


def build_row(row: int, f_code_h: int, f_code_v: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    pred = [0, 0]
    specs: dict[int, tuple[int, int]] = {}
    vectors = feature_vectors(f_code_h, f_code_v) if row == FEATURE_ROW else {}

    for col in range(h.MB_WIDTH):
        bits += "1"  # macroblock_address_increment = 1
        vx, vy = vectors.get(col, (0, 0))
        bits += h.P_MC_NOT_CODED
        bits += h.enc_comp(vx, pred[0], f_code_h)
        bits += h.enc_comp(vy, pred[1], f_code_v)
        pred = [vx, vy]
        specs[col] = (vx, vy)

    return h.bits_to_bytes(bits), specs


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_p_f_code_range.m2v"

    generations = []
    for f_code_h, f_code_v in F_CODE_PAIRS:
        row_payloads, row_specs = [], []
        for row in range(h.MB_HEIGHT):
            payload, specs = build_row(row, f_code_h, f_code_v)
            row_payloads.append(payload)
            row_specs.append(specs)
        generations.append((tuple((payload,) for payload in row_payloads), row_specs))

    frame_count = len(F_CODE_PAIRS) + 1
    with tempfile.TemporaryDirectory(prefix="mister_h262_fcode_") as td:
        temp = Path(td)
        raw, skeleton = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=frame_count,
                        gop=frame_count + 1, bframes=0)
        expected_types = ["I"] + ["P"] * len(F_CODE_PAIRS)
        if h.picture_types(ffprobe, skeleton) != expected_types:
            raise SystemExit("FFmpeg skeleton picture order changed")

        specs = {index + 1: (False, generations[index][0])
                 for index in range(len(F_CODE_PAIRS))}
        f_codes = {index + 1: pair for index, pair in enumerate(F_CODE_PAIRS)}
        data = h.patch_pictures(skeleton.read_bytes(),
                                [1] + [2] * len(F_CODE_PAIRS), specs,
                                forward_f_codes=f_codes)
        out.write_bytes(data)

    expected_types = ["I"] + ["P"] * len(F_CODE_PAIRS)
    if h.picture_types(ffprobe, out) != expected_types:
        raise SystemExit("verification failed: picture order changed after patching")

    frames = h.decode_planes(ffmpeg, out, frame_count)
    reference = frames[0]
    for generation, pair in enumerate(F_CODE_PAIRS):
        expected = h.blank_frame()
        row_specs = generations[generation][1]
        for row in range(h.MB_HEIGHT):
            for col in range(h.MB_WIDTH):
                h.apply_macroblock(expected, row, col, reference,
                                   row_specs[row][col])
        actual = frames[generation + 1]
        if bytes(expected) != actual:
            mismatches = sum(a != b for a, b in zip(expected, actual))
            first = next(i for i, (a, b) in enumerate(zip(expected, actual))
                         if a != b)
            raise SystemExit(
                f"verification failed for P{generation + 1} f_code={pair}: "
                f"{mismatches} mismatches, first at byte {first}")
        reference = actual

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"picture order: I + {len(F_CODE_PAIRS)} consecutive P pictures")
    print(f"forward f_code pairs: {F_CODE_PAIRS}")
    print(f"feature macroblocks: row {FEATURE_ROW}, columns {FEATURE_COLS}")
    print("coverage: unequal H/V values 1..4, residuals, signs, predictor wrap")
    print("verification: pixel-exact against FFmpeg, chained P by P")


if __name__ == "__main__":
    main()
