#!/usr/bin/env python3
"""Generate the 720x480 interlaced B field-motion regression.

Entry 695: the P field fixture proves forward field prediction, where one
macroblock draws on two independently selected reference fields.  A
bidirectional field macroblock draws on four: each destination field averages
a forward and a backward field prediction, and every one of those four carries
its own motion_vertical_field_select.  That is what makes the B engine's field
walk a different problem from the P engine's rather than a wider one, and it is
what this fixture exercises.

The B picture clears frame_pred_frame_dct and predicts every macroblock with
field motion (frame_motion_type = 01), so each macroblock codes four vectors:
two per direction, each preceded by its own field select.  Vertical components
are in field lines.

Row 5 carries the coverage: forward and backward selecting different parities
for the same destination field, crossed selection in one direction only,
opposite horizontal vectors per direction, vertical half-sample phases in field
units on both directions at once, and both destination fields drawn from a
single parity.  Every other macroblock predicts its own parity at zero
displacement in both directions, which keeps the vector predictors tracked
rather than assumed while leaving the average of the two references as the
expected value.

Verified pixel-exact against FFmpeg's decode of this same bitstream via
h262common's bidirectional field reference model.  Generated media are local
regression artifacts, not committed repository inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
FIELD_ROW = 5

# col -> (forward mvs, backward mvs); each is ((sel, vx, vy) per destination
# field).  vy is half-pel in FIELD lines: 2 == one whole field line.
FIELD_COLS: dict[int, tuple[tuple, tuple]] = {
    # forward takes its own parity, backward takes the opposite one
    6:  (((0, 0, 2), (1, 0, 2)), ((1, 0, -2), (0, 0, -2))),
    # crossed selection forward, straight backward, zero displacement
    12: (((1, 0, 0), (0, 0, 0)), ((0, 0, 0), (1, 0, 0))),
    # opposite horizontal integer vectors per direction
    18: (((0, 4, 0), (1, -4, 0)), ((0, -4, 0), (1, 4, 0))),
    # vertical half-sample in field units on both directions at once
    24: (((0, 0, 1), (1, 0, -1)), ((1, 0, 1), (0, 0, -1))),
    # both destination fields from the bottom field forward, top field backward
    30: (((1, 3, 1), (1, 3, 1)), ((0, -3, 1), (0, -3, 1))),
    # both directions from a single parity, opposite parities to each other
    36: (((0, -3, -2), (0, -3, -2)), ((1, 2, 2), (1, 2, 2))),
}

# Each destination field predicts its own parity, no displacement, both ways.
REST = (((0, 0, 0), (1, 0, 0)), ((0, 0, 0), (1, 0, 0)))


def build_row(row: int):
    """Return (payload_bytes, {col: (fwd_mvs, bwd_mvs)}) for one B slice."""
    bits = format(SLICE_QSCALE, "05b") + "0"
    fpmv = h.FieldMotionPredictor()
    bpmv = h.FieldMotionPredictor()
    specs: dict[int, tuple] = {}

    for col in range(h.MB_WIDTH):
        mvs = FIELD_COLS[col] if (row == FIELD_ROW and col in FIELD_COLS) else REST
        fwd, bwd = mvs
        bits += "1"                       # macroblock_address_increment = 1
        bits += h.BTYPE[(3, 0)]           # bidirectional, no coded blocks
        bits += "01"                      # frame_motion_type = field-based
        # motion_vectors(0) then motion_vectors(1); within each, the field
        # select of a vector immediately precedes that vector.
        for slot in (0, 1):
            sel, vx, vy = fwd[slot]
            bits += "1" if sel else "0"
            bits += fpmv.encode(slot, vx, vy)
        for slot in (0, 1):
            sel, vx, vy = bwd[slot]
            bits += "1" if sel else "0"
            bits += bpmv.encode(slot, vx, vy)
        specs[col] = mvs

    return h.bits_to_bytes(bits), specs


def clear_progressive_sequence(data: bytes) -> bytes:
    """Clear progressive_sequence in the sequence extension."""
    b = bytearray(data)
    found = 0
    for offset, code in h.start_codes(b):
        if code == 0xB5 and offset + 5 < len(b) and (b[offset + 4] >> 4) == 1:
            b[offset + 5] &= ~0x08
            found += 1
    if not found:
        raise SystemExit("no sequence extension found")
    return bytes(b)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "test_b_field_motion.m2v",
    )
    parser.add_argument(
        "--oracle-output",
        type=Path,
        help="optional readmemh byte oracle for all three decoded YUV420P frames",
    )
    args = parser.parse_args()
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = args.output.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    def p_row():
        bits = format(SLICE_QSCALE, "05b") + "0"
        for _ in range(h.MB_WIDTH):
            bits += "1" + h.P_MC_NOT_CODED + "1" + "1"
        return h.bits_to_bytes(bits)

    b_bits, b_specs = [], []
    for r in range(h.MB_HEIGHT):
        payload, spec = build_row(r)
        b_bits.append(payload)
        b_specs.append(spec)

    p_rows = tuple((p_row(),) for _ in range(h.MB_HEIGHT))
    b_rows = tuple((p,) for p in b_bits)

    with tempfile.TemporaryDirectory(prefix="mister_h262_bfm_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        # 30000/1001 is frame_rate_code 4, which the 480i admission gate
        # requires; the module default of 25 is code 3 and is refused.
        h.make_skeleton(ffmpeg, raw, sk, frame_count=3, gop=12, bframes=1,
                        fps="30000/1001")
        if [t for _, t in h.pictures(sk.read_bytes())] != [1, 2, 3]:
            raise SystemExit("FFmpeg skeleton coded order changed")
        data = h.patch_pictures(
            sk.read_bytes(), [1, 2, 3],
            {1: (False, p_rows), 2: (True, b_rows)},
            interlaced={
                0: {"progressive_frame": False, "top_field_first": True},
                1: {"frame_pred_frame_dct": True, "progressive_frame": False,
                    "top_field_first": True},
                2: {"frame_pred_frame_dct": False, "progressive_frame": False,
                    "top_field_first": True},
            },
        )
        data = clear_progressive_sequence(data)
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "B", "P"]:
        raise SystemExit("verification failed: display order is not I/B/P")

    frames = h.decode_planes(ffmpeg, out, 3)
    iframe, bframe, pframe = frames

    expected = h.blank_frame()
    for r in range(h.MB_HEIGHT):
        for c in range(h.MB_WIDTH):
            fwd, bwd = b_specs[r][c]
            h.apply_field_macroblock(expected, r, c, iframe, fwd,
                                     bwd_ref=pframe, bwd_mvs=bwd)

    problem = h.compare_frames(bytes(expected), bframe, bytes(len(expected)))
    if problem:
        raise SystemExit(f"verification failed: {problem}")

    # Decoded display order is I, B, P; the oracle carries all three.
    raw_oracle = bytes(iframe) + bytes(expected) + bytes(pframe)
    if len(raw_oracle) != 3 * (h.Y_SIZE + 2 * h.C_SIZE):
        raise SystemExit(f"unexpected oracle byte count: {len(raw_oracle)}")
    if args.oracle_output:
        oracle = args.oracle_output.resolve()
        oracle.parent.mkdir(parents=True, exist_ok=True)
        oracle.write_text("".join(f"{value:02x}\n" for value in raw_oracle))

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    oracle_digest = hashlib.sha256(raw_oracle).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("picture order: I B P (display), I P B (coded)")
    print("B picture: progressive_sequence 0, progressive_frame 0, "
          "frame_pred_frame_dct 0, frame_motion_type 01 (field) on every macroblock")
    print(f"row {FIELD_ROW}: four-field coverage at columns {sorted(FIELD_COLS)}")
    print("verification: pixel-exact against FFmpeg decode via h262common "
          "bidirectional field model")
    print(f"yuv420p_sha256: {oracle_digest}")
    if args.oracle_output:
        print(f"oracle: {args.oracle_output.resolve()} ({len(raw_oracle)} bytes)")


if __name__ == "__main__":
    main()
