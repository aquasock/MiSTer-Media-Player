#!/usr/bin/env python3
"""Generate the controlled 48x32 six-macroblock/two-row MPEG-2 regression stream.

The script uses FFmpeg to create a legal 48x32 I/P/I MPEG-2 elementary-stream
skeleton, then replaces only the controlled P-picture fields needed by the FPGA
diagnostic:

* forward f_code horizontal/vertical = (2, 2)
* slice_vertical_position 1 and 2
* three adjacent motion-forward-only macroblocks per slice
* macroblock_address_increment = 1 for every macroblock
* motion_code = (0, 0) for every macroblock
* no residual coefficients

The resulting P picture therefore reconstructs all six macroblocks by colocated
zero-vector prediction from the preceding I reference picture.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

WIDTH = 48
HEIGHT = 32
FPS = 25
SLICE_PAYLOAD = bytes.fromhex("12 79 e7")
SEQ_END = bytes.fromhex("00 00 01 b7")


def require_tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"required tool not found in PATH: {name}")
    return path


def start_codes(data: bytes | bytearray) -> list[tuple[int, int]]:
    found: list[tuple[int, int]] = []
    pos = 0
    marker = b"\x00\x00\x01"
    while True:
        pos = data.find(marker, pos)
        if pos < 0:
            return found
        if pos + 3 < len(data):
            found.append((pos, data[pos + 3]))
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


def make_source_frame() -> bytes:
    # Six visibly distinct 16x16 luma macroblocks arranged as 3 columns x 2 rows.
    values = (
        (48, 96, 144),
        (64, 128, 192),
    )
    y = bytearray(WIDTH * HEIGHT)
    for yy in range(HEIGHT):
        for xx in range(WIDTH):
            y[yy * WIDTH + xx] = values[yy // 16][xx // 16]

    chroma_width = WIDTH // 2
    chroma_height = HEIGHT // 2
    cb = bytes([96]) * (chroma_width * chroma_height)
    cr = bytes([160]) * (chroma_width * chroma_height)
    return bytes(y) + cb + cr


def generate_skeleton(ffmpeg: str, raw_path: Path, output_path: Path) -> None:
    frame = make_source_frame()
    raw_path.write_bytes(frame * 3)

    subprocess.run(
        [
            ffmpeg,
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "rawvideo",
            "-pix_fmt", "yuv420p",
            "-s", f"{WIDTH}x{HEIGHT}",
            "-r", str(FPS),
            "-i", str(raw_path),
            "-frames:v", "3",
            "-an",
            "-c:v", "mpeg2video",
            "-pix_fmt", "yuv420p",
            "-bf", "0",
            "-q:v", "2",
            "-g", "12",
            # At 25 fps, 0.08 s is frame 2 (zero based), giving I/P/I.
            "-force_key_frames", "0.08",
            "-f", "mpeg2video",
            str(output_path),
        ],
        check=True,
    )

    data = output_path.read_bytes()
    if not data.endswith(SEQ_END):
        output_path.write_bytes(data + SEQ_END)


def patch_controlled_p_picture(data: bytes) -> bytes:
    codes = start_codes(data)
    picture_offsets = [offset for offset, code in codes if code == 0x00]
    if len(picture_offsets) != 3:
        raise SystemExit(
            f"expected exactly three picture_start_codes, found {len(picture_offsets)}"
        )

    p_picture = picture_offsets[1]
    next_picture = picture_offsets[2]

    # Locate the P picture-coding extension (extension_start_code, id 8) before
    # the first P slice. f_code[0][0] and f_code[0][1] are the low nibble of
    # byte 0 and the high nibble of byte 1 following the start code.
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

    patched[pce_offset + 4] = (patched[pce_offset + 4] & 0xF0) | 0x02
    patched[pce_offset + 5] = 0x20 | (patched[pce_offset + 5] & 0x0F)

    # The 48x32 picture must contain exactly two P slices, rows 1 and 2.
    codes = start_codes(patched)
    p_region = [
        (index, offset, code)
        for index, (offset, code) in enumerate(codes)
        if p_picture < offset < next_picture and 0x01 <= code <= 0xAF
    ]
    slice_codes = [code for _, _, code in p_region]
    if slice_codes != [0x01, 0x02]:
        raise SystemExit(
            "expected P slice start codes [0x01, 0x02], got "
            + repr([hex(code) for code in slice_codes])
        )

    # Replace payloads from back to front so offset changes cannot invalidate
    # the earlier replacement coordinates. This intentionally does not depend
    # on FFmpeg choosing a particular original P-slice payload length.
    replacements: list[tuple[int, int]] = []
    for index, offset, _code in p_region:
        payload_start = offset + 4
        payload_end = codes[index + 1][0]
        replacements.append((payload_start, payload_end))

    for payload_start, payload_end in reversed(replacements):
        patched[payload_start:payload_end] = SLICE_PAYLOAD

    return bytes(patched)


def verify_output(ffmpeg: str, ffprobe: str, path: Path) -> None:
    types = picture_types(ffprobe, path)
    if types != ["I", "P", "I"]:
        raise SystemExit(f"unexpected picture order: {types!r}")

    data = path.read_bytes()
    codes = start_codes(data)
    pics = [offset for offset, code in codes if code == 0x00]
    if len(pics) != 3:
        raise SystemExit("verification failed: picture count changed")
    p_picture, next_picture = pics[1], pics[2]

    pce = None
    p_slices: list[tuple[int, bytes]] = []
    for index, (offset, code) in enumerate(codes):
        if not (p_picture < offset < next_picture):
            continue
        end = codes[index + 1][0]
        if code == 0xB5 and (data[offset + 4] >> 4) == 0x8:
            pce = data[offset + 4:end]
        elif code in (0x01, 0x02):
            p_slices.append((code, data[offset + 4:end]))

    if pce is None or len(pce) < 2:
        raise SystemExit("verification failed: missing P coding extension")
    if (pce[0] & 0x0F) != 2 or (pce[1] >> 4) != 2:
        raise SystemExit("verification failed: forward f_code is not (2,2)")
    if p_slices != [(0x01, SLICE_PAYLOAD), (0x02, SLICE_PAYLOAD)]:
        raise SystemExit(f"verification failed: unexpected controlled slices {p_slices!r}")

    # Decode to yuv420p and prove that zero-vector/no-residual P reconstruction
    # is pixel-identical to the preceding I reference frame.
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
    frame_bytes = WIDTH * HEIGHT * 3 // 2
    if len(decoded) != frame_bytes * 3:
        raise SystemExit(
            f"verification failed: decoded {len(decoded)} bytes, "
            f"expected {frame_bytes * 3}"
        )
    if decoded[:frame_bytes] != decoded[frame_bytes:2 * frame_bytes]:
        raise SystemExit("verification failed: decoded P frame differs from I reference")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "test_p_six_mb_two_row.m2v",
        help="output MPEG-2 elementary stream path",
    )
    args = parser.parse_args()

    ffmpeg = require_tool("ffmpeg")
    ffprobe = require_tool("ffprobe")
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="mister_h262_sixmb_") as temp_dir:
        temp = Path(temp_dir)
        raw_path = temp / "six_mb.yuv"
        skeleton_path = temp / "six_mb_skeleton.m2v"
        generate_skeleton(ffmpeg, raw_path, skeleton_path)

        skeleton_types = picture_types(ffprobe, skeleton_path)
        if skeleton_types != ["I", "P", "I"]:
            raise SystemExit(
                f"FFmpeg skeleton picture order changed: {skeleton_types!r}; expected I/P/I"
            )

        final_data = patch_controlled_p_picture(skeleton_path.read_bytes())
        args.output.write_bytes(final_data)

    verify_output(ffmpeg, ffprobe, args.output)

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    version = subprocess.run(
        [ffmpeg, "-version"], check=True, text=True, capture_output=True
    ).stdout.splitlines()[0]
    print(f"generated: {args.output}")
    print(f"bytes: {args.output.stat().st_size}")
    print(f"sha256: {digest}")
    print(f"ffmpeg: {version}")
    print("picture order: I P I")
    print("P slices: 01:12 79 e7, 02:12 79 e7")
    print("forward f_code: (2,2)")


if __name__ == "__main__":
    main()
