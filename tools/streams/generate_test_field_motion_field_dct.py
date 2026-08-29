#!/usr/bin/env python3
"""Generate a 720x480 P/B fixture combining field motion and field DCT."""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
SCALE = h.quantiser_scale(SLICE_QSCALE)
TEST_ROW = 5
COEFFS = {
    6: (32, {0: [(0, 2)]}),
    12: (48, {0: [(0, 1)], 1: [(0, -1)]}),
    18: (12, {2: [(0, 2)], 3: [(0, -2)]}),
    24: (21, {1: [(0, -1)], 3: [(0, 2)], 5: [(0, 1)]}),
    30: (63, {0: [(0, 1)], 1: [(0, -1)], 2: [(0, 2)],
              3: [(0, -2)], 4: [(0, 1)], 5: [(0, -1)]}),
}
P_MVS = {
    6: ((0, 0, 2), (1, 0, 2)),
    12: ((1, 0, 0), (0, 0, 0)),
    18: ((0, 4, 0), (1, -4, 0)),
    24: ((0, 0, 1), (1, 0, -1)),
    30: ((1, 3, 1), (1, 3, 1)),
}
B_MVS = {
    6: (P_MVS[6], ((1, 0, -2), (0, 0, -2))),
    12: (P_MVS[12], ((0, 0, 0), (1, 0, 0))),
    18: (P_MVS[18], ((0, -4, 0), (1, 4, 0))),
    24: (P_MVS[24], ((1, 0, 1), (0, 0, -1))),
    30: (P_MVS[30], ((0, -3, 1), (0, -3, 1))),
}
P_REST = ((0, 0, 0), (1, 0, 0))
B_REST = (P_REST, P_REST)


def emit_residual(bits: str, cbp: int,
                  coeffs: dict[int, list[tuple[int, int]]]) -> str:
    bits += h.CBP_VLC[cbp]
    for block in range(6):
        if cbp & (1 << (5 - block)):
            bits += h.emit_block(coeffs[block])
    return bits


def apply_residual(frame: bytearray, row: int, col: int, cbp: int,
                   coeffs: dict[int, list[tuple[int, int]]]) -> None:
    for block in range(6):
        if not (cbp & (1 << (5 - block))):
            continue
        residual = h.block_residual(coeffs[block], SCALE)
        if block < 4:
            bx0 = col * 16 + (block & 1) * 8
            by0 = row * 16 + ((block >> 1) & 1)
            plane_base, stride, row_step = 0, h.WIDTH, 2
        else:
            bx0, by0 = col * 8, row * 8
            plane_base = h.Y_SIZE if block == 4 else h.Y_SIZE + h.C_SIZE
            stride, row_step = h.CW, 1
        for yy in range(8):
            for xx in range(8):
                index = plane_base + (by0 + yy * row_step) * stride + bx0 + xx
                frame[index] = max(0, min(255, frame[index] + residual[yy][xx]))


def p_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    predictor = h.FieldMotionPredictor()
    specs = {}
    for col in range(h.MB_WIDTH):
        coded = row == TEST_ROW and col in COEFFS
        mvs = P_MVS[col] if coded else P_REST
        bits += h.enc_mba(1)
        bits += h.P_MC_CODED if coded else h.P_MC_NOT_CODED
        bits += "01"
        if coded:
            bits += "1"
        for slot in (0, 1):
            sel, vx, vy = mvs[slot]
            bits += str(sel) + predictor.encode(slot, vx, vy)
        if coded:
            bits = emit_residual(bits, *COEFFS[col])
        specs[col] = (mvs, COEFFS[col] if coded else None)
    return h.bits_to_bytes(bits), specs


def b_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    fp, bp = h.FieldMotionPredictor(), h.FieldMotionPredictor()
    specs = {}
    for col in range(h.MB_WIDTH):
        coded = row == TEST_ROW and col in COEFFS
        fwd, bwd = B_MVS[col] if coded else B_REST
        bits += h.enc_mba(1) + h.BTYPE[(3, 1 if coded else 0)] + "01"
        if coded:
            bits += "1"
        for slot in (0, 1):
            sel, vx, vy = fwd[slot]
            bits += str(sel) + fp.encode(slot, vx, vy)
        for slot in (0, 1):
            sel, vx, vy = bwd[slot]
            bits += str(sel) + bp.encode(slot, vx, vy)
        if coded:
            negated = {block: [(run, -level) for run, level in values]
                       for block, values in COEFFS[col][1].items()}
            bits = emit_residual(bits, COEFFS[col][0], negated)
            spec_coeffs = (COEFFS[col][0], negated)
        else:
            spec_coeffs = None
        specs[col] = (fwd, bwd, spec_coeffs)
    return h.bits_to_bytes(bits), specs


def clear_progressive_sequence(data: bytes) -> bytes:
    result = bytearray(data)
    found = False
    for offset, code in h.start_codes(result):
        if code == 0xB5 and (result[offset + 4] >> 4) == 1:
            result[offset + 5] &= ~0x08
            found = True
    if not found:
        raise SystemExit("no sequence extension found")
    return bytes(result)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--oracle-output", type=Path, required=True)
    args = parser.parse_args()
    ffmpeg, ffprobe = h.require_tool("ffmpeg"), h.require_tool("ffprobe")
    p_payloads, p_specs, b_payloads, b_specs = [], [], [], []
    for row in range(h.MB_HEIGHT):
        payload, specs = p_row(row)
        p_payloads.append(payload); p_specs.append(specs)
        payload, specs = b_row(row)
        b_payloads.append(payload); b_specs.append(specs)

    with tempfile.TemporaryDirectory(prefix="mister_h262_fmfdct_") as directory:
        temp = Path(directory)
        raw, skeleton = temp / "src.yuv", temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=3, gop=12,
                        bframes=1, fps="30000/1001")
        data = h.patch_pictures(
            skeleton.read_bytes(), [1, 2, 3],
            {1: (False, tuple((p,) for p in p_payloads)),
             2: (True, tuple((p,) for p in b_payloads))},
            interlaced={
                0: {"progressive_frame": False, "top_field_first": True},
                1: {"frame_pred_frame_dct": False,
                    "progressive_frame": False, "top_field_first": True},
                2: {"frame_pred_frame_dct": False,
                    "progressive_frame": False, "top_field_first": True},
            })
        args.output.write_bytes(clear_progressive_sequence(data))

    if h.picture_types(ffprobe, args.output) != ["I", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P")
    iframe, bframe, pframe = h.decode_planes(ffmpeg, args.output, 3)
    expected_p = h.blank_frame(); p_mask = bytearray(len(expected_p))
    for row in range(h.MB_HEIGHT):
        for col in range(h.MB_WIDTH):
            mvs, coded = p_specs[row][col]
            h.apply_field_macroblock(expected_p, row, col, iframe, mvs)
            if coded:
                apply_residual(expected_p, row, col, *coded)
                h.mark_residual(p_mask, row, col, coded[0], field_dct=True)
    problem = h.compare_frames(bytes(expected_p), pframe, bytes(p_mask))
    if problem:
        raise SystemExit(f"verification failed (P): {problem}")

    expected_b = h.blank_frame()
    for row in range(h.MB_HEIGHT):
        for col in range(h.MB_WIDTH):
            fwd, bwd, coded = b_specs[row][col]
            h.apply_field_macroblock(expected_b, row, col, iframe, fwd,
                                     bwd_ref=bytes(expected_p), bwd_mvs=bwd)
            if coded:
                apply_residual(expected_b, row, col, *coded)
    problem = h.compare_frames(bytes(expected_b), bframe,
                               bytes([1]) * len(expected_b))
    if problem:
        raise SystemExit(f"verification failed (B): {problem}")

    oracle = bytes(iframe) + bytes(expected_b) + bytes(expected_p)
    args.oracle_output.write_text("".join(f"{value:02x}\n" for value in oracle))
    print(f"generated: {args.output.resolve()}")
    print(f"bytes: {args.output.stat().st_size}")
    print(f"sha256: {hashlib.sha256(args.output.read_bytes()).hexdigest()}")
    print("picture order: I B P (display), I P B (coded)")
    print("P/B: field motion plus field-DCT residuals")
    print(f"row {TEST_ROW}: combined coverage at columns {sorted(COEFFS)}")
    print("verification: reference model agrees with FFmpeg decode")
    print(f"yuv420p_sha256: {hashlib.sha256(oracle).hexdigest()}")


if __name__ == "__main__":
    main()
