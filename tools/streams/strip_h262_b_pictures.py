#!/usr/bin/env python3
"""Filter and optionally repeat H.262 elementary-stream picture units.

The default behavior removes complete B-picture units and copies every other
source byte verbatim.  ``--keep-types I`` can instead retain only I pictures,
and ``--repeat-retained`` duplicates each retained picture unit without
changing its bytes.  A picture unit begins at picture_start_code and ends at
the next picture, GOP, sequence-header, or sequence-end start code.  The tool
requires at least one removed picture, at least one retained picture, and
exactly one terminal sequence_end_code.
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


def transform_pictures(
    data: bytes, keep_types: set[int], repeat_retained: int
) -> tuple[bytes, list[PictureUnit]]:
    units = picture_units(data)
    removed = [unit for unit in units if unit.coding_type not in keep_types]
    retained = [unit for unit in units if unit.coding_type in keep_types]
    if not removed:
        raise ValueError("input contains no pictures outside the keep set")
    if not retained:
        raise ValueError("input contains no pictures in the keep set")
    if repeat_retained < 1:
        raise ValueError("repeat_retained must be positive")

    chunks: list[bytes] = []
    cursor = 0
    for unit in units:
        chunks.append(data[cursor:unit.start])
        if unit.coding_type in keep_types:
            chunks.extend([unit.bytes_from(data)] * repeat_retained)
        cursor = unit.end
    chunks.append(data[cursor:])
    output = b"".join(chunks)

    output_units = picture_units(output)
    source_retained_bytes = [
        unit.bytes_from(data)
        for unit in retained
        for _repeat in range(repeat_retained)
    ]
    output_picture_bytes = [unit.bytes_from(output) for unit in output_units]
    if output_picture_bytes != source_retained_bytes:
        raise AssertionError("retained picture units changed during transformation")
    if any(unit.coding_type not in keep_types for unit in output_units):
        raise AssertionError("output contains a picture outside the keep set")
    return output, units


def strip_b_pictures(data: bytes) -> tuple[bytes, list[PictureUnit]]:
    """Preserve the original entry-724 default transformation API."""
    return transform_pictures(data, {1, 2}, 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--keep-types",
        choices=("I", "IP"),
        default="IP",
        help="picture types to retain (default: IP)",
    )
    parser.add_argument(
        "--repeat-retained",
        type=int,
        default=1,
        metavar="COUNT",
        help="repeat each retained picture unit COUNT times (default: 1)",
    )
    args = parser.parse_args()
    if args.repeat_retained < 1:
        parser.error("--repeat-retained must be positive")

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

    keep_types = {
        coding_type
        for coding_type, name in PICTURE_NAMES.items()
        if name in args.keep_types
    }
    try:
        output, source_units = transform_pictures(
            source, keep_types, args.repeat_retained
        )
    except ValueError as error:
        raise SystemExit(str(error)) from None
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
        "keep_types": args.keep_types,
        "repeat_retained": args.repeat_retained,
        "retained_source_picture_types": count_types(
            [unit for unit in source_units if unit.coding_type in keep_types]
        ),
        "removed_picture_types": count_types(
            [unit for unit in source_units if unit.coding_type not in keep_types]
        ),
        "removed_b_pictures": sum(unit.coding_type == 3 for unit in source_units),
        "retained_picture_units_byte_exact": True,
        "terminal_sequence_end": True,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
