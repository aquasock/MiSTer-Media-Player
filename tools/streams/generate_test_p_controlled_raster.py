#!/usr/bin/env python3
"""Generate a controlled progressive-frame MPEG-2 I/P/I raster regression.

Transmitted P macroblocks use motion-forward-only, zero motion, and no residual.
Optional interior columns may be omitted from every slice; the resulting
macroblock_address_increment gaps are standards-defined skipped P-frame
macroblocks and reconstruct from the zero-vector forward prediction.

The default target remains 128x96 = 8x6 = 48 macroblocks with no skips so this
script continues to reproduce the accepted Phase 1U-i geometry vector.
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
MBA_VLC = {
    1: "1", 2: "011", 3: "010", 4: "0011", 5: "0010",
    6: "00011", 7: "00010", 8: "0000111", 9: "0000110",
    10: "00001011", 11: "00001010", 12: "00001001", 13: "00001000",
    14: "00000111", 15: "00000110", 16: "0000010111", 17: "0000010110",
    18: "0000010101", 19: "0000010100", 20: "0000010011", 21: "0000010010",
    22: "00000100011", 23: "00000100010", 24: "00000100001", 25: "00000100000",
    26: "00000011111", 27: "00000011110", 28: "00000011101", 29: "00000011100",
    30: "00000011011", 31: "00000011010", 32: "00000011001", 33: "00000011000",
}
MBA_ESCAPE = "00000001000"


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
        [ffprobe, "-v", "error", "-select_streams", "v:0",
         "-show_entries", "frame=pict_type", "-of", "csv=p=0", str(path)],
        check=True, text=True, capture_output=True,
    )
    return [line.strip().strip(",") for line in result.stdout.replace("\r", "").splitlines() if line.strip()]


def mba_bits(increment: int) -> str:
    if increment <= 0:
        raise ValueError("macroblock_address_increment must be positive")
    parts: list[str] = []
    while increment > 33:
        parts.append(MBA_ESCAPE)
        increment -= 33
    parts.append(MBA_VLC[increment])
    return "".join(parts)


def controlled_row_payload(mb_width: int, skipped_columns: frozenset[int]) -> bytes:
    # quantiser_scale_code=2 => 00010, extra_bit_slice=0 => 0
    bits = "000100"
    previous = -1
    for column in range(mb_width):
        if column in skipped_columns:
            continue
        increment = column - previous
        # Table B.1 MBA, Table B.3 motion-forward-only 001, then horizontal
        # and vertical Table B.10 motion_code zero (1, 1).
        bits += mba_bits(increment) + "00111"
        previous = column
    bits += "0" * ((8 - (len(bits) % 8)) % 8)
    return int(bits, 2).to_bytes(len(bits) // 8, "big")


def parse_skip_columns(text: str) -> frozenset[int]:
    if not text.strip():
        return frozenset()
    try:
        return frozenset(int(item.strip()) for item in text.split(",") if item.strip())
    except ValueError as exc:
        raise SystemExit("--skip-cols must be a comma-separated list of integer macroblock columns") from exc


def make_source_frame(mb_width: int, mb_height: int) -> bytes:
    width = mb_width * 16
    height = mb_height * 16
    y = bytearray(width * height)
    for yy in range(height):
        mb_y = yy // 16
        for xx in range(width):
            mb_x = xx // 16
            y[yy * width + xx] = 32 + ((mb_y * 29 + mb_x * 17) % 176)
    cw, ch = width // 2, height // 2
    return bytes(y) + bytes([96]) * (cw * ch) + bytes([160]) * (cw * ch)


def generate_skeleton(ffmpeg: str, raw_path: Path, output_path: Path, mb_width: int, mb_height: int) -> None:
    width = mb_width * 16
    height = mb_height * 16
    frame = make_source_frame(mb_width, mb_height)
    raw_path.write_bytes(frame * 3)
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "yuv420p", "-s", f"{width}x{height}",
         "-r", str(FPS), "-i", str(raw_path), "-frames:v", "3", "-an",
         "-c:v", "mpeg2video", "-pix_fmt", "yuv420p", "-bf", "0",
         "-q:v", "2", "-g", "12", "-force_key_frames", "0.08",
         "-f", "mpeg2video", str(output_path)],
        check=True,
    )
    data = output_path.read_bytes()
    if not data.endswith(SEQ_END):
        output_path.write_bytes(data + SEQ_END)


def patch_controlled_p_picture(data: bytes, mb_width: int, mb_height: int, skipped_columns: frozenset[int]) -> bytes:
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0x00]
    if len(pictures) != 3:
        raise SystemExit(f"expected exactly three pictures, found {len(pictures)}")
    p_picture, next_picture = pictures[1], pictures[2]
    patched = bytearray(data)

    pce_offset: int | None = None
    for offset, code in codes:
        if p_picture < offset < next_picture and code == 0xB5 and offset + 5 < len(patched):
            if (patched[offset + 4] >> 4) == 0x8:
                pce_offset = offset
                break
    if pce_offset is None:
        raise SystemExit("P picture_coding_extension() not found")

    patched[pce_offset + 4] = (patched[pce_offset + 4] & 0xF0) | 0x02
    patched[pce_offset + 5] = 0x20 | (patched[pce_offset + 5] & 0x0F)

    codes = start_codes(patched)
    expected_slice_codes = tuple(range(1, mb_height + 1))
    region = [(index, offset, code) for index, (offset, code) in enumerate(codes)
              if p_picture < offset < next_picture and 0x01 <= code <= 0xAF]
    got = tuple(code for _, _, code in region)
    if got != expected_slice_codes:
        raise SystemExit(f"expected P slices {expected_slice_codes!r}, got {got!r}")

    payload = controlled_row_payload(mb_width, skipped_columns)
    replacements = [(offset + 4, codes[index + 1][0]) for index, offset, _code in region]
    for payload_start, payload_end in reversed(replacements):
        patched[payload_start:payload_end] = payload
    return bytes(patched)


def verify_output(ffmpeg: str, ffprobe: str, path: Path, mb_width: int, mb_height: int,
                  skipped_columns: frozenset[int]) -> None:
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
    expected_payload = controlled_row_payload(mb_width, skipped_columns)
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
    if p_slices != [(code, expected_payload) for code in expected_slice_codes]:
        raise SystemExit(f"verification failed: unexpected slices {p_slices!r}")

    width = mb_width * 16
    height = mb_height * 16
    decoded = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"],
        check=True, capture_output=True,
    ).stdout
    frame_bytes = width * height * 3 // 2
    if len(decoded) != frame_bytes * 3:
        raise SystemExit(f"verification failed: decoded {len(decoded)} bytes, expected {frame_bytes * 3}")
    if decoded[:frame_bytes] != decoded[frame_bytes:2 * frame_bytes]:
        raise SystemExit("verification failed: decoded P frame differs from I reference")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mb-width", type=int, default=8)
    parser.add_argument("--mb-height", type=int, default=6)
    parser.add_argument("--skip-cols", default="",
                        help="comma-separated interior macroblock columns omitted from every P slice")
    parser.add_argument("-o", "--output", type=Path, default=None)
    args = parser.parse_args()

    if not (2 <= args.mb_width <= 45):
        raise SystemExit("--mb-width must be in the controlled decoder range 2..45")
    if not (2 <= args.mb_height <= 30):
        raise SystemExit("--mb-height must be in the controlled decoder range 2..30")

    skipped_columns = parse_skip_columns(args.skip_cols)
    if any(column <= 0 or column >= args.mb_width - 1 for column in skipped_columns):
        raise SystemExit("--skip-cols may contain only interior columns; first/last slice macroblocks stay coded")

    if args.output is None:
        name = "test_p_skipped_mb.m2v" if skipped_columns else "test_p_fortyeight_mb_six_row.m2v"
        args.output = Path(__file__).resolve().parent / name

    ffmpeg = require_tool("ffmpeg")
    ffprobe = require_tool("ffprobe")
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="mister_h262_raster_") as temp_dir:
        temp = Path(temp_dir)
        raw_path = temp / "raster.yuv"
        skeleton_path = temp / "raster_skeleton.m2v"
        generate_skeleton(ffmpeg, raw_path, skeleton_path, args.mb_width, args.mb_height)
        skeleton_types = picture_types(ffprobe, skeleton_path)
        if skeleton_types != ["I", "P", "I"]:
            raise SystemExit(f"FFmpeg skeleton picture order changed: {skeleton_types!r}")
        args.output.write_bytes(
            patch_controlled_p_picture(skeleton_path.read_bytes(), args.mb_width, args.mb_height, skipped_columns)
        )

    verify_output(ffmpeg, ffprobe, args.output, args.mb_width, args.mb_height, skipped_columns)
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    version = subprocess.run([ffmpeg, "-version"], check=True, text=True, capture_output=True).stdout.splitlines()[0]
    payload_hex = controlled_row_payload(args.mb_width, skipped_columns).hex(" ")
    print(f"generated: {args.output}")
    print(f"geometry: {args.mb_width}x{args.mb_height} macroblocks ({args.mb_width * args.mb_height} total)")
    print(f"pixels: {args.mb_width * 16}x{args.mb_height * 16}")
    print(f"skipped columns per row: {','.join(map(str, sorted(skipped_columns))) or 'none'}")
    print(f"bytes: {args.output.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"ffmpeg: {version}")
    print("picture order: I P I")
    print(f"P slices: 01..{args.mb_height:02x}, payload {payload_hex}")
    print("forward f_code: (2,2)")


if __name__ == "__main__":
    main()
