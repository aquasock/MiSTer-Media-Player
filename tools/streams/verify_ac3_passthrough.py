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
from verify_arm_av_pipeline import strip_records

PA = 0xF872
PB = 0x4E1F
HEADER_WORDS = 4

# data type -> (burst period in samples, elementary sync word)
BURSTS = {
    1:  (1536, b'\x0b\x77'),   # AC-3
    11: (512,  b'\x7f\xfe\x80\x01'),   # DTS type I
    12: (1024, b'\x7f\xfe\x80\x01'),   # DTS type II
    13: (2048, b'\x7f\xfe\x80\x01'),   # DTS type III
}


def parse_bursts(raw: bytes, expect_type: int) -> tuple[list[dict], bytes, list[str]]:
    """Walk the stream one burst period at a time.

    The period is not fixed: AC-3 always uses 1536 samples, but DTS chooses
    512, 1024 or 2048 and announces which through its data type, so the period
    is taken from the data type of each burst rather than assumed.
    """
    problems: list[str] = []
    frames = bytearray()
    bursts: list[dict] = []
    index = 0
    offset = 0
    while offset + HEADER_WORDS * 2 <= len(raw):
        pa, pb, pc, pd = struct.unpack('<4H', raw[offset:offset + 8])
        if pa != PA or pb != PB:
            problems.append(f'burst {index}: sync words {pa:#06x} {pb:#06x}')
            break
        data_type = pc & 0x1F
        if data_type not in BURSTS:
            problems.append(f'burst {index}: unknown data type {data_type}')
            break
        if data_type != expect_type:
            problems.append(f'burst {index}: data type {data_type}, expected {expect_type}')
        samples, sync = BURSTS[data_type]
        period_bytes = samples * 2 * 2
        if offset + period_bytes > len(raw):
            problems.append(f'burst {index}: truncated period')
            break
        block = raw[offset:offset + period_bytes]
        offset += period_bytes
        if pd % 8:
            problems.append(f'burst {index}: length {pd} bits is not whole bytes')
        length = pd // 8
        if length <= 0 or HEADER_WORDS * 2 + length > period_bytes:
            problems.append(f'burst {index}: payload length {length} does not fit')
            index += 1
            continue
        payload = block[HEADER_WORDS * 2:HEADER_WORDS * 2 + length]
        # Payload words are big-endian on the wire; undo the 16-bit swap.
        swapped = bytearray(len(payload))
        swapped[0::2] = payload[1::2]
        swapped[1::2] = payload[0::2]
        if len(payload) & 1:
            swapped[-1] = payload[-1]
        if swapped[:len(sync)] != sync:
            problems.append(f'burst {index}: payload does not start with the '
                            f'expected sync word')
        stuffing = block[HEADER_WORDS * 2 + length:]
        if any(stuffing):
            problems.append(f'burst {index}: stuffing is not zero')
        frames += swapped
        bursts.append({'index': index, 'data_type': data_type,
                       'length_bytes': length, 'period_samples': samples})
        index += 1
    return bursts, bytes(frames), problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--helper', required=True, type=Path)
    parser.add_argument('--fixture', required=True, type=Path)
    parser.add_argument('--substream', type=lambda v: int(v, 0), default=0x80)
    parser.add_argument('--codec', choices=('ac3', 'dts'), default='ac3')
    parser.add_argument('--data-type', type=int, default=None,
                        help='expected IEC 61937 data type; defaults by codec')
    parser.add_argument('--report', type=Path, default=None)
    parser.add_argument('--allow-truncated-tail', action='store_true',
                        help='accept a source that ends mid-frame, as a VOB '
                             'fragment from a multi-file title legitimately does')
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix='ac3_passthrough_') as directory:
        temp = Path(directory)
        burst_pcm = temp / 'burst.s16le'
        result = subprocess.run(
            [str(args.helper), '--protocol', '1', '--audio-out', 'spdif',
             '--source', f'file:{args.fixture.resolve()}',
             '--pcm-out', str(burst_pcm), '--video-out', str(temp / 'v.m2v')],
            capture_output=True, text=True)
        tail_only = (args.allow_truncated_tail and
                     'truncated or undecodable' in result.stderr and
                     burst_pcm.exists() and burst_pcm.stat().st_size > 0)
        if result.returncode and not tail_only:
            print(result.stderr[-4000:])
            raise SystemExit('helper failed in passthrough mode')
        raw = burst_pcm.read_bytes()

        # The installed path uses the annotated stdout transport, not
        # --pcm-out. Verify that every burst record carries the independent
        # non-audio flag and that stripping those records reproduces the
        # already byte-checked explicit burst stream.
        transported = subprocess.run(
            [str(args.helper), '--protocol', '1', '--audio-out', 'spdif',
             '--source', f'file:{args.fixture.resolve()}'],
            capture_output=True)
        transport_stderr = transported.stderr.decode(errors='replace')
        transport_tail_only = (args.allow_truncated_tail and
                               'truncated or undecodable' in transport_stderr and
                               bool(transported.stdout))
        if transported.returncode and not transport_tail_only:
            print(transport_stderr[-4000:])
            raise SystemExit('helper failed in annotated passthrough mode')
        _, _, inband_pcm, inband_end = strip_records(
            transported.stdout, 48000, expected_non_audio=True)
        inband_matches_explicit = inband_pcm == raw

        expect = args.data_type
        if expect is None:
            expect = 11 if args.codec == 'dts' else 1
        bursts, carried, problems = parse_bursts(raw, expect)
        source_frames = extract_ac3(args.fixture.read_bytes(), args.substream)
        if args.allow_truncated_tail and len(source_frames) > len(carried):
            # The source's final partial frame is never emitted, by design.
            trailing = len(source_frames) - len(carried)
            source_frames = source_frames[:len(carried)]
        else:
            trailing = 0
        identical = carried == source_frames
        if not identical:
            problems.append('carried frames differ from the source AC-3')

        # An independent decode of the carried frames must match a decode of
        # the source frames: same decoder, so this is exact when bytes match.
        decoded = {}
        for name, payload in (('carried', carried), ('source', source_frames)):
            es = temp / f'{name}.{args.codec}'
            es.write_bytes(payload)
            out = temp / f'{name}.s16le'
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror',
                            '-f', args.codec, '-i', str(es), '-ac', '2', '-ar', '48000',
                            '-f', 's16le', str(out)], check=True)
            decoded[name] = hashlib.sha256(out.read_bytes()).hexdigest()

        report = {
            'fixture': str(args.fixture), 'helper': str(args.helper),
            'codec': args.codec, 'expected_data_type': expect,
            'stream_bytes': len(raw), 'bursts_parsed': len(bursts),
            'inband_non_audio_marked': bool(inband_pcm),
            'inband_end_records': inband_end,
            'inband_matches_explicit': inband_matches_explicit,
            'period_samples_seen': sorted({b['period_samples'] for b in bursts}),
            'frame_lengths_seen': sorted({b['length_bytes'] for b in bursts}),
            'carried_bytes': len(carried), 'source_bytes': len(source_frames),
            'source_trailing_bytes_ignored': trailing,
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
                            and report['decodes_match'] and bursts != []
                            and report['inband_non_audio_marked']
                            and inband_end == 1 and inband_matches_explicit)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
