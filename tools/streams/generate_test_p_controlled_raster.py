#!/usr/bin/env python3
"""Generate a controlled progressive-frame MPEG-2 I/P/I raster regression.

The P picture contains one slice per macroblock row. Every macroblock is:
  macroblock_address_increment = 1
  P macroblock_type = motion-forward-only
  motion_code horizontal = 0
  motion_code vertical = 0
  no residual coefficients

The default target is 128x96 = 8x6 = 48 macroblocks. The generator is
parameterized so later controlled-raster tests do not require a new binary or
new generator for each geometry.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

FPS = 25
SEQ_END = bytes.fromhex("00 00 01 b7")


def require_tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"required tool not found in PATH: {name}")
    return path


def start_codes(data: bytes | bytearray) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    pos = 0
    marker = b"\x00\x00\x01"
    while True:
        pos = data.find(marker, pos)
        if pos < 0:
            return out
        if pos + 3 < len(data):
            out.append((pos, data[pos + 3]))
        pos += 4


def picture_types(ffprobe: str, path: Path) -> list[str]:
    result = subprocess.run(
        [
            ffprobe,
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "frame=pict_type",
            "-of", "csv=p=0",
            str(path),
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    return [
        line.strip().strip(",")
        for line in result.stdout.replace("\r", "").splitlines()
        if line.strip()
    ]


def controlled_row_payload(mb_width: int) -> bytes:
    # quantiser_scale_code=2 => 00010, extra_bit_slice=0 => 0
    # Each controlled P macroblock is:
    #   MBA increment 1: 1
    #   P motion-forward-only macroblock_type: 001
    #   horizontal motion_code 0: 1
    #   vertical motion_code 0: 1
    # => 100111, repeated once per macroblock.
    bits = "000100" + ("100111" * mb_width)
    bits += "0" * ((8 - (len(bits) % 8)) % 8)
    return int(bits, 2).to_bytes(len(bits) // 8, "big")


def make_source_frame(mb_width: int, mb_height: int) -> bytes:
    width = mb_width * 16
    height = mb_height * 16
    y = bytearray(width * height)

    # Distinct but studio-range-safe constant luma value for each macroblock.
    for yy in range(height):
        mb_y = yy // 16
        for xx in range(width):
            mb_x = xx // 16
            value = 32 + ((mb_y * 29 + mb_x * 17) % 176)
            y[yy * width + xx] = value

    cw, ch = width // 2, height // 2
    cb = bytes([96]) * (cw * ch)
    cr = bytes([160]) * (cw * ch)
    return bytes(y) + cb + cr


def generate_skeleton(
    ffmpeg: str,
    raw_path: Path,
    output_path: Path,
    mb_width: int,
    mb_height: int,
) -> None:
    width = mb_width * 16
    height = mb_height * 16
    frame = make_source_frame(mb_width, mb_height)
    raw_path.write_bytes(frame * 3)

    subprocess.run(
        [
            ffmpeg,
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "rawvideo",
            "-pix_fmt", "yuv420p",
            "-s", f"{width}x{height}",
            "-r", str(FPS),
            "-i", str(raw_path),
            "-frames:v", "3",
            "-an",
            "-c:v", "mpeg2video",
            "-pix_fmt", "yuv420p",
            "-bf", "0",
            "-q:v", "2",
            "-g", "12",
            "-force_key_frames", "0.08",
            "-f", "mpeg2video",
            str(output_path),
        ],
        check=True,
    )
    data = output_path.read_bytes()
    if not data.endswith(SEQ_END):
        output_path.write_bytes(data + SEQ_END)


def patch_controlled_p_picture(data: bytes, mb_width: int, mb_height: int) -> bytes:
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0x00]
    if len(pictures) != 3:
        raise SystemExit(f"expected exactly three pictures, found {len(pictures)}")
    p_picture, next_picture = pictures[1], pictures[2]

    patched = bytearray(data)
    pce_offset: int | None = None
    for offset, code in codes:
        if not (p_picture < offset < next_picture):
            continue
        if code == 0xB5 and offset + 5 < len(patched):
            if (patched[offset + 4] >> 4) == 0x8:
                pce_offset = offset
                break
    if pce_offset is None:
        raise SystemExit("P picture_coding_extension() not found")

    # forward f_code horizontal/vertical = (2,2)
    patched[pce_offset + 4] = (patched[pce_offset + 4] & 0xF0) | 0x02
    patched[pce_offset + 5] = 0x20 | (patched[pce_offset + 5] & 0x0F)

    codes = start_codes(patched)
    expected_slice_codes = tuple(range(1, mb_height + 1))
    region = [
        (index, offset, code)
        for index, (offset, code) in enumerate(codes)
        if p_picture < offset < next_picture and 0x01 <= code <= 0xAF
    ]
    got = tuple(code for _, _, code in region)
    if got != expected_slice_codes:
        raise SystemExit(
            f"expected P slices {expected_slice_codes!r}, got {got!r}"
        )

    payload = controlled_row_payload(mb_width)
    replacements: list[tuple[int, int]] = []
    for index, offset, _code in region:
        replacements.append((offset + 4, codes[index + 1][0]))
    for payload_start, payload_end in reversed(replacements):
        patched[payload_start:payload_end] = payload

    return bytes(patched)


def verify_output(
    ffmpeg: str,
    ffprobe: str,
    path: Path,
    mb_width: int,
    mb_height: int,
) -> None:
    types = picture_types(ffprobe, path)
    if types != ["I", "P", "I"]:
        raise SystemExit(f"unexpected picture order: {types!r}")

    data = path.read_bytes()
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0x00]
    if len(pictures) != 3:
        raise SystemExit("verification failed: picture count changed")
    p_picture, next_picture = pictures[1], pictures[2]

    pce = None
    p_slices: list[tuple[int, bytes]] = []
    expected_slice_codes = tuple(range(1, mb_height + 1))
    expected_payload = controlled_row_payload(mb_width)
    for index, (offset, code) in enumerate(codes):
        if not (p_picture < offset < next_picture):
            continue
        end = codes[index + 1][0]
        if code == 0xB5 and (data[offset + 4] >> 4) == 0x8:
            pce = data[offset + 4:end]
        elif code in expected_slice_codes:
            p_slices.append((code, data[offset + 4:end]))

    if pce is None or len(pce) < 2:
        raise SystemExit("verification failed: missing P coding extension")
    if (pce[0] & 0x0F) != 2 or (pce[1] >> 4) != 2:
        raise SystemExit("verification failed: forward f_code is not (2,2)")

    expected_slices = [
        (code, expected_payload) for code in expected_slice_codes
    ]
    if p_slices != expected_slices:
        raise SystemExit(f"verification failed: unexpected slices {p_slices!r}")

    width = mb_width * 16
    height = mb_height * 16
    decoded = subprocess.run(
        [
            ffmpeg,
            "-v", "error",
            "-i", str(path),
            "-f", "rawvideo",
            "-pix_fmt", "yuv420p",
            "-",
        ],
        check=True,
        capture_output=True,
    ).stdout
    frame_bytes = width * height * 3 // 2
    if len(decoded) != frame_bytes * 3:
        raise SystemExit(
            f"verification failed: decoded {len(decoded)} bytes, "
            f"expected {frame_bytes * 3}"
        )
    if decoded[:frame_bytes] != decoded[frame_bytes:2 * frame_bytes]:
        raise SystemExit("verification failed: decoded P frame differs from I reference")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mb-width", type=int, default=8)
    parser.add_argument("--mb-height", type=int, default=6)
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "test_p_fortyeight_mb_six_row.m2v",
    )
    args = parser.parse_args()

    if not (2 <= args.mb_width <= 45):
        raise SystemExit("--mb-width must be in the controlled decoder range 2..45")
    if not (2 <= args.mb_height <= 30):
        raise SystemExit("--mb-height must be in the controlled decoder range 2..30")

    ffmpeg = require_tool("ffmpeg")
    ffprobe = require_tool("ffprobe")
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="mister_h262_raster_") as temp_dir:
        temp = Path(temp_dir)
        raw_path = temp / "raster.yuv"
        skeleton_path = temp / "raster_skeleton.m2v"
        generate_skeleton(
            ffmpeg, raw_path, skeleton_path, args.mb_width, args.mb_height
        )
        skeleton_types = picture_types(ffprobe, skeleton_path)
        if skeleton_types != ["I", "P", "I"]:
            raise SystemExit(
                f"FFmpeg skeleton picture order changed: {skeleton_types!r}"
            )
        args.output.write_bytes(
            patch_controlled_p_picture(
                skeleton_path.read_bytes(), args.mb_width, args.mb_height
            )
        )

    verify_output(ffmpeg, ffprobe, args.output, args.mb_width, args.mb_height)

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    version = subprocess.run(
        [ffmpeg, "-version"], check=True, text=True, capture_output=True
    ).stdout.splitlines()[0]
    payload_hex = controlled_row_payload(args.mb_width).hex(" ")
    print(f"generated: {args.output}")
    print(f"geometry: {args.mb_width}x{args.mb_height} macroblocks "
          f"({args.mb_width * args.mb_height} total)")
    print(f"pixels: {args.mb_width * 16}x{args.mb_height * 16}")
    print(f"bytes: {args.output.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"ffmpeg: {version}")
    print("picture order: I P I")
    print(f"P slices: 01..{args.mb_height:02x}, payload {payload_hex}")
    print("forward f_code: (2,2)")


if __name__ == "__main__":
    main()
