#!/usr/bin/env python3
"""Prove schema-nine telemetry decoding at both supported raster origins."""

from __future__ import annotations

from pathlib import Path
import tempfile

from PIL import Image

import decode_hardware_cadence as cadence


def snapshot_words() -> list[int]:
    words = [cadence.MAGIC, 0x0926EA60]
    words.extend((0x10203040 + index * 0x01010101) & 0xFFFFFFFF
                 for index in range(2, cadence.WORDS - 1))
    checksum = 0
    for word in words:
        checksum ^= word
    words.append(checksum)
    return words


def render(path: Path, width: int, height: int, y_origin: int,
           words: list[int]) -> None:
    image = Image.new("RGB", (width, height), "black")
    pixels = image.load()
    for row, word in enumerate(words):
        bits = list(cadence.ROW_PREFIX)
        bits.extend((row >> bit) & 1 for bit in range(5, -1, -1))
        bits.extend((word >> bit) & 1 for bit in range(31, -1, -1))
        bits.append(word.bit_count() & 1)
        for column, value in enumerate(bits):
            colour = (255, 255, 255) if value else (0, 0, 0)
            x0 = cadence.X0 + column * cadence.CELL
            y0 = y_origin + row * cadence.CELL
            for y in range(y0, y0 + cadence.CELL):
                for x in range(x0, x0 + cadence.CELL):
                    pixels[x, y] = colour
    image.save(path)


def main() -> None:
    expected = snapshot_words()
    with tempfile.TemporaryDirectory(prefix="mister_cadence_decode_") as name:
        temp = Path(name)
        diagnostic = temp / "diagnostic.png"
        native = temp / "native.png"
        render(diagnostic, 800, 600, cadence.DIAGNOSTIC_Y0, expected)
        render(native, 720, 480, cadence.NATIVE_480I_Y0, expected)
        if cadence.decode_words(diagnostic) != expected:
            raise SystemExit("800x600 diagnostic telemetry mismatch")
        if cadence.decode_words(native) != expected:
            raise SystemExit("720x480 native telemetry mismatch")
    print("CADENCE_DECODER_LAYOUT_PASS diagnostic_y=444 native_y=324 words=38")


if __name__ == "__main__":
    main()
