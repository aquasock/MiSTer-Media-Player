#!/usr/bin/env python3
"""Load a development RBF/stream on MiSTer and acquire cadence telemetry."""

from __future__ import annotations

import argparse
from ftplib import FTP, error_perm
from io import BytesIO
import json
import os
from pathlib import Path
import shlex
import sys
import time

import pexpect

from decode_hardware_cadence import (
    TelemetryDecodeError,
    decode,
    validate,
)


REMOTE_DIR = "/media/fat/_cadence"
REMOTE_GAME_DIR = "/media/fat/games/MediaPlayer"
REMOTE_STREAM = f"{REMOTE_GAME_DIR}/cadence_stream.m2v"
REMOTE_SCREENSHOT_DIR = "/media/fat/screenshots"
REMOTE_SCREENSHOT = f"{REMOTE_SCREENSHOT_DIR}/cadence_probe.png"
REMOTE_MGL = f"{REMOTE_DIR}/run.mgl"
MGL_DELAY_SECONDS = 4


def ensure_ftp_directory(ftp: FTP, path: str) -> None:
    current = ""
    for component in path.strip("/").split("/"):
        current += "/" + component
        try:
            ftp.mkd(current)
        except error_perm as exc:
            if not str(exc).startswith("550"):
                raise


def upload_file(ftp: FTP, local_path: Path, remote_path: str) -> None:
    with local_path.open("rb") as source:
        ftp.storbinary(f"STOR {remote_path}", source)


class MisterShell:
    def __init__(self, host: str, user: str, password: str, timeout: int = 15):
        ssh_environment = os.environ.copy()
        ssh_environment.pop("DISPLAY", None)
        ssh_environment.pop("SSH_ASKPASS", None)
        ssh_environment["SSH_ASKPASS_REQUIRE"] = "never"
        self.child = pexpect.spawn(
            "ssh",
            [
                "-F",
                "/dev/null",
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
                "-o",
                "PreferredAuthentications=password",
                f"{user}@{host}",
            ],
            encoding="utf-8",
            timeout=timeout,
            env=ssh_environment,
        )
        while True:
            match = self.child.expect(
                [r"(?i)password:\s*$", r"[#>$]\s*$", pexpect.EOF, pexpect.TIMEOUT]
            )
            if match == 0:
                self.child.sendline(password)
            elif match == 1:
                break
            elif match == 2:
                raise RuntimeError("SSH ended before a MiSTer shell prompt appeared")
            else:
                raise RuntimeError("timed out connecting to the MiSTer shell")

    def fifo(self, command: str) -> None:
        shell_command = (
            "printf '%s\\n' " + shlex.quote(command) + " > /dev/MiSTer_cmd"
        )
        self.child.sendline(shell_command)
        self.child.expect(r"[#>$]\s*$")

    def close(self) -> None:
        if self.child.isalive():
            self.child.sendline("exit")
            self.child.close(force=True)


def make_mgl() -> bytes:
    return (
        "<mistergamedescription>\n"
        "  <rbf>_cadence/cadence</rbf>\n"
        f"  <file delay=\"{MGL_DELAY_SECONDS}\" type=\"f\" index=\"1\" "
        "path=\"cadence_stream.m2v\"/>\n"
        "</mistergamedescription>\n"
    ).encode("utf-8")


def retrieve_screenshot(ftp: FTP, output: Path) -> None:
    temporary = output.with_name(output.name + ".part")
    output.parent.mkdir(parents=True, exist_ok=True)
    with temporary.open("wb") as destination:
        ftp.retrbinary(f"RETR {REMOTE_SCREENSHOT}", destination.write)
    temporary.replace(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("rbf", type=Path)
    parser.add_argument("stream", type=Path)
    parser.add_argument("--host", default="10.10.0.30")
    parser.add_argument("--user", default="root")
    parser.add_argument("--password", default=os.environ.get("MISTER_PASSWORD", "1"))
    parser.add_argument("--expected-pictures", type=int, required=True)
    parser.add_argument("--require-fps", type=float)
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--poll-interval", type=float, default=2.0)
    parser.add_argument(
        "--initial-wait",
        type=float,
        default=5.0,
        help="seconds to wait before the first screenshot request",
    )
    parser.add_argument(
        "--output", type=Path, default=Path("/tmp/mister_cadence.png")
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if not args.rbf.is_file():
        parser.error(f"RBF not found: {args.rbf}")
    if not args.stream.is_file():
        parser.error(f"stream not found: {args.stream}")
    if args.poll_interval <= 0 or args.timeout <= 0:
        parser.error("timeout and poll interval must be positive")
    if args.initial_wait < MGL_DELAY_SECONDS:
        parser.error(
            f"initial wait must be at least the {MGL_DELAY_SECONDS}-second "
            "MGL file-injection delay"
        )

    ftp = FTP(args.host, timeout=15)
    shell: MisterShell | None = None
    try:
        ftp.login(args.user, args.password)
        ensure_ftp_directory(ftp, REMOTE_DIR)
        ensure_ftp_directory(ftp, REMOTE_GAME_DIR)
        ensure_ftp_directory(ftp, REMOTE_SCREENSHOT_DIR)
        upload_file(ftp, args.rbf, f"{REMOTE_DIR}/cadence.rbf")
        upload_file(ftp, args.stream, REMOTE_STREAM)
        ftp.storbinary(f"STOR {REMOTE_MGL}", BytesIO(make_mgl()))
        try:
            ftp.delete(REMOTE_SCREENSHOT)
        except error_perm:
            pass

        shell = MisterShell(args.host, args.user, args.password)
        shell.fifo(f"load_core {REMOTE_MGL}")
        time.sleep(args.initial_wait)

        deadline = time.monotonic() + args.timeout
        last_error = "telemetry screenshot not yet available"
        result = None
        while time.monotonic() < deadline:
            time.sleep(min(args.poll_interval, max(0.0, deadline-time.monotonic())))
            try:
                ftp.delete(REMOTE_SCREENSHOT)
            except error_perm:
                pass
            shell.fifo("screenshot cadence_probe.png")
            time.sleep(0.75)
            try:
                retrieve_screenshot(ftp, args.output)
                result = decode(args.output)
                break
            except (error_perm, FileNotFoundError, TelemetryDecodeError) as exc:
                last_error = str(exc)

        if result is None:
            raise RuntimeError(
                f"no valid telemetry after {args.timeout:.1f} seconds: {last_error}"
            )

        failures = validate(
            result,
            expected_pictures=args.expected_pictures,
            expected_bytes=args.stream.stat().st_size,
            require_fps=args.require_fps,
        )
        result["stream"] = str(args.stream)
        result["rbf"] = str(args.rbf)
        result["screenshot"] = str(args.output)
        result["validation_failures"] = failures
        if args.json:
            print(json.dumps(result, indent=2, sort_keys=True))
        else:
            print(
                f"MiSTer hardware: {result['display_pictures']} pictures, "
                f"{result['cadence_seconds']:.6f} s, "
                f"{result['delivered_fps']:.6f} fps"
            )
            print(
                "decoder/presentation/destination stalls: "
                f"{result['decoder_stall_cycles']}/"
                f"{result['presentation_stall_cycles']}/"
                f"{result['destination_stall_cycles']}"
            )
            print(
                "I/P/B decoder stalls: "
                f"{result['i_stall_cycles']}/"
                f"{result['p_stall_cycles']}/"
                f"{result['b_stall_cycles']}"
            )
            for failure in failures:
                print(f"FAIL: {failure}")
        return int(bool(failures))
    finally:
        if shell is not None:
            shell.close()
        try:
            ftp.quit()
        except Exception:
            ftp.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, error_perm, pexpect.ExceptionPexpect) as exc:
        print(f"hardware cadence acquisition failed: {exc}", file=sys.stderr)
        raise SystemExit(2)
