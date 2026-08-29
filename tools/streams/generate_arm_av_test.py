#!/usr/bin/env python3
"""Generate deterministic Program Streams used for ARM audio validation."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

import finalize_program_stream as ps


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
    parser.add_argument(
        "--sample-rate",
        type=int,
        choices=(44100, 48000),
        default=48000,
        help="MPEG Layer II and reference PCM sample rate",
    )
    args = parser.parse_args()

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required")
    if not args.source.is_file():
        raise SystemExit(f"missing source stream: {args.source}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    rate_suffix = "" if args.sample_rate == 48000 else "_44k"
    if args.profile == "short":
        program = args.output_dir / f"01_arm_mp2_audio{rate_suffix}.mpg"
        demuxed_video = args.output_dir / f"reference_video{rate_suffix}.m2v"
        reference_pcm = args.output_dir / f"reference_audio{rate_suffix}.s16le"
        duration = "0.20"
        left_source = (
            f"sine=frequency=440:sample_rate={args.sample_rate}:duration=0.20"
        )
        right_source = (
            f"sine=frequency=660:sample_rate={args.sample_rate}:duration=0.20"
        )
        audio_filter = "[1:a][2:a]amerge=inputs=2[a]"
        mp3_audio_filter = "[0:a][1:a]amerge=inputs=2[a]"
    else:
        program = args.output_dir / f"02_arm_mp2_faded_tones{rate_suffix}.mpg"
        demuxed_video = (
            args.output_dir / f"reference_video_faded{rate_suffix}.m2v"
        )
        reference_pcm = (
            args.output_dir / f"reference_audio_faded{rate_suffix}.s16le"
        )
        duration = "3.00"
        left_source = (
            f"sine=frequency=440:sample_rate={args.sample_rate}:duration=3.00"
        )
        right_source = (
            f"sine=frequency=660:sample_rate={args.sample_rate}:duration=3.00"
        )
        envelope = "afade=t=in:st=0.25:d=0.25,afade=t=out:st=2.50:d=0.25"
        audio_filter = (
            f"[1:a]{envelope}[left];[2:a]{envelope}[right];"
            "[left][right]amerge=inputs=2[a]"
        )
        mp3_audio_filter = (
            f"[0:a]{envelope}[left];[1:a]{envelope}[right];"
            "[left][right]amerge=inputs=2[a]"
        )

    run([
        ffmpeg, "-hide_banner", "-loglevel", "fatal", "-y",
        "-f", "mpegvideo", "-i", str(args.source),
        "-f", "lavfi", "-i", left_source,
        "-f", "lavfi", "-i", right_source,
        "-filter_complex", audio_filter,
        "-map", "0:v:0", "-map", "[a]", "-t", duration,
        "-c:v", "copy", "-c:a", "mp2", "-b:a", "192k",
        "-ar", str(args.sample_rate),
        "-ac", "2", "-muxrate", "1200k", "-f", "mpeg", str(program),
    ])
    ps.finalize_program_stream(program)
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(program),
        "-map", "0:v:0", "-c", "copy", "-f", "mpeg2video", str(demuxed_video),
    ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(program),
        "-map", "0:a:0", "-f", "s16le", "-acodec", "pcm_s16le",
        "-ar", str(args.sample_rate), "-ac", "2", str(reference_pcm),
    ])

    mp3_cbr = args.output_dir / f"03_arm_mp3_cbr_stereo_id3{rate_suffix}.mp3"
    mp3_cbr_pcm = args.output_dir / f"reference_mp3_cbr_stereo{rate_suffix}.s16le"
    mp3_vbr = args.output_dir / f"04_arm_mp3_vbr_mono{rate_suffix}.mp3"
    mp3_vbr_pcm = args.output_dir / f"reference_mp3_vbr_mono{rate_suffix}.s16le"
    run([
        ffmpeg, "-hide_banner", "-loglevel", "fatal", "-y",
        "-f", "lavfi", "-i", left_source,
        "-f", "lavfi", "-i", right_source,
        "-filter_complex", mp3_audio_filter,
        "-map", "[a]", "-t", duration,
        "-c:a", "libmp3lame", "-b:a", "192k", "-ar", str(args.sample_rate),
        "-ac", "2", "-write_xing", "0", "-id3v2_version", "3",
        "-write_id3v1", "1", "-metadata", "title=MiSTer MP3 CBR fixture",
        str(mp3_cbr),
    ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(mp3_cbr),
        "-f", "s16le", "-acodec", "pcm_s16le", "-ar", str(args.sample_rate),
        "-ac", "2", str(mp3_cbr_pcm),
    ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "fatal", "-y",
        "-f", "lavfi", "-i", left_source, "-t", duration,
        "-c:a", "libmp3lame", "-q:a", "4", "-ar", str(args.sample_rate),
        "-ac", "1", "-write_xing", "0", "-id3v2_version", "3",
        "-metadata", "title=MiSTer MP3 VBR mono fixture", str(mp3_vbr),
    ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(mp3_vbr),
        "-f", "s16le", "-acodec", "pcm_s16le", "-ar", str(args.sample_rate),
        "-ac", "2", str(mp3_vbr_pcm),
    ])
    unsupported_mp3 = args.output_dir / "bad_mp3_32000.mp3"
    run([
        ffmpeg, "-hide_banner", "-loglevel", "fatal", "-y",
        "-f", "lavfi", "-i", "sine=frequency=550:sample_rate=32000:duration=0.20",
        "-c:a", "libmp3lame", "-b:a", "96k", "-ar", "32000", "-ac", "1",
        "-write_xing", "0", str(unsupported_mp3),
    ])
    print(f"profile: {args.profile}")
    print(f"rate: {args.sample_rate} Hz")
    print(program)
    print(mp3_cbr)
    print(mp3_vbr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
