#!/usr/bin/env python3
"""Generate deterministic native-480i H.262 all-I candidate streams.

FFmpeg first weaves 60000/1001 source pictures into 30000/1001 TFF or BFF
frames and encodes ordinary frame-DCT all-I MPEG-2.  Sustained visual fixtures
can use either the original high-detail test pattern or a low-complexity pattern
with a moving bar and alternating field markers.  The generator then changes
only the sequence/picture signalling bits required by the approved subset:
interlaced sequence, interlaced frame, matching 4:2:0 chroma type, no repeat,
and the authored first-field order.  Patched and unpatched streams must decode
to identical YCbCr planes before an artifact is accepted.

Generated media and the manifest are local regression artifacts, not committed
repository inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import analyze_h262_compatibility as analyzer
import h262common as h


FRAME_COUNT = 4
SOURCE_RATE = "60000/1001"
FRAME_RATE = "30000/1001"
SEQUENCE_END = b"\x00\x00\x01\xb7"
DETAILED_SOURCE = f"testsrc2=size=720x480:rate={SOURCE_RATE}"
LIGHT_SOURCE = (
    f"nullsrc=size=720x480:rate={SOURCE_RATE},"
    "geq="
    "lum='if(between(Y,64,415)*between(X,40+mod(N*4,640),"
    "71+mod(N*4,640)),235,"
    "if(eq(mod(N,2),0)*between(X,16,79)*between(Y,16,63),200,"
    "if(eq(mod(N,2),1)*between(X,16,79)*between(Y,416,463),200,"
    "if(between(Y,119,122)+between(Y,357,360),112,32))))':"
    "cb='128':cr='128'"
)
STEP_HOLD_SOURCE_FIELDS = 60
STEP_HOLD_BAR_X = 48
STEP_HOLD_BAR_WIDTH = 8
STEP_HOLD_BAR_STEP = 96
STEP_HOLD_BAR_SPAN = 576
STEP_HOLD_SOURCE = (
    f"nullsrc=size=720x480:rate={SOURCE_RATE},"
    "geq="
    "lum='if(between(Y,64,415)*between(X,"
    f"{STEP_HOLD_BAR_X}+mod(floor(N/{STEP_HOLD_SOURCE_FIELDS})*"
    f"{STEP_HOLD_BAR_STEP},{STEP_HOLD_BAR_SPAN}),"
    f"{STEP_HOLD_BAR_X + STEP_HOLD_BAR_WIDTH - 1}+"
    f"mod(floor(N/{STEP_HOLD_SOURCE_FIELDS})*{STEP_HOLD_BAR_STEP},"
    f"{STEP_HOLD_BAR_SPAN})),235,"
    "if(between(Y,119,122)+between(Y,357,360),112,32))':"
    "cb='128':cr='128'"
)


@dataclass(frozen=True)
class Case:
    name: str
    filter_mode: str
    top_field_first: bool


CASES = (
    Case("tff", "interleave_top", True),
    Case("bff", "interleave_bottom", False),
)


def set_payload_bit(data: bytearray, payload_offset: int, bit: int, value: bool) -> None:
    byte_offset = payload_offset + bit // 8
    mask = 1 << (7 - bit % 8)
    if value:
        data[byte_offset] |= mask
    else:
        data[byte_offset] &= ~mask


def patch_interlaced_signalling(
    payload: bytes, top_field_first: bool, frame_count: int
) -> bytes:
    data = bytearray(payload)
    codes = analyzer.start_codes(payload)
    sequence_extensions = 0
    picture_extensions = 0
    for offset, code in codes:
        if code != 0xB5 or offset + 5 >= len(data):
            continue
        payload_offset = offset + 4
        extension_id = analyzer.read_bits(payload[payload_offset:], 0, 4)
        if extension_id == 1:
            set_payload_bit(data, payload_offset, 12, False)
            sequence_extensions += 1
        elif extension_id == 8:
            set_payload_bit(data, payload_offset, 24, top_field_first)
            set_payload_bit(data, payload_offset, 25, True)
            set_payload_bit(data, payload_offset, 30, False)
            set_payload_bit(data, payload_offset, 31, False)
            set_payload_bit(data, payload_offset, 32, False)
            picture_extensions += 1
    if sequence_extensions < 1:
        raise RuntimeError("expected at least one sequence extension")
    if picture_extensions != frame_count:
        raise RuntimeError(
            f"expected {frame_count} picture coding extensions, found {picture_extensions}"
        )
    return bytes(data)


def decode_raw(ffmpeg: str, path: Path, frame_count: int) -> bytes:
    result = subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-threads", "1",
         "-i", str(path), "-frames:v", str(frame_count), "-an",
         "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"],
        check=True, capture_output=True,
    )
    expected = frame_count * 720 * 480 * 3 // 2
    if len(result.stdout) != expected:
        raise RuntimeError(f"decoded {len(result.stdout)} bytes, expected {expected}")
    return result.stdout


def validate_step_hold_decoded(raw: bytes, frame_count: int) -> dict[str, Any]:
    """Prove the encoded fixture itself contains no stale bar position."""
    luma_size = 720 * 480
    frame_size = luma_size * 3 // 2
    hold_frames = STEP_HOLD_SOURCE_FIELDS // 2
    max_adjacent_field_delta = 0
    previous_position: int | None = None
    prior_positions: set[int] = set()
    step_count = 0
    for frame_index in range(frame_count):
        frame = raw[frame_index * frame_size:(frame_index + 1) * frame_size]
        position = STEP_HOLD_BAR_X + (
            (frame_index // hold_frames) * STEP_HOLD_BAR_STEP
        ) % STEP_HOLD_BAR_SPAN
        sample_x = position + STEP_HOLD_BAR_WIDTH // 2
        even_row = frame[200 * 720:201 * 720]
        odd_row = frame[201 * 720:202 * 720]
        if even_row[sample_x] < 180 or odd_row[sample_x] < 180:
            raise SystemExit(
                f"step-hold frame {frame_index}: current bar is not bright"
            )
        max_adjacent_field_delta = max(
            max_adjacent_field_delta,
            max(abs(a - b) for a, b in zip(even_row, odd_row)),
        )
        if previous_position is not None and position != previous_position:
            prior_positions.add(previous_position)
            step_count += 1
        for prior_position in prior_positions:
            if prior_position == position:
                continue
            old_x = prior_position + STEP_HOLD_BAR_WIDTH // 2
            if even_row[old_x] > 80 or odd_row[old_x] > 80:
                raise SystemExit(
                    f"step-hold frame {frame_index}: old bar remains encoded"
                )
        previous_position = position
    return {
        "bar_width_pixels": STEP_HOLD_BAR_WIDTH,
        "hold_source_fields": STEP_HOLD_SOURCE_FIELDS,
        "hold_output_frames": hold_frames,
        "bar_step_pixels": STEP_HOLD_BAR_STEP,
        "observed_steps": step_count,
        "decoded_prior_position_clear": True,
        "max_adjacent_field_row_delta": max_adjacent_field_delta,
    }


def encoder_command(
    ffmpeg: str, case: Case, output: Path, frame_count: int, source: str
) -> list[str]:
    source_filter = f"{source},tinterlace=mode={case.filter_mode}"
    return [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", source_filter,
        "-frames:v", str(frame_count), "-an", "-c:v", "mpeg2video",
        "-pix_fmt", "yuv420p", "-threads", "1", "-flags", "+bitexact",
        "-g", "1", "-bf", "0", "-q:v", "2", "-qmin", "2", "-qmax", "12",
        "-sc_threshold", "1000000000", "-f", "mpeg2video", str(output),
    ]


def portable_command(command: list[str], ffmpeg: str, output: Path) -> list[str]:
    return [
        "ffmpeg" if argument == ffmpeg else output.name if argument == str(output) else argument
        for argument in command
    ]


def generate_artifact(
    ffmpeg: str,
    ffprobe: str,
    temp: Path,
    output_dir: Path,
    case: Case,
    frame_count: int,
    output_name: str,
    artifact_name: str,
    source: str = DETAILED_SOURCE,
    source_profile: str = "detailed",
) -> dict[str, Any]:
    progressive = temp / f"{artifact_name}_frame_dct_progressive.m2v"
    output = output_dir / output_name
    command = encoder_command(ffmpeg, case, progressive, frame_count, source)
    subprocess.run(command, check=True)
    original = progressive.read_bytes()
    if not original.endswith(SEQUENCE_END):
        original += SEQUENCE_END
        progressive.write_bytes(original)
    patched = patch_interlaced_signalling(
        original, case.top_field_first, frame_count
    )
    output.write_bytes(patched)

    progressive_raw = decode_raw(ffmpeg, progressive, frame_count)
    interlaced_raw = decode_raw(ffmpeg, output, frame_count)
    if progressive_raw != interlaced_raw:
        raise SystemExit(
            f"{artifact_name}: signalling patch changed decoded YCbCr planes"
        )

    picture_types = h.picture_types(ffprobe, output)
    if picture_types != ["I"] * frame_count:
        raise SystemExit(
            f"{artifact_name}: expected {frame_count} I pictures: {picture_types}"
        )
    analysis = analyzer.analyze_file(output)
    if analysis["classification"] != (
        "interlaced_420_i_frame_candidate_requires_macroblock_execution"
    ):
        raise SystemExit(
            f"{artifact_name}: generated stream left the approved envelope: "
            f"{analysis['classification_reasons']}"
        )
    coding = [picture["coding_extension"] for picture in analysis["pictures"]]
    if not all(
        entry["top_field_first"] == case.top_field_first for entry in coding
    ):
        raise SystemExit(f"{artifact_name}: first-field order was not preserved")

    decoded_sha = hashlib.sha256(interlaced_raw).hexdigest()
    analysis["path"] = output.name
    result = {
        "name": artifact_name,
        "field_order": "top-first" if case.top_field_first else "bottom-first",
        "source_rate": SOURCE_RATE,
        "frame_rate": FRAME_RATE,
        "frame_count": frame_count,
        "encoded_duration_seconds": frame_count * 1001 / 30000,
        "source_profile": source_profile,
        "encoder_command": portable_command(command, ffmpeg, progressive),
        "signalling_patch": {
            "progressive_sequence": 0,
            "picture_structure": 3,
            "top_field_first": int(case.top_field_first),
            "frame_pred_frame_dct": 1,
            "repeat_first_field": 0,
            "chroma_420_type": 0,
            "progressive_frame": 0,
        },
        "decoded_yuv420p_sha256": decoded_sha,
        "patched_vs_unpatched_decoded_planes_equal": True,
        "analysis": analysis,
    }
    if source_profile == "step-hold-field-identical":
        result["step_hold_validation"] = validate_step_hold_decoded(
            interlaced_raw, frame_count
        )
    print(
        f"generated {output.name}: order={result['field_order']} "
        f"frames={frame_count} bytes={output.stat().st_size} "
        f"sha256={analysis['sha256']} decoded_sha256={decoded_sha}"
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path,
        default=Path(__file__).resolve().parent / "generated_interlaced",
    )
    parser.add_argument(
        "--visual-seconds", type=int, default=0,
        help="also generate sustained TFF/BFF visual fixtures of this duration",
    )
    parser.add_argument(
        "--light-visual-seconds", type=int, default=0,
        help=(
            "also generate low-complexity TFF/BFF motion fixtures of this "
            "duration"
        ),
    )
    parser.add_argument(
        "--step-hold-visual-seconds", type=int, default=0,
        help=(
            "also generate TFF/BFF fixtures with pair-identical fields and "
            "a narrow bar that steps after one-second stationary holds"
        ),
    )
    args = parser.parse_args()
    if args.visual_seconds < 0:
        parser.error("--visual-seconds must be zero or greater")
    if args.light_visual_seconds < 0:
        parser.error("--light-visual-seconds must be zero or greater")
    if args.step_hold_visual_seconds < 0:
        parser.error("--step-hold-visual-seconds must be zero or greater")

    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    version = subprocess.run(
        [ffmpeg, "-version"], check=True, text=True, capture_output=True
    ).stdout.splitlines()[0]
    manifest_cases: list[dict[str, Any]] = []
    visual_cases: list[dict[str, Any]] = []
    light_visual_cases: list[dict[str, Any]] = []
    step_hold_visual_cases: list[dict[str, Any]] = []

    with tempfile.TemporaryDirectory(prefix="mister_h262_interlaced_") as temp_name:
        temp = Path(temp_name)
        for case in CASES:
            manifest_cases.append(generate_artifact(
                ffmpeg, ffprobe, temp, output_dir, case, FRAME_COUNT,
                f"test_interlaced_i_{case.name}.m2v", case.name,
            ))

        if args.visual_seconds:
            visual_frame_count = (
                args.visual_seconds * 30000 + 500
            ) // 1001
            for case in CASES:
                visual_name = f"visual_{case.name}_{args.visual_seconds}s"
                visual_cases.append(generate_artifact(
                    ffmpeg, ffprobe, temp, output_dir, case,
                    visual_frame_count,
                    f"visual_interlaced_i_{case.name}_{args.visual_seconds}s.m2v",
                    visual_name,
                ))

        if args.light_visual_seconds:
            light_frame_count = (
                args.light_visual_seconds * 30000 + 500
            ) // 1001
            for case in CASES:
                light_name = (
                    f"light_visual_{case.name}_{args.light_visual_seconds}s"
                )
                light_visual_cases.append(generate_artifact(
                    ffmpeg, ffprobe, temp, output_dir, case,
                    light_frame_count,
                    f"light_interlaced_i_{case.name}_"
                    f"{args.light_visual_seconds}s.m2v",
                    light_name,
                    source=LIGHT_SOURCE,
                    source_profile="low-complexity-field-motion",
                ))

        if args.step_hold_visual_seconds:
            step_hold_frame_count = (
                args.step_hold_visual_seconds * 30000 + 500
            ) // 1001
            for case in CASES:
                step_hold_name = (
                    f"step_hold_visual_{case.name}_"
                    f"{args.step_hold_visual_seconds}s"
                )
                step_hold_visual_cases.append(generate_artifact(
                    ffmpeg, ffprobe, temp, output_dir, case,
                    step_hold_frame_count,
                    f"step_hold_interlaced_i_{case.name}_"
                    f"{args.step_hold_visual_seconds}s.m2v",
                    step_hold_name,
                    source=STEP_HOLD_SOURCE,
                    source_profile="step-hold-field-identical",
                ))

    manifest = {
        "purpose": "native 720x480i59.94 frame-DCT all-I decoder and field-order regressions",
        "ffmpeg_version": version,
        "generated_media_committed": False,
        "cases": manifest_cases,
        "visual_cases": visual_cases,
        "light_visual_cases": light_visual_cases,
        "step_hold_visual_cases": step_hold_visual_cases,
    }
    manifest_path = output_dir / "interlaced_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote: {manifest_path}")


if __name__ == "__main__":
    main()
