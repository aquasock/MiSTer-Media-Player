#!/usr/bin/env python3
"""Generate MiSTer-Media-Player H.262 diagnostic elementary streams.

These streams are generated from semantic test definitions. Historical stream
bytes are intentionally not inputs to this generator.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

W, H = 720, 480
FPS = "30000/1001"
ROOT = Path(__file__).resolve().parent
OUT = ROOT / "streams"


def ppm(path: Path, pixel) -> None:
    with path.open("wb") as f:
        f.write(f"P6\n{W} {H}\n255\n".encode())
        row = bytearray(W * 3)
        for y in range(H):
            for x in range(W):
                r, g, b = pixel(x, y)
                i = x * 3
                row[i:i+3] = bytes((r, g, b))
            f.write(row)


def run_ffmpeg(inputs: list[str], frames: int, gop: int, bf: int, q: int, output: Path) -> None:
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        *inputs,
        "-frames:v", str(frames), "-g", str(gop), "-bf", str(bf),
        "-q:v", str(q), "-qmin", str(q), "-qmax", str(q),
        "-c:v", "mpeg2video", "-profile:v", "main", "-level:v", "main",
        "-pix_fmt", "yuv420p", "-r", FPS, "-aspect", "4:3",
        "-intra_vlc", "0", "-non_linear_quant", "0", "-alternate_scan", "0",
        "-sc_threshold", "1000000000", "-threads", "1",
        "-f", "mpeg2video", str(output),
    ]
    subprocess.run(cmd, check=True)


def main() -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required")
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mmp-h262-") as td:
        t = Path(td)

        ppm(t / "gray.ppm", lambda x, y: (128, 128, 128))

        def q1(x: int, y: int):
            if x < 16 and y < 16:
                v = 96 if ((x // 2 + y // 2) & 1) else 160
                return v, v, v
            return 128, 128, 128
        ppm(t / "q1.ppm", q1)

        def detail(x: int, y: int):
            if x < 48 and y < 48:
                v = 64 + ((x * 13 + y * 7) & 127)
                return v, 255 - v, (x * 5 + y * 11) & 255
            return 128, 128, 128
        ppm(t / "detail.ppm", detail)

        still = lambda name: ["-loop", "1", "-framerate", FPS, "-i", str(t / name)]
        run_ffmpeg(still("gray.ppm"), 1, 1, 0, 2, OUT / "test_flat_gray_i.m2v")
        run_ffmpeg(still("q1.ppm"), 1, 1, 0, 1, OUT / "test_all_i_q1.m2v")
        run_ffmpeg(still("detail.ppm"), 1, 1, 0, 4, OUT / "test_all_i.m2v")
        run_ffmpeg(still("detail.ppm"), 4, 12, 0, 3, OUT / "test_static_ip.m2v")

        for n in range(4):
            def moving(x: int, y: int, n=n):
                bx, by = 16 + n * 24, 32 + n * 8
                if bx <= x < bx + 64 and by <= y < by + 64:
                    v = 48 if (((x - bx) // 8 + (y - by) // 8) & 1) else 208
                    return v, v, v
                return 128, 128, 128
            ppm(t / f"move{n:02d}.ppm", moving)
        run_ffmpeg(["-framerate", FPS, "-i", str(t / "move%02d.ppm")], 4, 12, 0, 3,
                   OUT / "test_ip_only.m2v")

        for n in range(4):
            def integration(x: int, y: int, n=n):
                bx, by = 24 + n * 32, 80
                if bx <= x < bx + 96 and by <= y < by + 80:
                    xx, yy = x - bx, y - by
                    return ((xx * 3 + n * 17) & 255,
                            (yy * 4 + n * 29) & 255,
                            ((xx + yy) * 2 + n * 41) & 255)
                return 128, 128, 128
            ppm(t / f"integ{n:02d}.ppm", integration)
        run_ffmpeg(["-framerate", FPS, "-i", str(t / "integ%02d.ppm")], 4, 12, 1, 5,
                   OUT / "stream-susi.m2v")


if __name__ == "__main__":
    main()
