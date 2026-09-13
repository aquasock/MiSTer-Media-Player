#!/usr/bin/env python3
"""Generate a deterministic 720x480 P-picture intra-macroblock regression.

Coded/display order is I/P.  The P picture predicts every macroblock from the
I reference except row 8, column 20, which is intra-coded with DC-only Y/Cb/Cr
blocks.  FFmpeg decoding is checked against the motion/reference model outside
that macroblock and against its authored constant planes within one IDCT LSB.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h


SLICE_QSCALE = 10
INTRA_ROW = 8
INTRA_COL = 20
Y_VALUE = 96
CB_VALUE = 128
CR_VALUE = 128
P_INTRA = "00011"  # H.262 Table B.3: intra, no macroblock_quant.

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
        size = 0
        payload = ""
    else:
        size = abs(difference).bit_length()
        if not 1 <= size <= 11:
            raise ValueError(difference)
        raw = difference if difference > 0 else difference + (1 << size) - 1
        payload = format(raw, f"0{size}b")
    return (DC_LUMA if luma else DC_CHROMA)[size] + payload


def intra_blocks() -> str:
    # Table 7-2 predictors reset to 128 at this slice's preceding non-intra MB.
    y_predictor = cb_predictor = cr_predictor = 128
    bits = ""
    for block in range(6):
        target = Y_VALUE if block < 4 else CB_VALUE if block == 4 else CR_VALUE
        predictor = y_predictor if block < 4 else cb_predictor if block == 4 else cr_predictor
        bits += encode_dc_difference(target - predictor, block < 4)
        bits += h.EOB
        if block < 4:
            y_predictor = target
        elif block == 4:
            cb_predictor = target
        else:
            cr_predictor = target
    return bits


def p_row(row: int) -> bytes:
    bits = format(SLICE_QSCALE, "05b") + "0"
    predictor = (0, 0)
    for col in range(h.MB_WIDTH):
        bits += h.enc_mba(1)
        if row == INTRA_ROW and col == INTRA_COL:
            bits += P_INTRA + intra_blocks()
            predictor = (0, 0)
        else:
            bits += h.P_MC_NOT_CODED
            bits += h.enc_comp(0, predictor[0]) + h.enc_comp(0, predictor[1])
            predictor = (0, 0)
    return h.bits_to_bytes(bits)


def verify_frame(iframe: bytes, pframe: bytes) -> None:
    expected = bytearray(iframe)
    mask = bytearray(len(expected))
    for block in range(6):
        if block < 4:
            x0 = INTRA_COL * 16 + (block & 1) * 8
            y0 = INTRA_ROW * 16 + ((block >> 1) & 1) * 8
            value = Y_VALUE
            stride = h.WIDTH
            base = 0
        else:
            x0 = INTRA_COL * 8
            y0 = INTRA_ROW * 8
            value = CB_VALUE if block == 4 else CR_VALUE
            stride = h.CW
            base = h.Y_SIZE if block == 4 else h.Y_SIZE + h.C_SIZE
        for yy in range(8):
            start = base + (y0 + yy) * stride + x0
            expected[start:start + 8] = bytes([value]) * 8
            mask[start:start + 8] = b"\x01" * 8
    problem = h.compare_frames(bytes(expected), pframe, bytes(mask))
    if problem:
        raise SystemExit(f"verification failed: {problem}")


def generate(output: Path) -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = tuple((p_row(row),) for row in range(h.MB_HEIGHT))

    with tempfile.TemporaryDirectory(prefix="mister_h262_pintra_") as directory:
        temp = Path(directory)
        raw = temp / "source.yuv"
        skeleton = temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=2, gop=12, bframes=0)
        if [kind for _, kind in h.pictures(skeleton.read_bytes())] != [1, 2]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        data = h.patch_pictures(
            skeleton.read_bytes(), [1, 2], {1: (False, rows)}
        )
        output.write_bytes(data)

    if h.picture_types(ffprobe, output) != ["I", "P"]:
        raise SystemExit("verification failed: display order is not I/P")
    iframe, pframe = h.decode_planes(ffmpeg, output, 2)
    verify_frame(iframe, pframe)

    print(f"generated: {output}")
    print(f"bytes: {output.stat().st_size}")
    print(f"sha256: {hashlib.sha256(output.read_bytes()).hexdigest()}")
    print(f"intra macroblock: row={INTRA_ROW} column={INTRA_COL}")
    print("expected RTL metadata: 1350 macroblocks, 1 intra macroblock, 6 intra blocks, 6 DC events")
    print("verification: reference-exact outside intra MB; intra Y/Cb/Cr within +/-1 IDCT LSB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path,
        default=Path(__file__).resolve().with_name("test_p_intra_macroblocks.m2v"),
    )
    args = parser.parse_args()
    generate(args.output.resolve())


if __name__ == "__main__":
    main()
