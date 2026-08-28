#!/usr/bin/env python3
"""Generate the field-DCT hardware fixture.

Entry 650 opens the field-DCT gate: frame pictures coded with
`frame_pred_frame_dct` clear, so each macroblock carries a `dct_type` bit and a
set macroblock orders its four luma blocks by field rather than by frame line.

The fixture comes from one standard ffmpeg command. `+ildct` enables field DCT
and `-g 1 -bf 0` keeps the stream all-intra, so field *prediction* -- the other
thing `frame_pred_frame_dct` gates -- cannot appear and the gate is isolated.
The scrolling bar is woven from 59.94 fields, which gives the encoder strong
field-to-field vertical detail and is what makes field DCT worth choosing.

What this script cannot establish: no ffmpeg command reports whether the
encoder actually set `dct_type` on any macroblock. `-debug mb_type` prints only
an intra marker. The decoder's own field-DCT macroblock counter is the oracle
for that, and a non-zero count is an acceptance criterion in entry 650. The
control encode below shows only that `+ildct` changed the bitstream.
"""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

WIDTH, HEIGHT = 720, 480
FRAMES = 360
DURATION = FRAMES * 1001 / 30000
VIDEO_RATE = 8_000_000
BUFFER_BITS = 1_835_008

# The suite's scrolling bar, advancing four scanlines per 59.94 Hz field.
BAR = (f"color=c=black:s={WIDTH}x{HEIGHT}:r=60000/1001:d={{d}},"
       "geq=lum='16+219*gte(Y,mod(N*4,472))*lt(Y,mod(N*4,472)+8)':cb=128:cr=128")

SEQ_END = bytes.fromhex("00 00 01 b7")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"verification failed: {message}")


def run(command: list[str]) -> None:
    proc = subprocess.run(command, capture_output=True, text=True)
    require(proc.returncode == 0, f"{command[0]} failed: {proc.stderr.strip()[:400]}")


def encode(output: Path, field_dct: bool) -> list[str]:
    command = [
        "ffmpeg", "-hide_banner", "-loglevel", "warning", "-xerror", "-threads", "1",
        "-f", "lavfi", "-i", BAR.format(d=f"{DURATION:.6f}"),
        "-vf", "tinterlace=mode=interleave_top,setsar=32/27",
        "-frames:v", str(FRAMES), "-an",
        "-c:v", "mpeg2video", "-pix_fmt", "yuv420p", "-threads", "1",
        "-flags", "+bitexact+ildct" if field_dct else "+bitexact",
        "-top", "1", "-g", "1", "-bf", "0",
        "-b:v", str(VIDEO_RATE), "-maxrate:v", str(VIDEO_RATE),
        "-bufsize:v", str(BUFFER_BITS),
        "-qmin", "1", "-qmax", "31", "-sc_threshold", "1000000000",
        "-f", "mpeg2video", str(output),
    ]
    run(command)
    return command


def start_codes(data: bytes) -> list[tuple[int, int]]:
    out, pos = [], 0
    while True:
        pos = data.find(b"\x00\x00\x01", pos)
        if pos < 0 or pos + 3 >= len(data):
            return out
        out.append((pos, data[pos + 3]))
        pos += 4


def bits_at(data: bytes, offset: int, count: int) -> str:
    return "".join(f"{b:08b}" for b in data[offset:offset + (count + 7) // 8 + 1])


def check_sequence(data: bytes) -> dict:
    headers = [o for o, c in start_codes(data) if c == 0xB3]
    require(headers, "no sequence header")
    o = headers[0]
    horizontal = (data[o + 4] << 4) | (data[o + 5] >> 4)
    vertical = ((data[o + 5] & 0x0F) << 8) | data[o + 6]
    frame_rate_code = data[o + 7] & 0x0F
    require(horizontal == WIDTH and vertical == HEIGHT,
            f"geometry is {horizontal}x{vertical}, expected {WIDTH}x{HEIGHT}")
    require(frame_rate_code == 4, f"frame_rate_code is {frame_rate_code}, expected 4")

    extensions = [o for o, c in start_codes(data) if c == 0xB5 and (data[o + 4] >> 4) == 1]
    require(extensions, "no sequence extension")
    b = bits_at(data, extensions[0] + 4, 24)
    progressive_sequence, chroma_format = b[12], b[13:15]
    require(progressive_sequence == "0", "progressive_sequence is set")
    require(chroma_format == "01", f"chroma_format is {chroma_format}, expected 4:2:0")
    return {"horizontal_size": horizontal, "vertical_size": vertical,
            "frame_rate_code": frame_rate_code, "progressive_sequence": 0,
            "chroma_format": "4:2:0"}


def check_pictures(data: bytes) -> dict:
    types = [(d[5] >> 3) & 7 for d in (data[o:o + 8] for o, c in start_codes(data) if c == 0)]
    require(types, "no pictures")
    require(set(types) == {1}, f"expected only I pictures, saw coding types {sorted(set(types))}")

    fields = {"picture_structure": set(), "top_field_first": set(),
              "frame_pred_frame_dct": set(), "intra_vlc_format": set(),
              "alternate_scan": set(), "repeat_first_field": set(),
              "chroma_420_type": set(), "progressive_frame": set()}
    count = 0
    for o, c in start_codes(data):
        if c != 0xB5 or (data[o + 4] >> 4) != 8:
            continue
        b = bits_at(data, o + 4, 40)
        fields["picture_structure"].add(b[22:24])
        fields["top_field_first"].add(b[24])
        fields["frame_pred_frame_dct"].add(b[25])
        fields["intra_vlc_format"].add(b[28])
        fields["alternate_scan"].add(b[29])
        fields["repeat_first_field"].add(b[30])
        fields["chroma_420_type"].add(b[31])
        fields["progressive_frame"].add(b[32])
        count += 1

    require(count == len(types), f"{count} picture coding extensions for {len(types)} pictures")
    expected = {"picture_structure": {"11"}, "top_field_first": {"1"},
                "frame_pred_frame_dct": {"0"}, "intra_vlc_format": {"0"},
                "alternate_scan": {"0"}, "repeat_first_field": {"0"},
                "chroma_420_type": {"0"}, "progressive_frame": {"0"}}
    for name, want in expected.items():
        require(fields[name] == want, f"{name} is {sorted(fields[name])}, expected {sorted(want)}")
    return {"pictures": len(types), "all_intra": True,
            "picture_structure": "frame", "frame_pred_frame_dct": 0,
            "top_field_first": 1, "alternate_scan": 0}


def check_motion(path: Path, frames: int) -> dict:
    """Decode independently and reject a stationary fixture."""
    frame_bytes = WIDTH * HEIGHT * 3 // 2
    command = ["ffmpeg", "-v", "error", "-i", str(path), "-map", "0:v:0", "-an",
               "-pix_fmt", "yuv420p", "-f", "rawvideo", "-"]
    hashes, decoded = set(), 0
    with tempfile.TemporaryFile() as errors:
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
        assert proc.stdout is not None
        try:
            while True:
                chunk = proc.stdout.read(frame_bytes)
                if not chunk:
                    break
                require(len(chunk) == frame_bytes, "partial decoded frame")
                hashes.add(hashlib.sha256(chunk).hexdigest())
                decoded += 1
            require(proc.wait() == 0, "independent decode failed")
            errors.seek(0)
            require(not errors.read(), "independent decode emitted errors")
        finally:
            proc.stdout.close()
            if proc.poll() is None:
                proc.terminate()
                proc.wait()
    require(decoded == frames, f"decoded {decoded} frames, expected {frames}")
    require(len(hashes) > 1, "fixture is stationary")
    return {"decoded_frames": decoded, "distinct_decoded_frames": len(hashes)}


def main() -> None:
    out = Path(__file__).resolve().parent / "test_field_dct.m2v"
    command = encode(out, field_dct=True)

    data = out.read_bytes()
    if not data.endswith(SEQ_END):
        data += SEQ_END
        out.write_bytes(data)

    sequence = check_sequence(data)
    pictures = check_pictures(data)
    motion = check_motion(out, FRAMES)

    with tempfile.TemporaryDirectory(prefix="field_dct_control_") as directory:
        control = Path(directory) / "frame_dct.m2v"
        encode(control, field_dct=False)
        differs = control.read_bytes() != out.read_bytes()
    require(differs, "+ildct produced a bitstream identical to the frame-DCT control")

    print(f"wrote {out} ({len(data)} bytes)")
    print(f"  sha256: {hashlib.sha256(data).hexdigest()}")
    print(f"  ffmpeg: {' '.join(command)}")
    print(f"  sequence: {sequence['horizontal_size']}x{sequence['vertical_size']}, "
          f"frame_rate_code {sequence['frame_rate_code']}, {sequence['chroma_format']}, "
          f"progressive_sequence {sequence['progressive_sequence']}")
    print(f"  pictures: {pictures['pictures']}, all intra, frame-structured, "
          f"frame_pred_frame_dct {pictures['frame_pred_frame_dct']}, "
          f"top_field_first {pictures['top_field_first']}, "
          f"alternate_scan {pictures['alternate_scan']}")
    print(f"  motion: {motion['decoded_frames']} decoded, "
          f"{motion['distinct_decoded_frames']} distinct")
    print("  control: +ildct bitstream differs from the frame-DCT encode")
    print("  NOT established here: that any macroblock set dct_type. The decoder's")
    print("  field-DCT counter is the oracle; entry 650 requires it to be non-zero.")


if __name__ == "__main__":
    sys.exit(main())
