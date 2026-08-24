#!/usr/bin/env python3
"""Copy the opening of a Program Stream, byte for byte, as its own stream.

Entry 453 isolated the soak's cadence and underrun defects by replaying the
failed movie's exact opening video as a raw elementary stream.  The paired
audio-video diagnostic has to be exact in the same sense: the same H.262 bytes,
the same MPEG Layer II bytes and the same mux placement as the full movie, cut
at a picture boundary and terminated cleanly, so that a difference in hardware
behaviour can only come from the transport that carries them.

Packs and PES packets are copied verbatim.  Only the packet holding the first
picture beyond the cut is rewritten, keeping its header and timestamps and
shortening its declared length to the payload actually retained, because a PES
whose length outruns its bytes is the truncated-stream failure case rather than
a short movie.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from check_media_compatibility import (
    PACED_FRAME_RATE_CODES,
    PROGRAM_END_CODE,
    SEQUENCE_END_CODE,
    demux_program_stream,
    strip_pes_header,
)

PICTURE_START_CODE = b"\x00\x00\x01\x00"
SEQUENCE_HEADER_CODE = b"\x00\x00\x01\xb3"
FINAL_VIDEO_PES = b"\x00\x00\x01\xe0\x00\x07\x80\x00\x00" + SEQUENCE_END_CODE
MP2_SAMPLES_PER_FRAME = 1152
MP2_BITRATES = (
    0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0,
)
MP2_RATES = (44100, 48000, 32000, 0)


def frame_rate(video: bytes) -> float:
    """Frame rate of the first sequence header, as the checker names it."""
    index = video.find(SEQUENCE_HEADER_CODE)
    if index < 0 or index + 8 > len(video):
        raise SystemExit("extracted video carries no sequence header")
    code = video[index + 7] & 0x0F
    if code not in PACED_FRAME_RATE_CODES:
        raise SystemExit(f"unsupported frame_rate_code {code}")
    text = PACED_FRAME_RATE_CODES[code]
    if "/" in text:
        numerator, denominator = text.split("/")
        return int(numerator) / int(denominator)
    return float(text)


def audio_samples(audio: bytes) -> int:
    """Samples the MPEG Layer II payload decodes to, counted by frame header."""
    samples = 0
    offset = 0
    while offset + 4 <= len(audio):
        header = audio[offset:offset + 4]
        if header[0] != 0xFF or (header[1] & 0xE0) != 0xE0:
            offset += 1
            continue
        bitrate = MP2_BITRATES[(header[2] >> 4) & 0x0F]
        rate = MP2_RATES[(header[2] >> 2) & 0x03]
        if not bitrate or not rate:
            offset += 1
            continue
        length = 144 * bitrate * 1000 // rate + ((header[2] >> 1) & 1)
        samples += MP2_SAMPLES_PER_FRAME
        offset += length
    return samples


def pack_length(data: bytes, offset: int) -> int:
    """Length of the pack header starting at *offset*, MPEG-1 or MPEG-2 form."""
    cursor = offset + 4
    if cursor < len(data) and (data[cursor] & 0xC0) == 0x40:
        cursor += 10
        if cursor <= len(data):
            cursor += data[cursor - 1] & 0x07
    else:
        cursor += 8
    return cursor - offset


def find_cut(data: bytes, pictures: int) -> tuple[int, int, int, int]:
    """Locate the picture that ends the opening.

    Returns the offset of the PES packet carrying the first picture past the
    cut, that packet's payload offset, the offset inside the file where the
    picture start code begins, and the number of complete pictures kept.
    """
    video_id: int | None = None
    window = 0
    seen = 0
    offset = 0
    while offset + 4 <= len(data):
        if data[offset:offset + 3] != b"\x00\x00\x01":
            offset += 1
            continue
        stream_id = data[offset + 3]
        if stream_id == 0xBA:
            offset += pack_length(data, offset)
            continue
        if stream_id == 0xB9:
            break
        if offset + 6 > len(data):
            break
        length = (data[offset + 4] << 8) | data[offset + 5]
        payload_start = offset + 6
        payload_end = payload_start + length
        if 0xE0 <= stream_id <= 0xEF:
            if video_id is None:
                video_id = stream_id
            if stream_id == video_id:
                for index in range(payload_start, min(payload_end, len(data))):
                    window = ((window << 8) | data[index]) & 0xFFFFFFFF
                    if window == 0x00000100:
                        seen += 1
                        if seen > pictures:
                            return offset, payload_start, index - 3, seen - 1
        offset = payload_end
    raise SystemExit(
        f"stream carries only {seen} pictures, fewer than the {pictures} requested"
    )


def extract_opening(source: Path, target: Path, pictures: int) -> dict[str, object]:
    data = source.read_bytes()
    if data[:4] != b"\x00\x00\x01\xba":
        raise SystemExit(f"not an MPEG Program Stream: {source}")

    packet, payload_start, picture_offset, kept = find_cut(data, pictures)
    _, _, source_metadata = demux_program_stream(data)
    audio_id = source_metadata["audio_stream_id"]
    header_bytes = data[packet:packet + 6]
    stream_id = header_bytes[3]
    retained = data[payload_start:picture_offset]
    if len(retained) > 0xFFFF:
        raise SystemExit("retained PES payload does not fit one packet")

    opening = bytearray(data[:packet])
    if retained:
        opening += bytes([0, 0, 1, stream_id, len(retained) >> 8, len(retained) & 0xFF])
        opening += retained
    opening += FINAL_VIDEO_PES

    # The mux carries audio for a moment that has not been reached at the cut,
    # so a cut taken on the video alone ends with less audio than picture.  The
    # sink would drain that shortfall as an underrun the source never had, so
    # keep copying the audio packets that follow until the audio covers the
    # video the diagnostic actually contains.
    video_only, audio_only, _ = demux_program_stream(bytes(opening))
    required = round(kept * 48000 / frame_rate(video_only))
    carried = audio_samples(audio_only)
    tail = bytearray()
    appended = 0
    offset = packet
    while carried < required and offset + 6 <= len(data):
        if data[offset:offset + 3] != b"\x00\x00\x01":
            offset += 1
            continue
        following = data[offset + 3]
        if following == 0xBA:
            offset += pack_length(data, offset)
            continue
        if following == 0xB9:
            break
        length = (data[offset + 4] << 8) | data[offset + 5]
        end = offset + 6 + length
        if following == audio_id:
            opening += data[offset:end]
            tail += strip_pes_header(data[offset + 6:end])
            carried = audio_samples(audio_only + bytes(tail))
            appended += 1
        offset = end
    opening += PROGRAM_END_CODE
    target.write_bytes(bytes(opening))

    video, audio, metadata = demux_program_stream(bytes(opening))
    full_video, _full_audio, _ = demux_program_stream(data)
    if not full_video.startswith(video[:-len(SEQUENCE_END_CODE)]):
        raise SystemExit("extracted video is not a prefix of the source video")
    if SEQUENCE_END_CODE not in video[-64:]:
        raise SystemExit("extracted stream has no terminal sequence end")
    if not metadata["program_end_seen"]:
        raise SystemExit("extracted stream has no Program Stream end")
    return {
        "bytes": len(opening),
        "appended_audio_packets": appended,
        "audio_samples": audio_samples(audio),
        "required_samples": required,
        "sha256": hashlib.sha256(bytes(opening)).hexdigest(),
        "pictures": kept,
        "video_bytes": len(video),
        "audio_bytes": len(audio),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument(
        "--pictures",
        type=int,
        default=577,
        help="complete pictures to keep (default 577, the entry 452 opening)",
    )
    args = parser.parse_args()
    result = extract_opening(args.source, args.target, args.pictures)
    print(
        f"opening: {result['pictures']} pictures, {result['bytes']} bytes, "
        f"SHA-256 {result['sha256']}"
    )
    print(
        f"demuxed: {result['video_bytes']} video bytes, "
        f"{result['audio_bytes']} audio bytes"
    )
    print(
        f"audio: {result['audio_samples']} samples against "
        f"{result['required_samples']} of picture, "
        f"{result['appended_audio_packets']} packets appended past the cut"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
