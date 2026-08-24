#!/usr/bin/env python3
"""Check whether a user-converted file will play on this core.

The v0.7.0 goal is that people convert their own media with FFmpeg and test it,
so the failure a user is most likely to hit is an unsupported input rather than
a decoder defect.  This reports the answer before the file reaches hardware and
names the FFmpeg option that fixes each problem.

It is a conformance check against the current implementation envelope, not a
second decoder; macroblock semantics remain the RTL's responsibility.  Video
syntax is delegated to analyze_h262_compatibility so there is one parser.

Usage:  tools/streams/check_media_compatibility.py FILE [FILE ...]
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import analyze_h262_compatibility as h262

# The envelope the RTL actually admits.  Geometry is the guard in
# mpeg2_h262_b_core_probe_part0.svh; the paced rates are the cadence terms in
# mpeg2_h262_b_presentation_scheduler.sv; the audio formats are what
# host/arm/media_player_helper.c accepts and what audio_pcm_output_adapter.sv
# can clock out.
MAX_WIDTH, MAX_HEIGHT = 720, 480
MAX_MB_WIDTH, MAX_MB_HEIGHT = 45, 30
PACED_FRAME_RATE_CODES = {
    1: "24000/1001", 2: "24", 3: "25", 4: "30000/1001", 5: "30",
}
UNPACED_FRAME_RATE_CODES = {6: "50", 7: "59.94", 8: "60"}
AUDIO_RATES = (44100, 48000)
SEQUENCE_END_CODE = b"\x00\x00\x01\xb7"


def demux_program_stream(data: bytes) -> tuple[bytes, bytes, dict[str, Any]]:
    """Split a Program Stream the way the helper does: first video and audio
    stream id each, everything else skipped."""
    video, audio = bytearray(), bytearray()
    video_id = audio_id = None
    other_ids: set[int] = set()
    i = 0
    while i + 4 <= len(data):
        if data[i:i + 3] != b"\x00\x00\x01":
            i += 1
            continue
        sid = data[i + 3]
        if sid == 0xBA:
            i += 4
            if i < len(data) and (data[i] & 0xC0) == 0x40:
                i += 10
                if i <= len(data):
                    i += data[i - 1] & 0x07
            else:
                i += 8
            continue
        if sid == 0xB9:
            break
        if i + 6 > len(data):
            break
        length = (data[i + 4] << 8) | data[i + 5]
        payload = data[i + 6:i + 6 + length]
        if 0xE0 <= sid <= 0xEF:
            if video_id is None:
                video_id = sid
            if sid == video_id:
                video += strip_pes_header(payload)
        elif 0xC0 <= sid <= 0xDF:
            if audio_id is None:
                audio_id = sid
            if sid == audio_id:
                audio += strip_pes_header(payload)
        elif sid not in (0xBB, 0xBE, 0xBF):
            other_ids.add(sid)
        i += 6 + length
    return bytes(video), bytes(audio), {
        "video_stream_id": video_id,
        "audio_stream_id": audio_id,
        "ignored_stream_ids": sorted(other_ids),
    }


def strip_pes_header(payload: bytes) -> bytes:
    """Mirror parse_pes_header() in host/arm/media_player_helper.c exactly, so
    the checker demuxes what the helper will actually feed the decoder.

    The MPEG-2 form comes first: a '10' prefix means a 3-byte header plus
    PES_header_data_length more.  Only if that prefix is absent is the MPEG-1
    form parsed, where optional stuffing precedes a buffer-scale field and a
    5- or 10-byte timestamp, or a lone 0x0f when neither is present."""
    if not payload:
        return b""
    if (payload[0] & 0xC0) == 0x80:
        if len(payload) < 3:
            return b""
        header_size = 3 + payload[2]
        return payload[header_size:] if header_size <= len(payload) else b""
    pos = 0
    while pos < len(payload) and payload[pos] == 0xFF:
        pos += 1
    if pos < len(payload) and (payload[pos] & 0xC0) == 0x40:
        pos += 2
    if pos >= len(payload):
        return b""
    if (payload[pos] & 0xF0) == 0x20:
        pos += 5
    elif (payload[pos] & 0xF0) == 0x30:
        pos += 10
    elif payload[pos] == 0x0F:
        pos += 1
    else:
        return b""
    return payload[pos:]


def probe_audio(path: Path) -> dict[str, Any] | None:
    """Ask ffprobe about the first audio stream; the generators already
    require ffprobe, so this adds no new dependency."""
    tool = shutil.which("ffprobe")
    if not tool:
        return {"error": "ffprobe not found; audio could not be checked"}
    try:
        out = subprocess.run(
            [tool, "-v", "error", "-select_streams", "a:0", "-show_entries",
             "stream=codec_name,sample_rate,channels", "-of", "json", str(path)],
            check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError as exc:
        return {"error": f"ffprobe failed: {exc.stderr.strip()}"}
    streams = json.loads(out).get("streams", [])
    if not streams:
        return None
    stream = streams[0]
    return {
        "codec_name": stream.get("codec_name"),
        "sample_rate": int(stream.get("sample_rate", 0) or 0),
        "channels": int(stream.get("channels", 0) or 0),
    }


def check(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    problems: list[str] = []
    notes: list[str] = []
    report: dict[str, Any] = {"path": str(path), "bytes": len(data)}

    is_ps = data[:4] == b"\x00\x00\x01\xba"
    report["container"] = "program_stream" if is_ps else "elementary_stream"

    if is_ps:
        video, audio_es, ids = demux_program_stream(data)
        report.update(ids)
        if ids["ignored_stream_ids"]:
            notes.append(
                "extra stream ids present and ignored: "
                + ", ".join(f"0x{v:02x}" for v in ids["ignored_stream_ids"]))
    else:
        video, audio_es = data, b""

    if not video:
        problems.append("no MPEG-2 video stream found")
        report["problems"] = problems
        report["verdict"] = "FAIL"
        return report

    # --- video ------------------------------------------------------------
    scratch = path.with_suffix(path.suffix + ".video_es")
    try:
        scratch.write_bytes(video)
        analysis = h262.analyze_file(scratch)
    finally:
        scratch.unlink(missing_ok=True)

    sequence = analysis.get("sequence", {})
    width = sequence.get("horizontal_size", 0)
    height = sequence.get("vertical_size", 0)
    rate_code = sequence.get("frame_rate_code")
    report["video"] = {
        "width": width, "height": height,
        "frame_rate_code": rate_code,
        "pictures": analysis.get("picture_count"),
        "picture_type_counts": analysis.get("picture_type_counts"),
        "classification": analysis.get("classification"),
    }

    if width > MAX_WIDTH or height > MAX_HEIGHT:
        problems.append(
            f"geometry {width}x{height} exceeds the {MAX_WIDTH}x{MAX_HEIGHT} envelope; "
            f"add a scale filter, e.g. scale={MAX_WIDTH}:{MAX_HEIGHT}")
    if width and height:
        mb_w, mb_h = (width + 15) // 16, (height + 15) // 16
        if mb_w > MAX_MB_WIDTH or mb_h > MAX_MB_HEIGHT:
            problems.append(
                f"{mb_w}x{mb_h} macroblocks exceeds the {MAX_MB_WIDTH}x{MAX_MB_HEIGHT} envelope")

    if rate_code in UNPACED_FRAME_RATE_CODES:
        problems.append(
            f"frame_rate_code {rate_code} ({UNPACED_FRAME_RATE_CODES[rate_code]} fps) "
            "is not paced; re-encode at 24, 25, 29.97 or 30 fps")
    elif rate_code not in PACED_FRAME_RATE_CODES:
        problems.append(f"unsupported frame_rate_code {rate_code}")

    for reason in analysis.get("classification_reasons", []):
        problems.append(f"video: {reason}")

    if not video.rstrip(b"\x00").endswith(SEQUENCE_END_CODE[:4].rstrip(b"\x00")) \
            and SEQUENCE_END_CODE not in video[-64:]:
        notes.append(
            "no sequence_end_code near the end of the video stream; the final "
            "reordered pictures may not flush cleanly")

    # --- audio ------------------------------------------------------------
    if is_ps:
        audio = probe_audio(path)
        report["audio"] = audio
        if audio is None:
            notes.append("no audio stream; video will play silently")
        elif "error" in audio:
            notes.append(audio["error"])
        else:
            if audio["codec_name"] != "mp2":
                problems.append(
                    f"audio codec {audio['codec_name']} is not MPEG Layer II; "
                    "re-encode with -c:a mp2")
            if audio["sample_rate"] not in AUDIO_RATES:
                problems.append(
                    f"audio sample rate {audio['sample_rate']} Hz unsupported; "
                    "use -ar 48000 or -ar 44100")
            if audio["channels"] not in (1, 2):
                problems.append(
                    f"audio has {audio['channels']} channels; use -ac 2")
    elif audio_es:
        notes.append("audio bytes present but container is not a Program Stream")

    report["problems"] = problems
    report["notes"] = notes
    report["verdict"] = "FAIL" if problems else "PASS"
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--json", action="store_true", help="emit the full report as JSON")
    args = parser.parse_args()

    reports = [check(p) for p in args.files]
    if args.json:
        print(json.dumps(reports, indent=2, sort_keys=True))
    else:
        for report in reports:
            video = report.get("video", {})
            print(f"{report['path']}: {report['verdict']}")
            print(f"  container {report['container']}, {report['bytes']} bytes")
            if video:
                print(f"  video {video['width']}x{video['height']} "
                      f"frame_rate_code={video['frame_rate_code']} "
                      f"pictures={video['pictures']} {video['picture_type_counts']}")
            audio = report.get("audio")
            if isinstance(audio, dict) and "codec_name" in audio:
                print(f"  audio {audio['codec_name']} {audio['sample_rate']} Hz "
                      f"{audio['channels']} ch")
            for problem in report["problems"]:
                print(f"  PROBLEM: {problem}")
            for note in report.get("notes", []):
                print(f"  note: {note}")
    return 1 if any(r["verdict"] == "FAIL" for r in reports) else 0


if __name__ == "__main__":
    sys.exit(main())
