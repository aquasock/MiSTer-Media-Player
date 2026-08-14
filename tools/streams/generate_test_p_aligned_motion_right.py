#!/usr/bin/env python3
"""Generate the controlled 128x96 H.262 P aligned-motion regression.

Each P slice has eight macroblock positions:
  col0: coded forward vector (+32,0) luma half-sample units, f_code=(3,3)
  col1: skipped (which resets the P-frame predictor to zero)
  col2: coded MBA increment 2, vector (0,0)
  col3..7: coded MBA increment 1, vector (0,0)
There are no residual coefficients.
"""
from __future__ import annotations

import hashlib
import subprocess
import tempfile
from pathlib import Path

from generate_test_p_controlled_raster import FPS, SEQ_END, picture_types, require_tool, start_codes

MB_WIDTH = 8
MB_HEIGHT = 6
WIDTH = MB_WIDTH * 16
HEIGHT = MB_HEIGHT * 16
ROW_PAYLOAD = bytes.fromhex("12 41 6e cf 3c f3 cf 38")


def make_source_frame() -> bytes:
    y = bytearray(WIDTH * HEIGHT)
    for yy in range(HEIGHT):
        mb_y = yy // 16
        for xx in range(WIDTH):
            mb_x = xx // 16
            y[yy * WIDTH + xx] = 32 + ((mb_y * 29 + mb_x * 17) % 176)
    cw, ch = WIDTH // 2, HEIGHT // 2
    cb = bytearray(cw * ch)
    cr = bytearray(cw * ch)
    for yy in range(ch):
        mb_y = yy // 8
        for xx in range(cw):
            mb_x = xx // 8
            cb[yy * cw + xx] = 48 + ((mb_y * 19 + mb_x * 23) % 144)
            cr[yy * cw + xx] = 64 + ((mb_y * 31 + mb_x * 13) % 128)
    return bytes(y) + bytes(cb) + bytes(cr)


def generate_skeleton(ffmpeg: str, raw_path: Path, output_path: Path) -> None:
    raw_path.write_bytes(make_source_frame() * 3)
    subprocess.run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "yuv420p", "-s", f"{WIDTH}x{HEIGHT}",
        "-r", str(FPS), "-i", str(raw_path), "-frames:v", "3", "-an",
        "-c:v", "mpeg2video", "-pix_fmt", "yuv420p", "-bf", "0",
        "-q:v", "2", "-g", "12", "-force_key_frames", "0.08",
        "-f", "mpeg2video", str(output_path),
    ], check=True)
    data = output_path.read_bytes()
    if not data.endswith(SEQ_END):
        output_path.write_bytes(data + SEQ_END)


def patch_p_picture(data: bytes) -> bytes:
    codes = start_codes(data)
    pictures = [off for off, code in codes if code == 0x00]
    if len(pictures) != 3:
        raise SystemExit(f"expected exactly three pictures, found {len(pictures)}")
    p_picture, next_picture = pictures[1], pictures[2]
    patched = bytearray(data)
    pce_offset = None
    for off, code in codes:
        if p_picture < off < next_picture and code == 0xB5 and off + 5 < len(patched):
            if (patched[off + 4] >> 4) == 0x8:
                pce_offset = off
                break
    if pce_offset is None:
        raise SystemExit("P picture_coding_extension() not found")
    patched[pce_offset + 4] = (patched[pce_offset + 4] & 0xF0) | 3
    patched[pce_offset + 5] = 0x30 | (patched[pce_offset + 5] & 0x0F)
    codes = start_codes(patched)
    region = [(idx, off, code) for idx, (off, code) in enumerate(codes)
              if p_picture < off < next_picture and 1 <= code <= MB_HEIGHT]
    if tuple(code for _, _, code in region) != tuple(range(1, MB_HEIGHT + 1)):
        raise SystemExit("unexpected P slice layout")
    replacements = [(off + 4, codes[idx + 1][0]) for idx, off, _ in region]
    for start, end in reversed(replacements):
        patched[start:end] = ROW_PAYLOAD
    return bytes(patched)


def expected_p_from_i(frame: bytes) -> bytes:
    cw, ch = WIDTH // 2, HEIGHT // 2
    y_size = WIDTH * HEIGHT
    c_size = cw * ch
    out = bytearray(frame)
    for yy in range(HEIGHT):
        base = yy * WIDTH
        out[base:base + 16] = frame[base + 16:base + 32]
    for plane in (y_size, y_size + c_size):
        for yy in range(ch):
            base = plane + yy * cw
            out[base:base + 8] = frame[base + 8:base + 16]
    return bytes(out)


def verify(ffmpeg: str, ffprobe: str, output: Path) -> None:
    if picture_types(ffprobe, output) != ["I", "P", "I"]:
        raise SystemExit("verification failed: picture order is not I/P/I")
    data = output.read_bytes()
    codes = start_codes(data)
    pictures = [off for off, code in codes if code == 0x00]
    p_picture, next_picture = pictures[1], pictures[2]
    pce = None
    slices = []
    for idx, (off, code) in enumerate(codes):
        if not (p_picture < off < next_picture):
            continue
        end = codes[idx + 1][0]
        if code == 0xB5 and (data[off + 4] >> 4) == 0x8:
            pce = data[off + 4:end]
        elif 1 <= code <= MB_HEIGHT:
            slices.append((code, data[off + 4:end]))
    if pce is None or len(pce) < 2 or (pce[0] & 0x0F) != 3 or (pce[1] >> 4) != 3:
        raise SystemExit("verification failed: forward f_code is not (3,3)")
    if slices != [(row, ROW_PAYLOAD) for row in range(1, MB_HEIGHT + 1)]:
        raise SystemExit(f"verification failed: unexpected P slices {slices!r}")
    decoded = subprocess.run([
        ffmpeg, "-v", "error", "-i", str(output),
        "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"
    ], check=True, capture_output=True).stdout
    frame_bytes = WIDTH * HEIGHT * 3 // 2
    if len(decoded) != frame_bytes * 3:
        raise SystemExit("verification failed: unexpected decoded size")
    i_frame = decoded[:frame_bytes]
    p_frame = decoded[frame_bytes:2 * frame_bytes]
    if p_frame != expected_p_from_i(i_frame):
        raise SystemExit("verification failed: P frame differs from expected aligned-motion prediction")
    if p_frame == i_frame:
        raise SystemExit("verification failed: P frame did not change")


def main() -> None:
    ffmpeg = require_tool("ffmpeg")
    ffprobe = require_tool("ffprobe")
    output = Path(__file__).resolve().parent / "test_p_aligned_motion_right.m2v"
    with tempfile.TemporaryDirectory(prefix="mister_h262_aligned_") as temp_dir:
        temp = Path(temp_dir)
        skeleton = temp / "skeleton.m2v"
        generate_skeleton(ffmpeg, temp / "source.yuv", skeleton)
        if picture_types(ffprobe, skeleton) != ["I", "P", "I"]:
            raise SystemExit("FFmpeg skeleton picture order changed")
        output.write_bytes(patch_p_picture(skeleton.read_bytes()))
    verify(ffmpeg, ffprobe, output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    version = subprocess.run([ffmpeg, "-version"], check=True, text=True, capture_output=True).stdout.splitlines()[0]
    print(f"generated: {output}")
    print("geometry: 8x6 macroblocks (128x96, 48 total)")
    print(f"bytes: {output.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"ffmpeg: {version}")
    print("picture order: I P I")
    print(f"P slices: 01..06, payload {ROW_PAYLOAD.hex(' ')}")
    print("forward f_code: (3,3); first MB vector (+32,0); column 1 skipped")


if __name__ == "__main__":
    main()
