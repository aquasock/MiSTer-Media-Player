#!/usr/bin/env python3
"""Decode the always-live decode/display stall probe from a MiSTer PNG.

Unlike tools/decode-hardware-telemetry.py (a one-shot snapshot armed once
after boot and never re-armed), this probe is redrawn from live state every
video frame, so it reflects whatever is happening at the exact moment the
screenshot was taken - including mid-hang. See
rtl/mpeg2_new/mpeg2_h262_live_deadlock_probe.sv for the encoding this mirrors.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2

X0 = 8
Y0 = 616
CELL = 4
COLS = 36  # 4-bit fixed prefix + 32 data bits
ROWS = 2
PREFIX = (1, 0, 1, 0)


def _cell_bit(image, y_origin: int, column: int, row: int) -> int:
    x0 = X0 + column * CELL + 1
    y0 = y_origin + row * CELL + 1
    pixels = image[y0:y0 + 2, x0:x0 + 2]
    return int(int(pixels.sum()) >= 128 * pixels.size)


def decode(path: Path) -> dict:
    image = cv2.imread(str(path))
    if image is None:
        raise SystemExit(f"could not read image: {path}")
    height, width = image.shape[:2]
    if width < X0 + COLS * CELL or height < Y0 + ROWS * CELL:
        raise SystemExit(
            f"image is {width}x{height}; probe requires at least "
            f"{X0 + COLS * CELL}x{Y0 + ROWS * CELL}"
        )

    words = []
    for row in range(ROWS):
        bits = [_cell_bit(image, Y0, column, row) for column in range(COLS)]
        prefix, data = tuple(bits[:4]), bits[4:]
        if prefix != PREFIX:
            raise SystemExit(
                f"row {row} prefix mismatch: got {prefix}, expected {PREFIX} "
                "(wrong screenshot region, or probe not present in this build)"
            )
        word = 0
        for index, bit in enumerate(data):
            word |= bit << index
        words.append(word)

    word0, word1 = words
    return {
        "decode_progress_count": word0 & 0xFFFF,
        "active_frame_bank": (word0 >> 16) & 0x3,
        "display_frame_bank": (word0 >> 18) & 0x3,
        "display_scratch": bool((word0 >> 20) & 0x1),
        "stream_full": bool((word0 >> 21) & 0x1),
        "burst_ready": bool((word0 >> 22) & 0x1),
        "p_destination_ownership_hold": bool((word0 >> 23) & 0x1),
        "b_presentation_hold": bool((word0 >> 24) & 0x1),
        "display_progress_count": word1 & 0xFFFF,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    args = parser.parse_args()
    result = decode(args.image)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
