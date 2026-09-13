#!/usr/bin/env python3
"""Generate a compact mixed-macroblock I/P/B raster and pixel oracle."""
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
from pathlib import Path

import h262common as h


WIDTH = 128
HEIGHT = 96
FRAME_BYTES = WIDTH * HEIGHT * 3 // 2


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent
        / "generated_compatibility"
        / "test_mixed_raster_soak.m2v",
    )
    parser.add_argument(
        "--oracle-output",
        type=Path,
        help="optional readmemh byte oracle for all decoded YUV420P frames",
    )
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")

    subprocess.run(
        [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-f",
            "lavfi",
            "-i",
            f"testsrc2=size={WIDTH}x{HEIGHT}:rate=25",
            "-frames:v",
            "24",
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
            "4",
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
        ],
        check=True,
    )
    payload = output.read_bytes()
    if not payload.endswith(h.SEQ_END):
        output.write_bytes(payload + h.SEQ_END)

    types = h.picture_types(ffprobe, output)
    expected_types = {"I": 1, "P": 8, "B": 15}
    if len(types) != 24 or any(types.count(k) != v for k, v in expected_types.items()):
        raise SystemExit(f"unexpected picture inventory: {types!r}")

    debug = subprocess.run(
        [ffmpeg, "-hide_banner", "-debug", "mb_type", "-i", str(output),
         "-f", "null", "-"],
        check=True,
        text=True,
        capture_output=True,
    ).stderr
    p_sections = re.findall(
        r"New frame, type: P(.*?)(?=New frame, type:|\Z)", debug, re.DOTALL
    )
    if not p_sections or not any(re.search(r"(?:^|\s)i(?:\s|$)", s) for s in p_sections):
        raise SystemExit("generated P pictures contain no intra macroblocks")

    raw = subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(output),
         "-pix_fmt", "yuv420p", "-f", "rawvideo", "-"],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    if len(raw) != 24 * FRAME_BYTES:
        raise SystemExit(f"unexpected decoded byte count: {len(raw)}")
    if args.oracle_output:
        oracle = args.oracle_output.resolve()
        oracle.parent.mkdir(parents=True, exist_ok=True)
        oracle.write_text("".join(f"{value:02x}\n" for value in raw))

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    oracle_digest = hashlib.sha256(raw).hexdigest()
    print(
        f"generated {output}: bytes={output.stat().st_size} "
        f"I=1 P=8 B=15 sha256={digest} yuv420p_sha256={oracle_digest}"
    )


if __name__ == "__main__":
    main()
