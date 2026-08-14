#!/usr/bin/env python3
"""Generate a controlled H.262 I/P1/P2/I consecutive-P reference regression.

P1 uses the accepted six-row per-macroblock dispatch map.  P2 uses the accepted
legacy aligned-motion map (column 0 shifted right in every row).  The script
verifies with FFmpeg that P2 is reconstructed from decoded P1, not directly from
I, by comparing exact Y/Cb/Cr frames against a software reference chain.
"""
from __future__ import annotations

import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

FPS = 25
SEQ_END = bytes.fromhex("00 00 01 b7")
MB_WIDTH = 8
MB_HEIGHT = 6
WIDTH = MB_WIDTH * 16
HEIGHT = MB_HEIGHT * 16

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
MOTION_CODE_POS8 = "0000010110"
MOTION_CODE_ZERO = "1"


def require_tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"required tool not found in PATH: {name}")
    return path


def start_codes(data: bytes | bytearray) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    pos = 0
    while True:
        pos = data.find(b"\x00\x00\x01", pos)
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


def bits_to_bytes(bits: str) -> bytes:
    bits += "0" * ((8 - (len(bits) % 8)) % 8)
    return int(bits, 2).to_bytes(len(bits) // 8, "big")


def row_payload(shift_column: int) -> bytes:
    # quantiser_scale_code=2, extra_bit_slice=0.  The macroblock immediately
    # following the shifted macroblock is skipped to reset PMV to zero.
    bits = "000100"
    previous = -1
    for column in range(MB_WIDTH):
        if column == shift_column + 1:
            continue
        increment = column - previous
        if column == shift_column:
            bits += MBA_VLC[increment] + "001" + MOTION_CODE_POS8 + "11" + MOTION_CODE_ZERO
        else:
            bits += MBA_VLC[increment] + "001" + MOTION_CODE_ZERO + MOTION_CODE_ZERO
        previous = column
    return bits_to_bytes(bits)


P1_PAYLOADS = tuple(row_payload(row) for row in range(MB_HEIGHT))
P2_PAYLOADS = tuple(row_payload(0) for _ in range(MB_HEIGHT))
P1_SHIFT_COLUMNS = tuple(range(MB_HEIGHT))
P2_SHIFT_COLUMNS = tuple(0 for _ in range(MB_HEIGHT))


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
    raw_path.write_bytes(make_source_frame() * 4)
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "yuv420p", "-s", f"{WIDTH}x{HEIGHT}",
         "-r", str(FPS), "-i", str(raw_path), "-frames:v", "4", "-an",
         "-c:v", "mpeg2video", "-pix_fmt", "yuv420p", "-bf", "0",
         "-q:v", "2", "-g", "12", "-force_key_frames", "0.12",
         "-f", "mpeg2video", str(output_path)],
        check=True,
    )
    data = output_path.read_bytes()
    if not data.endswith(SEQ_END):
        output_path.write_bytes(data + SEQ_END)


def patch_p_pictures(data: bytes) -> bytes:
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0x00]
    if len(pictures) != 4:
        raise SystemExit(f"expected exactly four pictures, found {len(pictures)}")

    patched = bytearray(data)
    replacements: list[tuple[int, int, bytes]] = []
    for p_index, payloads in ((1, P1_PAYLOADS), (2, P2_PAYLOADS)):
        picture_start = pictures[p_index]
        picture_end = pictures[p_index + 1]
        pce_offset = None
        slice_regions: list[tuple[int, int, int]] = []
        for index, (offset, code) in enumerate(codes):
            if not (picture_start < offset < picture_end):
                continue
            if code == 0xB5 and offset + 5 < len(patched) and (patched[offset + 4] >> 4) == 0x8:
                pce_offset = offset
            if 1 <= code <= MB_HEIGHT:
                end = codes[index + 1][0]
                slice_regions.append((code, offset + 4, end))
        if pce_offset is None:
            raise SystemExit(f"P{p_index} picture_coding_extension() not found")
        patched[pce_offset + 4] = (patched[pce_offset + 4] & 0xF0) | 3
        patched[pce_offset + 5] = 0x30 | (patched[pce_offset + 5] & 0x0F)
        if tuple(code for code, _, _ in slice_regions) != tuple(range(1, MB_HEIGHT + 1)):
            raise SystemExit(f"unexpected P{p_index} slice layout")
        for row, (_, start, end) in enumerate(slice_regions):
            replacements.append((start, end, payloads[row]))

    for start, end, payload in sorted(replacements, reverse=True):
        patched[start:end] = payload
    return bytes(patched)


def apply_shift_plan(frame: bytes, shift_columns: tuple[int, ...]) -> bytes:
    cw, ch = WIDTH // 2, HEIGHT // 2
    y_size = WIDTH * HEIGHT
    c_size = cw * ch
    out = bytearray(frame)
    for row, shift_column in enumerate(shift_columns):
        for yy in range(row * 16, (row + 1) * 16):
            base = yy * WIDTH + shift_column * 16
            out[base:base + 16] = frame[base + 16:base + 32]
        for plane in (y_size, y_size + c_size):
            for yy in range(row * 8, (row + 1) * 8):
                base = plane + yy * cw + shift_column * 8
                out[base:base + 8] = frame[base + 8:base + 16]
    return bytes(out)


def verify(ffmpeg: str, ffprobe: str, output: Path) -> None:
    if picture_types(ffprobe, output) != ["I", "P", "P", "I"]:
        raise SystemExit("verification failed: picture order is not I/P/P/I")
    data = output.read_bytes()
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0x00]
    for p_index, payloads in ((1, P1_PAYLOADS), (2, P2_PAYLOADS)):
        picture_start = pictures[p_index]
        picture_end = pictures[p_index + 1]
        pce = None
        slices: list[tuple[int, bytes]] = []
        for index, (offset, code) in enumerate(codes):
            if not (picture_start < offset < picture_end):
                continue
            end = codes[index + 1][0]
            if code == 0xB5 and (data[offset + 4] >> 4) == 0x8:
                pce = data[offset + 4:end]
            elif 1 <= code <= MB_HEIGHT:
                slices.append((code, data[offset + 4:end]))
        if pce is None or len(pce) < 2 or (pce[0] & 0x0F) != 3 or (pce[1] >> 4) != 3:
            raise SystemExit(f"verification failed: P{p_index} forward f_code is not (3,3)")
        expected_slices = [(row + 1, payloads[row]) for row in range(MB_HEIGHT)]
        if slices != expected_slices:
            raise SystemExit(f"verification failed: unexpected P{p_index} slices {slices!r}")

    decoded = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(output),
         "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"],
        check=True, capture_output=True,
    ).stdout
    frame_bytes = WIDTH * HEIGHT * 3 // 2
    if len(decoded) != frame_bytes * 4:
        raise SystemExit("verification failed: unexpected decoded size")
    frames = [decoded[i * frame_bytes:(i + 1) * frame_bytes] for i in range(4)]
    expected_p1 = apply_shift_plan(frames[0], P1_SHIFT_COLUMNS)
    expected_p2 = apply_shift_plan(expected_p1, P2_SHIFT_COLUMNS)
    if frames[1] != expected_p1:
        raise SystemExit("verification failed: P1 differs from expected dispatch reconstruction")
    if frames[2] != expected_p2:
        raise SystemExit("verification failed: P2 differs from reconstruction using P1 as reference")
    if frames[2] == apply_shift_plan(frames[0], P2_SHIFT_COLUMNS):
        raise SystemExit("verification failed: P2 does not distinguish P1-reference use from I-reference use")
    if frames[2] == frames[1]:
        raise SystemExit("verification failed: P2 did not materially change from P1")


def main() -> None:
    ffmpeg = require_tool("ffmpeg")
    ffprobe = require_tool("ffprobe")
    output = Path(__file__).resolve().parent / "test_p_consecutive_reference.m2v"
    with tempfile.TemporaryDirectory(prefix="mister_h262_ppref_") as temp_dir:
        temp = Path(temp_dir)
        skeleton = temp / "skeleton.m2v"
        generate_skeleton(ffmpeg, temp / "source.yuv", skeleton)
        if picture_types(ffprobe, skeleton) != ["I", "P", "P", "I"]:
            raise SystemExit("FFmpeg skeleton picture order changed")
        output.write_bytes(patch_p_pictures(skeleton.read_bytes()))
    verify(ffmpeg, ffprobe, output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    version = subprocess.run([ffmpeg, "-version"], check=True, text=True, capture_output=True).stdout.splitlines()[0]
    print(f"generated: {output}")
    print("geometry: 8x6 macroblocks (128x96, 48 total)")
    print(f"bytes: {output.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"ffmpeg: {version}")
    print("picture order: I P P I")
    print("P1 shift map: 0x201008040201")
    print("P2 shift map: 0x010101010101")
    print("P2 software verification uses reconstructed P1 as its forward reference")


if __name__ == "__main__":
    main()
