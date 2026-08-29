#!/usr/bin/env python3
"""Generate a 720x480 interlaced P/B field-DCT residual regression.

The P and B pictures are frame pictures with frame_pred_frame_dct clear.  All
motion is ordinary frame prediction (frame_motion_type 10), while selected
pattern-bearing macroblocks set dct_type and carry residuals in all useful
luma block combinations.  This isolates field-DCT block ordering from the
already-qualified field-motion arithmetic.

Generated media are local regression artifacts, not repository inputs.  The
reference model applies the field-DCT luma layout and is checked against
FFmpeg's independent decode before an oracle is emitted.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
RESIDUAL_ROW = 8
QUANTIZED_P_COL = 5
QUANTIZED_B_COL = 5
B_MC_CODED_QUANT = "00010"
SCALE = h.quantiser_scale(SLICE_QSCALE)

# Exercise each luma block alone, both field pairs, all luma, and luma+chroma.
# Every selected macroblock sets dct_type=1.
RESIDUALS = {
    5: (32, {0: [(0, 7)]}),
    12: (48, {0: [(0, 1)], 1: [(0, -1)]}),
    19: (12, {2: [(0, 2)], 3: [(0, -2)]}),
    26: (21, {1: [(0, -1)], 3: [(0, 2)], 5: [(0, 1)]}),
    33: (3, {4: [(0, 1)], 5: [(0, -1)]}),
    40: (63, {0: [(0, 1)], 1: [(0, -1)],
              2: [(0, 2)], 3: [(0, -2)],
              4: [(0, 1)], 5: [(0, -1)]}),
}

# Half-sample frame vectors make the cache exercise field-DCT's doubled row
# walk rather than proving only the integer, zero-vector case.  Each B entry is
# (forward, backward), with opposite vertical parities represented.
P_VECTORS = {
    5: (0, 1), 12: (1, 1), 19: (0, -1),
    26: (-1, 1), 33: (2, -1), 40: (0, 0),
}
B_VECTORS = {
    5: ((0, 1), (0, -1)),
    12: ((1, 1), (-1, -1)),
    19: ((0, -1), (1, 1)),
    26: ((-1, 1), (0, -1)),
    33: ((2, -1), (-2, 1)),
    40: ((0, 0), (0, 0)),
}


def clear_progressive_sequence(data: bytes) -> bytes:
    b = bytearray(data)
    found = 0
    for offset, code in h.start_codes(b):
        if code == 0xB5 and offset + 5 < len(b) and (b[offset + 4] >> 4) == 1:
            b[offset + 5] &= ~0x08
            found += 1
    if not found:
        raise SystemExit("no sequence extension found")
    return bytes(b)


def emit_residual(bits: str, cbp: int, coeffs: dict[int, list[tuple[int, int]]]) -> str:
    bits += h.CBP_VLC[cbp]
    for block in range(6):
        if cbp & (1 << (5 - block)):
            bits += h.emit_block(coeffs[block])
    return bits


def build_p_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    predictor = [0, 0]
    specs = {}
    for col in range(h.MB_WIDTH):
        bits += h.enc_mba(1)
        if row == RESIDUAL_ROW and col in RESIDUALS:
            cbp, coeffs = RESIDUALS[col]
            mvx, mvy = P_VECTORS[col]
            bits += (h.P_MC_CODED_QUANT
                     if col == QUANTIZED_P_COL else h.P_MC_CODED)
            bits += "10"                 # frame_motion_type
            bits += "1"                  # dct_type: field DCT
            if col == QUANTIZED_P_COL:
                # macroblock_modes() fields precede macroblock_quant's scale.
                # Repeating the slice scale leaves the pixel oracle unchanged
                # while making this fixture prove the production parser order.
                bits += format(SLICE_QSCALE, "05b")
            bits += h.enc_comp(mvx, predictor[0]) + h.enc_comp(mvy, predictor[1])
            predictor[:] = (mvx, mvy)
            bits = emit_residual(bits, cbp, coeffs)
            specs[col] = (cbp, coeffs, (mvx, mvy))
        else:
            bits += h.P_MC_NOT_CODED
            bits += "10"                 # frame_motion_type; no dct_type
            bits += h.enc_comp(0, predictor[0]) + h.enc_comp(0, predictor[1])
            predictor[:] = (0, 0)
            specs[col] = (None, None, (0, 0))
    return h.bits_to_bytes(bits), specs


def build_b_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    fp, bp = [0, 0], [0, 0]
    specs = {}
    for col in range(h.MB_WIDTH):
        bits += h.enc_mba(1)
        if row == RESIDUAL_ROW and col in RESIDUALS:
            cbp, base_coeffs = RESIDUALS[col]
            fvec, bvec = B_VECTORS[col]
            coeffs = {block: [(run, -level) for run, level in values]
                      for block, values in base_coeffs.items()}
            bits += (B_MC_CODED_QUANT
                     if col == QUANTIZED_B_COL else h.BTYPE[(3, 1)])
            bits += "10"                 # frame_motion_type
            bits += "1"                  # dct_type: field DCT
            if col == QUANTIZED_B_COL:
                # macroblock_modes() fields precede macroblock_quant's scale.
                # Repeat the slice scale so only syntax order changes.
                bits += format(SLICE_QSCALE, "05b")
            bits += h.enc_comp(fvec[0], fp[0]) + h.enc_comp(fvec[1], fp[1])
            bits += h.enc_comp(bvec[0], bp[0]) + h.enc_comp(bvec[1], bp[1])
            fp[:] = fvec
            bp[:] = bvec
            bits = emit_residual(bits, cbp, coeffs)
            specs[col] = (cbp, coeffs, fvec, bvec)
        else:
            bits += h.BTYPE[(3, 0)]
            bits += "10"                 # frame_motion_type; no dct_type
            bits += h.enc_comp(0, fp[0]) + h.enc_comp(0, fp[1])
            bits += h.enc_comp(0, bp[0]) + h.enc_comp(0, bp[1])
            fp[:] = (0, 0)
            bp[:] = (0, 0)
            specs[col] = (None, None, (0, 0), (0, 0))
    return h.bits_to_bytes(bits), specs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().with_name(
                            "test_interlaced_field_dct_residual.m2v"))
    parser.add_argument("--oracle-output", type=Path)
    args = parser.parse_args()
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = args.output.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    p_payloads, p_specs = [], []
    b_payloads, b_specs = [], []
    for row in range(h.MB_HEIGHT):
        payload, specs = build_p_row(row)
        p_payloads.append(payload)
        p_specs.append(specs)
        payload, specs = build_b_row(row)
        b_payloads.append(payload)
        b_specs.append(specs)

    p_rows = tuple((payload,) for payload in p_payloads)
    b_rows = tuple((payload,) for payload in b_payloads)
    with tempfile.TemporaryDirectory(prefix="mister_h262_field_dct_") as directory:
        temp = Path(directory)
        raw, skeleton = temp / "src.yuv", temp / "skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=3, gop=12,
                        bframes=1, fps="30000/1001")
        if [kind for _, kind in h.pictures(skeleton.read_bytes())] != [1, 2, 3]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        data = h.patch_pictures(
            skeleton.read_bytes(), [1, 2, 3],
            {1: (False, p_rows), 2: (True, b_rows)},
            interlaced={
                0: {"progressive_frame": False, "top_field_first": True},
                1: {"frame_pred_frame_dct": False,
                    "progressive_frame": False, "top_field_first": True},
                2: {"frame_pred_frame_dct": False,
                    "progressive_frame": False, "top_field_first": True},
            },
        )
        out.write_bytes(clear_progressive_sequence(data))

    if h.picture_types(ffprobe, out) != ["I", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P")
    iframe, bframe, pframe = h.decode_planes(ffmpeg, out, 3)

    expected_p = h.blank_frame()
    p_mask = bytearray(len(expected_p))
    for row in range(h.MB_HEIGHT):
        for col in range(h.MB_WIDTH):
            cbp, coeffs, fvec = p_specs[row][col]
            h.apply_macroblock(expected_p, row, col, iframe, fvec,
                               cbp=cbp, coeffs_per_block=coeffs,
                               scale=SCALE, field_dct=bool(cbp))
            h.mark_residual(p_mask, row, col, cbp, field_dct=bool(cbp))
    problem = h.compare_frames(bytes(expected_p), pframe, bytes(p_mask))
    if problem:
        raise SystemExit(f"verification failed (P): {problem}")

    expected_b = h.blank_frame()
    b_mask = bytearray(len(expected_b))
    for row in range(h.MB_HEIGHT):
        for col in range(h.MB_WIDTH):
            cbp, coeffs, fvec, bvec = b_specs[row][col]
            h.apply_macroblock(expected_b, row, col, iframe, fvec,
                               bwd_ref=pframe, bwd_vec=bvec, cbp=cbp,
                               coeffs_per_block=coeffs, scale=SCALE,
                               field_dct=bool(cbp))
            h.mark_residual(b_mask, row, col, cbp, field_dct=bool(cbp))
    problem = h.compare_frames(bytes(expected_b), bframe, bytes(b_mask))
    if problem:
        raise SystemExit(f"verification failed (B): {problem}")

    oracle = bytes(iframe) + bytes(expected_b) + bytes(expected_p)
    if args.oracle_output:
        target = args.oracle_output.resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("".join(f"{value:02x}\n" for value in oracle))

    print(f"generated: {out}")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {hashlib.sha256(out.read_bytes()).hexdigest()}")
    print("picture order: I B P (display), I P B (coded)")
    print("P/B: frame pictures, frame_pred_frame_dct 0, frame_motion_type 10")
    print(f"row {RESIDUAL_ROW}: dct_type 1 at columns {sorted(RESIDUALS)}")
    print(f"row {RESIDUAL_ROW}: quantized P macroblock at column {QUANTIZED_P_COL}")
    print(f"row {RESIDUAL_ROW}: quantized B macroblock at column {QUANTIZED_B_COL}")
    print("coverage: Y0/Y1/Y2/Y3, both field pairs, all luma, luma plus chroma,")
    print("          integer and horizontal/vertical/diagonal half-sample prediction")
    print("verification: field-DCT reference model agrees with FFmpeg decode")
    print(f"yuv420p_sha256: {hashlib.sha256(oracle).hexdigest()}")
    if args.oracle_output:
        print(f"oracle: {args.oracle_output.resolve()} ({len(oracle)} bytes)")


if __name__ == "__main__":
    main()
