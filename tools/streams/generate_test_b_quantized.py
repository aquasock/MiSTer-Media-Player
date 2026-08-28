#!/usr/bin/env python3
"""Exercise all three H.262 Table B-4 quantized non-intra B types.

Each slice changes the quantizer at three macroblocks, then uses the retained
scale in a non-quantized coded macroblock. Motion includes signed half samples.
"""
from pathlib import Path
import hashlib
import tempfile
import h262common as h

QTYPES = {1: "000011", 2: "000010", 3: "00010"}
COEFFS = {b: [(0, 7 if b % 2 else -5)] for b in range(6)}


def b_row():
    bits = "010100"
    specs = []
    fp, bp = [0, 0], [0, 0]
    scale = 10
    for col in range(h.MB_WIDTH):
        direction = {10: 1, 11: 1, 15: 2, 16: 2, 20: 3, 21: 3}.get(col, 3)
        changed = {10: 3, 15: 17, 20: 31}.get(col)
        coded = col in (10, 11, 15, 16, 20, 21)
        bits += "1" + (QTYPES[direction] if changed else h.BTYPE[(direction, int(coded))])
        if changed:
            scale = changed
            bits += f"{scale:05b}"
        fv = (-3, 0) if coded else (0, 0)
        bv = (5, 0) if coded else (0, 0)
        if direction & 1:
            bits += h.enc_comp(fv[0], fp[0]) + h.enc_comp(fv[1], fp[1])
            fp[:] = fv
        if direction & 2:
            bits += h.enc_comp(bv[0], bp[0]) + h.enc_comp(bv[1], bp[1])
            bp[:] = bv
        if coded:
            bits += h.CBP_VLC[63] + "".join(h.emit_block(COEFFS[b]) for b in range(6))
        specs.append((direction, fv, bv, coded, scale))
    return h.bits_to_bytes(bits), specs


def main():
    ffmpeg = h.require_tool("ffmpeg")
    output = Path(__file__).with_name("test_b_quantized.m2v")
    p_bits = "010100" + ("1" + h.P_MC_NOT_CODED + "11") * h.MB_WIDTH
    p_rows = tuple((h.bits_to_bytes(p_bits),) for _ in range(h.MB_HEIGHT))
    payload, specs = b_row()
    b_rows = tuple((payload,) for _ in range(h.MB_HEIGHT))
    with tempfile.TemporaryDirectory() as td:
        raw, skeleton = Path(td)/"raw.yuv", Path(td)/"skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, skeleton, frame_count=3, gop=12, bframes=1)
        output.write_bytes(h.patch_pictures(skeleton.read_bytes(), [1, 2, 3],
                           {1: (False, p_rows), 2: (True, b_rows)}))
    iframe, bframe, pframe = h.decode_planes(ffmpeg, output, 3)
    expected, mask = h.blank_frame(), bytearray(len(bframe))
    for row in range(h.MB_HEIGHT):
        for col, (direction, fv, bv, coded, scale) in enumerate(specs):
            args = dict(cbp=63 if coded else None,
                        coeffs_per_block=COEFFS if coded else None,
                        scale=h.quantiser_scale(scale))
            if direction == 3:
                args.update(bwd_ref=pframe, bwd_vec=bv)
            h.apply_macroblock(expected, row, col,
                               pframe if direction == 2 else iframe,
                               bv if direction == 2 else fv, **args)
            h.mark_residual(mask, row, col, 63 if coded else None)
    problem = h.compare_frames(bytes(expected), bframe, bytes(mask))
    if problem:
        raise SystemExit(problem)
    print(f"B_QUANTIZED_FIXTURE_PASS bytes={output.stat().st_size} "
          f"sha256={hashlib.sha256(output.read_bytes()).hexdigest()} "
          "quantized_types=3 scale_changes=90 retained_scale_blocks=540")


if __name__ == "__main__":
    main()
