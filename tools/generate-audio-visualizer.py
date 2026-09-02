#!/usr/bin/env python3
"""Generate the indexed eight-level legal H.262 loop used by audio playback."""

import argparse
import pathlib
import struct
import subprocess
import tempfile

MAGIC = b"MMPVIS1\0"
LEVELS = 8
GOPS = 20
FRAMES_PER_GOP = 3
FPS_NUM = 30000
FPS_DEN = 1001

SOURCE = (
    "nullsrc=s=720x480:r=30000/1001:d=2.002," 
    "geq="
    "lum='clip(104+44*sin(0.045*hypot(X-W/2,Y-H/2)-2*PI*N/60)"
    "+24*sin(6*atan2(Y-H/2,X-W/2)+2*PI*N/60),16,235)':"
    "cb='clip(128+52*sin(4*atan2(Y-H/2,X-W/2)+2*PI*N/60),16,240)':"
    "cr='clip(128+52*cos(5*atan2(Y-H/2,X-W/2)-2*PI*N/60),16,240)'"
)

GRADE_LOW = (-0.20, 0.82, 0.35)
GRADE_HIGH = (0.12, 1.32, 1.90)


def grade(level: int) -> str:
    fraction = level / (LEVELS - 1)
    brightness = GRADE_LOW[0] + (GRADE_HIGH[0] - GRADE_LOW[0]) * fraction
    contrast = GRADE_LOW[1] + (GRADE_HIGH[1] - GRADE_LOW[1]) * fraction
    saturation = GRADE_LOW[2] + (GRADE_HIGH[2] - GRADE_LOW[2]) * fraction
    return (f"eq=brightness={brightness:.4f}:contrast={contrast:.4f}:"
            f"saturation={saturation:.4f}")


def start_codes(data: bytes, code: int) -> list[int]:
    marker = b"\x00\x00\x01" + bytes((code,))
    found = []
    offset = 0
    while True:
        offset = data.find(marker, offset)
        if offset < 0:
            return found
        found.append(offset)
        offset += 4


def split_gops(data: bytes) -> list[bytes]:
    starts = start_codes(data, 0xB3)
    if len(starts) != GOPS:
        raise RuntimeError(f"encoder produced {len(starts)} GOPs, expected {GOPS}")
    chunks = [data[start : starts[index + 1] if index + 1 < len(starts) else len(data)]
              for index, start in enumerate(starts)]
    for index, chunk in enumerate(chunks):
        pictures = start_codes(chunk, 0x00)
        groups = start_codes(chunk, 0xB8)
        if len(pictures) != FRAMES_PER_GOP or len(groups) != 1:
            raise RuntimeError(f"GOP {index} is not an independent three-picture group")
        group = groups[0]
        if group + 8 > len(chunk) or not (chunk[group + 7] & 0x40):
            raise RuntimeError(f"GOP {index} is not marked closed")
    return chunks


def encode(ffmpeg: str, grade: str, destination: pathlib.Path) -> bytes:
    command = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-f", "lavfi",
        "-i", SOURCE, "-vf", grade, "-frames:v", str(GOPS * FRAMES_PER_GOP),
        "-pix_fmt", "yuv420p", "-c:v", "mpeg2video", "-profile:v", "main",
        "-level:v", "main", "-g", str(FRAMES_PER_GOP), "-bf", "0",
        "-sc_threshold", "1000000000", "-flags", "+cgop", "-q:v", "8",
        "-f", "mpeg2video", str(destination),
    ]
    subprocess.run(command, check=True)
    return destination.read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    args = parser.parse_args()

    variants = []
    with tempfile.TemporaryDirectory(prefix="mmp-visualizer-") as temporary:
        root = pathlib.Path(temporary)
        for level in range(LEVELS):
            variants.append(split_gops(encode(args.ffmpeg, grade(level),
                                              root / f"level-{level}.m2v")))
        switched = root / "switched.m2v"
        switched.write_bytes(b"".join(
            variants[gop % LEVELS][gop] for gop in range(GOPS)
        ) + b"\x00\x00\x01\xb7")
        subprocess.run([
            args.ffmpeg, "-hide_banner", "-loglevel", "error", "-f",
            "mpegvideo", "-i", str(switched), "-f", "null", "-",
        ], check=True)

    header_size = 32 + LEVELS * GOPS * 8
    offset = header_size
    entries = []
    payload = bytearray()
    for level in range(LEVELS):
        for gop in variants[level]:
            entries.append((offset, len(gop)))
            payload.extend(gop)
            offset += len(gop)
    header = MAGIC + struct.pack("<6I", 1, LEVELS, GOPS, FRAMES_PER_GOP,
                                 FPS_NUM, FPS_DEN)
    index = b"".join(struct.pack("<2I", *entry) for entry in entries)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(header + index + payload)
    print(f"wrote {args.output} ({offset} bytes, {LEVELS} levels, {GOPS} GOPs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
