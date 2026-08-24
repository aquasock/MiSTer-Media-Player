#!/usr/bin/env python3
"""Generate deterministic Program Streams used for ARM audio validation."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).resolve().parent / "test_b_bidirectional.m2v",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "generated_arm_av",
    )
    parser.add_argument(
        "--profile",
        choices=("short", "faded"),
        default="short",
        help="short transport fixture or longer faded audio-quality fixture",
    )
    args = parser.parse_args()

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required")
    if not args.source.is_file():
        raise SystemExit(f"missing source stream: {args.source}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.profile == "short":
        program = args.output_dir / "01_arm_mp2_audio.mpg"
        demuxed_video = args.output_dir / "reference_video.m2v"
        reference_pcm = args.output_dir / "reference_audio.s16le"
        duration = "0.20"
        left_source = "sine=frequency=440:sample_rate=48000:duration=0.20"
        right_source = "sine=frequency=660:sample_rate=48000:duration=0.20"
        audio_filter = "[1:a][2:a]amerge=inputs=2[a]"
    else:
        program = args.output_dir / "02_arm_mp2_faded_tones.mpg"
        demuxed_video = args.output_dir / "reference_video_faded.m2v"
        reference_pcm = args.output_dir / "reference_audio_faded.s16le"
        duration = "3.00"
        left_source = "sine=frequency=440:sample_rate=48000:duration=3.00"
        right_source = "sine=frequency=660:sample_rate=48000:duration=3.00"
        envelope = "afade=t=in:st=0.25:d=0.25,afade=t=out:st=2.50:d=0.25"
        audio_filter = (
            f"[1:a]{envelope}[left];[2:a]{envelope}[right];"
            "[left][right]amerge=inputs=2[a]"
        )

    run([
        ffmpeg, "-hide_banner", "-loglevel", "fatal", "-y",
        "-f", "mpegvideo", "-i", str(args.source),
        "-f", "lavfi", "-i", left_source,
        "-f", "lavfi", "-i", right_source,
        "-filter_complex", audio_filter,
        "-map", "0:v:0", "-map", "[a]", "-t", duration,
        "-c:v", "copy", "-c:a", "mp2", "-b:a", "192k", "-ar", "48000",
        "-ac", "2", "-muxrate", "1200k", "-f", "mpeg", str(program),
    ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(program),
        "-map", "0:v:0", "-c", "copy", "-f", "mpeg2video", str(demuxed_video),
    ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(program),
        "-map", "0:a:0", "-f", "s16le", "-acodec", "pcm_s16le",
        "-ar", "48000", "-ac", "2", str(reference_pcm),
    ])
    print(f"profile: {args.profile}")
    print(program)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
