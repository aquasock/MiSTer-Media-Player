#!/usr/bin/env python3
"""Verify ARM helper demux, timestamps, audio decode, and failure paths."""

from __future__ import annotations

import argparse
import array
import math
import subprocess
import tempfile
from pathlib import Path

PTS_MARKER = b"\x00\x00\x01\xb0"
PCM_MARKER = b"\x00\x00\x01\xb1"
PCM_END_MARKER = b"\x00\x00\x01\xb6"
RECORD_SIZE = 9


def strip_records(data: bytes) -> tuple[bytes, list[int], bytes, int]:
    clean = bytearray()
    timestamps: list[int] = []
    pcm = bytearray()
    end_count = 0
    position = 0
    while position < len(data):
        marker = data[position:position + 4]
        if marker == PTS_MARKER:
            if position + RECORD_SIZE > len(data):
                raise RuntimeError("truncated timestamp record")
            value = int.from_bytes(data[position + 4:position + 9], "big")
            timestamps.append(value >> 7)
            position += RECORD_SIZE
        elif marker == PCM_MARKER:
            if position + RECORD_SIZE > len(data):
                raise RuntimeError("truncated PCM record")
            mode = data[position + 4]
            if mode != 0x03:
                raise RuntimeError(f"unsupported PCM record mode 0x{mode:02x}")
            left = data[position + 5:position + 7]
            right = data[position + 7:position + 9]
            pcm += left[::-1] + right[::-1]
            position += RECORD_SIZE
        elif marker == PCM_END_MARKER:
            end_count += 1
            position += 4
        else:
            clean.append(data[position])
            position += 1
    if end_count > 1:
        raise RuntimeError(f"multiple PCM end records: {end_count}")
    if pcm and end_count != 1:
        raise RuntimeError("PCM transport has no clean end record")
    if end_count and not pcm:
        raise RuntimeError("PCM end record has no samples")
    return bytes(clean), timestamps, bytes(pcm), end_count


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


def pcm_frame_boundary_jumps(path: Path) -> tuple[int, int]:
    samples = array.array("h")
    samples.frombytes(path.read_bytes())
    if len(samples) % 2:
        raise RuntimeError(f"odd stereo PCM sample count in {path}")
    frames = len(samples) // 2
    maximum = [0, 0]
    for frame in range(1152, frames, 1152):
        for channel in range(2):
            before = samples[(frame - 1) * 2 + channel]
            after = samples[frame * 2 + channel]
            maximum[channel] = max(maximum[channel], abs(after - before))
    return maximum[0], maximum[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("helper", type=Path)
    parser.add_argument(
        "--test-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "generated_arm_av",
    )
    parser.add_argument(
        "--profile",
        choices=("short", "faded"),
        default="short",
    )
    args = parser.parse_args()
    raw_video = Path(__file__).resolve().parent / "test_b_bidirectional.m2v"
    if args.profile == "short":
        program = args.test_dir / "01_arm_mp2_audio.mpg"
        reference_video_path = args.test_dir / "reference_video.m2v"
        reference_pcm = args.test_dir / "reference_audio.s16le"
    else:
        program = args.test_dir / "02_arm_mp2_faded_tones.mpg"
        reference_video_path = args.test_dir / "reference_video_faded.m2v"
        reference_pcm = args.test_dir / "reference_audio_faded.s16le"
    # Near-silent fade regions magnify the small synthesis differences between
    # minimp3 and FFmpeg, so retain the original limit for the short fixture and
    # use a still-strong, profile-specific floor for the faded quality fixture.
    minimum_correlation = 0.97 if args.profile == "short" else 0.965
    reference_video = reference_video_path.read_bytes()

    capabilities = subprocess.run(
        [str(args.helper), "--capabilities"], text=True, capture_output=True,
    )
    expected_capabilities = (
        "protocol=1 sources=file reserved_sources=dvd "
        "containers=m2v,mpeg-ps video=h262 audio=mp2-s16le-48000 "
        "transport=inband-pcm-v1"
    )
    if capabilities.returncode or capabilities.stdout.strip() != expected_capabilities:
        raise RuntimeError(f"unexpected capabilities: {capabilities.stdout!r}")

    with tempfile.TemporaryDirectory(prefix="mister_arm_av_verify_") as temporary:
        temp = Path(temporary)
        helper_video = temp / "helper_video.m2v"
        helper_pcm = temp / "helper_audio.s16le"
        inband_pcm_path = temp / "inband_audio.s16le"
        transported = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{program}"],
            capture_output=True,
        )
        if transported.returncode:
            raise RuntimeError(transported.stderr.decode(errors="replace").strip())
        clean_transport, transport_timestamps, inband_pcm, end_count = strip_records(
            transported.stdout
        )
        if clean_transport != reference_video:
            raise RuntimeError(
                f"in-band video differs: helper={len(clean_transport)} "
                f"reference={len(reference_video)}"
            )
        if not transport_timestamps or transport_timestamps != sorted(transport_timestamps):
            raise RuntimeError(f"invalid in-band timestamps: {transport_timestamps}")
        inband_pcm_path.write_bytes(inband_pcm)
        inband_maximum, inband_rms, inband_correlation = pcm_metrics(
            inband_pcm_path, reference_pcm
        )
        inband_boundary_jumps = pcm_frame_boundary_jumps(inband_pcm_path)
        reference_boundary_jumps = pcm_frame_boundary_jumps(reference_pcm)
        boundary_limits = tuple(max(1024, jump * 3) for jump in reference_boundary_jumps)
        if inband_correlation < minimum_correlation or end_count != 1:
            raise RuntimeError(
                f"in-band PCM mismatch: max={inband_maximum}, rms={inband_rms:.4f}, "
                f"correlation={inband_correlation:.6f}, end={end_count}"
            )
        if any(actual > limit for actual, limit in
               zip(inband_boundary_jumps, boundary_limits)):
            raise RuntimeError(
                "in-band PCM discontinuity at MPEG audio frame boundary: "
                f"actual={inband_boundary_jumps}, limits={boundary_limits}"
            )

        completed = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{program}",
             "--video-out", str(helper_video), "--pcm-out", str(helper_pcm)],
            text=True, capture_output=True,
        )
        if completed.returncode:
            raise RuntimeError(completed.stderr.strip())
        clean_video, timestamps, explicit_pcm, explicit_end = strip_records(
            helper_video.read_bytes()
        )
        if explicit_pcm or explicit_end:
            raise RuntimeError("explicit --pcm-out also emitted in-band PCM")
        if clean_video != reference_video:
            raise RuntimeError(
                f"video differs: helper={len(clean_video)} reference={len(reference_video)}"
            )
        if not timestamps or timestamps != sorted(timestamps):
            raise RuntimeError(f"invalid video timestamps: {timestamps}")
        maximum, rms, correlation = pcm_metrics(helper_pcm, reference_pcm)
        boundary_jumps = pcm_frame_boundary_jumps(helper_pcm)
        pcm_frame_count = helper_pcm.stat().st_size // 4
        # minimp3 and FFmpeg use different synthesis implementations, so their
        # integer samples are not bit-identical.  Strong waveform correlation,
        # equal length, and the channel-specific test tones prove useful decode.
        if correlation < minimum_correlation:
            raise RuntimeError(
                f"PCM mismatch: max={maximum}, rms={rms:.4f}, correlation={correlation:.6f}"
            )
        if any(actual > limit for actual, limit in
               zip(boundary_jumps, boundary_limits)):
            raise RuntimeError(
                "PCM discontinuity at MPEG audio frame boundary: "
                f"actual={boundary_jumps}, limits={boundary_limits}"
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
    print(
        f"transport: {len(inband_pcm) // 4} PCM records, one clean end, "
        f"correlation {inband_correlation:.6f}"
    )
    print("errors: truncated Program Stream rejected")
    print("compatibility: raw M2V copied byte-identically")
    print("protocol: capabilities stable; file URI equals legacy path")
    print("sources: missing/unknown rejected; dvd reserved without access")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
