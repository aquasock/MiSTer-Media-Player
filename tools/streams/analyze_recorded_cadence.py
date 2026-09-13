#!/usr/bin/env python3
"""Measure logical-counter and visible-raster cadence in a 60 fps recording.

The default crop describes the stable Entry-238 camera geometry. Both tracks
are matched independently against the decoded source pictures, so a changing
counter cannot conceal a repeated or stale displayed raster.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from fractions import Fraction
from pathlib import Path

import numpy as np

WIDTH, HEIGHT = 180, 120


def command_output(command: list[str], binary: bool = False):
    return subprocess.check_output(command, text=not binary)


def probe(path: Path) -> dict:
    raw = command_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=nb_frames,avg_frame_rate",
        "-of", "json", str(path),
    ])
    return json.loads(raw)["streams"][0]


def picture_types(path: Path) -> list[str]:
    raw = command_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "frame=pict_type", "-of", "csv=p=0", str(path),
    ])
    return [line.strip().rstrip(",") for line in raw.splitlines() if line.strip()]


def decode(path: Path, vf: str, width: int, height: int, gray: bool = False):
    channels = 1 if gray else 3
    pix_fmt = "gray" if gray else "rgb24"
    raw = command_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-vf", vf,
        "-f", "rawvideo", "-pix_fmt", pix_fmt, "-",
    ], binary=True)
    frame_bytes = width * height * channels
    if len(raw) % frame_bytes:
        raise RuntimeError(f"unaligned decoded data from {path}")
    shape = (-1, height, width) if gray else (-1, height, width, channels)
    return np.frombuffer(raw, np.uint8).reshape(shape).copy()


def normalize_features(patches: np.ndarray) -> np.ndarray:
    z = patches.astype(np.float32)
    axes = tuple(range(1, z.ndim))
    z = (z-z.mean(axis=axes, keepdims=True))/np.maximum(
        z.std(axis=axes, keepdims=True), 1.0
    )
    flat = z.reshape(len(z), -1)
    return flat/np.maximum(np.linalg.norm(flat, axis=1, keepdims=True), 1e-6)


def counter_costs(camera: np.ndarray, source: np.ndarray) -> np.ndarray:
    camera = camera[:, :43, 6:112].astype(np.float32)
    source = source[:, :43, :106].astype(np.float32)
    for _ in range(2):
        source = (source+np.roll(source, 1, 1)+np.roll(source, -1, 1)+
                  np.roll(source, 1, 2)+np.roll(source, -1, 2))/5.0

    def features(patches: np.ndarray) -> np.ndarray:
        patches = (patches-patches.mean(axis=(1, 2), keepdims=True))/np.maximum(
            patches.std(axis=(1, 2), keepdims=True), 1.0
        )
        gx = np.diff(patches, axis=2, prepend=patches[:, :, :1])
        gy = np.diff(patches, axis=1, prepend=patches[:, :1, :])
        joined = np.concatenate([
            0.35*patches.reshape(len(patches), -1),
            gx.reshape(len(patches), -1),
            gy.reshape(len(patches), -1),
        ], axis=1)
        return joined/np.maximum(np.linalg.norm(joined, axis=1, keepdims=True), 1e-6)

    return 1.0-features(camera)@features(source).T


def raster_costs(camera: np.ndarray, source: np.ndarray) -> np.ndarray:
    mask = np.ones((HEIGHT, WIDTH), bool)
    mask[0:16, 0:32] = False       # embedded counter
    mask[34:86, 35:150] = False    # MiSTer loading overlay
    mask[:2] = mask[-2:] = False
    mask[:, :2] = mask[:, -2:] = False
    dynamic = source.astype(np.float32).std(axis=0).mean(axis=2) > 4.0
    for _ in range(2):
        dynamic = np.logical_or.reduce([
            np.roll(np.roll(dynamic, y, 0), x, 1)
            for y in (-1, 0, 1) for x in (-1, 0, 1)
        ])

    def features(frames: np.ndarray) -> np.ndarray:
        values = frames[:, mask & dynamic, :]
        return normalize_features(values)

    return 1.0-features(camera)@features(source).T


def monotonic_path(cost: np.ndarray, unmatched: float = 0.45) -> np.ndarray:
    """Viterbi path: pre-playback or source frame, then stay/advance 1..3."""
    camera_count, source_count = cost.shape
    dp = np.full((camera_count, source_count+1), np.inf)
    previous = np.full((camera_count, source_count+1), -1, np.int16)
    dp[0, 0] = unmatched
    dp[0, 1:] = cost[0]+1.0
    for time in range(1, camera_count):
        dp[time, 0] = dp[time-1, 0]+unmatched
        previous[time, 0] = 0
        enter = dp[time-1, 0]+cost[time, 0]
        if enter < dp[time, 1]:
            dp[time, 1], previous[time, 1] = enter, 0
        for source in range(source_count):
            state = source+1
            candidates = [(dp[time, state]-cost[time, source],
                           int(previous[time, state])),
                          (dp[time-1, state], state)]
            for jump in (1, 2, 3):
                prior = source-jump
                if prior < 0:
                    break
                candidates.append((dp[time-1, prior+1]+0.10*(jump-1), prior+1))
            best, prior_state = min(candidates)
            dp[time, state] = best+cost[time, source]
            previous[time, state] = prior_state
    state = int(np.argmin(dp[-1]))
    path = np.empty(camera_count, np.int16)
    for time in range(camera_count-1, -1, -1):
        path[time] = state-1
        if time:
            state = max(0, int(previous[time, state]))
    return path


def runs(path: np.ndarray) -> list[tuple[int, int, int]]:
    active = np.flatnonzero(path >= 0)
    if not len(active):
        raise RuntimeError("no playback interval recovered")
    result: list[tuple[int, int, int]] = []
    start = int(active[0])
    for index in range(start+1, int(active[-1])+1):
        if path[index] != path[index-1]:
            result.append((int(path[index-1]), start, index-start))
            start = index
    result.append((int(path[active[-1]]), start, int(active[-1])+1-start))
    return result


def report(name: str, path: np.ndarray, fps: float, types: list[str]) -> list[tuple[int, int, int]]:
    track_runs = runs(path)
    interior = track_runs[1:-1] if len(track_runs) > 2 else track_runs
    holds = np.array([entry[2] for entry in interior])
    advances = [right[0]-left[0] for left, right in zip(track_runs, track_runs[1:])]
    first, last = track_runs[0][1], track_runs[-1][1]
    seconds = (last-first)/fps
    logical_span = track_runs[-1][0]-track_runs[0][0]
    effective = logical_span/seconds if seconds else 0.0
    print(f"{name}: logical={track_runs[0][0]}..{track_runs[-1][0]} "
          f"duration={seconds:.3f}s effective={effective:.3f}fps")
    print(f"  holds(camera): min={holds.min()} median={np.median(holds):.1f} "
          f"max={holds.max()} mean={holds.mean():.2f}")
    print(f"  advances={{{', '.join(f'{value}: {advances.count(value)}' for value in sorted(set(advances)))}}}")
    grouped: dict[str, list[int]] = {}
    for frame, _start, hold in interior:
        if 0 <= frame < len(types):
            grouped.setdefault(types[frame], []).append(hold)
    for kind in sorted(grouped):
        values = np.array(grouped[kind])
        print(f"  {kind}: count={len(values)} median={np.median(values):.1f} "
              f"mean={values.mean():.2f} range={values.min()}..{values.max()}")
    return track_runs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("--display-crop", default="500:744:211:247",
                        help="ffmpeg crop w:h:x:y before clockwise rectification")
    parser.add_argument("--fps", type=float, default=60000/1001,
                        help="recorded-video sample rate (default: 60000/1001)")
    args = parser.parse_args()

    info = probe(args.video)
    fps = args.fps
    camera_prefix = f"crop={args.display_crop},transpose=2"
    camera = decode(args.video, f"{camera_prefix},scale={WIDTH}:{HEIGHT}:flags=area",
                    WIDTH, HEIGHT)
    source = decode(args.source, f"scale={WIDTH}:{HEIGHT}:flags=area", WIDTH, HEIGHT)
    camera_counter = decode(args.video, f"{camera_prefix},crop=150:54:0:0", 150, 54, True)
    source_counter = decode(args.source,
                            "scale=744:500:flags=area,crop=150:54:0:0", 150, 54, True)
    types = picture_types(args.source)
    declared = info.get("nb_frames", "unknown")
    encoded_fps = float(Fraction(info["avg_frame_rate"]))
    print(f"video={args.video} camera_frames={len(camera)} declared={declared} "
          f"analysis_fps={fps:.6f} encoded_fps={encoded_fps:.6f} "
          f"source_frames={len(source)}")
    counter_path = monotonic_path(counter_costs(camera_counter, source_counter))
    raster_path = monotonic_path(raster_costs(camera, source))
    report("counter", counter_path, fps, types)
    report("raster", raster_path, fps, types)
    overlap = (counter_path >= 0) & (raster_path >= 0)
    mismatch = np.flatnonzero(overlap & (counter_path != raster_path))
    longest = current = 0
    for flag in overlap & (counter_path != raster_path):
        current = current+1 if flag else 0
        longest = max(longest, current)
    print(f"counter_raster_mismatch={len(mismatch)}/{int(overlap.sum())} "
          f"longest_run={longest}")
    if len(mismatch):
        print("  samples="+",".join(
            f"{index}:{counter_path[index]}/{raster_path[index]}"
            for index in mismatch[:40]
        ))


if __name__ == "__main__":
    main()
