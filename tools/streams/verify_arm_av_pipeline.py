#!/usr/bin/env python3
"""Verify ARM helper demux, timestamps, audio decode, and failure paths."""

from __future__ import annotations

import argparse
import array
import math
import subprocess
import tempfile
from pathlib import Path

import check_media_compatibility as compatibility

PTS_MARKER = b"\x00\x00\x01\xb0"
PCM_MARKER = b"\x00\x00\x01\xb1"
PCM_END_MARKER = b"\x00\x00\x01\xb6"
RECORD_SIZE = 9


def sequence_header(frame_rate_code: int) -> bytes:
    """Return a minimal 720x480 H.262 sequence header for preflight tests."""
    return b"\x00\x00\x01\xb3\x2d\x01\xe0" + bytes([0x20 | frame_rate_code])


def split_sequence_program(reference_program: bytes, frame_rate_code: int) -> bytes:
    """Build a tiny PS whose first sequence header crosses two video PES packets."""
    if not reference_program.startswith(b"\x00\x00\x01\xba"):
        raise RuntimeError("reference fixture has no MPEG Program Stream pack header")
    first = reference_program[4]
    if first & 0xc0 == 0x40:
        pack_size = 14 + (reference_program[13] & 7)
    elif first & 0xf0 == 0x20:
        pack_size = 12
    else:
        raise RuntimeError("reference fixture has an invalid pack header")

    def video_pes(payload: bytes) -> bytes:
        body = b"\x80\x00\x00" + payload
        return b"\x00\x00\x01\xe0" + len(body).to_bytes(2, "big") + body

    header = sequence_header(frame_rate_code)
    return (
        reference_program[:pack_size]
        + video_pes(header[:2])
        + video_pes(header[2:])
        + b"\x00\x00\x01\xb9"
    )


def private_subpicture_program(reference_program: bytes) -> bytes:
    """Build a tiny silent PS proving non-audio private packets stay ignored."""
    if not reference_program.startswith(b"\x00\x00\x01\xba"):
        raise RuntimeError("reference fixture has no MPEG Program Stream pack header")
    first = reference_program[4]
    if first & 0xc0 == 0x40:
        pack_size = 14 + (reference_program[13] & 7)
    elif first & 0xf0 == 0x20:
        pack_size = 12
    else:
        raise RuntimeError("reference fixture has an invalid pack header")

    video_body = b"\x80\x00\x00" + sequence_header(2)
    private_body = b"\x80\x00\x00\x20subpicture"
    return (
        reference_program[:pack_size]
        + b"\x00\x00\x01\xe0" + len(video_body).to_bytes(2, "big") + video_body
        + b"\x00\x00\x01\xbd" + len(private_body).to_bytes(2, "big")
        + private_body
        + b"\x00\x00\x01\xb9"
    )


def require_rejected_without_output(
    completed: subprocess.CompletedProcess[bytes], label: str,
    output_paths: tuple[Path, ...] = (),
) -> None:
    stderr = completed.stderr.decode(errors="replace")
    if completed.returncode == 0:
        raise RuntimeError(f"{label} was accepted")
    if completed.stdout:
        raise RuntimeError(f"{label} emitted {len(completed.stdout)} transport bytes")
    for path in output_paths:
        if path.exists() and path.stat().st_size:
            raise RuntimeError(f"{label} emitted {path.stat().st_size} bytes to {path}")
    if "unsupported H.262 frame rate code" not in stderr:
        raise RuntimeError(f"{label} did not report the frame-rate rejection: {stderr}")


def strip_records(
    data: bytes, expected_sample_rate: int,
) -> tuple[bytes, list[int], bytes, int]:
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
            if position + 5 > len(data):
                raise RuntimeError("truncated PCM record")
            mode = data[position + 4]
            expected_mode = 0x03 if expected_sample_rate == 48000 else 0x01
            if mode & 0x03 != expected_mode:
                raise RuntimeError(
                    f"PCM record mode 0x{mode:02x} does not identify "
                    f"{expected_sample_rate} Hz stereo (expected 0x{expected_mode:02x})"
                )
            # Entry 462: the mode byte's upper six bits carry the frame count,
            # and zero is the earlier encoding of a single frame.
            frames = (mode >> 2) or 1
            size = 5 + 4 * frames
            if position + size > len(data):
                raise RuntimeError("truncated PCM record")
            for index in range(frames):
                base = position + 5 + index * 4
                pcm += data[base:base + 2][::-1] + data[base + 2:base + 4][::-1]
            position += size
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


def verify_mp3_transport(
    helper: Path,
    source: Path,
    reference_pcm: Path,
    sample_rate: int,
    temporary: Path,
    label: str,
) -> tuple[int, int, float]:
    """Verify audio-only MP3 through in-band, explicit, and legacy outputs."""
    transported = subprocess.run(
        [str(helper), "--protocol", "1", "--source", f"file:{source}"],
        capture_output=True,
    )
    if transported.returncode:
        raise RuntimeError(
            f"{label} failed: "
            + transported.stderr.decode(errors="replace").strip()
        )
    video, timestamps, inband_pcm, end_count = strip_records(
        transported.stdout, sample_rate
    )
    if video or timestamps or not inband_pcm or end_count != 1:
        raise RuntimeError(
            f"{label} transport is not audio-only: video={len(video)} "
            f"timestamps={timestamps} pcm={len(inband_pcm)} end={end_count}"
        )
    inband_path = temporary / f"{label}_inband.s16le"
    inband_path.write_bytes(inband_pcm)
    maximum, rms, correlation = pcm_metrics(inband_path, reference_pcm)
    if correlation < 0.97:
        raise RuntimeError(
            f"{label} PCM mismatch: max={maximum}, rms={rms:.4f}, "
            f"correlation={correlation:.6f}"
        )

    explicit_video = temporary / f"{label}_explicit.transport"
    explicit_pcm = temporary / f"{label}_explicit.s16le"
    explicit = subprocess.run(
        [str(helper), "--protocol", "1", "--source", f"file:{source}",
         "--video-out", str(explicit_video), "--pcm-out", str(explicit_pcm)],
        capture_output=True,
    )
    if explicit.returncode:
        raise RuntimeError(
            f"{label} explicit output failed: "
            + explicit.stderr.decode(errors="replace").strip()
        )
    if explicit_video.read_bytes():
        raise RuntimeError(f"{label} explicit output emitted video bytes")
    if explicit_pcm.read_bytes() != inband_pcm:
        raise RuntimeError(f"{label} explicit and in-band PCM differ")

    legacy_video = temporary / f"{label}_legacy.transport"
    legacy_pcm = temporary / f"{label}_legacy.s16le"
    legacy = subprocess.run(
        [str(helper), "--video-out", str(legacy_video),
         "--pcm-out", str(legacy_pcm), str(source)],
        capture_output=True,
    )
    if (legacy.returncode or legacy_video.read_bytes() or
            legacy_pcm.read_bytes() != explicit_pcm.read_bytes()):
        raise RuntimeError(f"{label} legacy path and file URI differ")
    return len(inband_pcm) // 4, maximum, correlation


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
    parser.add_argument(
        "--sample-rate", type=int, choices=(44100, 48000), default=48000,
    )
    args = parser.parse_args()
    raw_video = Path(__file__).resolve().parent / "test_b_bidirectional.m2v"
    rate_suffix = "" if args.sample_rate == 48000 else "_44k"
    if args.profile == "short":
        program = args.test_dir / f"01_arm_mp2_audio{rate_suffix}.mpg"
        reference_video_path = args.test_dir / f"reference_video{rate_suffix}.m2v"
        reference_pcm = args.test_dir / f"reference_audio{rate_suffix}.s16le"
    else:
        program = args.test_dir / f"02_arm_mp2_faded_tones{rate_suffix}.mpg"
        reference_video_path = (
            args.test_dir / f"reference_video_faded{rate_suffix}.m2v"
        )
        reference_pcm = (
            args.test_dir / f"reference_audio_faded{rate_suffix}.s16le"
        )
    minimum_correlation = 0.97
    reference_video = reference_video_path.read_bytes()

    capabilities = subprocess.run(
        [str(args.helper), "--capabilities"], text=True, capture_output=True,
    )
    expected_capabilities = (
        "protocol=1 sources=file reserved_sources=dvd "
        "containers=m2v,mpeg-ps,mp3,wav,flac video=h262 "
        "audio=mp2-s16le-44100,mp2-s16le-48000,"
        "mp3-s16le-44100,mp3-s16le-48000,"
        "wav-s16le-stereo-44100,wav-s16le-stereo-48000,"
        "flac-s16le-stereo-44100,flac-s16le-stereo-48000 "
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
            transported.stdout, args.sample_rate
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
            helper_video.read_bytes(), args.sample_rate
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

        mp3_cbr = args.test_dir / (
            f"03_arm_mp3_cbr_stereo_id3{rate_suffix}.mp3"
        )
        mp3_cbr_reference = args.test_dir / (
            f"reference_mp3_cbr_stereo{rate_suffix}.s16le"
        )
        mp3_vbr = args.test_dir / f"04_arm_mp3_vbr_mono{rate_suffix}.mp3"
        mp3_vbr_reference = args.test_dir / (
            f"reference_mp3_vbr_mono{rate_suffix}.s16le"
        )
        mp3_cbr_result = verify_mp3_transport(
            args.helper, mp3_cbr, mp3_cbr_reference, args.sample_rate,
            temp, "mp3_cbr_stereo",
        )
        mp3_vbr_result = verify_mp3_transport(
            args.helper, mp3_vbr, mp3_vbr_reference, args.sample_rate,
            temp, "mp3_vbr_mono",
        )

        unsupported_mp3 = args.test_dir / "bad_mp3_32000.mp3"
        unsupported = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{unsupported_mp3}"], capture_output=True,
        )
        if (unsupported.returncode == 0 or unsupported.stdout or
                b"unsupported MP3 format: 32000 Hz" not in unsupported.stderr):
            raise RuntimeError(
                "32 kHz MP3 was not rejected before transport: "
                + unsupported.stderr.decode(errors="replace").strip()
            )

        malformed_id3 = temp / "malformed_id3.mp3"
        malformed_id3.write_bytes(b"ID3\x04\x00\x00\x00\x00\x01\x00short")
        malformed = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{malformed_id3}"], capture_output=True,
        )
        if malformed.returncode == 0 or malformed.stdout:
            raise RuntimeError("truncated ID3v2 MP3 was accepted or emitted output")

        fake_mp3 = temp / "raw_video.mp3"
        fake_mp3.write_bytes(raw_video.read_bytes())
        fake = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{fake_mp3}"],
            capture_output=True,
        )
        if fake.returncode == 0 or fake.stdout:
            raise RuntimeError("H.262 renamed to MP3 was accepted or emitted output")

        truncated_mp3 = temp / "truncated.mp3"
        mp3_source = mp3_cbr.read_bytes()
        truncated_mp3.write_bytes(mp3_source[:-200])
        truncated_audio = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{truncated_mp3}"], capture_output=True,
        )
        if truncated_audio.returncode == 0:
            raise RuntimeError("truncated MP3 frame was accepted")

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

        for frame_rate_code in range(1, 6):
            supported_raw = temp / f"rate_code_{frame_rate_code}.m2v"
            supported_copy = temp / f"rate_code_{frame_rate_code}.copy.m2v"
            supported_raw.write_bytes(sequence_header(frame_rate_code))
            supported = subprocess.run(
                [str(args.helper), "--protocol", "1", "--source",
                 f"file:{supported_raw}", "--video-out", str(supported_copy)],
                capture_output=True,
            )
            if (supported.returncode or
                    supported_copy.read_bytes() != supported_raw.read_bytes()):
                raise RuntimeError(
                    f"supported H.262 frame-rate code {frame_rate_code} failed"
                )

        for frame_rate_code in range(6, 9):
            unsupported_raw = temp / f"rate_code_{frame_rate_code}.m2v"
            unsupported_pcm = temp / f"rate_code_{frame_rate_code}.pcm"
            unsupported_raw.write_bytes(sequence_header(frame_rate_code))
            rejected = subprocess.run(
                [str(args.helper), "--protocol", "1", "--source",
                 f"file:{unsupported_raw}", "--pcm-out", str(unsupported_pcm)],
                capture_output=True,
            )
            require_rejected_without_output(
                rejected, f"raw H.262 frame-rate code {frame_rate_code}",
                (unsupported_pcm,),
            )

        split_rate = temp / "split_rate_code_6.mpg"
        split_rate.write_bytes(split_sequence_program(source, 6))
        split_rejected = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source", f"file:{split_rate}"],
            capture_output=True,
        )
        require_rejected_without_output(
            split_rejected, "cross-PES H.262 frame-rate code 6"
        )

        envelope_rate = (
            Path(__file__).resolve().parent
            / "generated_compatibility" / "envelope" / "bad_rate_50.mpg"
        )
        envelope_pcm = temp / "bad_rate_50.pcm"
        envelope_rejected = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{envelope_rate}", "--pcm-out", str(envelope_pcm)],
            capture_output=True,
        )
        require_rejected_without_output(
            envelope_rejected, "compatibility bad_rate_50.mpg", (envelope_pcm,)
        )

        envelope_dir = envelope_rate.parent
        silent_program = envelope_dir / "good_video_only.mpg"
        silent_reference, _, _ = compatibility.demux_program_stream(
            silent_program.read_bytes()
        )
        silent = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{silent_program}"],
            capture_output=True,
        )
        if silent.returncode:
            raise RuntimeError(
                "video-only Program Stream failed: "
                + silent.stderr.decode(errors="replace").strip()
            )
        silent_video, silent_timestamps, silent_pcm, silent_end = strip_records(
            silent.stdout, 48000
        )
        if silent_video != silent_reference:
            raise RuntimeError(
                f"video-only payload differs: helper={len(silent_video)} "
                f"reference={len(silent_reference)}"
            )
        if (not silent_timestamps or
                silent_timestamps != sorted(silent_timestamps)):
            raise RuntimeError(
                f"video-only timestamps are invalid: {silent_timestamps}"
            )
        if silent_pcm or silent_end:
            raise RuntimeError("video-only Program Stream emitted PCM transport")

        # This fixture predates AC-3 support and retained its historical
        # filename. It is now a positive private-stream regression: the helper
        # must decode the AC-3 track and terminate its in-band PCM cleanly.
        ac3_audio = envelope_dir / "bad_audio_codec.mpg"
        ac3_supported = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{ac3_audio}"],
            capture_output=True,
        )
        if ac3_supported.returncode:
            raise RuntimeError(
                "AC-3 private audio failed: "
                + ac3_supported.stderr.decode(errors="replace").strip()
            )
        _, ac3_timestamps, ac3_pcm, ac3_end = strip_records(
            ac3_supported.stdout, 48000
        )
        if (not ac3_timestamps or ac3_timestamps != sorted(ac3_timestamps)
                or not ac3_pcm or ac3_end != 1):
            raise RuntimeError(
                "AC-3 private audio transport is incomplete: "
                f"timestamps={len(ac3_timestamps)} pcm={len(ac3_pcm)} "
                f"end={ac3_end}"
            )

        private_subpicture = temp / "private_subpicture.mpg"
        private_subpicture.write_bytes(private_subpicture_program(source))
        ignored_private = subprocess.run(
            [str(args.helper), "--protocol", "1", "--source",
             f"file:{private_subpicture}"],
            capture_output=True,
        )
        if ignored_private.returncode or ignored_private.stdout != sequence_header(2):
            raise RuntimeError(
                "non-audio private Program Stream packet was not ignored: "
                + ignored_private.stderr.decode(errors="replace").strip()
            )

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
        f"transport: {len(inband_pcm) // 4} PCM frames at {args.sample_rate} Hz, "
        "one clean end, "
        f"correlation {inband_correlation:.6f}"
    )
    print("errors: truncated Program Stream rejected")
    print(
        "mp3: CBR stereo+ID3 "
        f"{mp3_cbr_result[0]} frames/correlation {mp3_cbr_result[2]:.6f}; "
        "VBR mono->stereo "
        f"{mp3_vbr_result[0]} frames/correlation {mp3_vbr_result[2]:.6f}"
    )
    print("mp3 errors: 32 kHz, malformed ID3, fake and truncated input rejected")
    print("rates: H.262 codes 1-5 accepted; 6-8 rejected before transport")
    print("rates: cross-PES and compatibility-envelope rejection passed")
    print(
        "program-stream audio: video-only silent pass; AC-3 private audio "
        "accepted; private subpicture ignored"
    )
    print("compatibility: raw M2V copied byte-identically")
    print("protocol: capabilities stable; file URI equals legacy path")
    print("sources: missing/unknown rejected; dvd reserved without access")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
