#!/usr/bin/env python3
"""Prove schema-twelve, schema-eleven, schema-ten and legacy decoding."""

from __future__ import annotations

from pathlib import Path
import tempfile

from PIL import Image

import decode_hardware_cadence as cadence


def snapshot_words() -> list[int]:
    """Schema thirteen: forty-three words ending in the XOR checksum."""
    words = [cadence.MAGIC, 0x0D2BEA60]
    words.extend((0x10203040 + index * 0x01010101) & 0xFFFFFFFF
                 for index in range(2, 37))
    words.extend(((3 << 16) | 2, (1 << 16) | 1, 12345))
    # Entry 518 per-field evidence: a starved first field whose fetches
    # resolved into region 2 while the other parity used region 1, with five
    # mismatching generations and seven sequence phase errors.
    # A starved first field whose returns never varied, against a second
    # field that did, plus differing regions, five mismatches, seven phase
    # errors and distinct per-parity content signatures.
    words.extend((((17 << 24) | (240 << 16) | (0 << 15) | (1 << 14) |
                   (2 << 3) | 1),
                  ((0xA5 << 24) | (0x3C << 16) | (5 << 8) | 7)))
    checksum = 0
    for word in words:
        checksum ^= word
    words.append(checksum)
    return words


def schema10_snapshot_words() -> list[int]:
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
        if parsed["schema_version"] != 13:
            raise SystemExit("schema thirteen was not reported")
        if parsed["framebuffer_first_field_varied"] is not False:
            raise SystemExit("first-field varied flag was not decoded")
        if parsed["framebuffer_second_field_varied"] is not True:
            raise SystemExit("second-field varied flag was not decoded")
        if parsed["framebuffer_first_field_signature"] != 0xA5:
            raise SystemExit("first-field signature was not decoded")
        if parsed["framebuffer_second_field_signature"] != 0x3C:
            raise SystemExit("second-field signature was not decoded")
        if parsed["framebuffer_last_first_field_fetches"] != 17:
            raise SystemExit("first-field DDR fetches were not decoded")
        if parsed["framebuffer_last_second_field_fetches"] != 240:
            raise SystemExit("second-field DDR fetches were not decoded")
        if parsed["framebuffer_last_first_field_region"] != 2:
            raise SystemExit("first-field DDR region was not decoded")
        if parsed["framebuffer_last_second_field_region"] != 1:
            raise SystemExit("second-field DDR region was not decoded")
        if parsed["framebuffer_field_region_mismatch_count"] != 5:
            raise SystemExit("region mismatch count was not decoded")
        if parsed["framebuffer_last_first_field_lines"] is not None:
            raise SystemExit("schema twelve must not report displayed lines")
        if parsed["framebuffer_sequence_phase_error_count"] != 7:
            raise SystemExit("sequence phase error count was not decoded")

        schema10 = schema10_snapshot_words()
        schema10_diagnostic = temp / "schema10_diagnostic.png"
        schema10_native = temp / "schema10_native.png"
        render(schema10_diagnostic, 800, 600,
               cadence.SCHEMA10_DIAGNOSTIC_Y0, schema10)
        render(schema10_native, 720, 480,
               cadence.SCHEMA10_NATIVE_480I_Y0, schema10)
        if cadence.decode_words(schema10_diagnostic) != schema10:
            raise SystemExit("schema-ten diagnostic telemetry mismatch")
        if cadence.decode_words(schema10_native) != schema10:
            raise SystemExit("schema-ten native telemetry mismatch")
        schema10_parsed = cadence.decode(schema10_native)
        if schema10_parsed["schema_version"] != 10:
            raise SystemExit("schema ten was not reported")
        if schema10_parsed["framebuffer_last_first_field_lines"] is not None:
            raise SystemExit("schema ten must not report per-field evidence")

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
    print("CADENCE_DECODER_LAYOUT_PASS schema13=428/308/43 "
          "schema10=436/316/41 legacy=444/324/38")


if __name__ == "__main__":
    main()
