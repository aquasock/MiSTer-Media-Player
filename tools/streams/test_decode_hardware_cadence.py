#!/usr/bin/env python3
"""Prove schema-ten and legacy schema-nine telemetry raster decoding."""

from __future__ import annotations

from pathlib import Path
import tempfile

from PIL import Image

import decode_hardware_cadence as cadence


def snapshot_words() -> list[int]:
    words = [cadence.MAGIC, 0x0A29EA60]
    words.extend((0x10203040 + index * 0x01010101) & 0xFFFFFFFF
                 for index in range(2, 37))
    words.extend(((3 << 16) | 2, (1 << 16) | 1, 12345))
    checksum = 0
    for word in words:
        checksum ^= word
    words.append(checksum)
    return words


def legacy_snapshot_words() -> list[int]:
    words = [cadence.MAGIC, 0x0926EA60]
    words.extend((0x20304050 + index * 0x01010101) & 0xFFFFFFFF
                 for index in range(2, 37))
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
        overlap = temp / "native_overlap.png"
        legacy_diagnostic = temp / "legacy_diagnostic.png"
        legacy_native = temp / "legacy_native.png"
        render(diagnostic, 800, 600, cadence.DIAGNOSTIC_Y0, expected)
        render(native, 720, 480, cadence.NATIVE_480I_Y0, expected)
        if cadence.decode_words(diagnostic) != expected:
            raise SystemExit("800x600 diagnostic telemetry mismatch")
        if cadence.decode_words(native) != expected:
            raise SystemExit("720x480 native telemetry mismatch")
        parsed = cadence.decode(native)
        if parsed["framebuffer_reset_count"] != 3:
            raise SystemExit("framebuffer reset count was not decoded")
        if parsed["framebuffer_publication_count"] != 2:
            raise SystemExit("framebuffer publication count was not decoded")
        if parsed["framebuffer_unpublished_reset_count"] != 1:
            raise SystemExit("unpublished framebuffer reset was not decoded")
        if parsed["framebuffer_prefill_miss_count"] != 1:
            raise SystemExit("framebuffer prefill miss was not decoded")
        if parsed["framebuffer_max_publication_latency_cycles"] != 12345:
            raise SystemExit("framebuffer publication latency was not decoded")

        legacy = legacy_snapshot_words()
        render(legacy_diagnostic, 800, 600,
               cadence.LEGACY_DIAGNOSTIC_Y0, legacy)
        render(legacy_native, 720, 480,
               cadence.LEGACY_NATIVE_480I_Y0, legacy)
        if cadence.decode_words(legacy_diagnostic) != legacy:
            raise SystemExit("legacy diagnostic telemetry mismatch")
        if cadence.decode_words(legacy_native) != legacy:
            raise SystemExit("legacy native telemetry mismatch")

        overlap_words = expected.copy()
        overlap_words[19] |= 1 << 28
        checksum = 0
        for word in overlap_words[:-1]:
            checksum ^= word
        overlap_words[-1] = checksum
        render(overlap, 720, 480, cadence.NATIVE_480I_Y0, overlap_words)
        result = cadence.decode(overlap)
        if not result["cache_bank_overlap_error"]:
            raise SystemExit("cache-bank overlap telemetry bit was not decoded")
    print("CADENCE_DECODER_LAYOUT_PASS schema10=436/316/41 legacy=444/324/38")


if __name__ == "__main__":
    main()
