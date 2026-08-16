#!/usr/bin/env python3
"""Generate the Commit-166 720x480 generalized-P regression.

The deterministic I/P/I elementary stream keeps the existing progressive 4:2:0
scope while expanding the P raster to 45x30 macroblocks. The patched P picture
contains ordered zero/non-zero signed half-sample motion, internal skipped
macroblocks, and one sparse non-intra Y residual block. Generated .m2v output is
local-only; do not commit the binary.
"""
from __future__ import annotations

import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

FPS = 25
WIDTH = 720
HEIGHT = 480
MB_WIDTH = 45
MB_HEIGHT = 30
SEQ_END = bytes.fromhex("00 00 01 b7")

MBA_VLC = {
    1:"1",2:"011",3:"010",4:"0011",5:"0010",6:"00011",7:"00010",
    8:"0000111",9:"0000110",10:"00001011",11:"00001010",
    12:"00001001",13:"00001000",14:"00000111",15:"00000110",
    16:"0000010111",17:"0000010110",18:"0000010101",19:"0000010100",
    20:"0000010011",21:"0000010010",22:"00000100011",23:"00000100010",
    24:"00000100001",25:"00000100000",26:"00000011111",
    27:"00000011110",28:"00000011101",29:"00000011100",
    30:"00000011011",31:"00000011010",32:"00000011001",
    33:"00000011000",
}
MCODE = {
    -16:"00000011001",-15:"00000011011",-14:"00000011101",
    -13:"00000011111",-12:"00000100001",-11:"00000100011",
    -10:"0000010011",-9:"0000010101",-8:"0000010111",-7:"00000111",
    -6:"00001001",-5:"00001011",-4:"0000111",-3:"00011",-2:"0011",
    -1:"011",0:"1",1:"010",2:"0010",3:"00010",4:"0000110",
    5:"00001010",6:"00001000",7:"00000110",8:"0000010110",
    9:"0000010100",10:"0000010010",11:"00000100010",
    12:"00000100000",13:"00000011110",14:"00000011100",
    15:"00000011010",16:"00000011000",
}

SKIPPED = {(5, 5), (20, 30)}
RESIDUAL_MB = (15, 20)


def require(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise SystemExit(f"required tool not found in PATH: {name}")
    return path


def start_codes(data: bytes):
    out = []
    pos = 0
    while True:
        pos = data.find(b"\x00\x00\x01", pos)
        if pos < 0:
            return out
        if pos + 3 < len(data):
            out.append((pos, data[pos + 3]))
        pos += 4


def picture_types(ffprobe: str, path: Path):
    result = subprocess.run(
        [
            ffprobe, "-v", "error", "-select_streams", "v:0",
            "-show_entries", "frame=pict_type", "-of", "csv=p=0", str(path),
        ],
        check=True, text=True, capture_output=True,
    )
    return [
        line.strip().strip(",")
        for line in result.stdout.replace("\r", "").splitlines()
        if line.strip()
    ]


def bits_to_bytes(bits: str) -> bytes:
    bits += "0" * ((-len(bits)) % 8)
    return int(bits, 2).to_bytes(len(bits) // 8, "big")


def delta_for(target: int, predictor: int) -> int:
    delta = target - predictor
    while delta > 63:
        delta -= 128
    while delta < -64:
        delta += 128
    return delta


def encode_component(target: int, predictor: int) -> str:
    delta = delta_for(target, predictor)
    if delta == 0:
        return MCODE[0]
    magnitude = abs(delta)
    motion_code = (magnitude - 1) // 4 + 1
    residual = (magnitude - 1) % 4
    if delta < 0:
        motion_code = -motion_code
    return MCODE[motion_code] + format(residual, "02b")


def target_vector(row: int, col: int):
    # Keep interpolation footprints away from frame edges.
    if col == 10 and row % 4 == 1 and row < MB_HEIGHT - 1:
        return (1, 1)
    if col == 20 and row % 6 == 2 and row < MB_HEIGHT - 1:
        return (-1, 1)
    return (0, 0)


def row_payload(row: int) -> bytes:
    bits = format(10 + (row % 5), "05b") + "0"
    previous_col = -1
    pred_x = pred_y = 0

    for col in range(MB_WIDTH):
        if (row, col) in SKIPPED:
            continue

        increment = col - previous_col
        if increment > 1:
            pred_x = pred_y = 0
        bits += MBA_VLC[increment]

        has_residual = (row, col) == RESIDUAL_MB
        bits += "1" if has_residual else "001"

        target_x, target_y = target_vector(row, col)
        bits += encode_component(target_x, pred_x)
        bits += encode_component(target_y, pred_y)
        pred_x, pred_y = target_x, target_y

        if has_residual:
            bits += "1010"
            bits += "10"
            bits += "10"

        previous_col = col

    return bits_to_bytes(bits)


ROW_PAYLOADS = tuple(row_payload(row) for row in range(MB_HEIGHT))


def source_frame() -> bytes:
    y = bytearray(WIDTH * HEIGHT)
    for yy in range(HEIGHT):
        for xx in range(WIDTH):
            y[yy * WIDTH + xx] = 24 + ((xx * 3 + yy * 5) % 200)

    cw, ch = WIDTH // 2, HEIGHT // 2
    cb = bytearray(cw * ch)
    cr = bytearray(cw * ch)
    for yy in range(ch):
        for xx in range(cw):
            cb[yy * cw + xx] = 72 + ((xx * 5 + yy * 3) % 112)
            cr[yy * cw + xx] = 88 + ((xx * 2 + yy * 7) % 96)
    return bytes(y) + bytes(cb) + bytes(cr)


def make_skeleton(ffmpeg: str, raw_path: Path, out_path: Path) -> None:
    raw_path.write_bytes(source_frame() * 3)
    subprocess.run(
        [
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-f", "rawvideo", "-pix_fmt", "yuv420p",
            "-s", f"{WIDTH}x{HEIGHT}", "-r", str(FPS), "-i", str(raw_path),
            "-frames:v", "3", "-an", "-c:v", "mpeg2video",
            "-pix_fmt", "yuv420p", "-bf", "0", "-q:v", "2", "-g", "12",
            "-force_key_frames", "0.08", "-f", "mpeg2video", str(out_path),
        ],
        check=True,
    )
    data = out_path.read_bytes()
    if not data.endswith(SEQ_END):
        out_path.write_bytes(data + SEQ_END)


def patch(data: bytes) -> bytes:
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0]
    if len(pictures) != 3:
        raise SystemExit(f"expected 3 pictures, found {len(pictures)}")

    p_start, next_start = pictures[1], pictures[2]
    patched = bytearray(data)

    pce = None
    for offset, code in codes:
        if (
            p_start < offset < next_start
            and code == 0xB5
            and offset + 8 < len(patched)
            and (patched[offset + 4] >> 4) == 8
        ):
            pce = offset
            break
    if pce is None:
        raise SystemExit("P picture_coding_extension not found")

    patched[pce + 4] = (patched[pce + 4] & 0xF0) | 3
    patched[pce + 5] = 0x30 | (patched[pce + 5] & 0x0F)
    patched[pce + 7] = (patched[pce + 7] | 0x40) & ~(0x20 | 0x10 | 0x04)

    codes = start_codes(patched)
    rows = [
        (index, offset, code)
        for index, (offset, code) in enumerate(codes)
        if p_start < offset < next_start and 1 <= code <= MB_HEIGHT
    ]
    expected_codes = tuple(range(1, MB_HEIGHT + 1))
    if tuple(code for _, _, code in rows) != expected_codes:
        raise SystemExit("unexpected P slice layout in FFmpeg skeleton")

    replacements = [
        (offset + 4, codes[index + 1][0])
        for index, offset, _ in rows
    ]
    for row, (start, end) in reversed(list(enumerate(replacements))):
        patched[start:end] = ROW_PAYLOADS[row]

    return bytes(patched)


def verify(ffmpeg: str, ffprobe: str, path: Path) -> None:
    if picture_types(ffprobe, path) != ["I", "P", "I"]:
        raise SystemExit("picture order is not I/P/I")

    data = path.read_bytes()
    codes = start_codes(data)
    pictures = [offset for offset, code in codes if code == 0]
    p_start, next_start = pictures[1], pictures[2]

    pce = None
    slices = []
    for index, (offset, code) in enumerate(codes):
        if not (p_start < offset < next_start):
            continue
        end = codes[index + 1][0]
        if code == 0xB5 and (data[offset + 4] >> 4) == 8:
            pce = data[offset + 4:end]
        elif 1 <= code <= MB_HEIGHT:
            slices.append((code, data[offset + 4:end]))

    if pce is None or len(pce) < 4:
        raise SystemExit("P picture_coding_extension missing/short")
    if (pce[0] & 0xF) != 3 or (pce[1] >> 4) != 3:
        raise SystemExit("forward f_code is not (3,3)")
    if slices != [
        (row + 1, ROW_PAYLOADS[row]) for row in range(MB_HEIGHT)
    ]:
        raise SystemExit("patched P slices do not match deterministic payloads")

    subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(path), "-f", "null", "-"],
        check=True,
    )


def main() -> None:
    ffmpeg = require("ffmpeg")
    ffprobe = require("ffprobe")
    out = Path(__file__).resolve().parent / "test_p_720x480_general_decode.m2v"

    with tempfile.TemporaryDirectory(prefix="mister_h262_p720_") as temp_dir:
        temp = Path(temp_dir)
        skeleton = temp / "skeleton.m2v"
        make_skeleton(ffmpeg, temp / "source.yuv", skeleton)
        if picture_types(ffprobe, skeleton) != ["I", "P", "I"]:
            raise SystemExit("FFmpeg skeleton picture order changed")
        out.write_bytes(patch(skeleton.read_bytes()))

    verify(ffmpeg, ffprobe, out)
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {hashlib.sha256(out.read_bytes()).hexdigest()}")
    print("picture order: I P I; forward f_code=(3,3)")
    print(f"skipped macroblocks: {sorted(SKIPPED)}")
    print(f"sparse residual macroblock: {RESIDUAL_MB}, Y0, +1 then EOB")
    print("non-zero half-sample vectors occur at safe interior macroblocks")


if __name__ == "__main__":
    main()
