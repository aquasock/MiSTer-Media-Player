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
GROUP_START_CODE = PREFIX + b"\xb8"
RECORD_SIZE = 9


def next_video_byte(transport: bytes, position: int) -> bytes | None:
    """The next byte that is video rather than the start of a record."""
    while position < len(transport):
        code = transport[position:position + 4]
        if code == PTS_MARKER:
            position += RECORD_SIZE
            continue
        if code == PCM_MARKER:
            frames = (transport[position + 4] >> 2) or 1
            position += 5 + 4 * frames
            continue
        if code == PCM_END_MARKER:
            position += 4
            continue
        return transport[position:position + 1]
    return None


def skip_one_video_byte(transport: bytes, position: int) -> int:
    """Advance past the byte that next_video_byte() already emitted."""
    while position < len(transport):
        code = transport[position:position + 4]
        if code == PTS_MARKER:
            position += RECORD_SIZE
            continue
        if code == PCM_MARKER:
            frames = (transport[position + 4] >> 2) or 1
            position += 5 + 4 * frames
            continue
        if code == PCM_END_MARKER:
            position += 4
            continue
        return position + 1
    return position


def split_records(transport: bytes, per_gop: bool = False,
                  avoid_prefix: bool = False) -> tuple[bytes, bytes, int, int]:
    """Return (video with timestamps, video alone, timestamp count, PCM count).

    With *per_gop*, a timestamp is kept only when a group start code has been
    passed since the last one was kept, which varies record density without
    touching a single video byte.

    With *avoid_prefix*, a timestamp that would land immediately after video
    ending in a start-code prefix is moved one byte later, so the record's own
    leading zero can no longer complete a start code the video does not
    contain.  Record count and video bytes are both unchanged; only the
    insertion point moves.
    """
    annotated = bytearray()
    plain = bytearray()
    timestamps = 0
    pcm = 0
    position = 0
    group_open = True
    deferred = [False]
    while position < len(transport):
        marker = transport.find(PREFIX, position)
        if marker < 0:
            annotated += transport[position:]
            plain += transport[position:]
            break
        annotated += transport[position:marker]
        plain += transport[position:marker]
        code = transport[marker:marker + 4]
        if code == GROUP_START_CODE:
            group_open = True
        if code == PTS_MARKER and marker + RECORD_SIZE <= len(transport):
            if group_open or not per_gop:
                record = transport[marker:marker + RECORD_SIZE]
                if avoid_prefix and bytes(annotated[-3:]) == PREFIX:
                    carried = next_video_byte(transport, marker + RECORD_SIZE)
                    if carried is not None:
                        annotated += carried
                        plain += carried
                        deferred[0] = True
                annotated += record
                timestamps += 1
                group_open = False
            position = marker + RECORD_SIZE
            if deferred[0]:
                deferred[0] = False
                position = skip_one_video_byte(transport, position)
        elif code == PCM_MARKER and marker + 5 <= len(transport):
            frames = (transport[marker + 4] >> 2) or 1
            pcm += frames
            position = marker + 5 + 4 * frames
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
        "--timestamps",
        choices=("all", "gop"),
        default="all",
        help="keep every timestamp record, or only the first of each group",
    )
    parser.add_argument(
        "--avoid-start-code-prefix",
        action="store_true",
        help="move a record that would land after 00 00 01 one byte later",
    )
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

    annotated, plain, timestamps, pcm = split_records(
        completed.stdout, per_gop=args.timestamps == "gop",
        avoid_prefix=args.avoid_start_code_prefix,
    )
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
