#!/usr/bin/env python3
"""Generate a B picture that exceeds the former residual-plan limits.

The authored B picture uses bidirectional zero-vector prediction everywhere.
Macroblock column 20 carries all six residual blocks on rows 5 through 24,
forming a visible vertical stripe while exercising 120 block descriptors and
120 coefficient events.  The former generalized-B limits were 16 and 64.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h


SLICE_QSCALE = 10
STRIPE_COLUMN = 20
FIRST_STRIPE_ROW = 5
LAST_STRIPE_ROW = 24
STRIPE_COEFFS = {block: [(0, 7)] for block in range(6)}


def p_row() -> bytes:
    bits = format(SLICE_QSCALE, "05b") + "0"
    for _ in range(h.MB_WIDTH):
        bits += "1" + h.P_MC_NOT_CODED + "1" + "1"
    return h.bits_to_bytes(bits)


def b_row(row: int) -> bytes:
    bits = format(SLICE_QSCALE, "05b") + "0"
    fp = [0, 0]
    bp = [0, 0]
    for column in range(h.MB_WIDTH):
        bits += "1"
        stripe = (
            FIRST_STRIPE_ROW <= row <= LAST_STRIPE_ROW
            and column == STRIPE_COLUMN
        )
        bits += h.BTYPE[(3, 1 if stripe else 0)]
        bits += h.enc_comp(0, fp[0]) + h.enc_comp(0, fp[1])
        bits += h.enc_comp(0, bp[0]) + h.enc_comp(0, bp[1])
        if stripe:
            bits += h.CBP_VLC[63]
            for block in range(6):
                bits += h.emit_block(STRIPE_COEFFS[block])
    return h.bits_to_bytes(bits)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().with_name(
            "test_b_residual_streaming.m2v"
        ),
    )
    args = parser.parse_args()

    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    p_rows = tuple((p_row(),) for _ in range(h.MB_HEIGHT))
    b_rows = tuple((b_row(row),) for row in range(h.MB_HEIGHT))

    with tempfile.TemporaryDirectory(prefix="mister_h262_bstream_") as td:
        temp = Path(td)
        raw = temp / "source.yuv"
        skeleton = temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=3, gop=12, bframes=1)
        data = skeleton.read_bytes()
        if [picture_type for _, picture_type in h.pictures(data)] != [1, 2, 3]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        output.write_bytes(
            h.patch_pictures(
                data,
                [1, 2, 3],
                {1: (False, p_rows), 2: (True, b_rows)},
            )
        )

    if h.picture_types(ffprobe, output) != ["I", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P")

    iframe, bframe, pframe = h.decode_planes(ffmpeg, output, 3)
    expected = h.blank_frame()
    residual_mask = bytearray(len(expected))
    scale = h.quantiser_scale(SLICE_QSCALE)
    for row in range(h.MB_HEIGHT):
        for column in range(h.MB_WIDTH):
            stripe = (
                FIRST_STRIPE_ROW <= row <= LAST_STRIPE_ROW
                and column == STRIPE_COLUMN
            )
            h.apply_macroblock(
                expected,
                row,
                column,
                iframe,
                (0, 0),
                bwd_ref=pframe,
                bwd_vec=(0, 0),
                cbp=63 if stripe else None,
                coeffs_per_block=STRIPE_COEFFS if stripe else None,
                scale=scale,
            )
            h.mark_residual(residual_mask, row, column, 63 if stripe else None)

    problem = h.compare_frames(bytes(expected), bframe, bytes(residual_mask))
    if problem:
        raise SystemExit(f"verification failed: {problem}")

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"generated: {output}")
    print(f"bytes: {output.stat().st_size}")
    print(f"sha256: {digest}")
    print("coded order: I P B; display order: I B P")
    print("B residual blocks: 120; coefficient events: 120")
    print(
        f"visible stripe: column {STRIPE_COLUMN}, "
        f"rows {FIRST_STRIPE_ROW}..{LAST_STRIPE_ROW}"
    )
    print("verification: pixel-exact motion / +-1 residual tolerance")


if __name__ == "__main__":
    main()
