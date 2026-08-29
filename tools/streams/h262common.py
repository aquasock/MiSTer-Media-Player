#!/usr/bin/env python3
"""Shared H.262 / ISO-IEC 13818-2 bitstream-authoring library.

Used by every generate_test_*.py regression-stream generator in this directory.
Centralizes VLC tables, bit-packing, start-code emulation-collision detection,
and a software reference-decoder model (non-intra dequantization + 8x8 IDCT,
P forward and B bidirectional half-sample motion compensation) so every
generated stream can be verified pixel-exact against FFmpeg's own decode
instead of relying on structural checks alone.

All VLC codewords below are reused verbatim from the retired tools/streams
generator set (see core-log.md Commit-175), which had them hardware-validated
across many prior commits; they are not re-derived from the standard text here.

quantiser_scale_type is fixed to 0 (linear) and alternate_scan to 0 (standard
zig-zag) for every stream built with this library, keeping the dequantization
math (and its cross-check against FFmpeg) unambiguous. Nonlinear quantiser
scale and alternate scan are deferred to the larger version-release suite.
"""
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

FPS = 25
WIDTH = 720
HEIGHT = 480
MB_WIDTH = 45
MB_HEIGHT = 30
SEQ_END = bytes.fromhex("00 00 01 b7")


def require_tool(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise SystemExit(f"required tool not found in PATH: {name}")
    return path


def start_codes(data: bytes) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    pos = 0
    while True:
        pos = data.find(b"\x00\x00\x01", pos)
        if pos < 0:
            return out
        if pos + 3 < len(data):
            out.append((pos, data[pos + 3]))
        pos += 4


def pictures(data: bytes) -> list[tuple[int, int]]:
    """[(offset, picture_coding_type)] for every picture_start_code (0x00)."""
    return [(o, (data[o + 5] >> 3) & 7) for o, c in start_codes(data) if c == 0]


def picture_types(ffprobe: str, path: Path) -> list[str]:
    result = subprocess.run(
        [ffprobe, "-v", "error", "-select_streams", "v:0",
         "-show_entries", "frame=pict_type", "-of", "csv=p=0", str(path)],
        check=True, text=True, capture_output=True,
    )
    return [line.strip().strip(",") for line in result.stdout.replace("\r", "").splitlines() if line.strip()]


def bits_to_bytes(bits: str) -> bytes:
    bits += "0" * ((-len(bits)) % 8)
    return int(bits, 2).to_bytes(len(bits) // 8, "big")


# --- Table B.1 macroblock_address_increment ---
MBA_VLC = {
    1: "1", 2: "011", 3: "010", 4: "0011", 5: "0010", 6: "00011", 7: "00010",
    8: "0000111", 9: "0000110", 10: "00001011", 11: "00001010", 12: "00001001",
    13: "00001000", 14: "00000111", 15: "00000110", 16: "0000010111",
    17: "0000010110", 18: "0000010101", 19: "0000010100", 20: "0000010011",
    21: "0000010010", 22: "00000100011", 23: "00000100010", 24: "00000100001",
    25: "00000100000", 26: "00000011111", 27: "00000011110", 28: "00000011101",
    29: "00000011100", 30: "00000011011", 31: "00000011010", 32: "00000011001",
    33: "00000011000",
}
MBA_ESCAPE = "00000001000"


def enc_mba(n: int) -> str:
    if n < 1:
        raise ValueError(n)
    bits = ""
    while n > 33:
        bits += MBA_ESCAPE
        n -= 33
    return bits + MBA_VLC[n]


# --- Table B.10 motion_code ---
MCODE = {
    -16: "00000011001", -15: "00000011011", -14: "00000011101", -13: "00000011111",
    -12: "00000100001", -11: "00000100011", -10: "0000010011", -9: "0000010101",
    -8: "0000010111", -7: "00000111", -6: "00001001", -5: "00001011", -4: "0000111",
    -3: "00011", -2: "0011", -1: "011", 0: "1", 1: "010", 2: "0010", 3: "00010",
    4: "0000110", 5: "00001010", 6: "00001000", 7: "00000110", 8: "0000010110",
    9: "0000010100", 10: "0000010010", 11: "00000100010", 12: "00000100000",
    13: "00000011110", 14: "00000011100", 15: "00000011010", 16: "00000011000",
}


def delta_for(target: int, pred: int, f_code: int = 3) -> int:
    if not (1 <= f_code <= 6):
        raise ValueError(f_code)
    f = 1 << (f_code - 1)
    low, high, span = -16 * f, 16 * f - 1, 32 * f
    if not (low <= target <= high and low <= pred <= high):
        raise ValueError((target, pred, f_code))
    d = target - pred
    while d > high:
        d -= span
    while d < low:
        d += span
    return d


def enc_comp(target: int, pred: int, f_code: int = 3) -> str:
    d = delta_for(target, pred, f_code)
    if d == 0:
        return "1"
    f = 1 << (f_code - 1)
    a = abs(d)
    mc = (a - 1) // f + 1
    res = (a - 1) % f
    if d < 0:
        mc = -mc
    residual_bits = "" if f_code == 1 else format(res, f"0{f_code - 1}b")
    return MCODE[mc] + residual_bits


# --- Table B.3 P macroblock_type ---
P_MC_NOT_CODED = "001"
P_MC_CODED = "1"
P_NO_MC_CODED = "01"
P_MC_CODED_QUANT = "00010"
P_NO_MC_CODED_QUANT = "00001"

# --- Table B.4 B macroblock_type; key=(direction,coded), direction 1=fwd,2=bwd,3=bidir ---
BTYPE = {(3, 0): "10", (3, 1): "11", (2, 0): "010", (2, 1): "011", (1, 0): "0010", (1, 1): "0011"}

# --- Table B.9 coded_block_pattern (validated subset; bit5..bit0 -> Y0,Y1,Y2,Y3,Cb,Cr) ---
CBP_VLC = {63: "001100", 48: "10010", 32: "1010", 21: "00011001", 12: "10011", 3: "001101"}

# --- Table B.14/B.15 non-intra DCT coefficients (validated subset) ---
FIRST_COEFF = {1: "10", -1: "11"}
ORDINARY = {(0, 1): "11", (1, 1): "011", (0, 2): "0100", (0, 3): "00101", (7, 1): "000100"}
EOB = "10"


def escape(run: int, level: int) -> str:
    if not (0 <= run <= 63):
        raise ValueError(run)
    if level == 0 or not (-2047 <= level <= 2047):
        raise ValueError(level)
    return "000001" + format(run, "06b") + format(level & 0xFFF, "012b")


def ordinary_or_escape(run: int, level: int) -> str:
    base = ORDINARY.get((run, abs(level)))
    if base is not None:
        return base + ("1" if level < 0 else "0")
    return escape(run, level)


def emit_block(coeffs: list[tuple[int, int]]) -> str:
    """coeffs: [(run, level), ...] in scan order (run = preceding zero count). Appends EOB."""
    bits = ""
    for index, (run, level) in enumerate(coeffs):
        if index == 0 and run == 0 and level in FIRST_COEFF:
            bits += FIRST_COEFF[level]
        else:
            bits += ordinary_or_escape(run, level)
    return bits + EOB


def coeffs_to_zigzag_dict(coeffs: list[tuple[int, int]]) -> dict[int, int]:
    d: dict[int, int] = {}
    pos = -1
    for run, level in coeffs:
        pos += run + 1
        d[pos] = level
    return d


class EmulatedStartCode(Exception):
    pass


def check_no_emulated_start_code(payload: bytes, context: str) -> None:
    if b"\x00\x00\x01" in payload:
        offset = payload.index(b"\x00\x00\x01")
        raise EmulatedStartCode(
            f"{context}: accidental start-code sequence at payload offset {offset}; "
            "choose different coefficient/motion values to avoid this collision"
        )


# --- reference-model: non-intra dequantization + IDCT (linear quantiser_scale only) ---
ZIGZAG = (
    (0, 0), (0, 1), (1, 0), (2, 0), (1, 1), (0, 2), (0, 3), (1, 2),
    (2, 1), (3, 0), (4, 0), (3, 1), (2, 2), (1, 3), (0, 4), (0, 5),
    (1, 4), (2, 3), (3, 2), (4, 1), (5, 0), (6, 0), (5, 1), (4, 2),
    (3, 3), (2, 4), (1, 5), (0, 6), (0, 7), (1, 6), (2, 5), (3, 4),
    (4, 3), (5, 2), (6, 1), (7, 0), (7, 1), (6, 2), (5, 3), (4, 4),
    (3, 5), (2, 6), (1, 7), (2, 7), (3, 6), (4, 5), (5, 4), (6, 3),
    (7, 2), (7, 3), (6, 4), (5, 5), (4, 6), (3, 7), (4, 7), (5, 6),
    (6, 5), (7, 4), (7, 5), (6, 6), (5, 7), (6, 7), (7, 6), (7, 7),
)


def quantiser_scale(code: int) -> int:
    return code * 2  # q_scale_type=0 (linear); every stream in this library forces this bit off


def dequantize_block(zigzag_levels: dict[int, int], scale: int) -> list[list[int]]:
    f = [[0] * 8 for _ in range(8)]
    for k, (r, c) in enumerate(ZIGZAG):
        level = zigzag_levels.get(k, 0)
        if level == 0:
            continue
        magnitude = (2 * abs(level) + 1) * 16 * scale // 32
        f[r][c] = magnitude if level > 0 else -magnitude
    total = sum(f[r][c] for r in range(8) for c in range(8))
    if total % 2 == 0:
        f[7][7] += 1 if f[7][7] % 2 == 0 else -1
    return f


_COS = [[math.cos((2 * x + 1) * u * math.pi / 16) for u in range(8)] for x in range(8)]
_C = [1 / math.sqrt(2)] + [1.0] * 7


def idct8x8(f: list[list[int]]) -> list[list[int]]:
    out = [[0.0] * 8 for _ in range(8)]
    for y in range(8):
        for x in range(8):
            s = 0.0
            for v in range(8):
                for u in range(8):
                    if f[v][u] == 0:
                        continue
                    s += _C[u] * _C[v] * f[v][u] * _COS[x][u] * _COS[y][v]
            out[y][x] = s / 4.0
    return [[round(out[y][x]) for x in range(8)] for y in range(8)]


def block_residual(coeffs: list[tuple[int, int]], scale: int) -> list[list[int]]:
    return idct8x8(dequantize_block(coeffs_to_zigzag_dict(coeffs), scale))


# --- reference-model: half-sample motion compensation (H.262 7.6) ---
def sample_plane(src: bytes, base: int, stride: int, w: int, h: int, x: int, y: int, vx: int, vy: int) -> int:
    ix, iy = vx // 2, vy // 2
    hx, hy = vx - 2 * ix, vy - 2 * iy
    sx, sy = x + ix, y + iy
    if not (0 <= sx < w and 0 <= sy < h and sx + hx < w and sy + hy < h):
        raise AssertionError((x, y, vx, vy, sx, sy, w, h))
    p00 = src[base + sy * stride + sx]
    if not hx and not hy:
        return p00
    if hx and not hy:
        return (p00 + src[base + sy * stride + sx + 1] + 1) // 2
    if hy and not hx:
        return (p00 + src[base + (sy + 1) * stride + sx] + 1) // 2
    return (p00 + src[base + sy * stride + sx + 1] + src[base + (sy + 1) * stride + sx]
            + src[base + (sy + 1) * stride + sx + 1] + 2) // 4


def sample_field(src: bytes, plane_base: int, plane_w: int, plane_h: int,
                 x: int, field_y: int, vx: int, vy: int, parity: int) -> int:
    """Sample one field of a frame plane.

    Field `parity` of a frame plane is the set of frame lines with that parity,
    so it is the same buffer read with the parity as an extra base offset,
    double the stride and half the height.  `field_y` and the vertical vector
    are both in field lines, which is what H.262 field motion vectors carry in
    a frame picture.
    """
    return sample_plane(src, plane_base + parity * plane_w, 2 * plane_w,
                        plane_w, plane_h // 2, x, field_y, vx, vy)


def apply_field_macroblock(out: bytearray, mb_row: int, mb_col: int, ref: bytes,
                           mvs: tuple[tuple[int, int, int], tuple[int, int, int]]) -> None:
    """Write one field-predicted macroblock's motion-compensated pixels.

    mvs[d] = (field_select, vx, vy) for destination field d, where d 0 is the
    top field and d 1 the bottom.  vx is half-pel in frame columns and vy is
    half-pel in field lines.  Each destination field half is 16x8 luma and 8x4
    chroma, which is what makes this different from a frame-predicted
    macroblock rather than merely a differently addressed one.
    """
    for d in (0, 1):
        sel, vx, vy = mvs[d]
        for j in range(8):
            for xx in range(16):
                px = mb_col * 16 + xx
                out[(mb_row * 16 + 2 * j + d) * WIDTH + px] = sample_field(
                    ref, 0, WIDTH, HEIGHT, px, mb_row * 8 + j, vx, vy, sel)
        cvx, cvy = trunc2(vx), trunc2(vy)
        for plane_index, plane_base in ((0, Y_SIZE), (1, Y_SIZE + C_SIZE)):
            for j in range(4):
                for xx in range(8):
                    px = mb_col * 8 + xx
                    out[plane_base + (mb_row * 8 + 2 * j + d) * CW + px] = sample_field(
                        ref, plane_base, CW, CH, px, mb_row * 4 + j, cvx, cvy, sel)


class FieldMotionPredictor:
    """H.262 7.6.3.1 predictor state for field vectors in a frame picture.

    The vertical predictor is stored doubled and halved before use, which is
    the rule that lets frame and field vectors share one predictor set.  Two
    vector slots are kept because field prediction in a frame picture always
    codes two vectors.
    """

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.pmv = [[0, 0], [0, 0]]

    def encode(self, slot: int, vx: int, vy: int, f_code: int = 3) -> str:
        bits = enc_comp(vx, self.pmv[slot][0], f_code)
        bits += enc_comp(vy, self.pmv[slot][1] // 2, f_code)
        self.pmv[slot] = [vx, vy * 2]
        return bits


def trunc2(v: int) -> int:
    return -(abs(v) // 2) if v < 0 else v // 2


def bidir_average(fwd: int, bwd: int) -> int:
    return (fwd + bwd + 1) // 2


# --- FFmpeg skeleton + picture_coding_extension / slice patching ---
def source_frames(count: int) -> bytes:
    out = bytearray()
    cw, ch = WIDTH // 2, HEIGHT // 2
    for k in range(count):
        y = bytearray(WIDTH * HEIGHT)
        cb = bytearray(cw * ch)
        cr = bytearray(cw * ch)
        for yy in range(HEIGHT):
            for xx in range(WIDTH):
                y[yy * WIDTH + xx] = 24 + ((xx * 3 + yy * 5 + k * 7) % 200)
        for yy in range(ch):
            for xx in range(cw):
                cb[yy * cw + xx] = 64 + ((xx * 5 + yy * 3 + k * 3) % 128)
                cr[yy * cw + xx] = 72 + ((xx * 2 + yy * 7 + k * 5) % 112)
        out += y + cb + cr
    return bytes(out)


def make_skeleton(ffmpeg: str, raw: Path, out: Path, frame_count: int, gop: int, bframes: int = 1,
                  fps: str | None = None) -> None:
    """Encode the FFmpeg skeleton the fixtures patch.

    `fps` overrides the module default for fixtures that must carry a
    particular frame_rate_code.  The decoder's 480i admission gate requires
    30000/1001, which the module default of 25 does not satisfy; passing it
    here leaves every other fixture on the default untouched.
    """
    raw.write_bytes(source_frames(frame_count))
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "yuv420p",
         "-s", f"{WIDTH}x{HEIGHT}", "-r", str(fps if fps is not None else FPS), "-i", str(raw),
         "-frames:v", str(frame_count), "-an",
         "-c:v", "mpeg2video", "-pix_fmt", "yuv420p", "-bf", str(bframes), "-g", str(gop),
         "-sc_threshold", "1000000000", "-q:v", "2", "-f", "mpeg2video", str(out)],
        check=True,
    )
    data = out.read_bytes()
    if not data.endswith(SEQ_END):
        out.write_bytes(data + SEQ_END)


def packed_row(code: int, payloads: tuple[bytes, ...]) -> bytes:
    b = bytearray(payloads[0])
    for p in payloads[1:]:
        b += b"\x00\x00\x01" + bytes([code]) + p
    return bytes(b)


def patch_picture(data: bytes, pic_index: int, is_b: bool,
                  row_groups: tuple[tuple[bytes, ...], ...],
                  forward_f_code: tuple[int, int] = (3, 3),
                  backward_f_code: tuple[int, int] = (3, 3),
                  frame_pred_frame_dct: bool = True,
                  progressive_frame: bool | None = None,
                  top_field_first: bool | None = None) -> bytes:
    """row_groups[row] is a tuple of one or more same-row slice payloads (already packed bytes)."""
    b = bytearray(data)
    pics = pictures(b)
    po, ptype = pics[pic_index]
    pe = pics[pic_index + 1][0] if pic_index + 1 < len(pics) else len(b)
    pce = None
    for o, c in start_codes(b):
        if po < o < pe and c == 0xB5 and o + 8 < len(b) and (b[o + 4] >> 4) == 8:
            pce = o
            break
    if pce is None:
        raise SystemExit(f"picture {pic_index} type {ptype}: missing picture_coding_extension")
    f_code_h, f_code_v = forward_f_code
    if not (1 <= f_code_h <= 6 and 1 <= f_code_v <= 6):
        raise ValueError(forward_f_code)
    b[pce + 4] = (b[pce + 4] & 0xF0) | f_code_h
    if is_b:
        backward_f_code_h, backward_f_code_v = backward_f_code
        if not (1 <= backward_f_code_h <= 6 and 1 <= backward_f_code_v <= 6):
            raise ValueError(backward_f_code)
        b[pce + 5] = (f_code_v << 4) | backward_f_code_h
        b[pce + 6] = (b[pce + 6] & 0x0F) | (backward_f_code_v << 4)
    else:
        b[pce + 5] = (f_code_v << 4) | (b[pce + 5] & 0x0F)
    # picture_coding_extension byte 7:
    #   bit7 top_field_first, bit6 frame_pred_frame_dct, bit5 concealment_motion_vectors,
    #   bit4 q_scale_type, bit3 intra_vlc_format, bit2 alternate_scan,
    #   bit1 repeat_first_field, bit0 chroma_420_type.
    # Byte 8 bit7 is progressive_frame.
    #
    # Entry 695: interlaced P/B needs frame_pred_frame_dct clear, which is what
    # admits field motion types and the macroblock dct_type bit together, and
    # progressive_frame clear so the sequence is a true interlaced one rather
    # than film in a 480i sequence.  Both default to the progressive-film shape
    # every earlier generator relies on: frame_pred_frame_dct was forced set,
    # and progressive_frame was never written, so it stays untouched unless a
    # caller asks for it.
    b[pce + 7] = b[pce + 7] & ~(0x20 | 0x10 | 0x04)
    if frame_pred_frame_dct:
        b[pce + 7] |= 0x40
    else:
        b[pce + 7] &= ~0x40
    if top_field_first is not None:
        b[pce + 7] = (b[pce + 7] | 0x80) if top_field_first else (b[pce + 7] & ~0x80)
    if progressive_frame is not None:
        b[pce + 8] = (b[pce + 8] | 0x80) if progressive_frame else (b[pce + 8] & ~0x80)

    codes = start_codes(b)
    pics = pictures(b)
    po, _ = pics[pic_index]
    pe = pics[pic_index + 1][0] if pic_index + 1 < len(pics) else len(b)
    rows = [(i, o, c) for i, (o, c) in enumerate(codes) if po < o < pe and 1 <= c <= MB_HEIGHT]
    if tuple(c for _, _, c in rows) != tuple(range(1, MB_HEIGHT + 1)):
        raise SystemExit(f"picture {pic_index} type {ptype}: unexpected skeleton slice layout")
    for row, (_, _, _) in enumerate(rows):
        for seg, segment in enumerate(row_groups[row]):
            check_no_emulated_start_code(segment, f"picture {pic_index} (type {ptype}) row {row + 1} segment {seg + 1}")
    repl = [(o + 4, codes[i + 1][0], packed_row(c, row_groups[row])) for row, (i, o, c) in enumerate(rows)]
    for start, end, payload in reversed(repl):
        b[start:end] = payload
    return bytes(b)


def patch_pictures(data: bytes, coded_types: list[int],
                   specs: dict[int, tuple[bool, tuple[tuple[bytes, ...], ...]]],
                   forward_f_codes: dict[int, tuple[int, int]] | None = None,
                   backward_f_codes: dict[int, tuple[int, int]] | None = None,
                   interlaced: dict[int, dict] | None = None) -> bytes:
    """specs: {pic_index: (is_b, row_groups)}. Applied in descending pic_index order (offset-safe)."""
    if [t for _, t in pictures(data)] != coded_types:
        raise SystemExit(f"expected coded types {coded_types}, found {[t for _, t in pictures(data)]}")
    b = data
    forward_f_codes = forward_f_codes or {}
    backward_f_codes = backward_f_codes or {}
    for pic_index in sorted(specs, reverse=True):
        is_b, row_groups = specs[pic_index]
        shape = (interlaced or {}).get(pic_index, {})
        b = patch_picture(b, pic_index, is_b, row_groups,
                          forward_f_codes.get(pic_index, (3, 3)),
                          backward_f_codes.get(pic_index, (3, 3)),
                          shape.get("frame_pred_frame_dct", True),
                          shape.get("progressive_frame"),
                          shape.get("top_field_first"))
    return b


CW, CH = WIDTH // 2, HEIGHT // 2
Y_SIZE = WIDTH * HEIGHT
C_SIZE = CW * CH


def mark_residual(mask: bytearray, mb_row: int, mb_col: int, cbp: int | None) -> None:
    """Flag every pixel of every CBP-selected block of one macroblock as residual-affected."""
    if not cbp:
        return
    for block in range(6):
        if not (cbp & (1 << (5 - block))):
            continue
        if block < 4:
            bx0 = mb_col * 16 + (block & 1) * 8
            by0 = mb_row * 16 + ((block >> 1) & 1) * 8
            for yy in range(8):
                base = (by0 + yy) * WIDTH + bx0
                mask[base:base + 8] = b"\x01" * 8
        else:
            plane_base = Y_SIZE if block == 4 else Y_SIZE + C_SIZE
            bx0, by0 = mb_col * 8, mb_row * 8
            for yy in range(8):
                base = plane_base + (by0 + yy) * CW + bx0
                mask[base:base + 8] = b"\x01" * 8


def compare_frames(expected: bytes, actual: bytes, residual_mask: bytes) -> str | None:
    """Exact match required outside residual_mask; +/-1 tolerance inside it.

    ITU-T H.262 does not mandate a bit-exact IDCT (IEEE 1180 allows small
    implementation-specific rounding variance), so residual-affected pixels
    may legitimately differ from FFmpeg's own IDCT by 1 LSB even when the
    encoded coefficients and dequantization are correct. Motion-compensation
    -only pixels have no such ambiguity and must match exactly.
    """
    bad_exact = bad_tolerant = 0
    first = None
    for i, (e, a, m) in enumerate(zip(expected, actual, residual_mask)):
        diff = abs(e - a)
        if m:
            if diff > 1:
                bad_tolerant += 1
                first = first or i
        else:
            if diff != 0:
                bad_exact += 1
                first = first or i
    if bad_exact or bad_tolerant:
        return (f"{bad_exact} exact-region mismatches, {bad_tolerant} residual-region "
                f"mismatches beyond +/-1 tolerance, first bad byte {first}")
    return None


def apply_macroblock(out: bytearray, mb_row: int, mb_col: int,
                      fwd_ref: bytes, fwd_vec: tuple[int, int],
                      bwd_ref: bytes | None = None, bwd_vec: tuple[int, int] | None = None,
                      cbp: int | None = None, coeffs_per_block: dict[int, list[tuple[int, int]]] | None = None,
                      scale: int = 16) -> None:
    """Write one macroblock's motion-compensated (+ optional residual) pixels into `out`.

    Luma blocks 0..3 are the 2x2 8x8 quadrants (Y0 top-left .. Y3 bottom-right);
    block 4 is Cb, block 5 is Cr; cbp bit (1<<(5-block)) selects which get a residual.
    """
    fx, fy = fwd_vec
    for yy in range(16):
        for xx in range(16):
            px = mb_col * 16 + xx
            py = mb_row * 16 + yy
            fwd = sample_plane(fwd_ref, 0, WIDTH, WIDTH, HEIGHT, px, py, fx, fy)
            if bwd_ref is not None:
                bx, by = bwd_vec
                bwd = sample_plane(bwd_ref, 0, WIDTH, WIDTH, HEIGHT, px, py, bx, by)
                val = bidir_average(fwd, bwd)
            else:
                val = fwd
            out[py * WIDTH + px] = val

    cfx, cfy = trunc2(fx), trunc2(fy)
    for plane_index, plane_base in ((0, Y_SIZE), (1, Y_SIZE + C_SIZE)):
        for yy in range(8):
            for xx in range(8):
                px = mb_col * 8 + xx
                py = mb_row * 8 + yy
                fwd = sample_plane(fwd_ref, plane_base, CW, CW, CH, px, py, cfx, cfy)
                if bwd_ref is not None:
                    cbx, cby = trunc2(bwd_vec[0]), trunc2(bwd_vec[1])
                    bwd = sample_plane(bwd_ref, plane_base, CW, CW, CH, px, py, cbx, cby)
                    val = bidir_average(fwd, bwd)
                else:
                    val = fwd
                out[plane_base + py * CW + px] = val

    if cbp is None or not coeffs_per_block:
        return
    for block in range(6):
        if not (cbp & (1 << (5 - block))):
            continue
        coeffs = coeffs_per_block[block]
        residual = block_residual(coeffs, scale)
        if block < 4:
            bx0 = mb_col * 16 + (block & 1) * 8
            by0 = mb_row * 16 + ((block >> 1) & 1) * 8
            for yy in range(8):
                for xx in range(8):
                    idx = (by0 + yy) * WIDTH + bx0 + xx
                    out[idx] = max(0, min(255, out[idx] + residual[yy][xx]))
        else:
            plane_base = Y_SIZE if block == 4 else Y_SIZE + C_SIZE
            bx0 = mb_col * 8
            by0 = mb_row * 8
            for yy in range(8):
                for xx in range(8):
                    idx = plane_base + (by0 + yy) * CW + bx0 + xx
                    out[idx] = max(0, min(255, out[idx] + residual[yy][xx]))


def blank_frame() -> bytearray:
    return bytearray(WIDTH * HEIGHT * 3 // 2)


def decode_planes(ffmpeg: str, path: Path, frame_count: int) -> list[bytes]:
    raw = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"],
        check=True, capture_output=True,
    ).stdout
    frame_bytes = WIDTH * HEIGHT * 3 // 2
    if len(raw) != frame_bytes * frame_count:
        raise SystemExit(f"decoded {len(raw)} bytes, expected {frame_bytes * frame_count}")
    return [raw[i * frame_bytes:(i + 1) * frame_bytes] for i in range(frame_count)]
