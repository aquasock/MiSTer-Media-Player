#!/usr/bin/env python3
"""Create a coded-to-display permutation and FFmpeg 4:2:0 pixel oracle."""
import argparse
import json
import subprocess
from pathlib import Path


def run(args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("stream", type=Path)
    p.add_argument("output", type=Path)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    data = a.stream.read_bytes()
    (a.output/"stream.hex").write_text(data.hex("\n") + "\n")
    probe = json.loads(run(["ffprobe", "-v", "error", "-show_packets", "-show_frames",
        "-show_entries", "packet=pos:frame=pkt_pos,width,height,pix_fmt", "-of", "json", str(a.stream)]))
    events = probe["packets_and_frames"]
    frames = [x for x in events if x["type"] == "frame"]
    positions = {int(x["pkt_pos"]): i for i, x in enumerate(frames)}
    mapping = [positions[int(x["pos"])] for x in events if x["type"] == "packet"]
    if len(positions) != len(frames) or sorted(mapping) != list(range(len(frames))):
        raise RuntimeError("nonbijective packet/frame mapping")
    if any((x["width"], x["height"], x["pix_fmt"]) != (720, 480, "yuv420p") for x in frames):
        raise RuntimeError("this full-raster harness requires 720x480 4:2:0")
    raw = run(["ffmpeg", "-v", "error", "-err_detect", "explode", "-threads", "1", "-i", str(a.stream),
               "-fps_mode", "passthrough", "-pix_fmt", "yuv420p", "-f", "rawvideo", "pipe:1"])
    if len(raw) != len(frames)*518400:
        raise RuntimeError("oracle frame size/count mismatch")
    (a.output/"pixels.hex").write_text(raw.hex("\n") + "\n")
    (a.output/"map.hex").write_text("".join(f"{i:08x}\n" for i in mapping))
    print(f"ORACLE_READY frames={len(frames)} samples={len(raw)} bytes={len(data)}")


if __name__ == "__main__":
    main()
