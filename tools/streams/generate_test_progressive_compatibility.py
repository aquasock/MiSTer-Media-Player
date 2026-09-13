#!/usr/bin/env python3
"""Generate the source-only v0.6.0 progressive compatibility corpus.

The generated MPEG-2 elementary streams and JSON manifest are local regression
artifacts, not repository inputs.  Every case uses FFmpeg's ordinary MPEG-2
encoder in single-threaded bitexact mode and records the exact encoder version,
arguments, structural analysis, digest, intended stress, and expected current
RTL boundary.  This corpus supplements rather than replaces the seven-stream
v0.5.0 hardware release matrix.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import analyze_h262_compatibility as analyzer
import h262common as h


REPO_ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Case:
    name: str
    source: str
    frames: int
    gop: int
    bframes: int
    quality: int
    slices: int
    intended_stress: str
    expected_current_boundary: str


CASES = (
    Case(
        "dense_residual",
        "nullsrc=size=720x480:rate=25,geq="
        "lum='mod(X*13+Y*7+N*17,220)+16':"
        "cb='mod(X*5+Y*11+N*3,224)+16':"
        "cr='mod(X*9+Y*3+N*5,224)+16'",
        12, 12, 2, 2, 1,
        "dense texture, dense coefficient traffic, and ordinary encoder quantiser decisions",
        "picture-wide residual descriptor and coefficient-event caps",
    ),
    Case(
        "mixed_macroblocks",
        "testsrc2=size=720x480:rate=25",
        24, 12, 2, 4, 1,
        "ordinary encoder selection among intra, predicted, skipped, and residual macroblocks",
        "intra-coded macroblocks within P and B pictures",
    ),
    Case(
        "long_gop",
        "testsrc2=size=720x480:rate=25",
        72, 24, 2, 6, 1,
        "long GOP playback, repeated reference rotation, B reordering, and sequence continuation",
        "long-stream ownership, publication, and soak validation",
    ),
)


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def portable_path(path: Path) -> str:
    """Use repository-relative paths when an artifact lives in this checkout."""
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(REPO_ROOT))
    except ValueError:
        return str(resolved)


def portable_command(command: list[str], ffmpeg: str) -> list[str]:
    """Remove host-specific tool and checkout prefixes from recorded commands."""
    result: list[str] = []
    for argument in command:
        if argument == ffmpeg:
            result.append(Path(argument).name)
        elif argument.startswith("/"):
            result.append(portable_path(Path(argument)))
        else:
            result.append(argument)
    return result


def ensure_sequence_end(stream: Path) -> None:
    """Terminate raw encoder output so the streaming RTL can retire its last slice."""
    sequence_end_code = b"\x00\x00\x01\xb7"
    payload = stream.read_bytes()
    if not payload.endswith(sequence_end_code):
        stream.write_bytes(payload + sequence_end_code)


def encoder_command(ffmpeg: str, case: Case, output: Path) -> list[str]:
    command = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", case.source,
        "-frames:v", str(case.frames),
        "-an", "-c:v", "mpeg2video", "-pix_fmt", "yuv420p",
        "-threads", "1", "-flags", "+bitexact",
        "-g", str(case.gop), "-bf", str(case.bframes),
        "-q:v", str(case.quality), "-qmin", "2", "-qmax", "12",
        "-sc_threshold", "1000000000", "-mpv_flags", "+strict_gop",
    ]
    if case.slices > 1:
        command.extend(["-slices", str(case.slices)])
    command.extend(["-f", "mpeg2video", str(output)])
    return command


def macroblock_debug_counts(
    ffmpeg: str, stream: Path, picture_order: list[str]
) -> dict[str, dict[str, int]]:
    """Inventory FFmpeg's decoded macroblock debug symbols by picture type."""
    expected = Counter(picture_order)
    # FFmpeg's mb_type debug output does not print the terminal delayed P
    # reference even though ffprobe and normal decode both publish it.
    if picture_order and picture_order[-1] == "P":
        expected["P"] -= 1
    last_totals: dict[str, int] = {}
    for _attempt in range(5):
        result = subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "debug", "-debug", "mb_type",
             "-threads", "1", "-i", str(stream), "-an", "-f", "null", "-"],
            check=True, text=True, capture_output=True,
        )
        counts: dict[str, Counter[str]] = defaultdict(Counter)
        current_type: str | None = None
        for line in result.stderr.splitlines():
            frame_match = re.search(r"New frame, type: ([IPB])", line)
            if frame_match:
                current_type = frame_match.group(1)
                continue
            row_match = re.search(r"\]\s+\d+\s+(.+)$", line)
            if current_type is None or row_match is None:
                continue
            symbols = row_match.group(1).split()
            if len(symbols) == h.MB_WIDTH and all(
                symbol in {"i", "I", "S", ">", "<", "X", "d", "D"}
                for symbol in symbols
            ):
                counts[current_type].update(symbols)
        last_totals = {picture: sum(symbols.values()) for picture, symbols in counts.items()}
        if all(
            last_totals.get(picture, 0) == count * h.MB_WIDTH * h.MB_HEIGHT
            for picture, count in expected.items()
        ):
            return {
                picture: dict(sorted(symbols.items()))
                for picture, symbols in sorted(counts.items())
            }
    raise RuntimeError(
        "incomplete FFmpeg macroblock debug inventory after five attempts: "
        f"expected={dict(expected)}, totals={last_totals}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path,
        default=Path(__file__).resolve().parent / "generated_compatibility",
    )
    args = parser.parse_args()

    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    version = subprocess.run(
        [ffmpeg, "-version"], check=True, text=True, capture_output=True
    ).stdout.splitlines()[0]

    manifest_cases: list[dict[str, Any]] = []

    multi_slice_output = output_dir / "test_compat_multi_slice.m2v"
    multi_slice_generator = Path(__file__).resolve().with_name(
        "generate_test_pb_restricted_slices.py"
    )
    multi_slice_command = [
        "python3", str(multi_slice_generator), "--output", str(multi_slice_output)
    ]
    run(multi_slice_command)
    multi_slice_analysis = analyzer.analyze_file(multi_slice_output)
    multi_slice_analysis["path"] = portable_path(multi_slice_output)
    if not any(
        picture["repeated_slice_rows"] for picture in multi_slice_analysis["pictures"]
    ):
        raise SystemExit("multi_slice: deterministic authoring did not produce repeated slice rows")
    manifest_cases.append({
        "name": "multi_slice",
        "intended_stress": (
            "multiple independently coded slices per macroblock row with predictor resets, "
            "non-unit leading macroblock addresses, motion, and residuals"
        ),
        "expected_current_boundary": "general slice streaming and arbitrary legal slice endpoints",
        "generator_command": portable_command(multi_slice_command, ffmpeg),
        "decoded_display_order": h.picture_types(ffprobe, multi_slice_output),
        "analysis": multi_slice_analysis,
    })
    print(
        f"generated {multi_slice_output.name}: "
        f"coded_order={''.join(multi_slice_analysis['picture_order'])} "
        f"max_slice={multi_slice_analysis['max_slice_payload_bytes']} "
        f"sha256={multi_slice_analysis['sha256']}"
    )

    for case in CASES:
        output = output_dir / f"test_compat_{case.name}.m2v"
        command = encoder_command(ffmpeg, case, output)
        run(command)
        ensure_sequence_end(output)
        picture_order = h.picture_types(ffprobe, output)
        analysis = analyzer.analyze_file(output)
        analysis["path"] = portable_path(output)
        macroblock_counts = macroblock_debug_counts(ffmpeg, output, picture_order)
        if analysis["classification"] != "progressive_420_candidate_requires_macroblock_execution":
            raise SystemExit(
                f"{case.name}: generated stream left the intended frontend envelope: "
                f"{analysis['classification_reasons']}"
            )
        if len(picture_order) != case.frames:
            raise SystemExit(
                f"{case.name}: expected {case.frames} decoded frames, got {len(picture_order)}"
            )
        if case.bframes and not {"I", "P", "B"}.issubset(picture_order):
            raise SystemExit(f"{case.name}: encoder did not produce the intended I/P/B mix")
        if case.slices > 1 and not any(
            picture["repeated_slice_rows"] for picture in analysis["pictures"]
        ):
            raise SystemExit(f"{case.name}: encoder did not produce repeated slice rows")
        if case.name == "mixed_macroblocks" and macroblock_counts.get("P", {}).get("i", 0) == 0:
            raise SystemExit("mixed_macroblocks: encoder did not produce intra macroblocks in P pictures")

        manifest_cases.append({
            "name": case.name,
            "intended_stress": case.intended_stress,
            "expected_current_boundary": case.expected_current_boundary,
            "encoder_command": portable_command(command, ffmpeg),
            "decoded_display_order": picture_order,
            "ffmpeg_macroblock_debug_counts": macroblock_counts,
            "analysis": analysis,
        })
        print(
            f"generated {output.name}: frames={case.frames} "
            f"coded_order={''.join(analysis['picture_order'])} "
            f"max_slice={analysis['max_slice_payload_bytes']} "
            f"sha256={analysis['sha256']}"
        )

    manifest = {
        "purpose": "v0.6.0 supplemental progressive 4:2:0 compatibility corpus",
        "authoritative_v0.5_matrix_replaced": False,
        "ffmpeg_version": version,
        "cases": manifest_cases,
    }
    manifest_path = output_dir / "compatibility_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote: {manifest_path}")


if __name__ == "__main__":
    main()
