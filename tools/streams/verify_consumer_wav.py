#!/usr/bin/env python3
"""Verify consumer WAV decode, conversion, resampling and transport output."""

from __future__ import annotations

import argparse
import array
import math
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

PCM_MARKER = b"\x00\x00\x01\xb1"
PCM_END_MARKER = b"\x00\x00\x01\xb6"


@dataclass(frozen=True)
class Profile:
    name: str
    codec: str
    channels: int
    source_rate: int
    output_rate: int
    exact: bool = False


PROFILES = (
    Profile("u8_mono_44100", "pcm_u8", 1, 44100, 44100),
    Profile("s16_stereo_44100", "pcm_s16le", 2, 44100, 44100, True),
    Profile("s24_stereo_48000", "pcm_s24le", 2, 48000, 48000),
    Profile("s32_stereo_48000", "pcm_s32le", 2, 48000, 48000),
    Profile("float_stereo_48000", "pcm_f32le", 2, 48000, 48000),
    Profile("s16_mono_22050", "pcm_s16le", 1, 22050, 44100),
    Profile("s24_stereo_96000", "pcm_s24le", 2, 96000, 48000),
    Profile("s16_surround_48000", "pcm_s16le", 6, 48000, 48000),
)


def run(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, check=True, **kwargs)


def generate(ffmpeg: str, profile: Profile, output: Path) -> None:
    tones = [220, 330, 440, 550, 660, 770][:profile.channels]
    expressions = "|".join(
        f"0.16*sin(2*PI*{frequency}*t)" for frequency in tones
    )
    layouts = {1: "mono", 2: "stereo", 6: "5.1"}
    source = (
        f"aevalsrc=exprs={expressions}:s={profile.source_rate}:d=0.30:"
        f"c={layouts[profile.channels]}"
    )
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", source, "-c:a", profile.codec, str(output),
    ])


def decode_reference(ffmpeg: str, source: Path, rate: int, output: Path) -> None:
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
        "-f", "s16le", "-c:a", "pcm_s16le", "-ar", str(rate), "-ac", "2",
        str(output),
    ])


def samples(data: bytes) -> array.array[int]:
    result = array.array("h")
    result.frombytes(data)
    if result.itemsize != 2:
        raise RuntimeError("host does not provide 16-bit array('h')")
    return result


def correlation(left: array.array[int], right: array.array[int]) -> float:
    count = min(len(left), len(right))
    if count < 100:
        raise RuntimeError("too few PCM samples for comparison")
    a = left[:count]
    b = right[:count]
    dot = sum(x * y for x, y in zip(a, b))
    aa = sum(x * x for x in a)
    bb = sum(y * y for y in b)
    return dot / math.sqrt(aa * bb)


def aligned_correlation(
    left: array.array[int], right: array.array[int], max_frames: int = 16,
) -> float:
    scores = []
    for frame_shift in range(-max_frames, max_frames + 1):
        sample_shift = frame_shift * 2
        if sample_shift < 0:
            a = left[-sample_shift:]
            b = right
        else:
            a = left
            b = right[sample_shift:]
        scores.append(correlation(a, b))
    return max(scores)


def strip_transport(
    data: bytes, rate: int, expected_non_audio: bool = False,
) -> tuple[bytes, int]:
    pcm = bytearray()
    ends = 0
    position = 0
    expected_mode = 0x03 if rate == 48000 else 0x01
    while position < len(data):
        marker = data[position:position + 4]
        if marker == PCM_MARKER:
            if position + 5 > len(data):
                raise RuntimeError("truncated PCM transport record")
            mode = data[position + 4]
            if mode & 3 != expected_mode:
                raise RuntimeError(f"wrong PCM transport mode 0x{mode:02x}")
            if bool(mode & 0x80) != expected_non_audio:
                raise RuntimeError(
                    f"wrong PCM non-audio flag in mode 0x{mode:02x}"
                )
            frames = ((mode >> 2) & 0x1F) or 1
            size = 5 + frames * 4
            if position + size > len(data):
                raise RuntimeError("truncated PCM transport payload")
            for frame in range(frames):
                base = position + 5 + frame * 4
                pcm += data[base:base + 2][::-1]
                pcm += data[base + 2:base + 4][::-1]
            position += size
        elif marker == PCM_END_MARKER:
            ends += 1
            position += 4
        else:
            raise RuntimeError(f"unexpected non-audio byte at transport offset {position}")
    return bytes(pcm), ends


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--helper", type=Path, required=True)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.helper.is_file():
        raise SystemExit(f"missing helper: {args.helper}")
    if not args.ffmpeg:
        raise SystemExit("ffmpeg is required to generate independent fixtures")

    with tempfile.TemporaryDirectory(prefix="consumer_wav_test.") as name:
        temporary = Path(name)
        outputs: dict[str, bytes] = {}
        for profile in PROFILES:
            wav = temporary / f"{profile.name}.wav"
            actual = temporary / f"{profile.name}.actual.pcm"
            reference = temporary / f"{profile.name}.reference.pcm"
            video = temporary / f"{profile.name}.video"
            generate(args.ffmpeg, profile, wav)
            decode_reference(args.ffmpeg, wav, profile.output_rate, reference)
            completed = run([
                str(args.helper), "--protocol", "1", "--source", f"file:{wav}",
                "--pcm-out", str(actual), "--video-out", str(video),
            ], capture_output=True)
            stderr = completed.stderr.decode(errors="replace")
            expected_log = (
                f"WAV {profile.channels} channel(s) at {profile.source_rate} Hz, "
                f"output {profile.output_rate} Hz"
            )
            if expected_log not in stderr:
                raise RuntimeError(f"{profile.name}: missing format report: {stderr}")
            if video.read_bytes():
                raise RuntimeError(f"{profile.name}: WAV emitted video bytes")
            actual_data = actual.read_bytes()
            reference_data = reference.read_bytes()
            if profile.exact and actual_data != reference_data:
                raise RuntimeError(f"{profile.name}: direct s16 path is not exact")
            actual_samples = samples(actual_data)
            reference_samples = samples(reference_data)
            length_error = abs(len(actual_samples) - len(reference_samples))
            if length_error > 16:
                raise RuntimeError(
                    f"{profile.name}: PCM length differs by {length_error} samples"
                )
            if profile.channels != 6:
                score = aligned_correlation(actual_samples, reference_samples)
                if score < 0.995:
                    raise RuntimeError(
                        f"{profile.name}: reference correlation only {score:.6f}"
                    )
            elif max(map(abs, actual_samples), default=0) < 100:
                raise RuntimeError("surround downmix is unexpectedly silent")
            outputs[profile.name] = actual_data

        transport_source = temporary / "s16_stereo_44100.wav"
        transported = run([
            str(args.helper), "--protocol", "1", "--audio-out", "spdif", "--source",
            f"file:{transport_source}",
        ], capture_output=True)
        transport_pcm, end_count = strip_transport(transported.stdout, 44100)
        if transport_pcm != outputs["s16_stereo_44100"] or end_count != 1:
            raise RuntimeError("in-band WAV transport differs from explicit PCM output")

        invalid = temporary / "renamed.wav"
        invalid.write_bytes(b"ID3\x04\x00\x00\x00\x00\x00\x00not a WAV file")
        invalid_pcm = temporary / "invalid.pcm"
        rejected = subprocess.run([
            str(args.helper), "--protocol", "1", "--source", f"file:{invalid}",
            "--pcm-out", str(invalid_pcm),
        ], capture_output=True, check=False)
        if rejected.returncode == 0 or rejected.stdout:
            raise RuntimeError("renamed non-WAV input was accepted")
        if invalid_pcm.exists() and invalid_pcm.stat().st_size:
            raise RuntimeError("renamed non-WAV input emitted PCM")

    print(
        "PASS WAV: u8/s16/s24/s32/float, mono/stereo/5.1, "
        "22.05/44.1/48/96 kHz conversion, exact direct s16, "
        "one in-band end marker, renamed-file rejection"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
