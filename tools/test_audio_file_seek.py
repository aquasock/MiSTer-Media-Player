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
SEEK_RE = re.compile(
    rb"audio seek ([+-]10) seconds current=([0-9]+) target=([0-9]+) "
    rb"length=([0-9]+) rate=([0-9]+)"
)
DURATION_RE = re.compile(
    rb"audio UI duration frames=([0-9]+) rate=([0-9]+)"
)


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
    output_bytes = 0
    after_go_bytes = 0
    forward_sent = False
    backward_sent = False
    ready_count = 0
    deadline = time.monotonic() + 20.0

    try:
        while process.poll() is None and time.monotonic() < deadline:
            for key, _ in selector.select(0.1):
                if key.data == "stdout":
                    count = drain_fd(process.stdout.fileno())
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
                        output_bytes += drain_fd(process.stdout.fileno())
                        parent.send(bytes((GO,)))
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
        drain_fd(process.stdout.fileno())
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
    durations = DURATION_RE.findall(error_output)
    if ready_count != 2 or len(matches) != 2:
        raise RuntimeError(
            f"{fixture.suffix}: expected two barriers/seeks, got "
            f"ready={ready_count} seeks={len(matches)}:\n"
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
    print(
        f"audio file seek {fixture.suffix}: PASS ready={ready_count} "
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
