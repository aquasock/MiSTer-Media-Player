#!/usr/bin/env python3
"""Generate native-rate 720x480 MPEG-2 media from Big Buck Bunny.

The synthetic corpus in generate_test_progressive_compatibility.py exercises
structure; this case adds real photographic content, which stresses residual
density and motion-vector range in ways testsrc2 does not.

The 854-pel source exceeds the framebuffer's SRC_WIDTH of 720 and would be
rejected outright by the horizontal_size guard in mpeg2_luma_framebuffer.sv,
so it is scaled to 720x480.  Its original 24 fps cadence is retained as H.262
frame_rate_code 2 so no repeated pictures are inserted by rate conversion.

By default this preserves the accepted video-only elementary-stream generator.
With --with-audio it emits the same video in an MPEG Program Stream with stereo
MPEG-1 Layer II audio, then adds the sequence end as a final video PES packet
for the v0.7.0 long-duration audio-video soak.

The output is a local regression artifact and is deliberately not committed.
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
import tempfile
from fractions import Fraction
from pathlib import Path

import h262common as h

DEFAULT_SOURCE = (
    Path(__file__).resolve().parent / "big_buck_bunny_480p_stereo.avi"
)
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parent
    / "generated_compatibility" / "test_bbb_480p_long_gop.m2v"
)
DEFAULT_PROGRAM_OUTPUT = (
    Path(__file__).resolve().parent
    / "generated_compatibility" / "test_bbb_480p_long_gop.mpg"
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--start", type=float, default=60.0,
        help="seek offset in seconds; the default skips the title card",
    )
    parser.add_argument(
        "--frames", type=int, default=250,
        help="encoded frame count; 240 is ten seconds at 24 fps",
    )
    parser.add_argument("--gop", type=int, default=24)
    parser.add_argument("--bframes", type=int, default=2)
    parser.add_argument("--quality", type=int, default=6)
    parser.add_argument(
        "--me-range", type=int, default=None,
        help="cap the encoder motion search range (ffmpeg -me_range); "
             "omit to leave the encoder default in place",
    )
    parser.add_argument(
        "--with-audio", action="store_true",
        help="mux source audio as MPEG Layer II and emit a Program Stream",
    )
    parser.add_argument(
        "--audio-rate", type=int, choices=(44100, 48000), default=48000,
        help="Program Stream audio sample rate used with --with-audio",
    )
    parser.add_argument(
        "--audio-bitrate", default="192k",
        help="MPEG Layer II bitrate used with --with-audio",
    )
    args = parser.parse_args()

    source = args.source.resolve()
    if not source.is_file():
        parser.error(f"source not found: {source}")
    if args.frames < 1:
        parser.error("frames must be positive")

    output = (
        args.output
        if args.output is not None
        else (DEFAULT_PROGRAM_OUTPUT if args.with_audio else DEFAULT_OUTPUT)
    ).resolve()
    if args.with_audio and output.suffix.lower() not in (".mpg", ".mpeg"):
        parser.error("--with-audio output must use .mpg or .mpeg")
    output.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg = h.require_tool("ffmpeg")

    def encode_video(video_output: Path) -> bytes:
        command = [
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-ss", str(args.start), "-i", str(source),
            "-frames:v", str(args.frames),
            "-vf", "scale=720:480:flags=bicubic,setsar=1",
            "-r", "24",
            "-an", "-c:v", "mpeg2video", "-pix_fmt", "yuv420p",
            "-threads", "1", "-flags", "+bitexact",
            "-g", str(args.gop), "-bf", str(args.bframes),
            "-q:v", str(args.quality), "-qmin", "2", "-qmax", "12",
            "-sc_threshold", "1000000000", "-mpv_flags", "+strict_gop",
        ]
        if args.me_range is not None:
            command += ["-me_range", str(args.me_range)]
        command += ["-f", "mpeg2video", str(video_output)]
        subprocess.run(command, check=True)

        payload = video_output.read_bytes()
        sequence_end = b"\x00\x00\x01\xb7"
        if not payload.endswith(sequence_end):
            payload += sequence_end
            video_output.write_bytes(payload)
            print("note    : appended missing sequence_end_code")
        return payload

    if args.with_audio:
        with tempfile.TemporaryDirectory(prefix="mister_bbb_av_") as temporary:
            video_output = Path(temporary) / "video.m2v"
            video_payload = encode_video(video_output)
            duration = Fraction(args.frames, 24)
            raw_program = Path(temporary) / "without_sequence_end.mpg"
            subprocess.run([
                ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                "-ss", str(args.start), "-i", str(source),
                "-map", "0:v:0", "-map", "0:a:0",
                "-frames:v", str(args.frames),
                "-vf", "scale=720:480:flags=bicubic,setsar=1",
                "-r", "24",
                "-c:v", "mpeg2video", "-pix_fmt", "yuv420p",
                "-threads", "1", "-flags", "+bitexact",
                "-g", str(args.gop), "-bf", str(args.bframes),
                "-q:v", str(args.quality), "-qmin", "2", "-qmax", "12",
                "-sc_threshold", "1000000000", "-mpv_flags", "+strict_gop",
                *(["-me_range", str(args.me_range)]
                  if args.me_range is not None else []),
                "-c:a", "mp2", "-b:a", args.audio_bitrate,
                "-ar", str(args.audio_rate), "-ac", "2",
                "-t", f"{float(duration):.9f}",
                "-f", "vob", str(raw_program),
            ], check=True)

            def demux_video(program_path: Path) -> bytes:
                return subprocess.run([
                    ffmpeg, "-hide_banner", "-loglevel", "error",
                    "-i", str(program_path),
                    "-map", "0:v:0", "-c", "copy", "-f", "mpeg2video", "-",
                ], check=True, capture_output=True).stdout

            demuxed = demux_video(raw_program)
            sequence_end = b"\x00\x00\x01\xb7"
            if demuxed + sequence_end != video_payload:
                raise RuntimeError(
                    "Program Stream video differs from the video-only encode"
                )

            program = raw_program.read_bytes()
            program_end = b"\x00\x00\x01\xb9"
            end_offset = program.rfind(program_end)
            if end_offset < 0:
                end_offset = len(program)
                terminator = program_end
            else:
                terminator = program[end_offset:]
            # MPEG-2 PES header with no optional fields and a four-byte video
            # payload.  PES_packet_length counts the three header bytes plus
            # the sequence_end_code payload.
            final_video_pes = (
                b"\x00\x00\x01\xe0\x00\x07\x80\x00\x00" + sequence_end
            )
            output.write_bytes(
                program[:end_offset] + final_video_pes + terminator
            )
            demuxed = demux_video(output)
            if demuxed != video_payload:
                raise RuntimeError("sequence-ended Program Stream video differs")
    else:
        encode_video(output)

    payload = output.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    print(f"stream  : {output} ({'mpeg-ps' if args.with_audio else 'mpeg2video'})")
    print(f"bytes   : {len(payload)}")
    print(f"sha256  : {digest}")
    print(f"frames  : {args.frames} at 24 fps, GOP {args.gop}, {args.bframes} B")
    print(f"quality : q:v {args.quality}, me_range "
          f"{args.me_range if args.me_range is not None else 'encoder default'}")
    if args.with_audio:
        print(f"audio   : MPEG Layer II stereo, {args.audio_rate} Hz, "
              f"{args.audio_bitrate}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
