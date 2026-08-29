#!/usr/bin/env python3
"""Verify consumer FLAC decode, conversion, resampling and transport output."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from verify_consumer_wav import aligned_correlation, run, samples, strip_transport


@dataclass(frozen=True)
class Profile:
    name: str
    sample_format: str
    channels: int
    source_rate: int
    output_rate: int
    exact: bool = False


PROFILES = (
    Profile("s16_mono_44100", "s16", 1, 44100, 44100),
    Profile("s16_stereo_44100", "s16", 2, 44100, 44100, True),
    Profile("s16_stereo_48000", "s16", 2, 48000, 48000, True),
    Profile("s24_stereo_44100", "s32", 2, 44100, 44100),
    Profile("s16_mono_22050", "s16", 1, 22050, 44100),
    Profile("s24_stereo_96000", "s32", 2, 96000, 48000),
    Profile("s16_surround_48000", "s16", 6, 48000, 48000),
)


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
        "-f", "lavfi", "-i", source, "-c:a", "flac",
        "-sample_fmt", profile.sample_format,
        "-metadata", f"title=MiSTer {profile.name} FLAC fixture",
        "-metadata", "artist=MiSTer Media Player", str(output),
    ])


def decode_reference(ffmpeg: str, source: Path, rate: int, output: Path) -> None:
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
        "-f", "s16le", "-c:a", "pcm_s16le", "-ar", str(rate), "-ac", "2",
        str(output),
    ])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--helper", type=Path, required=True)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--ffprobe", default=shutil.which("ffprobe"))
    args = parser.parse_args()
    if not args.helper.is_file():
        raise SystemExit(f"missing helper: {args.helper}")
    if not args.ffmpeg or not args.ffprobe:
        raise SystemExit("ffmpeg and ffprobe are required")

    with tempfile.TemporaryDirectory(prefix="consumer_flac_test.") as name:
        temporary = Path(name)
        outputs: dict[str, bytes] = {}
        observed_24_bit = False
        for profile in PROFILES:
            flac = temporary / f"{profile.name}.flac"
            actual = temporary / f"{profile.name}.actual.pcm"
            reference = temporary / f"{profile.name}.reference.pcm"
            video = temporary / f"{profile.name}.video"
            generate(args.ffmpeg, profile, flac)
            probe = run([
                args.ffprobe, "-v", "error", "-show_entries",
                "stream=bits_per_raw_sample", "-of", "default=nw=1:nk=1",
                str(flac),
            ], capture_output=True)
            bits = int(probe.stdout.decode().strip())
            if profile.sample_format == "s32":
                if bits != 24:
                    raise RuntimeError(f"{profile.name}: generated {bits}-bit FLAC")
                observed_24_bit = True
            decode_reference(args.ffmpeg, flac, profile.output_rate, reference)
            completed = run([
                str(args.helper), "--protocol", "1", "--source", f"file:{flac}",
                "--pcm-out", str(actual), "--video-out", str(video),
            ], capture_output=True)
            stderr = completed.stderr.decode(errors="replace")
            expected_log = (
                f"FLAC {profile.channels} channel(s) at {profile.source_rate} Hz, "
                f"output {profile.output_rate} Hz"
            )
            if expected_log not in stderr:
                raise RuntimeError(f"{profile.name}: missing format report: {stderr}")
            if video.read_bytes():
                raise RuntimeError(f"{profile.name}: FLAC emitted video bytes")
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
                raise RuntimeError("FLAC surround downmix is unexpectedly silent")
            outputs[profile.name] = actual_data

        if not observed_24_bit:
            raise RuntimeError("24-bit FLAC coverage was not generated")
        transport_source = temporary / "s16_stereo_44100.flac"
        transported = run([
            str(args.helper), "--protocol", "1", "--source",
            f"file:{transport_source}",
        ], capture_output=True)
        transport_pcm, end_count = strip_transport(transported.stdout, 44100)
        if transport_pcm != outputs["s16_stereo_44100"] or end_count != 1:
            raise RuntimeError("in-band FLAC transport differs from explicit PCM output")

        invalid = temporary / "renamed.flac"
        invalid.write_bytes(b"RIFF\x10\x00\x00\x00WAVEnot a FLAC file")
        invalid_pcm = temporary / "invalid.pcm"
        rejected = subprocess.run([
            str(args.helper), "--protocol", "1", "--source", f"file:{invalid}",
            "--pcm-out", str(invalid_pcm),
        ], capture_output=True, check=False)
        if rejected.returncode == 0 or rejected.stdout:
            raise RuntimeError("renamed non-FLAC input was accepted")
        if invalid_pcm.exists() and invalid_pcm.stat().st_size:
            raise RuntimeError("renamed non-FLAC input emitted PCM")

    print(
        "PASS FLAC: 16/24-bit, metadata, mono/stereo/5.1, "
        "22.05/44.1/48/96 kHz conversion, exact direct s16, "
        "one in-band end marker, renamed-file rejection"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
