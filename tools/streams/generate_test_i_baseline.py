#!/usr/bin/env python3
"""Generate the 720x480 all-intra baseline regression.

Four unmodified all-intra pictures straight from FFmpeg's own encoder (no
hand-authored bitstream patching at all) at the full 45x30 macroblock DVD
target geometry, one ordinary slice per row. This is the cheapest, fastest
stream in the set: a fast-fail sanity floor confirming basic intra decode
and full-width raster/slice structure before running the heavier P/B
feature streams. Motion, residual, addressing and B-prediction coverage
live in the other five generators in this directory.
"""
from __future__ import annotations

import hashlib
import subprocess
import tempfile
from pathlib import Path

import h262common as h

FRAME_COUNT = 4


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_i_baseline.m2v"

    with tempfile.TemporaryDirectory(prefix="mister_h262_ibase_") as td:
        temp = Path(td)
        raw = temp / "src.yuv"
        raw.write_bytes(h.source_frames(FRAME_COUNT))
        subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "yuv420p",
             "-s", f"{h.WIDTH}x{h.HEIGHT}", "-r", str(h.FPS), "-i", str(raw), "-frames:v", str(FRAME_COUNT),
             "-an", "-c:v", "mpeg2video", "-pix_fmt", "yuv420p", "-g", "1", "-q:v", "2",
             "-f", "mpeg2video", str(out)],
            check=True,
        )
        data = out.read_bytes()
        if not data.endswith(h.SEQ_END):
            out.write_bytes(data + h.SEQ_END)

    types = h.picture_types(ffprobe, out)
    if types != ["I"] * FRAME_COUNT:
        raise SystemExit(f"verification failed: expected {FRAME_COUNT} I pictures, got {types!r}")

    data = out.read_bytes()
    pics = h.pictures(data)
    if [t for _, t in pics] != [1] * FRAME_COUNT:
        raise SystemExit("verification failed: not every coded picture is intra")

    codes = h.start_codes(data)
    for pi in range(FRAME_COUNT):
        po = pics[pi][0]
        pe = pics[pi + 1][0] if pi + 1 < len(pics) else len(data)
        rows = [c for o, c in codes if po < o < pe and 1 <= c <= h.MB_HEIGHT]
        if rows != list(range(1, h.MB_HEIGHT + 1)):
            raise SystemExit(f"verification failed: picture {pi} is not exactly one slice per row (45x30)")

    subprocess.run([ffmpeg, "-v", "error", "-i", str(out), "-f", "null", "-"], check=True)

    s = subprocess.run(
        [ffprobe, "-v", "error", "-show_entries", "stream=width,height,pix_fmt", "-of", "default=nw=1", str(out)],
        check=True, text=True, capture_output=True,
    )
    if "width=720" not in s.stdout or "height=480" not in s.stdout or "pix_fmt=yuv420p" not in s.stdout:
        raise SystemExit(f"verification failed: unexpected stream geometry: {s.stdout}")

    digest = hashlib.sha256(data).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total), one slice per row")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"picture order: {' '.join(types)}")
    print("verification: all-intra, full-width raster/slice structure, FFmpeg decode completes cleanly")


if __name__ == "__main__":
    main()
