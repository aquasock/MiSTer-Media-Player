#!/usr/bin/env python3
"""Remove complete B-picture units from an H.262 elementary stream.

All bytes outside B-picture units are copied verbatim.  A picture unit begins
at picture_start_code and ends at the next picture, GOP, sequence-header, or
sequence-end start code.  The tool is deliberately narrow: it requires at
least one B picture, at least one retained I/P picture, and exactly one terminal
sequence_end_code.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path


START_PREFIX = b"\x00\x00\x01"
PICTURE_START = 0x00
SEQUENCE_HEADER = 0xB3
GROUP_START = 0xB8
SEQUENCE_END = 0xB7
BOUNDARIES = {PICTURE_START, SEQUENCE_HEADER, GROUP_START, SEQUENCE_END}
PICTURE_NAMES = {1: "I", 2: "P", 3: "B"}


@dataclass(frozen=True)
class PictureUnit:
    start: int
    end: int
    coding_type: int

    def bytes_from(self, data: bytes) -> bytes:
        return data[self.start:self.end]


def start_codes(data: bytes) -> list[tuple[int, int]]:
    codes: list[tuple[int, int]] = []
    cursor = 0
    while True:
        offset = data.find(START_PREFIX, cursor)
        if offset < 0:
            return codes
        if offset + 3 >= len(data):
            raise ValueError(f"truncated start code at byte {offset}")
        codes.append((offset, data[offset + 3]))
        cursor = offset + 4


def picture_units(data: bytes) -> list[PictureUnit]:
    boundaries = [entry for entry in start_codes(data) if entry[1] in BOUNDARIES]
    units: list[PictureUnit] = []
    for index, (start, code) in enumerate(boundaries):
        if code != PICTURE_START:
            continue
        end = boundaries[index + 1][0] if index + 1 < len(boundaries) else len(data)
        if start + 6 > end:
            raise ValueError(f"truncated picture header at byte {start}")
        coding_type = (data[start + 5] >> 3) & 0x07
        if coding_type not in PICTURE_NAMES:
            raise ValueError(
                f"unsupported picture_coding_type {coding_type} at byte {start}"
            )
        units.append(PictureUnit(start, end, coding_type))
    return units


def count_types(units: list[PictureUnit]) -> dict[str, int]:
    return {
        name: sum(unit.coding_type == coding_type for unit in units)
        for coding_type, name in PICTURE_NAMES.items()
    }


def strip_b_pictures(data: bytes) -> tuple[bytes, list[PictureUnit]]:
    units = picture_units(data)
    removed = [unit for unit in units if unit.coding_type == 3]
    retained = [unit for unit in units if unit.coding_type != 3]
    if not removed:
        raise ValueError("input contains no B pictures")
    if not retained:
        raise ValueError("input contains no I or P pictures")

    chunks: list[bytes] = []
    cursor = 0
    for unit in removed:
        chunks.append(data[cursor:unit.start])
        cursor = unit.end
    chunks.append(data[cursor:])
    output = b"".join(chunks)

    output_units = picture_units(output)
    source_retained_bytes = [unit.bytes_from(data) for unit in retained]
    output_picture_bytes = [unit.bytes_from(output) for unit in output_units]
    if output_picture_bytes != source_retained_bytes:
        raise AssertionError("retained picture units changed during transformation")
    if any(unit.coding_type == 3 for unit in output_units):
        raise AssertionError("output still contains a B picture")
    return output, units


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source_path = args.input.resolve()
    output_path = args.output.resolve()
    if source_path == output_path:
        parser.error("input and output paths must differ")
    if output_path.exists():
        parser.error(f"output already exists: {output_path}")

    source = source_path.read_bytes()
    if source.count(START_PREFIX + bytes([SEQUENCE_END])) != 1:
        raise SystemExit("input must contain exactly one sequence_end_code")
    if not source.endswith(START_PREFIX + bytes([SEQUENCE_END])):
        raise SystemExit("input sequence_end_code must be terminal")

    output, source_units = strip_b_pictures(source)
    output_units = picture_units(output)
    if output.count(START_PREFIX + bytes([SEQUENCE_END])) != 1:
        raise AssertionError("output does not contain exactly one sequence_end_code")
    if not output.endswith(START_PREFIX + bytes([SEQUENCE_END])):
        raise AssertionError("output sequence_end_code is not terminal")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(output)
    report = {
        "input": str(source_path),
        "output": str(output_path),
        "input_bytes": len(source),
        "output_bytes": len(output),
        "input_sha256": hashlib.sha256(source).hexdigest(),
        "output_sha256": hashlib.sha256(output).hexdigest(),
        "input_picture_types": count_types(source_units),
        "output_picture_types": count_types(output_units),
        "removed_b_pictures": sum(unit.coding_type == 3 for unit in source_units),
        "retained_picture_units_byte_exact": True,
        "terminal_sequence_end": True,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
