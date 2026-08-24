#!/usr/bin/env python3
"""Prove bounded ARM A/V scheduling while preserving both streams exactly."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

PREFIX = b"\x00\x00\x01"
PTS_MARKER = PREFIX + b"\xb0"
PCM_MARKER = PREFIX + b"\xb1"
PCM_END_MARKER = PREFIX + b"\xb6"
RECORD_SIZE = 9
READ_SIZE = 1024 * 1024


def checked_process(command: list[str]) -> subprocess.Popen[bytes]:
    return subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def finish(process: subprocess.Popen[bytes], label: str) -> str:
    assert process.stderr is not None
    stderr = process.stderr.read().decode(errors="replace")
    returncode = process.wait()
    if returncode:
        raise RuntimeError(f"{label} failed ({returncode}): {stderr.strip()}")
    return stderr


def hash_stream(stream) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    while True:
        chunk = stream.read(READ_SIZE)
        if not chunk:
            break
        digest.update(chunk)
        size += len(chunk)
    return digest.hexdigest(), size


def analyze_inband(stream, sample_rate: int) -> dict[str, int | str | list[int]]:
    video_hash = hashlib.sha256()
    pcm_hash = hashlib.sha256()
    transport_hash = hashlib.sha256()
    buffer = bytearray()
    video_bytes = 0
    clean_video_bytes = 0
    pcm_frames = 0
    pts_values: list[int] = []
    end_count = 0
    first_pcm_position: int | None = None
    last_pcm_position: int | None = None
    current_batch_position: int | None = None
    current_batch = 0
    batches: list[tuple[int, int]] = []
    max_video_gap = 0

    def close_batch() -> None:
        nonlocal current_batch
        if not current_batch:
            return
        assert current_batch_position is not None
        batches.append((current_batch_position, current_batch))
        current_batch = 0

    eof = False
    while not eof:
        chunk = stream.read(READ_SIZE)
        if chunk:
            buffer.extend(chunk)
        else:
            eof = True
        position = 0
        safe_end = len(buffer) if eof else max(0, len(buffer) - (RECORD_SIZE - 1))
        while position < safe_end:
            marker_position = buffer.find(PREFIX, position)
            if marker_position < 0 or marker_position >= safe_end:
                data = buffer[position:safe_end]
                video_hash.update(data)
                transport_hash.update(data)
                video_bytes += len(data)
                clean_video_bytes += len(data)
                position = safe_end
                break
            if marker_position > position:
                data = buffer[position:marker_position]
                video_hash.update(data)
                transport_hash.update(data)
                video_bytes += len(data)
                clean_video_bytes += len(data)
                position = marker_position
            if len(buffer) - position < 4:
                break
            marker = bytes(buffer[position:position + 4])
            if marker in (PTS_MARKER, PCM_MARKER) and len(buffer) - position < RECORD_SIZE:
                break
            if marker == PTS_MARKER:
                record = bytes(buffer[position:position + RECORD_SIZE])
                video_hash.update(record)
                transport_hash.update(record)
                video_bytes += RECORD_SIZE
                pts_values.append(int.from_bytes(record[4:9], "big") >> 7)
                position += RECORD_SIZE
            elif marker == PCM_MARKER:
                record = bytes(buffer[position:position + RECORD_SIZE])
                expected_mode = 0x03 if sample_rate == 48000 else 0x01
                if record[4] != expected_mode:
                    raise RuntimeError(
                        f"PCM mode 0x{record[4]:02x} does not identify {sample_rate} Hz"
                    )
                pcm_hash.update(record[5:7][::-1] + record[7:9][::-1])
                transport_hash.update(record)
                pcm_frames += 1
                if first_pcm_position is None:
                    first_pcm_position = clean_video_bytes
                if current_batch_position != clean_video_bytes:
                    close_batch()
                    current_batch_position = clean_video_bytes
                current_batch += 1
                if last_pcm_position is not None:
                    max_video_gap = max(
                        max_video_gap, clean_video_bytes - last_pcm_position
                    )
                last_pcm_position = clean_video_bytes
                position += RECORD_SIZE
            elif marker == PCM_END_MARKER:
                close_batch()
                end_count += 1
                transport_hash.update(marker)
                position += 4
            else:
                # A video payload can end in 00 00 01 immediately before a
                # real in-band marker.  Advance one byte so that overlapping
                # prefixes cannot hide the following record.
                data = bytes(buffer[position:position + 1])
                video_hash.update(data)
                transport_hash.update(data)
                video_bytes += len(data)
                clean_video_bytes += len(data)
                position += len(data)
        if position:
            del buffer[:position]
        if eof and buffer:
            if buffer.startswith((PTS_MARKER, PCM_MARKER)):
                raise RuntimeError("truncated in-band record")
            video_hash.update(buffer)
            transport_hash.update(buffer)
            video_bytes += len(buffer)
            clean_video_bytes += len(buffer)
            buffer.clear()
    close_batch()
    if first_pcm_position is None or last_pcm_position is None:
        raise RuntimeError("transport contains no PCM")
    if end_count != 1:
        raise RuntimeError(f"transport contains {end_count} PCM end markers")
    first_batch = batches[0][1]
    terminal_batch = batches[-1][1] if batches[-1][0] == clean_video_bytes else 0
    steady_batches = batches[1:-1] if terminal_batch else batches[1:]
    max_steady_batch = max((count for _, count in steady_batches), default=0)
    return {
        "video_sha256": video_hash.hexdigest(),
        "pcm_sha256": pcm_hash.hexdigest(),
        "transport_sha256": transport_hash.hexdigest(),
        "transport_bytes": video_bytes + pcm_frames * RECORD_SIZE + end_count * 4,
        "video_bytes": video_bytes,
        "clean_video_bytes": clean_video_bytes,
        "pcm_frames": pcm_frames,
        "pts_count": len(pts_values),
        "first_pcm_clean_byte": first_pcm_position,
        "first_pcm_batch": first_batch,
        "max_steady_pcm_batch": max_steady_batch,
        "terminal_pcm_batch": terminal_batch,
        "max_pcm_free_video_bytes": max_video_gap,
        "tail_pcm_free_video_bytes": clean_video_bytes - last_pcm_position,
        "pcm_end_count": end_count,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("helper", type=Path)
    parser.add_argument("program", type=Path)
    parser.add_argument("--sample-rate", type=int, choices=(44100, 48000), required=True)
    parser.add_argument("--max-initial-batch", type=int, default=8192)
    parser.add_argument("--max-steady-batch", type=int, default=2048)
    parser.add_argument("--max-video-gap", type=int, default=65535)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    helper = str(args.helper.resolve())
    program = str(args.program.resolve())
    with tempfile.TemporaryDirectory(prefix="mister_transport_analysis_") as temporary:
        pcm_path = Path(temporary) / "reference.s16le"
        explicit = checked_process([
            helper, "--protocol", "1", "--source", f"file:{program}",
            "--pcm-out", str(pcm_path),
        ])
        assert explicit.stdout is not None
        video_sha, video_size = hash_stream(explicit.stdout)
        finish(explicit, "explicit helper pass")
        with pcm_path.open("rb") as pcm_stream:
            pcm_sha, pcm_size = hash_stream(pcm_stream)
        if pcm_size % 4:
            raise RuntimeError(f"explicit PCM size is not stereo-aligned: {pcm_size}")
        pcm_frames = pcm_size // 4

        inband = checked_process([
            helper, "--protocol", "1", "--source", f"file:{program}",
        ])
        assert inband.stdout is not None
        result = analyze_inband(inband.stdout, args.sample_rate)
        scheduler_stderr = finish(inband, "scheduled helper pass")

    if result["video_sha256"] != video_sha or result["video_bytes"] != video_size:
        raise RuntimeError("scheduled transport changed video bytes or PTS records")
    if result["pcm_sha256"] != pcm_sha or result["pcm_frames"] != pcm_frames:
        raise RuntimeError("scheduled transport changed decoded PCM")
    if result["first_pcm_batch"] > args.max_initial_batch:
        raise RuntimeError(
            f"initial PCM batch {result['first_pcm_batch']} exceeds "
            f"{args.max_initial_batch}"
        )
    if result["max_steady_pcm_batch"] > args.max_steady_batch:
        raise RuntimeError(
            f"steady PCM batch {result['max_steady_pcm_batch']} exceeds "
            f"{args.max_steady_batch}"
        )
    if result["max_pcm_free_video_bytes"] > args.max_video_gap:
        raise RuntimeError(
            f"PCM-free video gap {result['max_pcm_free_video_bytes']} exceeds "
            f"{args.max_video_gap}"
        )
    result["scheduler_stderr"] = scheduler_stderr.strip().splitlines()
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(
            "exact: video/PTS "
            f"{result['video_bytes']} bytes, PCM {result['pcm_frames']} frames"
        )
        print(
            "schedule: initial batch "
            f"{result['first_pcm_batch']}, steady batch <= "
            f"{result['max_steady_pcm_batch']}, terminal batch "
            f"{result['terminal_pcm_batch']}, PCM-free video <= "
            f"{result['max_pcm_free_video_bytes']} bytes"
        )
        print(
            "terminal: one PCM end, trailing video gap "
            f"{result['tail_pcm_free_video_bytes']} bytes"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
