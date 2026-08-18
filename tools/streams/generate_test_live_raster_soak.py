#!/usr/bin/env python3
"""Generate a small-geometry 72-picture I/P/B live-raster soak stream."""
from __future__ import annotations

import argparse
import hashlib
import subprocess
from pathlib import Path

import h262common as h


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent
        / "generated_compatibility"
        / "test_live_raster_soak.m2v",
    )
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")

    command = [
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        "nullsrc=size=128x96:rate=25,geq="
        "lum='mod(X*13+Y*7+N*17,220)+16':"
        "cb='mod(X*5+Y*11+N*3,224)+16':"
        "cr='mod(X*9+Y*3+N*5,224)+16'",
        "-frames:v",
        "72",
        "-an",
        "-c:v",
        "mpeg2video",
        "-pix_fmt",
        "yuv420p",
        "-threads",
        "1",
        "-flags",
        "+bitexact",
        "-g",
        "24",
        "-bf",
        "2",
        "-q:v",
        "6",
        "-qmin",
        "2",
        "-qmax",
        "12",
        "-sc_threshold",
        "1000000000",
        "-mpv_flags",
        "+strict_gop",
        "-f",
        "mpeg2video",
        str(output),
    ]
    subprocess.run(command, check=True)
    sequence_end = b"\x00\x00\x01\xb7"
    payload = output.read_bytes()
    if not payload.endswith(sequence_end):
        output.write_bytes(payload + sequence_end)

    types = h.picture_types(ffprobe, output)
    if len(types) != 72 or types.count("I") != 3 or types.count("P") != 22 or types.count("B") != 47:
        raise SystemExit(f"unexpected picture inventory: {types!r}")
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(
        f"generated {output}: bytes={output.stat().st_size} "
        f"I={types.count('I')} P={types.count('P')} B={types.count('B')} "
        f"sha256={digest}"
    )


if __name__ == "__main__":
    main()
