#!/usr/bin/env python3
"""Nonzero forward/backward predictors before B intra, then independent reuse."""
import argparse
from pathlib import Path
import tempfile
import h262common as h
from generate_test_b_intra_macroblocks import intra_blocks, verify_frame


def row_payload(row, first_intra=False):
    bits = "010100"
    fp, bp = (0, 0), (0, 0)
    for col in range(h.MB_WIDTH):
        bits += "1"
        if (row in (8, 9) and col == 20) or (first_intra and row==0 and col==0):
            bits += ("00011" if row != 9 else "00000101010") + intra_blocks()
            fp, bp = (0, 0), (0, 0)
            continue
        direction = {21: 1, 22: 2}.get(col, 3)
        fv = (9, -5) if row in (8, 9) and col == 19 else (0, 0)
        bv = (-7, 3) if row in (8, 9) and col == 19 else (0, 0)
        bits += h.BTYPE[(direction, 0)]
        if direction & 1:
            bits += h.enc_comp(fv[0], fp[0]) + h.enc_comp(fv[1], fp[1])
            fp = fv
        if direction & 2:
            bits += h.enc_comp(bv[0], bp[0]) + h.enc_comp(bv[1], bp[1])
            bp = bv
    return h.bits_to_bytes(bits)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--first-intra',action='store_true')
    args=parser.parse_args()
    ffmpeg = h.require_tool("ffmpeg")
    out = Path(__file__).with_name("test_b_first_intra.m2v" if args.first_intra else "test_b_intra_motion_reset.m2v")
    p_bits = "010100" + ("1" + h.P_MC_NOT_CODED + "11")*h.MB_WIDTH
    p_rows = tuple((h.bits_to_bytes(p_bits),) for _ in range(h.MB_HEIGHT))
    b_rows = tuple((row_payload(row,args.first_intra),) for row in range(h.MB_HEIGHT))
    with tempfile.TemporaryDirectory() as td:
        raw, sk = Path(td)/"raw.yuv", Path(td)/"skeleton.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=3, gop=12, bframes=1)
        out.write_bytes(h.patch_pictures(sk.read_bytes(), [1, 2, 3],
                        {1: (False, p_rows), 2: (True, b_rows)}))
    iframe, bframe, pframe = h.decode_planes(ffmpeg, out, 3)
    # The intra helper verifies its two authored patches; supply the expected
    # motion-shifted predecessor macroblocks as the remaining base picture.
    expected = bytearray(iframe)
    for row in (8, 9):
        h.apply_macroblock(expected, row, 19, iframe, (9, -5),
                           bwd_ref=pframe, bwd_vec=(-7, 3))
    if args.first_intra:
        for base,width,height,value in [(0,720,16,96),(h.Y_SIZE,360,8,128),(h.Y_SIZE+h.C_SIZE,360,8,128)]:
            for y in range(height):expected[base+y*width:base+y*width+height]=bytes([value])*height
    verify_frame(bytes(expected), bframe)
    print(f"B_INTRA_RESET_FIXTURE_PASS bytes={out.stat().st_size} "
          "intra_types=2 nonzero_predictors=4 post_intra_directions=3")


if __name__ == "__main__":
    main()
