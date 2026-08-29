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
MAX_PCM_FRAMES = 32
MAX_RECORD_SIZE = 5 + 4 * MAX_PCM_FRAMES
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
    transport_bytes = 0
    clean_video_bytes = 0
    pcm_record_frames = 1
    pcm_record_size = RECORD_SIZE
    pcm_frames = 0
    pts_values: list[int] = []
    pts_clean_positions: list[int] = []
    origin_pts: int | None = None
    origin_pending = False
    last_pts: int | None = None
    max_deficit = 0
    max_deficit_pts = 0
    final_deficit = 0
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
        safe_end = len(buffer) if eof else max(0, len(buffer) - (MAX_RECORD_SIZE - 1))
        while position < safe_end:
            marker_position = buffer.find(PREFIX, position)
            if marker_position < 0 or marker_position >= safe_end:
                data = buffer[position:safe_end]
                video_hash.update(data)
                transport_hash.update(data)
                transport_bytes += len(data)
                video_bytes += len(data)
                clean_video_bytes += len(data)
                position = safe_end
                break
            if marker_position > position:
                data = buffer[position:marker_position]
                video_hash.update(data)
                transport_hash.update(data)
                transport_bytes += len(data)
                video_bytes += len(data)
                clean_video_bytes += len(data)
                position = marker_position
            if len(buffer) - position < 4:
                break
            marker = bytes(buffer[position:position + 4])
            if marker == PTS_MARKER and len(buffer) - position < RECORD_SIZE:
                break
            if marker == PCM_MARKER:
                if len(buffer) - position < 5:
                    break
                # Entry 699 reserves bit seven for IEC 61937 non-audio
                # framing; bits six through two carry the frame count.
                pcm_record_frames = ((buffer[position + 4] >> 2) & 0x1F) or 1
                pcm_record_size = 5 + 4 * pcm_record_frames
                if len(buffer) - position < pcm_record_size:
                    break
            if marker == PTS_MARKER:
                record = bytes(buffer[position:position + RECORD_SIZE])
                video_hash.update(record)
                transport_hash.update(record)
                transport_bytes += len(record)
                video_bytes += RECORD_SIZE
                pts = int.from_bytes(record[4:9], "big") >> 7
                pts_values.append(pts)
                pts_clean_positions.append(clean_video_bytes)
                last_pts = pts
                if origin_pending:
                    origin_pts = pts
                    origin_pending = False
                elif origin_pts is not None:
                    # The sink drains PCM at a fixed rate while it presents the
                    # pictures crossing beside it, so audio that has not
                    # crossed by the time its picture does is audio the sink
                    # cannot have.  Measured in coded order, so a reorder lead
                    # counts against the schedule rather than for it.
                    expected = (pts - origin_pts) * sample_rate // 90000
                    final_deficit = expected - pcm_frames
                    if final_deficit > max_deficit:
                        max_deficit = final_deficit
                        max_deficit_pts = pts - origin_pts
                position += RECORD_SIZE
            elif marker == PCM_MARKER:
                record = bytes(buffer[position:position + pcm_record_size])
                expected_mode = 0x03 if sample_rate == 48000 else 0x01
                if record[4] & 0x03 != expected_mode:
                    raise RuntimeError(
                        f"PCM mode 0x{record[4]:02x} does not identify {sample_rate} Hz"
                    )
                if pcm_record_frames > MAX_PCM_FRAMES:
                    raise RuntimeError(
                        f"PCM record carries {pcm_record_frames} frames, above "
                        f"the {MAX_PCM_FRAMES} the extractor supports"
                    )
                for index in range(pcm_record_frames):
                    base = 5 + index * 4
                    pcm_hash.update(
                        record[base:base + 2][::-1] + record[base + 2:base + 4][::-1]
                    )
                transport_hash.update(record)
                transport_bytes += len(record)
                pcm_frames += pcm_record_frames
                if first_pcm_position is None:
                    first_pcm_position = clean_video_bytes
                    # Audio that starts before any timestamp has crossed has no
                    # timeline to be measured against yet; take the first one
                    # that follows as the origin instead.
                    origin_pts = last_pts
                    origin_pending = last_pts is None
                if current_batch_position != clean_video_bytes:
                    close_batch()
                    current_batch_position = clean_video_bytes
                current_batch += pcm_record_frames
                if last_pcm_position is not None:
                    max_video_gap = max(
                        max_video_gap, clean_video_bytes - last_pcm_position
                    )
                last_pcm_position = clean_video_bytes
                position += pcm_record_size
            elif marker == PCM_END_MARKER:
                close_batch()
                end_count += 1
                transport_hash.update(marker)
                transport_bytes += len(marker)
                position += 4
            else:
                # A video payload can end in 00 00 01 immediately before a
                # real in-band marker.  Advance one byte so that overlapping
                # prefixes cannot hide the following record.
                data = bytes(buffer[position:position + 1])
                video_hash.update(data)
                transport_hash.update(data)
                transport_bytes += len(data)
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
            transport_bytes += len(buffer)
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
    pts_clean_gaps = [
        current - previous
        for previous, current in zip(pts_clean_positions, pts_clean_positions[1:])
    ]
    return {
        "video_sha256": video_hash.hexdigest(),
        "pcm_sha256": pcm_hash.hexdigest(),
        "transport_sha256": transport_hash.hexdigest(),
        "transport_bytes": transport_bytes,
        "video_bytes": video_bytes,
        "clean_video_bytes": clean_video_bytes,
        "pcm_frames": pcm_frames,
        "pts_count": len(pts_values),
        "min_pts_clean_video_gap": min(pts_clean_gaps, default=0),
        "max_pts_clean_video_gap": max(pts_clean_gaps, default=0),
        "first_pcm_clean_byte": first_pcm_position,
        "first_pcm_batch": first_batch,
        "max_steady_pcm_batch": max_steady_batch,
        "terminal_pcm_batch": terminal_batch,
        "max_pcm_free_video_bytes": max_video_gap,
        "max_audio_deficit_frames": max_deficit,
        "max_audio_deficit_at_seconds": round(max_deficit_pts / 90000.0, 3),
        "final_audio_deficit_frames": final_deficit,
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
    parser.add_argument("--max-video-gap", type=int, default=4096)
    parser.add_argument("--max-audio-deficit", type=int, default=8192)
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
    if result["max_audio_deficit_frames"] > args.max_audio_deficit:
        raise RuntimeError(
            f"audio deficit {result['max_audio_deficit_frames']} frames at "
            f"{result['max_audio_deficit_at_seconds']} s exceeds "
            f"{args.max_audio_deficit}"
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
            "timeline: audio deficit <= "
            f"{result['max_audio_deficit_frames']} frames at "
            f"{result['max_audio_deficit_at_seconds']} s, final "
            f"{result['final_audio_deficit_frames']} frames"
        )
        print(
            "terminal: one PCM end, trailing video gap "
            f"{result['tail_pcm_free_video_bytes']} bytes"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
