#!/usr/bin/env python3
"""Generate a 720x480 25 fps MPEG-2 elementary stream from Big Buck Bunny.

The synthetic corpus in generate_test_progressive_compatibility.py exercises
structure; this case adds real photographic content, which stresses residual
density and motion-vector range in ways testsrc2 does not.

Two source properties must be corrected before the decoder will accept it.
The 854-pel source exceeds the framebuffer's SRC_WIDTH of 720 and would be
rejected outright by the horizontal_size guard in mpeg2_luma_framebuffer.sv,
so it is scaled to 720x480.  The source is also 24 fps, which carries
frame_rate_code 2; the presentation scheduler engages its 25 fps cadence
accumulator only on frame_rate_code 3, so the stream is resampled to 25 fps
to exercise the cadence path the project is actually targeting.

The stream is a local regression artifact and is deliberately not committed.
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
from pathlib import Path

import h262common as h

DEFAULT_SOURCE = (
    Path(__file__).resolve().parents[2]
    / ".ai" / "archived_results" / "big_buck_bunny_480p_stereo.avi"
)
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parent
    / "generated_compatibility" / "test_bbb_480p_long_gop.m2v"
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--start", type=float, default=60.0,
        help="seek offset in seconds; the default skips the title card",
    )
    parser.add_argument(
        "--frames", type=int, default=250,
        help="encoded frame count; 250 is ten seconds at 25 fps",
    )
    parser.add_argument("--gop", type=int, default=24)
    parser.add_argument("--bframes", type=int, default=2)
    parser.add_argument("--quality", type=int, default=6)
    args = parser.parse_args()

    source = args.source.resolve()
    if not source.is_file():
        parser.error(f"source not found: {source}")
    if args.frames < 1:
        parser.error("frames must be positive")

    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg = h.require_tool("ffmpeg")

    command = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-ss", str(args.start), "-i", str(source),
        "-frames:v", str(args.frames),
        "-vf", "scale=720:480:flags=bicubic,setsar=1",
        "-r", "25",
        "-an", "-c:v", "mpeg2video", "-pix_fmt", "yuv420p",
        "-threads", "1", "-flags", "+bitexact",
        "-g", str(args.gop), "-bf", str(args.bframes),
        "-q:v", str(args.quality), "-qmin", "2", "-qmax", "12",
        "-sc_threshold", "1000000000", "-mpv_flags", "+strict_gop",
        "-f", "mpeg2video", str(output),
    ]
    subprocess.run(command, check=True)

    payload = output.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    print(f"stream  : {output}")
    print(f"bytes   : {len(payload)}")
    print(f"sha256  : {digest}")
    print(f"frames  : {args.frames} at 25 fps, GOP {args.gop}, {args.bframes} B")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
