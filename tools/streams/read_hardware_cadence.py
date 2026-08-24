#!/usr/bin/env python3
"""Read the cadence snapshot from a stream the user launched themselves.

Entry 373: run_hardware_cadence.py launches a stream via MGL and screenshots
it, but its launch path has repeatedly disagreed with normal operation --
reporting picture and byte counts that do not match the stream given to it, and
error flags on streams that pass when launched from the core's own file
selector.  Those artefacts reproduce on an archived, independently validated
image, so they are properties of that harness rather than of the core.

This reads telemetry without launching anything: trigger a screenshot on the
MiSTer, fetch it, decode it.  Start the stream however you normally would,
leave it on screen, then run this.
"""

from __future__ import annotations

import argparse
import json
from ftplib import FTP
from io import BytesIO
from pathlib import Path
import sys
import time

import pexpect

from decode_hardware_cadence import TelemetryDecodeError, decode

REMOTE_SHOT = "/media/fat/screenshots/cadence_probe.png"


def trigger_screenshot(host: str, user: str, password: str) -> None:
    child = pexpect.spawn(
        f"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        f"{user}@{host}", timeout=20, encoding="utf-8")
    index = child.expect(["[Pp]assword:", r"[#$] $"])
    if index == 0:
        child.sendline(password)
        child.expect(r"[#$] $")
    child.sendline("echo screenshot cadence_probe.png > /dev/MiSTer_cmd")
    child.expect(r"[#$] $")
    child.sendline("exit")
    child.close()


def fetch(host: str, user: str, password: str, dest: Path) -> None:
    ftp = FTP()
    ftp.connect(host, 21, timeout=20)
    ftp.login(user, password)
    buf = BytesIO()
    ftp.retrbinary(f"RETR {REMOTE_SHOT}", buf.write)
    ftp.quit()
    dest.write_bytes(buf.getvalue())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="10.10.0.30")
    ap.add_argument("--user", default="root")
    ap.add_argument("--password", default="1")
    ap.add_argument("--output", type=Path, default=Path("/tmp/cadence_probe.png"))
    ap.add_argument("--settle", type=float, default=2.0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    trigger_screenshot(args.host, args.user, args.password)
    time.sleep(args.settle)
    fetch(args.host, args.user, args.password, args.output)

    try:
        result = decode(args.output)
    except TelemetryDecodeError as exc:
        print(f"decode failed: {exc}", file=sys.stderr)
        print("the overlay may not be on screen; the snapshot is drawn by the "
              "cadence profiler and must be visible when the screenshot is taken",
              file=sys.stderr)
        return 1

    result["screenshot"] = str(args.output)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for key in ("schema_version", "associated_count", "display_pts_low11",
                    "pcm_sample_count", "pcm_fifo_peak", "audio_underrun",
                    "pcm_protocol_error", "stc_seconds", "error_flags",
                    "sequence_end_seen", "session_quiet"):
            if key in result:
                print(f"{key:20} {result[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
