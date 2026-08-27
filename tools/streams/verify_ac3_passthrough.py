#!/usr/bin/env python3
"""Verify the helper's IEC 61937 AC-3 passthrough output.

Example:
  python3 tools/streams/verify_ac3_passthrough.py \
    --helper host/build/media_player_helper.native \
    --fixture /path/to/ac3_480i_tff_5p1.mpg

The emitted stream must parse as one burst per 1536-sample period with the
correct sync words, data type and length, the frames carried inside must be
byte identical to the AC-3 in the source, and an independent decoder must
reproduce the same audio from them. Passing this proves the bytes are right;
it does not prove any receiver locks onto them, which needs hardware.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import subprocess
import tempfile
from pathlib import Path

from generate_test_dvd_ac3_av import extract_ac3

PA = 0xF872
PB = 0x4E1F
DATA_TYPE_AC3 = 1
SAMPLES_PER_PERIOD = 1536
PERIOD_BYTES = SAMPLES_PER_PERIOD * 2 * 2
HEADER_WORDS = 4


def parse_bursts(raw: bytes) -> tuple[list[dict], bytes, list[str]]:
    problems: list[str] = []
    frames = bytearray()
    bursts: list[dict] = []
    if len(raw) % PERIOD_BYTES:
        problems.append(f'stream is {len(raw)} bytes, not a whole number of '
                        f'{PERIOD_BYTES}-byte burst periods')
    for index in range(len(raw) // PERIOD_BYTES):
        block = raw[index * PERIOD_BYTES:(index + 1) * PERIOD_BYTES]
        pa, pb, pc, pd = struct.unpack('<4H', block[:8])
        if pa != PA or pb != PB:
            problems.append(f'burst {index}: sync words {pa:#06x} {pb:#06x}')
            continue
        data_type = pc & 0x1F
        if data_type != DATA_TYPE_AC3:
            problems.append(f'burst {index}: data type {data_type}, expected {DATA_TYPE_AC3}')
        if pd % 8:
            problems.append(f'burst {index}: length {pd} bits is not whole bytes')
        length = pd // 8
        if length <= 0 or HEADER_WORDS * 2 + length > PERIOD_BYTES:
            problems.append(f'burst {index}: payload length {length} does not fit')
            continue
        payload = block[HEADER_WORDS * 2:HEADER_WORDS * 2 + length]
        # Payload words are big-endian on the wire; undo the 16-bit swap.
        swapped = bytearray(len(payload))
        swapped[0::2] = payload[1::2]
        swapped[1::2] = payload[0::2]
        if len(payload) & 1:
            swapped[-1] = payload[-1]
        if swapped[:2] != b'\x0b\x77':
            problems.append(f'burst {index}: payload is not an AC-3 sync frame')
        stuffing = block[HEADER_WORDS * 2 + length:]
        if any(stuffing):
            problems.append(f'burst {index}: stuffing is not zero')
        frames += swapped
        bursts.append({'index': index, 'data_type': data_type,
                       'length_bytes': length})
    return bursts, bytes(frames), problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--helper', required=True, type=Path)
    parser.add_argument('--fixture', required=True, type=Path)
    parser.add_argument('--substream', type=lambda v: int(v, 0), default=0x80)
    parser.add_argument('--report', type=Path, default=None)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix='ac3_passthrough_') as directory:
        temp = Path(directory)
        burst_pcm = temp / 'burst.s16le'
        result = subprocess.run(
            [str(args.helper), '--protocol', '1', '--audio-out', 'spdif',
             '--source', f'file:{args.fixture.resolve()}',
             '--pcm-out', str(burst_pcm), '--video-out', str(temp / 'v.m2v')],
            capture_output=True, text=True)
        if result.returncode:
            print(result.stderr[-4000:])
            raise SystemExit('helper failed in passthrough mode')
        raw = burst_pcm.read_bytes()
        bursts, carried, problems = parse_bursts(raw)
        source_frames = extract_ac3(args.fixture.read_bytes(), args.substream)
        identical = carried == source_frames
        if not identical:
            problems.append('carried frames differ from the source AC-3')

        # An independent decode of the carried frames must match a decode of
        # the source frames: same decoder, so this is exact when bytes match.
        decoded = {}
        for name, payload in (('carried', carried), ('source', source_frames)):
            es = temp / f'{name}.ac3'
            es.write_bytes(payload)
            out = temp / f'{name}.s16le'
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror',
                            '-f', 'ac3', '-i', str(es), '-ac', '2', '-ar', '48000',
                            '-f', 's16le', str(out)], check=True)
            decoded[name] = hashlib.sha256(out.read_bytes()).hexdigest()

        report = {
            'fixture': str(args.fixture), 'helper': str(args.helper),
            'stream_bytes': len(raw), 'burst_periods': len(raw) // PERIOD_BYTES,
            'bursts_parsed': len(bursts),
            'burst_period_bytes': PERIOD_BYTES,
            'samples_per_period': SAMPLES_PER_PERIOD,
            'frame_lengths_seen': sorted({b['length_bytes'] for b in bursts}),
            'carried_bytes': len(carried), 'source_bytes': len(source_frames),
            'frames_byte_identical': identical,
            'carried_decode_sha256': decoded['carried'],
            'source_decode_sha256': decoded['source'],
            'decodes_match': decoded['carried'] == decoded['source'],
            'problems': problems[:20], 'problem_count': len(problems),
            'scope': 'Byte correctness of the emitted bursts only. It does not '
                     'prove any receiver locks onto them, nor that the path to '
                     'the S/PDIF pin is bit transparent, both of which need '
                     'hardware.'}
        report['passed'] = (not problems and identical
                            and report['decodes_match'] and bursts != [])
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
