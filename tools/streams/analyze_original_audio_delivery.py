#!/usr/bin/env python3
"""Validate an integrated original-opening audio-delivery trace."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("log", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--complete", action="store_true",
                        help="require end-of-stream playback completion")
    args = parser.parse_args()

    rows = list(csv.DictReader(args.trace.open(newline="")))
    if not rows:
        raise RuntimeError("empty audio delivery trace")
    events = [row["event"] for row in rows]
    numeric = ("cycle", "video_byte", "transport_byte", "audio_written",
               "audio_read", "audio_used", "clean_used", "underrun",
               "pcm_error")
    parsed = [{key: int(row[key]) for key in numeric} for row in rows]
    log = args.log.read_text(errors="replace")
    result_match = re.search(
        r"AUDIO_TRANSPORT_RESULT complete=(\d+) starvation_intervals=(\d+) "
        r"underrun=(\d+) protocol_error=(\d+) written=(\d+) read=(\d+) "
        r"max_used=(\d+)", log)
    prefix_match = re.search(
        r"AUDIO_PREFIX_PASS cycle=(\d+) video=(\d+) transport=(\d+) "
        r"starvation_intervals=(\d+) writes=(\d+) reads=(\d+) max_used=(\d+)",
        log)
    if result_match is None:
        raise RuntimeError("simulation log has no audio transport result")
    complete, intervals, underrun, protocol, written, read, max_used = (
        int(value) for value in result_match.groups())
    problems: list[str] = []
    if events.count("START") != 1:
        problems.append(f"START count is {events.count('START')}, expected one")
    for forbidden in ("EMPTY", "UNDERRUN"):
        if forbidden in events:
            problems.append(f"trace contains {forbidden}")
    if intervals or underrun or protocol:
        problems.append(
            f"result reports intervals/underrun/protocol={intervals}/{underrun}/{protocol}")
    if any(row["underrun"] or row["pcm_error"] for row in parsed):
        problems.append("sampled trace reports an audio error")
    if max(row["clean_used"] for row in parsed) > 65536:
        problems.append("clean-video queue exceeded 65536 bytes")
    if max(row["audio_used"] for row in parsed) > 8191 or max_used > 8191:
        problems.append("audio FIFO used count exceeded its reported full-scale value")
    if args.complete and not complete:
        problems.append("playback did not complete")
    if not args.complete and prefix_match is None:
        problems.append("bounded replay has no AUDIO_PREFIX_PASS result")
    report = {
        "passed": not problems,
        "scope": "Behavioral FIFO capacity and production-path delivery order; "
                 "not an FPGA CDC timing or physical receiver model.",
        "complete_required": args.complete,
        "playback_complete": bool(complete),
        "events": {name: events.count(name) for name in sorted(set(events))},
        "starvation_intervals": intervals,
        "underrun": bool(underrun),
        "pcm_protocol_error": bool(protocol),
        "audio_frames_written": written,
        "audio_frames_read": read,
        "max_audio_used": max_used,
        "max_clean_video_used": max(row["clean_used"] for row in parsed),
        "last_video_byte": parsed[-1]["video_byte"],
        "last_transport_byte": parsed[-1]["transport_byte"],
        "problems": problems,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
