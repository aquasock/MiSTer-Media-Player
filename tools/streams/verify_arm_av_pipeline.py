#!/usr/bin/env python3
"""Verify ARM helper demux, timestamps, audio decode, and failure paths."""

from __future__ import annotations

import argparse
import array
import math
import subprocess
import tempfile
from pathlib import Path

MARKER = b"\x00\x00\x01\xb0"
RECORD_SIZE = 9


def strip_records(data: bytes) -> tuple[bytes, list[int]]:
    clean = bytearray()
    timestamps: list[int] = []
    position = 0
    while True:
        hit = data.find(MARKER, position)
        if hit < 0:
            clean += data[position:]
            break
        clean += data[position:hit]
        if hit + RECORD_SIZE > len(data):
            raise RuntimeError("truncated timestamp record")
        value = int.from_bytes(data[hit + 4:hit + 9], "big")
        timestamps.append(value >> 7)
        position = hit + RECORD_SIZE
    return bytes(clean), timestamps


def pcm_metrics(actual_path: Path, reference_path: Path) -> tuple[int, float, float]:
    actual = array.array("h")
    reference = array.array("h")
    actual.frombytes(actual_path.read_bytes())
    reference.frombytes(reference_path.read_bytes())
    if len(actual) != len(reference):
        raise RuntimeError(
            f"PCM length differs: helper={len(actual)} reference={len(reference)}"
        )
    if not actual:
        raise RuntimeError("helper produced no PCM")
    differences = [abs(a - b) for a, b in zip(actual, reference)]
    maximum = max(differences)
    rms = math.sqrt(sum(value * value for value in differences) / len(differences))
    dot = sum(a * b for a, b in zip(actual, reference))
    actual_energy = sum(value * value for value in actual)
    reference_energy = sum(value * value for value in reference)
    correlation = dot / math.sqrt(actual_energy * reference_energy)
    return maximum, rms, correlation


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("helper", type=Path)
    parser.add_argument(
        "--test-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "generated_arm_av",
    )
    args = parser.parse_args()
    raw_video = Path(__file__).resolve().parent / "test_b_bidirectional.m2v"
    program = args.test_dir / "01_arm_mp2_audio.mpg"
    reference_video = (args.test_dir / "reference_video.m2v").read_bytes()
    reference_pcm = args.test_dir / "reference_audio.s16le"

    capabilities = subprocess.run(
        [str(args.helper), "--capabilities"], text=True, capture_output=True,
    )
    expected_capabilities = (
        "protocol=1 sources=file reserved_sources=dvd "
        "containers=m2v,mpeg-ps video=h262 audio=mp2-s16le-48000"
    )
    if capabilities.returncode or capabilities.stdout.strip() != expected_capabilities:
        raise RuntimeError(f"unexpected capabilities: {capabilities.stdout!r}")

    with tempfile.TemporaryDirectory(prefix="mister_arm_av_verify_") as temporary:
        temp = Path(temporary)
        helper_video = temp / "helper_video.m2v"
        helper_pcm = temp / "helper_audio.s16le"
        completed = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{program}",
             "--video-out", str(helper_video), "--pcm-out", str(helper_pcm)],
            text=True, capture_output=True,
        )
        if completed.returncode:
            raise RuntimeError(completed.stderr.strip())
        clean_video, timestamps = strip_records(helper_video.read_bytes())
        if clean_video != reference_video:
            raise RuntimeError(
                f"video differs: helper={len(clean_video)} reference={len(reference_video)}"
            )
        if not timestamps or timestamps != sorted(timestamps):
            raise RuntimeError(f"invalid video timestamps: {timestamps}")
        maximum, rms, correlation = pcm_metrics(helper_pcm, reference_pcm)
        pcm_frame_count = helper_pcm.stat().st_size // 4
        # minimp3 and FFmpeg use different synthesis implementations, so their
        # integer samples are not bit-identical.  Strong waveform correlation,
        # equal length, and the channel-specific test tones prove useful decode.
        if correlation < 0.97:
            raise RuntimeError(
                f"PCM mismatch: max={maximum}, rms={rms:.4f}, correlation={correlation:.6f}"
            )

        legacy_video = temp / "legacy_video.m2v"
        legacy_pcm = temp / "legacy_audio.s16le"
        legacy = subprocess.run(
            [str(args.helper), "--video-out", str(legacy_video),
             "--pcm-out", str(legacy_pcm), str(program)],
            text=True, capture_output=True,
        )
        if (legacy.returncode or legacy_video.read_bytes() != helper_video.read_bytes()
                or legacy_pcm.read_bytes() != helper_pcm.read_bytes()):
            raise RuntimeError("legacy path and protocol-one file source differ")

        truncated = temp / "truncated.mpg"
        source = program.read_bytes()
        # Cut through the first audio PES packet, rather than at an arbitrary
        # mux-sector boundary that could also be a valid shortened stream.
        truncated.write_bytes(source[:3000])
        failed = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{truncated}",
             "--video-out", str(temp / "bad.m2v"),
             "--pcm-out", str(temp / "bad.pcm")],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if failed.returncode == 0:
            raise RuntimeError("truncated Program Stream was accepted")

        raw_output = temp / "raw_copy.m2v"
        copied = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{raw_video}",
             "--video-out", str(raw_output)],
            text=True, capture_output=True,
        )
        if copied.returncode or raw_output.read_bytes() != raw_video.read_bytes():
            raise RuntimeError("raw M2V compatibility path failed")

        dvd = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", "dvd:/dev/sr0"],
            text=True, capture_output=True,
        )
        if dvd.returncode == 0 or "reserved for a later" not in dvd.stderr:
            raise RuntimeError("reserved DVD source was not rejected clearly")

        unknown_source = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", "network:example"],
            text=True, capture_output=True,
        )
        if unknown_source.returncode == 0 or "unsupported media source" not in unknown_source.stderr:
            raise RuntimeError("unknown media source scheme was accepted")

        missing_file = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{temp / 'missing.mpg'}"],
            text=True, capture_output=True,
        )
        if missing_file.returncode == 0 or "missing.mpg" not in missing_file.stderr:
            raise RuntimeError("missing file source was not rejected")

        future_protocol = subprocess.run(
            [str(args.helper), "--protocol", "2", "--source", f"file:{program}"],
            text=True, capture_output=True,
        )
        if future_protocol.returncode == 0 or "unsupported protocol" not in future_protocol.stderr:
            raise RuntimeError("unknown helper protocol was accepted")

    print(f"video: byte-identical after removing {len(timestamps)} PTS records")
    print(
        f"audio: {pcm_frame_count} stereo frames, max error {maximum}, "
        f"rms {rms:.4f}, correlation {correlation:.6f}"
    )
    print("errors: truncated Program Stream rejected")
    print("compatibility: raw M2V copied byte-identically")
    print("protocol: capabilities stable; file URI equals legacy path")
    print("sources: missing/unknown rejected; dvd reserved without access")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
