#!/usr/bin/env python3
"""Add the terminal video PES and Program Stream end required by the core."""
from __future__ import annotations

import argparse
from pathlib import Path

from check_media_compatibility import (
    PROGRAM_END_CODE,
    SEQUENCE_END_CODE,
    demux_program_stream,
)

FINAL_VIDEO_PES = (
    b"\x00\x00\x01\xe0\x00\x07\x80\x00\x00" + SEQUENCE_END_CODE
)


def finalize_program_stream(path: Path) -> tuple[bool, bool]:
    """Finalize *path* in place and return (added_sequence_end, added_program_end)."""
    data = path.read_bytes()
    if data[:4] != b"\x00\x00\x01\xba":
        raise ValueError(f"not an MPEG Program Stream: {path}")

    video, _audio, metadata = demux_program_stream(data)
    end_offset = metadata["program_end_offset"]
    added_sequence_end = SEQUENCE_END_CODE not in video[-64:]
    added_program_end = end_offset is None

    if end_offset is None:
        prefix = data
        terminator = PROGRAM_END_CODE
    else:
        prefix = data[:end_offset]
        terminator = data[end_offset:]

    if added_sequence_end:
        prefix += FINAL_VIDEO_PES
    finalized = prefix + terminator
    path.write_bytes(finalized)

    final_video, _final_audio, final_metadata = demux_program_stream(finalized)
    if SEQUENCE_END_CODE not in final_video[-64:]:
        raise RuntimeError(f"failed to add terminal sequence end: {path}")
    if not final_metadata["program_end_seen"]:
        raise RuntimeError(f"failed to add Program Stream end: {path}")
    return added_sequence_end, added_program_end


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()
    for path in args.files:
        added_sequence, added_program = finalize_program_stream(path)
        print(
            f"finalized: {path} "
            f"sequence_end={'added' if added_sequence else 'present'} "
            f"program_end={'added' if added_program else 'present'}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
