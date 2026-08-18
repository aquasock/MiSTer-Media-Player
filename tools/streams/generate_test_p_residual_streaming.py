#!/usr/bin/env python3
"""Generate a P picture exceeding the former residual-plan limits.

The authored P picture contains one DC-only intra macroblock in each of rows
5 through 24 at column 20.  Its 20 intra macroblocks produce 120 transformed
blocks and 120 coefficient events, deliberately crossing the retired
16-block/32-event flattened-plan boundary while remaining easy to identify on
MiSTer as a vertical constant-colour stripe.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import generate_test_p_intra_macroblocks as pintra
import h262common as h


FIRST_INTRA_ROW = 5
LAST_INTRA_ROW = 24
INTRA_COL = 20
INTRA_COUNT = LAST_INTRA_ROW - FIRST_INTRA_ROW + 1


def p_row(row: int) -> bytes:
    bits = format(pintra.SLICE_QSCALE, "05b") + "0"
    predictor = (0, 0)
    for col in range(h.MB_WIDTH):
        bits += h.enc_mba(1)
        if FIRST_INTRA_ROW <= row <= LAST_INTRA_ROW and col == INTRA_COL:
            bits += pintra.P_INTRA + pintra.intra_blocks()
            predictor = (0, 0)
        else:
            bits += h.P_MC_NOT_CODED
            bits += h.enc_comp(0, predictor[0]) + h.enc_comp(0, predictor[1])
            predictor = (0, 0)
    return h.bits_to_bytes(bits)


def verify_frame(iframe: bytes, pframe: bytes) -> None:
    expected = bytearray(iframe)
    mask = bytearray(len(expected))
    for mb_row in range(FIRST_INTRA_ROW, LAST_INTRA_ROW + 1):
        for block in range(6):
            if block < 4:
                x0 = INTRA_COL * 16 + (block & 1) * 8
                y0 = mb_row * 16 + ((block >> 1) & 1) * 8
                value = pintra.Y_VALUE
                stride = h.WIDTH
                base = 0
            else:
                x0 = INTRA_COL * 8
                y0 = mb_row * 8
                value = pintra.CB_VALUE if block == 4 else pintra.CR_VALUE
                stride = h.CW
                base = h.Y_SIZE if block == 4 else h.Y_SIZE + h.C_SIZE
            for yy in range(8):
                start = base + (y0 + yy) * stride + x0
                expected[start:start + 8] = bytes([value]) * 8
                mask[start:start + 8] = b"\x01" * 8
    problem = h.compare_frames(bytes(expected), pframe, bytes(mask))
    if problem:
        raise SystemExit(f"verification failed: {problem}")


def generate(output: Path) -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = tuple((p_row(row),) for row in range(h.MB_HEIGHT))

    with tempfile.TemporaryDirectory(prefix="mister_h262_pstream_") as directory:
        temp = Path(directory)
        raw = temp / "source.yuv"
        skeleton = temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=2, gop=12, bframes=0)
        if [kind for _, kind in h.pictures(skeleton.read_bytes())] != [1, 2]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        data = h.patch_pictures(skeleton.read_bytes(), [1, 2], {1: (False, rows)})
        output.write_bytes(data)

    if h.picture_types(ffprobe, output) != ["I", "P"]:
        raise SystemExit("verification failed: display order is not I/P")
    iframe, pframe = h.decode_planes(ffmpeg, output, 2)
    verify_frame(iframe, pframe)

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"generated: {output}")
    print(f"bytes: {output.stat().st_size}")
    print(f"sha256: {digest}")
    print(
        f"intra macroblocks: rows={FIRST_INTRA_ROW}..{LAST_INTRA_ROW} "
        f"column={INTRA_COL} count={INTRA_COUNT}"
    )
    print("expected RTL metadata: 1350 macroblocks, 120 intra blocks, 120 DC events")
    print("verification: reference-exact outside stripe; intra Y/Cb/Cr within +/-1 IDCT LSB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().with_name("test_p_residual_streaming.m2v"),
    )
    args = parser.parse_args()
    generate(args.output.resolve())


if __name__ == "__main__":
    main()
