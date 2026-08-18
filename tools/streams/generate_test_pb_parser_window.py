#!/usr/bin/env python3
"""Generate a P/B stream whose legal slice header exceeds the parser window.

The first slice of every P and B picture carries 2,000 extra_information_slice
bytes before 45 zero-motion macroblocks.  Its payload therefore crosses the
512-byte RTL parser window without consuming residual descriptors.  All other
slices are ordinary one-row zero-motion slices.  The decoded pictures must stay
pixel-identical to the initial I reference.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h


SLICE_QSCALE = 10
EXTRA_INFORMATION_BYTES = 2000


def header(extra_count: int) -> str:
    return (
        format(SLICE_QSCALE, "05b")
        + ("1" + "00000000") * extra_count
        + "0"
    )


def p_row(extra_count: int = 0) -> bytes:
    bits = header(extra_count)
    for _ in range(h.MB_WIDTH):
        bits += h.enc_mba(1) + h.P_MC_NOT_CODED + h.enc_comp(0, 0) * 2
    return h.bits_to_bytes(bits)


def b_row(extra_count: int = 0) -> bytes:
    bits = header(extra_count)
    for _ in range(h.MB_WIDTH):
        bits += h.enc_mba(1) + h.BTYPE[(3, 0)] + h.enc_comp(0, 0) * 4
    return h.bits_to_bytes(bits)


def generate(out: Path) -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out.parent.mkdir(parents=True, exist_ok=True)

    p_groups = tuple(
        (p_row(EXTRA_INFORMATION_BYTES if row == 0 else 0),)
        for row in range(h.MB_HEIGHT)
    )
    b_groups = tuple(
        (b_row(EXTRA_INFORMATION_BYTES if row == 0 else 0),)
        for row in range(h.MB_HEIGHT)
    )

    with tempfile.TemporaryDirectory(prefix="mister_h262_parser_window_") as td:
        temp = Path(td)
        raw, skeleton = temp / "src.yuv", temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=5, gop=12, bframes=1)
        data = h.patch_pictures(skeleton.read_bytes(), [1, 2, 3, 2, 3], {
            1: (False, p_groups),
            2: (True, b_groups),
            3: (False, p_groups),
            4: (True, b_groups),
        })
        out.write_bytes(data)

    display_order = h.picture_types(ffprobe, out)
    if display_order != ["I", "B", "P", "B", "P"]:
        raise SystemExit(f"unexpected display order: {display_order}")
    frames = h.decode_planes(ffmpeg, out, 5)
    if any(frame != frames[0] for frame in frames[1:]):
        raise SystemExit("zero-motion P/B pictures do not match the initial I reference")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("coded order: I P B P B; display order: I B P B P")
    print(f"extra_information_slice bytes in each first P/B slice: {EXTRA_INFORMATION_BYTES}")
    print(f"authored P payload bytes: {len(p_groups[0][0])}")
    print(f"authored B payload bytes: {len(b_groups[0][0])}")
    print("verification: all four P/B pictures are pixel-identical to the initial I reference")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path,
        default=Path(__file__).resolve().parent / "test_pb_parser_window.m2v",
    )
    args = parser.parse_args()
    generate(args.output.resolve())


if __name__ == "__main__":
    main()
