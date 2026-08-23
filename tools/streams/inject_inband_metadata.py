#!/usr/bin/env python3
"""Annotate an H.262 elementary stream with in-band picture metadata records.

Entry 371: the throwaway harness that exercises mpeg2_h262_inband_metadata on
hardware.  No daemon exists yet, and none is needed to prove the path: the
fabric reads records out of the ordinary ioctl_download byte stream, so a file
produced here loads through the normal core file selector.

A record is 0x000001B0 followed by five payload bytes:

    pts[32:0] picture_structure[1:0] tff rff progressive_frame 00

0x000001B0 is a reserved H.262 start code.  No encoder emits it and start-code
emulation prevention keeps 0x000001 out of payload data, so annotating a stream
cannot collide with its contents, and an unannotated stream contains no records.

Timestamps here are synthetic and evenly spaced.  This proves extraction, not
presentation: nothing in the fabric consumes them yet.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PICTURE_START = b"\x00\x00\x01\x00"
RECORD_MARKER = b"\x00\x00\x01\xB0"


def build_record(pts: int, picture_structure: int, tff: int, rff: int,
                 progressive_frame: int) -> bytes:
    if not 0 <= pts < (1 << 33):
        raise ValueError(f"pts {pts} does not fit in 33 bits")
    value = (pts << 7) | ((picture_structure & 3) << 5) | ((tff & 1) << 4) \
            | ((rff & 1) << 3) | ((progressive_frame & 1) << 2)
    return RECORD_MARKER + value.to_bytes(5, "big")


def annotate(data: bytes, pts_start: int, pts_step: int, limit: int | None,
             picture_structure: int, tff: int, rff: int,
             progressive_frame: int) -> tuple[bytes, int, int]:
    out = bytearray()
    pts = pts_start
    count = 0
    last_pts = pts_start
    pos = 0
    while True:
        hit = data.find(PICTURE_START, pos)
        if hit < 0:
            break
        if limit is not None and count >= limit:
            break
        out += data[pos:hit]
        out += build_record(pts, picture_structure, tff, rff, progressive_frame)
        last_pts = pts
        pts = (pts + pts_step) % (1 << 33)
        count += 1
        pos = hit
        # Step past this start code so the next search does not re-find it.
        out += data[pos:pos + 4]
        pos += 4
    out += data[pos:]
    return bytes(out), count, last_pts


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path)
    ap.add_argument("dest", type=Path)
    ap.add_argument("--pts-start", type=lambda s: int(s, 0), default=0x77EF2)
    ap.add_argument("--pts-step", type=int, default=3003,
                    help="90 kHz ticks between pictures; 3003 is 29.97 Hz")
    ap.add_argument("--limit", type=int, default=None,
                    help="annotate at most this many pictures")
    ap.add_argument("--picture-structure", type=int, default=3,
                    help="3 = frame picture")
    ap.add_argument("--top-field-first", type=int, default=0)
    ap.add_argument("--repeat-first-field", type=int, default=0)
    ap.add_argument("--progressive-frame", type=int, default=1)
    args = ap.parse_args()

    data = args.source.read_bytes()
    if RECORD_MARKER in data:
        print(f"error: {args.source} already contains 0x000001B0; refusing to "
              f"annotate a stream that may already carry records",
              file=sys.stderr)
        return 2

    out, count, last_pts = annotate(
        data, args.pts_start, args.pts_step, args.limit,
        args.picture_structure, args.top_field_first,
        args.repeat_first_field, args.progressive_frame)
    args.dest.write_bytes(out)

    print(f"source        {args.source}  {len(data)} bytes")
    print(f"dest          {args.dest}  {len(out)} bytes")
    print(f"records       {count}")
    print(f"first pts     0x{args.pts_start:09X}")
    print(f"last pts      0x{last_pts:09X}   low11 = 0x{last_pts & 0x7FF:03X}")
    print(f"count field   {min(count, 255)}   (saturates at 255 in the snapshot)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
