#!/usr/bin/env python3
"""Generate a deterministic 720x480 B-picture intra-macroblock regression.

Coded order is I/P/B and display order is I/B/P.  P is reference-exact to I.
B predicts every macroblock forward from I except row 8, column 20, which is
intra-coded with DC-only Y/Cb/Cr blocks.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h


SLICE_QSCALE = 10
INTRA_ROWS = (8, 9)
INTRA_COL = 20
Y_VALUE = 96
CB_VALUE = 128
CR_VALUE = 128
B_INTRA = "00011"  # H.262 Table B.4: intra, no macroblock_quant.
B_INTRA_QUANT = "000001"  # H.262 Table B.4: intra plus quantiser_scale_code.
B_FORWARD = "0010"
DC_LUMA = {
    0: "100", 1: "00", 2: "01", 3: "101", 4: "110", 5: "1110",
    6: "11110", 7: "111110", 8: "1111110", 9: "11111110",
    10: "111111110", 11: "111111111",
}
DC_CHROMA = {
    0: "00", 1: "01", 2: "10", 3: "110", 4: "1110", 5: "11110",
    6: "111110", 7: "1111110", 8: "11111110", 9: "111111110",
    10: "1111111110", 11: "1111111111",
}


def encode_dc_difference(difference: int, luma: bool) -> str:
    if difference == 0:
        size, payload = 0, ""
    else:
        size = abs(difference).bit_length()
        raw = difference if difference > 0 else difference + (1 << size) - 1
        payload = format(raw, f"0{size}b")
    return (DC_LUMA if luma else DC_CHROMA)[size] + payload


def intra_blocks() -> str:
    y_predictor = cb_predictor = cr_predictor = 128
    bits = ""
    for block in range(6):
        target = Y_VALUE if block < 4 else CB_VALUE if block == 4 else CR_VALUE
        predictor = y_predictor if block < 4 else cb_predictor if block == 4 else cr_predictor
        bits += encode_dc_difference(target - predictor, block < 4) + h.EOB
        if block < 4:
            y_predictor = target
        elif block == 4:
            cb_predictor = target
        else:
            cr_predictor = target
    return bits


def p_row() -> bytes:
    bits = format(SLICE_QSCALE, "05b") + "0"
    for _ in range(h.MB_WIDTH):
        bits += h.enc_mba(1) + h.P_MC_NOT_CODED
        bits += h.enc_comp(0, 0) + h.enc_comp(0, 0)
    return h.bits_to_bytes(bits)


def b_row(row: int) -> bytes:
    bits = format(SLICE_QSCALE, "05b") + "0"
    predictor = (0, 0)
    for col in range(h.MB_WIDTH):
        bits += h.enc_mba(1)
        if row in INTRA_ROWS and col == INTRA_COL:
            bits += (B_INTRA if row == INTRA_ROWS[0]
                     else B_INTRA_QUANT + format(SLICE_QSCALE, "05b"))
            bits += intra_blocks()
        else:
            bits += B_FORWARD
            bits += h.enc_comp(0, predictor[0]) + h.enc_comp(0, predictor[1])
            predictor = (0, 0)
    return h.bits_to_bytes(bits)


def verify_frame(iframe: bytes, bframe: bytes) -> None:
    expected = bytearray(iframe)
    mask = bytearray(len(expected))
    for intra_row in INTRA_ROWS:
        for block in range(6):
            if block < 4:
                x0 = INTRA_COL * 16 + (block & 1) * 8
                y0 = intra_row * 16 + ((block >> 1) & 1) * 8
                value, stride, base = Y_VALUE, h.WIDTH, 0
            else:
                x0, y0 = INTRA_COL * 8, intra_row * 8
                value = CB_VALUE if block == 4 else CR_VALUE
                stride = h.CW
                base = h.Y_SIZE if block == 4 else h.Y_SIZE + h.C_SIZE
            for yy in range(8):
                start = base + (y0 + yy) * stride + x0
                expected[start:start + 8] = bytes([value]) * 8
                mask[start:start + 8] = b"\x01" * 8
    problem = h.compare_frames(bytes(expected), bframe, bytes(mask))
    if problem:
        raise SystemExit(f"verification failed: {problem}")


def generate(output: Path) -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    output.parent.mkdir(parents=True, exist_ok=True)
    p_rows = tuple((p_row(),) for _ in range(h.MB_HEIGHT))
    b_rows = tuple((b_row(row),) for row in range(h.MB_HEIGHT))
    with tempfile.TemporaryDirectory(prefix="mister_h262_bintra_") as directory:
        temp = Path(directory)
        raw, skeleton = temp / "source.yuv", temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=3, gop=12, bframes=1)
        data = h.patch_pictures(skeleton.read_bytes(), [1, 2, 3],
                                {1: (False, p_rows), 2: (True, b_rows)})
        output.write_bytes(data)
    if h.picture_types(ffprobe, output) != ["I", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P")
    iframe, bframe, pframe = h.decode_planes(ffmpeg, output, 3)
    if iframe != pframe:
        raise SystemExit("verification failed: P reference differs from I")
    verify_frame(iframe, bframe)
    print(f"generated: {output}")
    print(f"bytes: {output.stat().st_size}")
    print(f"sha256: {hashlib.sha256(output.read_bytes()).hexdigest()}")
    print(f"intra macroblocks: rows={INTRA_ROWS} column={INTRA_COL}")
    print("expected RTL metadata: 1350 B macroblocks, 2 intra macroblocks, 12 intra blocks, 12 DC events")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().with_name("test_b_intra_macroblocks.m2v"))
    generate(parser.parse_args().output.resolve())


if __name__ == "__main__":
    main()
