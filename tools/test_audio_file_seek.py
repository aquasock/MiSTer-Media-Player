#!/usr/bin/env python3
"""Exercise standalone-audio READY/GO seeks through the real helper."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import selectors
import shutil
import socket
import subprocess
import tempfile
import time


READY = 0x81
GO = 0x03
SEEK_BACK_10 = 0x0A
SEEK_FORWARD_10 = 0x0B
SEEK_FORWARD_60 = 0x0D
SEEK_CONTINUE = 0x85
SEEK_RE = re.compile(
    rb"audio seek ([+-]10) seconds current=([0-9]+) target=([0-9]+) "
    rb"length=([0-9]+) rate=([0-9]+)"
)
IGNORED_RE = re.compile(
    rb"ignoring audio seek \+60 seconds at boundary current=([0-9]+) "
    rb"length=([0-9]+) rate=([0-9]+)"
)
DURATION_RE = re.compile(
    rb"audio UI duration frames=([0-9]+) rate=([0-9]+)"
)
PCM_MARKER = 0xB1
PCM_END_MARKER = 0xB6
DISPLAY_MARKER = 0xB9
AUDIO_UI_BEGIN = 0x10
AUDIO_UI_DATA = 0x11
AUDIO_UI_COMMIT = 0x12
AUDIO_UI_FRAME_BYTES = 720 * 480 * 3 // 2


TIME_GLYPHS = {
    "0": (14, 17, 19, 21, 25, 17, 14),
    "1": (4, 12, 4, 4, 4, 4, 14),
    "2": (14, 17, 1, 2, 4, 8, 31),
    "3": (30, 1, 1, 14, 1, 1, 30),
    "4": (2, 6, 10, 18, 31, 2, 2),
    "5": (31, 16, 16, 30, 1, 1, 30),
    "6": (14, 16, 16, 30, 17, 17, 14),
    "7": (31, 1, 2, 4, 8, 8, 8),
    "8": (14, 17, 17, 14, 17, 17, 14),
    "9": (14, 17, 17, 15, 1, 1, 14),
    ":": (0, 4, 4, 0, 4, 4, 0),
}


def make_fixture(directory: Path, extension: str, rate: int,
                 codec: list[str]) -> Path:
    output = directory / f"seek.{extension}"
    command = [
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i",
        f"sine=frequency=997:sample_rate={rate}:duration=12",
        "-map_metadata", "-1", "-ac", "2", *codec, str(output),
    ]
    subprocess.run(command, check=True)
    return output


def drain_fd(fd: int, capture: bytearray | None = None) -> int:
    total = 0
    while True:
        try:
            data = os.read(fd, 16384)
        except BlockingIOError:
            break
        if not data:
            break
        total += len(data)
        if capture is not None:
            capture.extend(data)
    return total


def final_audio_ui_frame(stream: bytes) -> bytes:
    offset = 0
    current = bytearray()
    final = b""

    while offset < len(stream):
        if stream[offset:offset + 3] != b"\x00\x00\x01":
            raise RuntimeError(f"unframed helper output at byte {offset}")
        code = stream[offset + 3]
        if code == PCM_MARKER:
            frames = (stream[offset + 4] >> 2) & 0x1F
            offset += 5 + frames * 4
            continue
        if code == PCM_END_MARKER:
            offset += 4
            continue
        if code != DISPLAY_MARKER:
            raise RuntimeError(
                f"unexpected audio-only marker 0x{code:02x} at {offset}"
            )
        size = int.from_bytes(stream[offset + 4:offset + 6], "big")
        end = offset + 6 + size
        if size < 1 or end > len(stream):
            raise RuntimeError(f"truncated display record at byte {offset}")
        command = stream[offset + 6]
        payload = stream[offset + 7:end]
        if command == AUDIO_UI_BEGIN:
            current.clear()
        elif command == AUDIO_UI_DATA:
            current.extend(payload)
        elif command == AUDIO_UI_COMMIT:
            if len(current) != AUDIO_UI_FRAME_BYTES:
                raise RuntimeError(
                    f"audio UI committed {len(current)} bytes"
                )
            final = bytes(current)
        offset = end
    if not final:
        raise RuntimeError("audio UI emitted no complete frame")
    return final


def check_time(frame: bytes, x: int, y: int, seconds: int) -> None:
    text = f"{seconds // 60:02d}:{seconds % 60:02d}"

    for index, character in enumerate(text):
        rows = TIME_GLYPHS[character]
        for row, bits in enumerate(rows):
            for column in range(5):
                expected = 220 if bits & (1 << (4 - column)) else 16
                actual = frame[(y + row) * 720 + x + index * 6 + column]
                if actual != expected:
                    raise RuntimeError(
                        f"timer {text} raster mismatch at "
                        f"{x + index * 6 + column},{y + row}: "
                        f"{actual} != {expected}"
                    )


def run_fixture(helper: Path, fixture: Path) -> None:
    parent, child = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
    process = subprocess.Popen(
        [str(helper), "--protocol", "1", "--source", f"file:{fixture}",
         "--control-fd", str(child.fileno())],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        pass_fds=(child.fileno(),),
    )
    child.close()
    assert process.stdout is not None
    assert process.stderr is not None
    os.set_blocking(process.stdout.fileno(), False)
    os.set_blocking(process.stderr.fileno(), False)
    parent.setblocking(False)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ, "stdout")
    selector.register(process.stderr, selectors.EVENT_READ, "stderr")
    selector.register(parent, selectors.EVENT_READ, "control")
    error_output = bytearray()
    stream_output = bytearray()
    output_bytes = 0
    after_go_bytes = 0
    forward_sent = False
    backward_sent = False
    overshoot_sent = False
    overshoot_output_start = 0
    ready_count = 0
    continue_count = 0
    deadline = time.monotonic() + 20.0

    try:
        while process.poll() is None and time.monotonic() < deadline:
            for key, _ in selector.select(0.1):
                if key.data == "stdout":
                    count = drain_fd(process.stdout.fileno(), stream_output)
                    output_bytes += count
                    if ready_count == 1:
                        after_go_bytes += count
                elif key.data == "stderr":
                    drain_fd(process.stderr.fileno(), error_output)
                else:
                    try:
                        event = parent.recv(1)
                    except BlockingIOError:
                        event = b""
                    if event == bytes((READY,)):
                        ready_count += 1
                        output_bytes += drain_fd(
                            process.stdout.fileno(), stream_output
                        )
                        parent.send(bytes((GO,)))
                        if ready_count == 2 and not overshoot_sent:
                            parent.send(bytes((SEEK_FORWARD_60,)))
                            overshoot_sent = True
                            overshoot_output_start = output_bytes
                    elif event == bytes((SEEK_CONTINUE,)):
                        continue_count += 1
                    elif event:
                        raise RuntimeError(
                            f"{fixture.suffix}: unexpected control {event.hex()}"
                        )
            if not forward_sent and output_bytes >= 8192:
                parent.send(bytes((SEEK_FORWARD_10,)))
                forward_sent = True
            if (ready_count == 1 and not backward_sent and
                    after_go_bytes >= 4096):
                parent.send(bytes((SEEK_BACK_10,)))
                backward_sent = True

        if process.poll() is None:
            process.kill()
            process.wait()
            raise RuntimeError(f"{fixture.suffix}: helper timed out")
        output_bytes += drain_fd(process.stdout.fileno(), stream_output)
        drain_fd(process.stderr.fileno(), error_output)
    finally:
        selector.close()
        parent.close()

    if process.returncode != 0:
        raise RuntimeError(
            f"{fixture.suffix}: helper exited {process.returncode}:\n"
            + error_output.decode(errors="replace")
        )
    matches = SEEK_RE.findall(error_output)
    ignored = IGNORED_RE.findall(error_output)
    durations = DURATION_RE.findall(error_output)
    if (ready_count != 2 or continue_count != 1 or len(matches) != 2 or
            len(ignored) != 1):
        raise RuntimeError(
            f"{fixture.suffix}: expected two barriers/seeks and one "
            f"barrier-free end no-op, got ready={ready_count} "
            f"continue={continue_count} "
            f"seeks={len(matches)} ignored={len(ignored)}:\n"
            + error_output.decode(errors="replace")
        )
    if len(durations) != 1:
        raise RuntimeError(
            f"{fixture.suffix}: expected one UI duration, got "
            f"{len(durations)}:\n" + error_output.decode(errors="replace")
        )
    duration_frames, duration_rate = map(int, durations[0])
    for signed, current, target, length, rate in matches:
        seconds = int(signed)
        current_frame = int(current)
        target_frame = int(target)
        length_frames = int(length)
        rate_hz = int(rate)
        expected = current_frame + seconds * rate_hz
        expected = min(max(expected, 0), length_frames)
        if target_frame != expected:
            raise RuntimeError(
                f"{fixture.suffix}: target {target_frame}, expected {expected}"
            )
        if length_frames != duration_frames or rate_hz != duration_rate:
            raise RuntimeError(
                f"{fixture.suffix}: UI duration {duration_frames}/{duration_rate} "
                f"does not match seek timeline {length_frames}/{rate_hz}"
            )
    ignored_current, ignored_length, ignored_rate = map(int, ignored[0])
    if ignored_current >= ignored_length:
        raise RuntimeError(
            f"{fixture.suffix}: end no-op arrived outside playable range "
            f"{ignored_current}/{ignored_length}"
        )
    if ignored_rate != duration_rate:
        raise RuntimeError(
            f"{fixture.suffix}: end no-op rate {ignored_rate} does not "
            f"match timeline rate {duration_rate}"
        )
    if output_bytes - overshoot_output_start < 4096:
        raise RuntimeError(
            f"{fixture.suffix}: playback did not continue after end no-op"
        )
    final_frame = final_audio_ui_frame(stream_output)
    duration_seconds = duration_frames // duration_rate
    check_time(final_frame, 258, 412, duration_seconds)
    check_time(final_frame, 348, 412, 0)
    if (final_frame[444 * 720 + 34] != 178 or
            final_frame[444 * 720 + 685] != 178):
        raise RuntimeError(
            f"{fixture.suffix}: final progress bar is not complete"
        )
    print(
        f"audio file seek {fixture.suffix}: PASS ready={ready_count} "
        f"continue={continue_count} "
        f"duration={duration_frames}/{duration_rate} "
        f"output={output_bytes} bytes"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("helper", type=Path)
    args = parser.parse_args()
    helper = args.helper.resolve()
    if not helper.is_file():
        parser.error(f"helper does not exist: {helper}")
    if shutil.which("ffmpeg") is None:
        parser.error("ffmpeg is required")

    formats = (
        ("mp3", 44100, ["-c:a", "libmp3lame", "-b:a", "128k"]),
        ("wav", 48000, ["-c:a", "pcm_s16le"]),
        ("flac", 44100, ["-c:a", "flac"]),
        ("ogg", 48000, ["-c:a", "libvorbis", "-q:a", "4"]),
    )
    with tempfile.TemporaryDirectory(prefix="mmp-audio-seek-") as temporary:
        directory = Path(temporary)
        for extension, rate, codec in formats:
            run_fixture(helper, make_fixture(directory, extension, rate, codec))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
