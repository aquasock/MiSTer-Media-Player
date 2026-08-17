#!/usr/bin/env python3
"""Generate the 720x480 P-presentation visual discriminator regression.

Why this stream exists
----------------------
Every other P regression in this directory is a poor *photographic* test. Their
final P picture differs from the I picture in only 1-14 macroblocks out of
1350 (0.1%-1.0% of the frame), because they were designed to prove syntax and
prediction semantics, not to be looked at. A display that never presented the
P at all - the Commit-175/176 failure mode, where the I frame stays on screen -
produces a photograph indistinguishable from a perfect decode. Confirming
"presented" from a handheld photo of the screen is therefore impossible with
them, and a targeted per-macroblock check cannot survive perspective skew,
JPEG artifacts, moire and glare against a high-frequency gradient.

This stream inverts that trade. One I picture, one P picture, and the P applies
a large vertical displacement to two diagonally opposite quadrants:

    +------------------+------------------+
    |  zero motion     |  shifted +24 px  |   rows 0..14
    +------------------+------------------+
    |  shifted -24 px  |  zero motion     |   rows 15..29
    +------------------+------------------+
      cols 0..21          cols 22..44

675 of 1350 macroblocks (50.0%) change. The source pattern's luma repeats every
40 rows, so a 24-pixel displacement is 60% of a period and lands the shifted
quadrants visibly out of phase with the stationary ones. The result is two hard
seams meeting at frame centre in a 2x2 pattern.

The point is that the pass/fail is *absolute*, not comparative: a correctly
presented P shows bold quadrant seams, and a stuck I frame shows an unbroken
diagonal gradient with no seams anywhere. No reference image, no registration,
no measurement - the two outcomes are not confusable by eye at a glance, which
is exactly the property the other streams lack.

Vector choice is bounds-constrained, not arbitrary. Top quadrants displace
downward (+24) and bottom quadrants upward (-24) so every prediction reads
inside the reference frame; a single sign everywhere would read off the top or
bottom edge. -48/+48 half-pel is within the f_code 3 range of [-64, 63].

This stream deliberately proves nothing about residual, escape, or reference
chaining - the other five streams cover those. It proves only that the final P
reached the display, and it proves that from a photograph.
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import h262common as h

SLICE_QSCALE = 10
# Half-sample units: 48 half-pel = 24 luma pixels = 60% of the source pattern's
# 40-row luma period.
SHIFT = 48
SPLIT_ROW = h.MB_HEIGHT // 2   # 15
SPLIT_COL = h.MB_WIDTH // 2    # 22


def vector_for(row: int, col: int) -> tuple[int, int]:
    """Quadrant displacement. Top displaces down, bottom up, so every
    prediction reads inside the reference frame."""
    top = row < SPLIT_ROW
    left = col < SPLIT_COL
    if top and not left:
        return (0, SHIFT)
    if not top and left:
        return (0, -SHIFT)
    return (0, 0)


def build_row(row: int):
    bits = format(SLICE_QSCALE, "05b") + "0"
    pred = [0, 0]
    spec = {}
    for col in range(h.MB_WIDTH):
        bits += "1"  # macroblock_address_increment = 1, no skips
        vx, vy = vector_for(row, col)
        bits += h.P_MC_NOT_CODED + h.enc_comp(vx, pred[0]) + h.enc_comp(vy, pred[1])
        pred = [vx, vy]
        spec[col] = (vx, vy)
    return h.bits_to_bytes(bits), spec


def main() -> None:
    ffmpeg = h.require_tool("ffmpeg")
    ffprobe = h.require_tool("ffprobe")
    out = Path(__file__).resolve().parent / "test_p_visual_discriminator.m2v"

    rows_bits, rows_spec = [], []
    for r in range(h.MB_HEIGHT):
        payload, spec = build_row(r)
        rows_bits.append(payload)
        rows_spec.append(spec)
    row_groups = tuple((p,) for p in rows_bits)

    with tempfile.TemporaryDirectory(prefix="mister_h262_visdisc_") as td:
        temp = Path(td)
        raw, sk = temp / "src.yuv", temp / "sk.m2v"
        h.make_skeleton(ffmpeg, raw, sk, frame_count=2, gop=3, bframes=0)
        skeleton_types = h.picture_types(ffprobe, sk)
        if skeleton_types != ["I", "P"]:
            raise SystemExit(f"FFmpeg skeleton picture order changed: {skeleton_types!r}")
        data = h.patch_pictures(sk.read_bytes(), [1, 2], {1: (False, row_groups)})
        out.write_bytes(data)

    if h.picture_types(ffprobe, out) != ["I", "P"]:
        raise SystemExit("verification failed: picture order changed after patching")

    frames = h.decode_planes(ffmpeg, out, 2)
    ref = frames[0]
    expected = h.blank_frame()
    for r in range(h.MB_HEIGHT):
        for c in range(h.MB_WIDTH):
            h.apply_macroblock(expected, r, c, ref, rows_spec[r][c])
    actual = frames[1]
    if bytes(expected) != actual:
        mismatches = sum(1 for a, b in zip(expected, actual) if a != b)
        first = next(i for i, (a, b) in enumerate(zip(expected, actual)) if a != b)
        raise SystemExit(
            f"verification failed: {mismatches} mismatches, first at byte {first}")

    # The whole reason this stream exists: quantify how visually separable the
    # final P is from the I, and refuse to ship a stream that is not separable.
    y_size = h.WIDTH * h.HEIGHT
    changed_mb = 0
    for r in range(h.MB_HEIGHT):
        for c in range(h.MB_WIDTH):
            hit = False
            for yy in range(16):
                base = (r * 16 + yy) * h.WIDTH + c * 16
                if ref[base:base + 16] != actual[base:base + 16]:
                    hit = True
                    break
            changed_mb += hit
    total_mb = h.MB_WIDTH * h.MB_HEIGHT
    diffs = [abs(a - b) for a, b in zip(ref[:y_size], actual[:y_size])]
    changed_px = sum(1 for d in diffs if d > 2)
    pct_mb = 100.0 * changed_mb / total_mb
    if pct_mb < 40.0:
        raise SystemExit(
            f"discriminator too weak: only {pct_mb:.1f}% of macroblocks change; "
            "a photograph could not separate a presented P from a stuck I frame")

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"generated: {out}")
    print("geometry: 45x30 macroblocks (720x480, 1350 total)")
    print(f"bytes: {out.stat().st_size}")
    print(f"sha256: {digest}")
    print("picture order: I + 1 P")
    print(f"quadrant vectors: top-right (0,{SHIFT}), bottom-left (0,{-SHIFT}), "
          f"others zero  [half-pel; {SHIFT // 2} px]")
    print(f"macroblocks changed vs I: {changed_mb}/{total_mb} ({pct_mb:.1f}%)")
    print(f"luma pixels changed >2:   {changed_px}/{y_size} "
          f"({100.0 * changed_px / y_size:.1f}%)")
    print("verification: pixel-exact against FFmpeg decode")
    print("visual pass: two hard seams crossing at frame centre (2x2 quadrants)")
    print("visual fail: unbroken diagonal gradient, no seams -> P never presented")


if __name__ == "__main__":
    main()
