#!/usr/bin/env python3
"""Generate fresh H.262 diagnostics for MiSTer-Media-Player c5b6bc75.

The streams are defined by semantic diagnostic requirements, not historical
bytes or historical hashes.  Every generated stream is structurally validated
against the subset currently admitted/probed by the RTL before it is kept.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

W, H = 720, 480
FPS = "30000/1001"
ROOT = Path(__file__).resolve().parent
OUT = ROOT / "streams"
SEQ_END = b"\x00\x00\x01\xB7"


@dataclass
class PictureInfo:
    coding_type: int
    slices: int
    picture_structure: int | None = None
    frame_pred_frame_dct: int | None = None
    concealment_motion_vectors: int | None = None
    q_scale_type: int | None = None
    intra_vlc_format: int | None = None
    alternate_scan: int | None = None
    progressive_frame: int | None = None
    f_codes: tuple[int, int, int, int] | None = None


class BitView:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def get(self, n: int) -> int:
        v = 0
        for _ in range(n):
            if self.pos >= len(self.data) * 8:
                raise ValueError("truncated bit field")
            b = self.data[self.pos >> 3]
            v = (v << 1) | ((b >> (7 - (self.pos & 7))) & 1)
            self.pos += 1
        return v


def start_codes(data: bytes) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    p = 0
    while True:
        p = data.find(b"\x00\x00\x01", p)
        if p < 0:
            return out
        if p + 3 < len(data):
            out.append((p, data[p + 3]))
        p += 4


def payload_between(data: bytes, codes: list[tuple[int, int]], idx: int) -> bytes:
    start = codes[idx][0] + 4
    end = codes[idx + 1][0] if idx + 1 < len(codes) else len(data)
    return data[start:end]


def picture_type(payload: bytes) -> int:
    b = BitView(payload)
    b.get(10)
    return b.get(3)


def parse_sequence_extension(payload: bytes) -> dict[str, int]:
    b = BitView(payload)
    if b.get(4) != 1:
        raise ValueError("not sequence_extension")
    b.get(8)
    progressive = b.get(1)
    chroma = b.get(2)
    b.get(2)
    b.get(2)
    b.get(12)
    if b.get(1) != 1:
        raise ValueError("sequence_extension marker_bit != 1")
    b.get(8)
    b.get(1)
    n = b.get(2)
    d = b.get(5)
    return {"progressive_sequence": progressive, "chroma_format": chroma,
            "frame_rate_extension_n": n, "frame_rate_extension_d": d}


def parse_picture_coding_extension(payload: bytes) -> dict[str, object]:
    b = BitView(payload)
    if b.get(4) != 8:
        raise ValueError("not picture_coding_extension")
    f = tuple(b.get(4) for _ in range(4))
    b.get(2)
    picture_structure = b.get(2)
    b.get(1)
    frame_pred = b.get(1)
    conceal = b.get(1)
    q_scale_type = b.get(1)
    intra_vlc = b.get(1)
    alt_scan = b.get(1)
    b.get(1)
    b.get(1)
    progressive_frame = b.get(1)
    return {"f_codes": f, "picture_structure": picture_structure,
            "frame_pred_frame_dct": frame_pred,
            "concealment_motion_vectors": conceal,
            "q_scale_type": q_scale_type,
            "intra_vlc_format": intra_vlc,
            "alternate_scan": alt_scan,
            "progressive_frame": progressive_frame}


def first_p_macroblock_type(data: bytes, codes: list[tuple[int, int]], p_pic_code_idx: int) -> str:
    slice_idx = None
    for i in range(p_pic_code_idx + 1, len(codes)):
        c = codes[i][1]
        if 1 <= c <= 0xAF:
            slice_idx = i
            break
        if c == 0x00:
            break
    if slice_idx is None:
        raise ValueError("P picture has no slice")
    b = BitView(payload_between(data, codes, slice_idx))
    if b.get(5) == 0:
        raise ValueError("P first slice qscale is zero")
    if b.get(1):
        b.get(8)
        if b.get(1) != 0:
            raise ValueError("P first slice extra_bit_slice is not terminated")
    if b.get(1) != 1:
        raise ValueError("P first macroblock_address_increment is not 1")
    prefix = "".join(str(b.get(1)) for _ in range(6))
    if prefix.startswith("1"):
        return "motion+pattern"
    if prefix.startswith("01"):
        return "pattern"
    if prefix.startswith("001"):
        return "motion"
    if prefix.startswith("00011"):
        return "intra"
    if prefix.startswith("00010"):
        return "quant+motion+pattern"
    if prefix.startswith("00001"):
        return "quant+pattern"
    if prefix == "000001":
        return "quant+intra"
    return "unknown"


def inspect_stream(path: Path) -> tuple[list[PictureInfo], dict[str, int], str | None]:
    data = path.read_bytes()
    codes = start_codes(data)
    seq_hdr = next((i for i, (_, c) in enumerate(codes) if c == 0xB3), None)
    if seq_hdr is None:
        raise ValueError("missing sequence_header_code")
    sh = BitView(payload_between(data, codes, seq_hdr))
    width = sh.get(12)
    height = sh.get(12)
    sh.get(4)
    rate = sh.get(4)
    seq_ext_idx = next((i for i in range(seq_hdr + 1, len(codes))
                        if codes[i][1] == 0xB5 and
                        payload_between(data, codes, i) and
                        (payload_between(data, codes, i)[0] >> 4) == 1), None)
    if seq_ext_idx is None:
        raise ValueError("missing sequence_extension")
    seq = parse_sequence_extension(payload_between(data, codes, seq_ext_idx))
    seq.update({"width": width, "height": height, "frame_rate_code": rate})

    pics: list[PictureInfo] = []
    first_p_type: str | None = None
    for i, (_, c) in enumerate(codes):
        if c != 0x00:
            continue
        pt = picture_type(payload_between(data, codes, i))
        j = i + 1
        pce = None
        slices = 0
        while j < len(codes) and codes[j][1] != 0x00:
            cc = codes[j][1]
            if cc == 0xB5:
                pl = payload_between(data, codes, j)
                if pl and (pl[0] >> 4) == 8:
                    pce = parse_picture_coding_extension(pl)
            if 1 <= cc <= 0xAF:
                slices += 1
            j += 1
        pi = PictureInfo(coding_type=pt, slices=slices)
        if pce:
            for k, v in pce.items():
                setattr(pi, k, v)
        pics.append(pi)
        if pt == 2 and first_p_type is None:
            first_p_type = first_p_macroblock_type(data, codes, i)
    return pics, seq, first_p_type


def validate(path: Path, expected_types: list[int], expected_p_mbtype: str | None = None) -> None:
    data = path.read_bytes()
    if not data.endswith(SEQ_END):
        raise ValueError(f"{path.name}: missing final sequence_end_code")
    pics, seq, p_mbtype = inspect_stream(path)
    got = [p.coding_type for p in pics]
    if got != expected_types:
        raise ValueError(f"{path.name}: picture types {got}, expected {expected_types}")
    required_seq = {"width": W, "height": H, "frame_rate_code": 4,
                    "progressive_sequence": 1, "chroma_format": 1,
                    "frame_rate_extension_n": 0, "frame_rate_extension_d": 0}
    for k, v in required_seq.items():
        if seq[k] != v:
            raise ValueError(f"{path.name}: {k}={seq[k]}, expected {v}")
    for n, p in enumerate(pics):
        if p.slices != H // 16:
            raise ValueError(f"{path.name}: picture {n} has {p.slices} slices, expected {H//16}")
        for k, v in {"picture_structure": 3, "frame_pred_frame_dct": 1,
                     "concealment_motion_vectors": 0, "q_scale_type": 0,
                     "intra_vlc_format": 0, "alternate_scan": 0,
                     "progressive_frame": 1}.items():
            if getattr(p, k) != v:
                raise ValueError(f"{path.name}: picture {n} {k}={getattr(p,k)}, expected {v}")
        if p.coding_type == 1 and p.f_codes != (15, 15, 15, 15):
            raise ValueError(f"{path.name}: I picture f_codes={p.f_codes}, expected all 15")
    if expected_p_mbtype is not None and p_mbtype != expected_p_mbtype:
        raise ValueError(f"{path.name}: first P mbtype={p_mbtype}, expected {expected_p_mbtype}")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
                    "-f", "null", "-"], check=True)


def validate_flat_gray_first_block(path: Path) -> None:
    """Check the intentionally simple first I-block syntax used by the RTL probe."""
    data = path.read_bytes()
    codes = start_codes(data)
    pic_i = next(i for i, (_, c) in enumerate(codes)
                 if c == 0x00 and picture_type(payload_between(data, codes, i)) == 1)
    slice_i = next(i for i in range(pic_i + 1, len(codes))
                   if 1 <= codes[i][1] <= 0xAF)
    b = BitView(payload_between(data, codes, slice_i))
    qscale = b.get(5)
    if b.get(1) != 0:
        raise ValueError(f"{path.name}: unexpected slice_extension_flag")
    if b.get(1) != 1:
        raise ValueError(f"{path.name}: first MBA is not 1")
    if b.get(1) != 1:
        raise ValueError(f"{path.name}: first I macroblock is not plain intra")

    dc_table = {
        "00": 1, "01": 2, "100": 0, "101": 3, "110": 4,
        "1110": 5, "11110": 6, "111110": 7, "1111110": 8,
        "11111110": 9, "111111110": 10, "111111111": 11,
    }
    code = ""
    while code not in dc_table:
        code += str(b.get(1))
        if len(code) > 9:
            raise ValueError(f"{path.name}: invalid first luminance DC VLC")
    dc_size = dc_table[code]
    raw = b.get(dc_size) if dc_size else 0
    if dc_size == 0:
        diff = 0
    elif raw >= (1 << (dc_size - 1)):
        diff = raw
    else:
        diff = raw + 1 - (1 << dc_size)
    dc = 128 + diff
    eob = (b.get(1) << 1) | b.get(1)
    observed = (qscale, dc_size, diff, dc, eob)
    expected = (2, 2, -2, 126, 0b10)
    if observed != expected:
        raise ValueError(f"{path.name}: first-block tuple {observed}, expected {expected}")


def ppm(path: Path, pixel) -> None:
    with path.open("wb") as f:
        f.write(f"P6\n{W} {H}\n255\n".encode())
        for y in range(H):
            row = bytearray(W * 3)
            for x in range(W):
                r, g, b = pixel(x, y)
                i = x * 3
                row[i:i+3] = bytes((r, g, b))
            f.write(row)


def encode(inputs: list[str], frames: int, gop: int, q: int, output: Path,
           force_key_frames: str | None = None) -> None:
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
           "-frames:v", str(frames), "-g", str(gop), "-bf", "0",
           "-q:v", str(q), "-qmin", str(q), "-qmax", str(q),
           "-c:v", "mpeg2video", "-profile:v", "main", "-level:v", "main",
           "-pix_fmt", "yuv420p", "-r", FPS, "-aspect", "4:3",
           "-intra_vlc", "0", "-non_linear_quant", "0", "-alternate_scan", "0",
           "-sc_threshold", "1000000000", "-threads", "1"]
    if force_key_frames:
        cmd += ["-force_key_frames", force_key_frames]
    cmd += ["-f", "mpeg2video", str(output)]
    subprocess.run(cmd, check=True)
    data = output.read_bytes()
    if not data.endswith(SEQ_END):
        output.write_bytes(data + SEQ_END)


def main() -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required")
    OUT.mkdir(parents=True, exist_ok=True)

    for old in OUT.glob("*.m2v"):
        old.unlink()

    with tempfile.TemporaryDirectory(prefix="mmp-h262-") as td:
        t = Path(td)
        ppm(t / "gray.ppm", lambda x, y: (128, 128, 128))

        def acstress(x: int, y: int):
            if x < 32 and y < 32:
                v = 80 if ((x // 2 + y // 2) & 1) else 176
                return v, v, v
            return 128, 128, 128
        ppm(t / "acstress.ppm", acstress)

        def detail(x: int, y: int):
            if x < 96 and y < 64:
                return ((x * 5 + y * 3) & 255,
                        (64 + x * 2 + y * 7) & 255,
                        (192 + x * 11 - y * 5) & 255)
            return 128, 128, 128
        ppm(t / "detail.ppm", detail)

        still = lambda name: ["-loop", "1", "-framerate", FPS, "-i", str(t / name)]
        encode(still("gray.ppm"), 3, 1, 2, OUT / "test_flat_gray_i.m2v")
        validate(OUT / "test_flat_gray_i.m2v", [1, 1, 1])
        validate_flat_gray_first_block(OUT / "test_flat_gray_i.m2v")

        encode(still("detail.ppm"), 3, 1, 4, OUT / "test_all_i.m2v")
        validate(OUT / "test_all_i.m2v", [1, 1, 1])

        encode(still("acstress.ppm"), 3, 1, 1, OUT / "test_all_i_q1.m2v")
        validate(OUT / "test_all_i_q1.m2v", [1, 1, 1])

        ppm(t / "ipi00.ppm", lambda x, y: (0, 0, 0))
        ppm(t / "ipi01.ppm", lambda x, y: (255, 255, 255))
        ppm(t / "ipi02.ppm", lambda x, y: (0, 0, 0))
        encode(["-framerate", FPS, "-i", str(t / "ipi%02d.ppm")],
               3, 12, 2, OUT / "test_ip_only.m2v",
               "expr:eq(n,0)+eq(n,2)")
        validate(OUT / "test_ip_only.m2v", [1, 2, 1], "intra")

    print("Generated and validated:")
    for p in sorted(OUT.glob("*.m2v")):
        pics, _, ptype = inspect_stream(p)
        names = {1: "I", 2: "P", 3: "B"}
        seq = "".join(names.get(x.coding_type, "?") for x in pics)
        suffix = f", first P macroblock={ptype}" if ptype else ""
        print(f"  {p.name}: {p.stat().st_size} bytes, pictures={seq}{suffix}")


if __name__ == "__main__":
    main()
