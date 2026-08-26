#!/usr/bin/env python3
"""Prove the current consolidated and retained legacy telemetry decoding."""

from __future__ import annotations

from pathlib import Path
import tempfile

from PIL import Image

import decode_hardware_cadence as cadence


def schema14_snapshot_words(schema_version: int = 14) -> list[int]:
    """Build a forty-three-word schema 13/14 record with XOR checksum."""
    words = [cadence.MAGIC,
             (schema_version << 24) | (43 << 16) | 60000]
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


def schema15_snapshot_words() -> list[int]:
    """Build a forty-eight-word schema 15 record with XOR checksum."""
    words = schema14_snapshot_words()[:-1]
    words[1] = (15 << 24) | (48 << 16) | 60000
    words.extend((0x12345678, 0x12345678,
                  0x89ABCDEF, 0x89ABCDEE,
                  (44 << 24) | (44 << 16) | (0 << 8) | 7))
    checksum = 0
    for word in words:
        checksum ^= word
    words.append(checksum)
    return words


def snapshot_words() -> list[int]:
    """Build a sixty-one-word current diagnostic record with XOR checksum."""
    words = schema15_snapshot_words()[:-1]
    words[1] = (16 << 24) | (61 << 16) | 60000
    # Entry 531 marks the current layout and replaces the historical whole-
    # field cache pair with accepted-write/raw-DDR-return evidence.
    words[40] |= (1 << 13) | (1 << 12) | (1 << 11) | (4 << 8)
    words[42:47] = [
        0x12345678,
        0x12345678,
        0x89ABCDEF,
        0x89ABCDEF,
        (44 << 24) | (44 << 16),
    ]
    words.extend((
        (1 << 24) | (2 << 16) | (3 << 8) | 4,
        (12 << 21) | (14 << 10) | (0 << 9) | (1 << 8),
        (0x2A << 24) | (0x29 << 16),
        (13 << 21) | (15 << 10) | (1 << 9) | (0 << 8),
        (0x2A << 24) | (0x28 << 16),
        (20 << 21) | (20 << 10),
        (0x2A << 24) | (0x2A << 16),
        0x11111111,
        0x11111110,
        (21 << 21) | (21 << 10),
        (0x2A << 24) | (0x2A << 16),
        0x22222222,
        0x22222220,
    ))
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
        if parsed["schema_version"] != 16:
            raise SystemExit("schema sixteen was not reported")
        if parsed["framebuffer_content_scope"] != "session":
            raise SystemExit("schema fourteen content scope was not decoded")
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
        if parsed["framebuffer_write_read_scope"] != \
                "accepted_luma_write_to_raw_ddr_return":
            raise SystemExit("current write/read scope was not decoded")
        if not parsed["framebuffer_write_read_first_expected_valid"] or \
                not parsed["framebuffer_write_read_second_expected_valid"]:
            raise SystemExit("write/read expected validity was not decoded")
        if parsed["framebuffer_write_read_region"] != 4:
            raise SystemExit("write/read physical region was not decoded")
        if parsed["framebuffer_write_read_first_expected_fingerprint"] != \
                0x12345678 or \
                parsed["framebuffer_write_read_first_raw_fingerprint"] != \
                0x12345678:
            raise SystemExit("first-field write/read pair was not decoded")
        if parsed["framebuffer_write_read_second_expected_fingerprint"] != \
                0x89ABCDEF or \
                parsed["framebuffer_write_read_second_raw_fingerprint"] != \
                0x89ABCDEF:
            raise SystemExit("second-field write/read pair was not decoded")
        if parsed["framebuffer_write_read_first_count"] != 44 or \
                parsed["framebuffer_write_read_second_count"] != 44:
            raise SystemExit("write/read completion counts were not decoded")
        if parsed["framebuffer_write_read_first_mismatch_count"] != 0 or \
                parsed["framebuffer_write_read_second_mismatch_count"] != 0:
            raise SystemExit("write/read mismatch counts were not decoded")
        if parsed["framebuffer_last_first_field_raw_fingerprint"] is not None:
            raise SystemExit("current layout exposed a retired cache aggregate")
        if parsed["framebuffer_first_field_tag_mismatch_count"] != 1:
            raise SystemExit("first-field tag mismatch count was not decoded")
        if parsed["framebuffer_second_field_tag_mismatch_count"] != 2:
            raise SystemExit("second-field tag mismatch count was not decoded")
        if parsed["framebuffer_first_field_content_mismatch_count"] != 3:
            raise SystemExit("first-field content mismatch count was not decoded")
        if parsed["framebuffer_second_field_content_mismatch_count"] != 4:
            raise SystemExit("second-field content mismatch count was not decoded")
        first_tag = parsed["framebuffer_first_field_first_tag_mismatch"]
        if first_tag is None or first_tag["expected_row"] != 12 or \
                first_tag["tagged_row"] != 14 or \
                first_tag["expected_bank"] != 0 or \
                first_tag["tagged_bank"] != 1 or \
                first_tag["expected_generation"] != 0x2A or \
                first_tag["tagged_generation"] != 0x29:
            raise SystemExit("first-field tag mismatch evidence was not decoded")
        second_content = parsed[
            "framebuffer_second_field_first_content_mismatch"
        ]
        if second_content is None or second_content["expected_row"] != 21 or \
                second_content["tagged_row"] != 21 or \
                second_content["raw_fingerprint"] != 0x22222222 or \
                second_content["display_fingerprint"] != 0x22222220:
            raise SystemExit(
                "second-field content mismatch evidence was not decoded"
            )

        schema15 = schema15_snapshot_words()
        schema15_diagnostic = temp / "schema15_diagnostic.png"
        schema15_native = temp / "schema15_native.png"
        render(schema15_diagnostic, 800, 600,
               cadence.SCHEMA15_DIAGNOSTIC_Y0, schema15)
        render(schema15_native, 720, 480,
               cadence.SCHEMA15_NATIVE_480I_Y0, schema15)
        if cadence.decode_words(schema15_diagnostic) != schema15:
            raise SystemExit("schema-fifteen diagnostic telemetry mismatch")
        schema15_parsed = cadence.decode(schema15_native)
        if schema15_parsed["schema_version"] != 15:
            raise SystemExit("schema fifteen was not retained")
        if schema15_parsed["framebuffer_first_field_tag_mismatch_count"] is not None:
            raise SystemExit("schema fifteen must not report line provenance")

        schema14 = schema14_snapshot_words()
        schema14_diagnostic = temp / "schema14_diagnostic.png"
        schema14_native = temp / "schema14_native.png"
        render(schema14_diagnostic, 800, 600,
               cadence.SCHEMA14_DIAGNOSTIC_Y0, schema14)
        render(schema14_native, 720, 480,
               cadence.SCHEMA14_NATIVE_480I_Y0, schema14)
        if cadence.decode_words(schema14_diagnostic) != schema14:
            raise SystemExit("schema-fourteen diagnostic telemetry mismatch")
        schema14_parsed = cadence.decode(schema14_native)
        if schema14_parsed["schema_version"] != 14:
            raise SystemExit("schema fourteen was not retained")
        if schema14_parsed["framebuffer_last_first_field_raw_fingerprint"] is not None:
            raise SystemExit("schema fourteen must not report fingerprints")

        schema13 = schema14_snapshot_words(13)
        schema13_native = temp / "schema13_native.png"
        render(schema13_native, 720, 480,
               cadence.SCHEMA14_NATIVE_480I_Y0, schema13)
        schema13_parsed = cadence.decode(schema13_native)
        if schema13_parsed["schema_version"] != 13:
            raise SystemExit("schema thirteen was not reported")
        if schema13_parsed["framebuffer_content_scope"] != "last_generation":
            raise SystemExit("schema thirteen content scope was not retained")
        if schema13_parsed["framebuffer_first_field_signature"] != 0xA5:
            raise SystemExit("schema thirteen field content was not retained")

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
    print("CADENCE_DECODER_LAYOUT_PASS current=356/236/61 "
          "retained=48,43,41,38-words")


if __name__ == "__main__":
    main()
