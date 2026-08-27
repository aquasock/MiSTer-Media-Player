#!/usr/bin/env python3
"""Generate a deterministic native-480i H.262 stream containing P pictures.

Entry 549: every pixel-accurate reconstruction regression in this project is
either interlaced and intra-only (tb_h262_interlaced_i_reconstruction, whose
source list stops at mpeg2_h262_intra_recon) or progressive and hardwired to a
128x96 oracle (the soak's MIXED_PIXEL_MODE).  Interlaced P/B reconstruction --
which is what an ordinary 480i programme stream actually contains -- has never
had a fixture, so no regression could observe it.

FFmpeg cannot be asked directly for the wanted combination: requesting
interlaced encoding with +ilme+ildct yields field motion types, field DCT and
wide f_codes that sit outside the supported subset and are rejected at the
first P header.  This generator therefore encodes ordinary frame-DCT,
frame-motion MPEG-2 with a short GOP and small motion range, then applies the
same signalling patch the all-I generator uses: clear progressive_sequence,
set the authored field order and frame_pred_frame_dct, and clear
progressive_frame.  The result is a frame-coded interlaced sequence with P
pictures and f_code 1/1.

Generated media are local regression artifacts, not committed repository
inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import analyze_h262_compatibility as analyzer  # noqa: E402
import generate_test_interlaced_i_frames as interlaced_i  # noqa: E402

FRAME_COUNT = 8
GOP = 4


def encode(ffmpeg: str, output: Path) -> None:
    subprocess.run(
        [
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi",
            "-i", "testsrc2=size=720x480:rate=60000/1001:duration=0.5"
                  ",tinterlace=mode=interleave_top",
            "-frames:v", str(FRAME_COUNT), "-an", "-c:v", "mpeg2video",
            "-pix_fmt", "yuv420p", "-threads", "1", "-flags", "+bitexact",
            "-top", "1", "-g", str(GOP), "-bf", "0",
            "-q:v", "2", "-qmin", "2", "-qmax", "12", "-me_range", "15",
            "-sc_threshold", "1000000000", "-f", "mpeg2video", str(output),
        ],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "generated_interlaced",
    )
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    raw = args.output_dir / "test_interlaced_p_frame_tff.m2v"
    patched = args.output_dir / "test_interlaced_p_tff.m2v"

    encode(args.ffmpeg, raw)
    data = interlaced_i.patch_interlaced_signalling(
        raw.read_bytes(), True, FRAME_COUNT
    )
    patched.write_bytes(data)

    report = analyzer.analyze_file(patched)
    sequence = report["sequence"]["extension"]
    coding = report["pictures"][1]["coding_extension"]
    if sequence["progressive_sequence"]:
        raise SystemExit("patched stream is still a progressive sequence")
    if "P" not in report["picture_order"]:
        raise SystemExit("patched stream contains no P picture")
    if not coding["frame_pred_frame_dct"]:
        raise SystemExit("P picture is not frame-predicted frame-DCT")
    if coding["progressive_frame"]:
        raise SystemExit("P picture is still marked progressive")

    digest = hashlib.sha256(data).hexdigest()
    print(f"INTERLACED_P_FIXTURE {patched.name} bytes={len(data)} sha256={digest}")
    print(f"  picture_order={report['picture_order']}")
    print(f"  f_code={coding['forward_horizontal_f_code']}/"
          f"{coding['forward_vertical_f_code']} "
          f"picture_structure={coding['picture_structure']} "
          f"top_field_first={coding['top_field_first']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
