#!/usr/bin/env python3
"""Generate the single short Program Stream used for the ARM audio cycle."""

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
    args = parser.parse_args()

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required")
    if not args.source.is_file():
        raise SystemExit(f"missing source stream: {args.source}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    program = args.output_dir / "01_arm_mp2_audio.mpg"
    demuxed_video = args.output_dir / "reference_video.m2v"
    reference_pcm = args.output_dir / "reference_audio.s16le"

    run([
        ffmpeg, "-hide_banner", "-loglevel", "fatal", "-y",
        "-f", "mpegvideo", "-i", str(args.source),
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=0.20",
        "-f", "lavfi", "-i", "sine=frequency=660:sample_rate=48000:duration=0.20",
        "-filter_complex", "[1:a][2:a]amerge=inputs=2[a]",
        "-map", "0:v:0", "-map", "[a]", "-t", "0.20",
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
    print(program)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
