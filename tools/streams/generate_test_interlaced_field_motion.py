#!/usr/bin/env python3
"""Generate the 720x480 interlaced P field-motion regression.

Entry 695: interlaced P and B frame pictures are refused today because field
motion prediction does not exist in the RTL at all -- frame_motion_type,
motion_vertical_field_select and dual_prime appear nowhere -- and because the
residual path carries no dct_type handling.  Entry 549 already provides an
interlaced P fixture, but it is frame-motion frame-DCT, so it exercises the
signalling and none of the missing mathematics.

This fixture is the other half: a 480i sequence whose P picture clears
frame_pred_frame_dct and predicts every macroblock with field motion
(frame_motion_type = 01).  Each macroblock therefore codes two vectors, one
per destination field, each with its own motion_vertical_field_select, and the
vertical components are in field lines rather than frame lines.

Row 5 carries the coverage: both field-select combinations, the crossed
selection where a field predicts from the opposite parity, integer and
half-sample vertical phases in field units, and horizontal half-sample.  Every
other macroblock predicts its own field at zero displacement, which reproduces
the co-located frame exactly and keeps the vector predictors tracked rather
than assumed.

Verified pixel-exact against FFmpeg's decode of this same bitstream via
h262common's field reference model.  Generated media are local regression
artifacts, not committed repository inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
FIELD_ROW = 5

# col -> ((sel, vx, vy) for the top field, (sel, vx, vy) for the bottom field).
# vy is half-pel in FIELD lines: 2 == one whole field line == two frame lines.
FIELD_COLS: dict[int, tuple[tuple[int, int, int], tuple[int, int, int]]] = {
    6:  ((0, 0, 2), (1, 0, 2)),      # each field from its own parity, one field line down
    12: ((1, 0, 0), (0, 0, 0)),      # crossed selection, zero displacement
    18: ((0, 4, 0), (1, -4, 0)),     # horizontal integer, opposite directions
    24: ((0, 0, 1), (1, 0, -1)),     # vertical half-sample in field units
    30: ((1, 3, 1), (1, 3, 1)),      # both fields from the bottom field, both half-sample
    36: ((0, -3, -2), (0, -3, -2)),  # both fields from the top field
}

REST = ((0, 0, 0), (1, 0, 0))  # each destination field predicts its own parity, no motion


def build_row(row: int):
    """Return (payload_bytes, {col: mvs}) for one slice of the P picture."""
    bits = format(SLICE_QSCALE, "05b") + "0"
    pmv = h.FieldMotionPredictor()
    specs: dict[int, tuple] = {}

    for col in range(h.MB_WIDTH):
        mvs = FIELD_COLS[col] if (row == FIELD_ROW and col in FIELD_COLS) else REST
        bits += "1"                       # macroblock_address_increment = 1
        bits += h.P_MC_NOT_CODED          # motion forward, no coded blocks, not intra
        bits += "01"                      # frame_motion_type = field-based
        # motion_vectors(0): the field select of each vector immediately
        # precedes that vector, and there is no dct_type because this
        # macroblock codes no pattern.
        for slot in (0, 1):
            sel, vx, vy = mvs[slot]
            bits += "1" if sel else "0"   # motion_vertical_field_select[slot][0]
            bits += pmv.encode(slot, vx, vy)
        specs[col] = mvs

    return h.bits_to_bytes(bits), specs


def clear_progressive_sequence(data: bytes) -> bytes:
    """Clear progressive_sequence in the sequence extension.

    Payload bit 12 after the extension start code is progressive_sequence,
    which is bit 3 of the second payload byte.
    """
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
        default=Path(__file__).resolve().parent / "test_interlaced_field_motion.m2v",
    )
    parser.add_argument(
        "--oracle-output",
        type=Path,
        help="optional readmemh byte oracle for both decoded YUV420P frames",
    )
    args = parser.parse_args()
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = args.output.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    rows_bits, rows_specs = [], []
    for r in range(h.MB_HEIGHT):
        payload, specs = build_row(r)
        rows_bits.append(payload)
        rows_specs.append(specs)

    with tempfile.TemporaryDirectory(prefix="mister_h262_ifm_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        # 30000/1001 is frame_rate_code 4, which the 480i admission gate
        # requires; the module default of 25 is code 3 and is refused, so
        # the I picture never becomes a reference and the P picture has
        # nothing to predict from.
        h.make_skeleton(ffmpeg, raw, sk, frame_count=2, gop=12, bframes=0,
                        fps="30000/1001")
        if h.picture_types(ffprobe, sk) != ["I", "P"]:
            raise SystemExit("FFmpeg skeleton picture order changed")
        row_groups = tuple((payload,) for payload in rows_bits)
        data = h.patch_pictures(
            sk.read_bytes(), [1, 2], {1: (False, row_groups)},
            interlaced={
                0: {"progressive_frame": False, "top_field_first": True},
                1: {"frame_pred_frame_dct": False, "progressive_frame": False,
                    "top_field_first": True},
            },
        )
        data = clear_progressive_sequence(data)
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "P"]:
        raise SystemExit("verification failed: picture order is not I/P")

    frames = h.decode_planes(ffmpeg, out, 2)
    iframe, pframe = frames[0], frames[1]

    expected = h.blank_frame()
    for r in range(h.MB_HEIGHT):
        for c in range(h.MB_WIDTH):
            h.apply_field_macroblock(expected, r, c, iframe, rows_specs[r][c])

    problem = h.compare_frames(bytes(expected), pframe, bytes(len(expected)))
    if problem:
        raise SystemExit(f"verification failed: {problem}")

    # The reference model is the oracle for the P frame and is byte-identical
    # to `pframe` by the check above; the I frame comes from the same decode.
    raw = bytes(iframe) + bytes(expected)
    if len(raw) != 2 * (h.Y_SIZE + 2 * h.C_SIZE):
        raise SystemExit(f"unexpected oracle byte count: {len(raw)}")
    if args.oracle_output:
        oracle = args.oracle_output.resolve()
        oracle.parent.mkdir(parents=True, exist_ok=True)
        oracle.write_text("".join(f"{value:02x}\n" for value in raw))

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    oracle_digest = hashlib.sha256(raw).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("picture order: I P")
    print("P picture: progressive_sequence 0, progressive_frame 0, "
          "frame_pred_frame_dct 0, frame_motion_type 01 (field) on every macroblock")
    print(f"row {FIELD_ROW}: field-select and half-sample coverage at columns "
          f"{sorted(FIELD_COLS)}")
    print("verification: pixel-exact against FFmpeg decode via h262common field model")
    print(f"yuv420p_sha256: {oracle_digest}")
    if args.oracle_output:
        print(f"oracle: {args.oracle_output.resolve()} ({len(raw)} bytes)")


if __name__ == "__main__":
    main()
