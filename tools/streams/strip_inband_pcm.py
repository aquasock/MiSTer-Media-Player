#!/usr/bin/env python3
"""Write the timestamp-carrying, audio-free twin of a scheduled transport.

Entry 456: every audio-video run differs from the smooth raw control in three
ways at once -- it carries in-band timestamp records, it carries in-band PCM
records, and the PCM sink paces it in real time.  Removing only the PCM leaves
a stream that is still timestamp-driven and still record-carrying, but has no
audio and no real-time gating, so playing it separates presentation from
delivery without changing the helper, the FPGA or the video bytes.

The residue is taken from the helper's own output rather than rebuilt, so the
timestamps land at exactly the elementary-stream offsets hardware saw.
"""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

PREFIX = b"\x00\x00\x01"
PTS_MARKER = PREFIX + b"\xb0"
PCM_MARKER = PREFIX + b"\xb1"
PCM_END_MARKER = PREFIX + b"\xb6"
RECORD_SIZE = 9


def split_records(transport: bytes) -> tuple[bytes, bytes, int, int]:
    """Return (video with timestamps, video alone, timestamp count, PCM count)."""
    annotated = bytearray()
    plain = bytearray()
    timestamps = 0
    pcm = 0
    position = 0
    while position < len(transport):
        marker = transport.find(PREFIX, position)
        if marker < 0:
            annotated += transport[position:]
            plain += transport[position:]
            break
        annotated += transport[position:marker]
        plain += transport[position:marker]
        code = transport[marker:marker + 4]
        if code == PTS_MARKER and marker + RECORD_SIZE <= len(transport):
            annotated += transport[marker:marker + RECORD_SIZE]
            timestamps += 1
            position = marker + RECORD_SIZE
        elif code == PCM_MARKER and marker + RECORD_SIZE <= len(transport):
            pcm += 1
            position = marker + RECORD_SIZE
        elif code == PCM_END_MARKER:
            position = marker + 4
        else:
            annotated += transport[marker:marker + 1]
            plain += transport[marker:marker + 1]
            position = marker + 1
    return bytes(annotated), bytes(plain), timestamps, pcm


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("helper", type=Path)
    parser.add_argument("program", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument(
        "--expect-video-sha256",
        default=None,
        help="hash the stream must reduce to once timestamps are removed too",
    )
    args = parser.parse_args()

    completed = subprocess.run(
        [str(args.helper.resolve()), "--protocol", "1",
         "--source", f"file:{args.program.resolve()}"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if completed.returncode:
        sys.stderr.write(completed.stderr.decode(errors="replace"))
        raise SystemExit(f"helper failed ({completed.returncode})")

    annotated, plain, timestamps, pcm = split_records(completed.stdout)
    if not pcm:
        raise SystemExit("transport carries no PCM to remove")
    if not timestamps:
        raise SystemExit("transport carries no timestamps to keep")
    video_sha = hashlib.sha256(plain).hexdigest()
    if args.expect_video_sha256 and video_sha != args.expect_video_sha256:
        raise SystemExit(
            f"video reduces to {video_sha}, not {args.expect_video_sha256}"
        )
    args.target.write_bytes(annotated)
    print(
        f"annotated: {len(annotated)} bytes, {timestamps} timestamps, "
        f"{pcm} PCM records removed"
    )
    print(f"annotated SHA-256 {hashlib.sha256(annotated).hexdigest()}")
    print(f"video alone {len(plain)} bytes, SHA-256 {video_sha}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
