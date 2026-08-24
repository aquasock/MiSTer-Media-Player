#!/usr/bin/env python3
"""Report the H.262 structure relevant to the active compatibility work.

This is deliberately a syntax inventory, not a second decoder.  It identifies
the admitted progressive 4:2:0 frontend envelope, the bounded native-interlaced
I-frame candidate envelope, picture order, slice layout, and payload pressure
before a stream is placed on MiSTer hardware.  Macroblock semantics remain the
responsibility of the RTL and the software reference decoder used by the
individual deterministic generators.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any


PICTURE_NAMES = {1: "I", 2: "P", 3: "B", 4: "D"}


def read_bits(payload: bytes, start: int, count: int) -> int:
    if start + count > len(payload) * 8:
        raise ValueError("truncated extension payload")
    value = 0
    for bit in range(start, start + count):
        value = (value << 1) | ((payload[bit // 8] >> (7 - bit % 8)) & 1)
    return value


def start_codes(data: bytes) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    cursor = 0
    while True:
        offset = data.find(b"\x00\x00\x01", cursor)
        if offset < 0:
            return result
        if offset + 3 < len(data):
            result.append((offset, data[offset + 3]))
        cursor = offset + 4


def payload_between(data: bytes, codes: list[tuple[int, int]], index: int) -> bytes:
    begin = codes[index][0] + 4
    end = codes[index + 1][0] if index + 1 < len(codes) else len(data)
    return data[begin:end]


def parse_sequence_header(payload: bytes) -> dict[str, int]:
    return {
        "horizontal_size": read_bits(payload, 0, 12),
        "vertical_size": read_bits(payload, 12, 12),
        "aspect_ratio_information": read_bits(payload, 24, 4),
        "frame_rate_code": read_bits(payload, 28, 4),
    }


def parse_sequence_extension(payload: bytes) -> dict[str, int | bool]:
    return {
        "profile_and_level_indication": read_bits(payload, 4, 8),
        "progressive_sequence": bool(read_bits(payload, 12, 1)),
        "chroma_format": read_bits(payload, 13, 2),
        "horizontal_size_extension": read_bits(payload, 15, 2),
        "vertical_size_extension": read_bits(payload, 17, 2),
        "low_delay": bool(read_bits(payload, 40, 1)),
    }


def parse_picture_header(payload: bytes) -> dict[str, int | str]:
    coding_type = read_bits(payload, 10, 3)
    return {
        "temporal_reference": read_bits(payload, 0, 10),
        "coding_type": coding_type,
        "type": PICTURE_NAMES.get(coding_type, f"reserved-{coding_type}"),
    }


def parse_picture_coding_extension(payload: bytes) -> dict[str, int | bool]:
    return {
        "forward_horizontal_f_code": read_bits(payload, 4, 4),
        "forward_vertical_f_code": read_bits(payload, 8, 4),
        "backward_horizontal_f_code": read_bits(payload, 12, 4),
        "backward_vertical_f_code": read_bits(payload, 16, 4),
        "intra_dc_precision": read_bits(payload, 20, 2),
        "picture_structure": read_bits(payload, 22, 2),
        "top_field_first": bool(read_bits(payload, 24, 1)),
        "frame_pred_frame_dct": bool(read_bits(payload, 25, 1)),
        "concealment_motion_vectors": bool(read_bits(payload, 26, 1)),
        "q_scale_type": bool(read_bits(payload, 27, 1)),
        "intra_vlc_format": bool(read_bits(payload, 28, 1)),
        "alternate_scan": bool(read_bits(payload, 29, 1)),
        "repeat_first_field": bool(read_bits(payload, 30, 1)),
        "chroma_420_type": bool(read_bits(payload, 31, 1)),
        "progressive_frame": bool(read_bits(payload, 32, 1)),
    }


def classify(sequence: dict[str, Any], pictures: list[dict[str, Any]]) -> tuple[str, list[str]]:
    reasons: list[str] = []
    extension = sequence.get("extension")
    if extension is None:
        reasons.append("missing sequence_extension")
        progressive_sequence = True
    else:
        progressive_sequence = bool(extension["progressive_sequence"])
        if extension["chroma_format"] != 1:
            reasons.append(f"chroma_format={extension['chroma_format']}")

    if sequence.get("horizontal_size", 0) > 720 or sequence.get("vertical_size", 0) > 480:
        reasons.append("geometry exceeds 720x480 storage envelope")

    for number, picture in enumerate(pictures):
        coding = picture.get("coding_extension")
        if coding is None:
            reasons.append(f"picture {number} missing picture_coding_extension")
            continue
        if coding["picture_structure"] != 3:
            reasons.append(f"picture {number} is not a frame picture")
        if not coding["frame_pred_frame_dct"]:
            reasons.append(f"picture {number} requires frame DCT/motion_type parsing")
        if coding["concealment_motion_vectors"]:
            reasons.append(f"picture {number} uses concealment motion vectors")

        if progressive_sequence:
            if not coding["progressive_frame"]:
                reasons.append(f"picture {number} is not progressive")
        else:
            if picture["coding_type"] != 1:
                reasons.append(f"picture {number} is not intra")
            if coding["progressive_frame"]:
                reasons.append(f"picture {number} is not an interlaced frame")
            if coding["repeat_first_field"]:
                reasons.append(f"picture {number} repeats its first field")
            if coding["chroma_420_type"]:
                reasons.append(f"picture {number} has progressive 4:2:0 chroma signalling")

    if reasons:
        return "outside_v0.5_frontend_envelope", sorted(set(reasons))
    if not progressive_sequence:
        if sequence.get("horizontal_size") != 720 or sequence.get("vertical_size") != 480:
            return "outside_native_480i_i_frame_envelope", [
                "native interlaced milestone requires 720x480 geometry"
            ]
        if sequence.get("frame_rate_code") != 4:
            return "outside_native_480i_i_frame_envelope", [
                "native interlaced milestone requires 30000/1001 frame rate"
            ]
        return "interlaced_420_i_frame_candidate_requires_macroblock_execution", []
    return "progressive_420_candidate_requires_macroblock_execution", []


def analyze_file(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    codes = start_codes(data)
    sequence: dict[str, Any] = {}
    pictures: list[dict[str, Any]] = []
    current_picture: dict[str, Any] | None = None

    for index, (_offset, code) in enumerate(codes):
        payload = payload_between(data, codes, index)
        if code == 0xB3 and not sequence:
            sequence.update(parse_sequence_header(payload))
        elif code == 0x00:
            current_picture = parse_picture_header(payload)
            current_picture["slices"] = []
            pictures.append(current_picture)
        elif code == 0xB5 and payload:
            extension_id = read_bits(payload, 0, 4)
            if extension_id == 1 and "extension" not in sequence:
                sequence["extension"] = parse_sequence_extension(payload)
            elif extension_id == 8 and current_picture is not None:
                current_picture["coding_extension"] = parse_picture_coding_extension(payload)
        elif 0x01 <= code <= 0xAF and current_picture is not None:
            current_picture["slices"].append({
                "vertical_position": code,
                "payload_bytes": len(payload),
            })

    for picture in pictures:
        rows = [entry["vertical_position"] for entry in picture["slices"]]
        counts = Counter(rows)
        picture["slice_count"] = len(rows)
        picture["repeated_slice_rows"] = sorted(row for row, count in counts.items() if count > 1)
        picture["max_slice_payload_bytes"] = max(
            (entry["payload_bytes"] for entry in picture["slices"]), default=0
        )

    classification, reasons = classify(sequence, pictures)
    types = [str(picture["type"]) for picture in pictures]
    return {
        "path": str(path),
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "sequence": sequence,
        "picture_count": len(pictures),
        "picture_order": types,
        "picture_type_counts": dict(sorted(Counter(types).items())),
        "pictures": pictures,
        "max_slice_payload_bytes": max(
            (picture["max_slice_payload_bytes"] for picture in pictures), default=0
        ),
        "classification": classification,
        "classification_reasons": reasons,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("streams", nargs="+", type=Path)
    parser.add_argument("--json", type=Path, help="write the complete report as JSON")
    args = parser.parse_args()

    reports = [analyze_file(path.resolve()) for path in args.streams]
    for report in reports:
        sequence = report["sequence"]
        order = "".join(report["picture_order"])
        repeated = sum(bool(picture["repeated_slice_rows"]) for picture in report["pictures"])
        print(
            f"{Path(report['path']).name}: {sequence.get('horizontal_size', '?')}x"
            f"{sequence.get('vertical_size', '?')} pictures={order} bytes={report['bytes']} "
            f"max_slice={report['max_slice_payload_bytes']} repeated_slice_pictures={repeated} "
            f"classification={report['classification']} sha256={report['sha256']}"
        )
        for reason in report["classification_reasons"]:
            print(f"  boundary: {reason}")

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps({"streams": reports}, indent=2) + "\n")
        print(f"wrote: {args.json}")


if __name__ == "__main__":
    main()
