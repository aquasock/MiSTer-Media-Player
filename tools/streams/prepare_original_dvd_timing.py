#!/usr/bin/env python3
"""Extract sparse native-helper PTS positions without changing movie bytes.

Run on the build PC. The native helper is explicit input so the exact demux
implementation and its output can be fingerprinted. PCM is sent to a separate
file and must not be present in the transport used by this video-only test.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from analyze_h262_compatibility import (
    start_codes, payload_between, parse_picture_header,
    parse_picture_coding_extension, read_bits,
)


def extract(data: bytes) -> tuple[bytes, list[dict[str, int]]]:
    clean = bytearray()
    records = []
    position = 0
    while position < len(data):
        offset = data.find(b'\x00\x00\x01', position)
        if offset < 0:
            clean.extend(data[position:])
            break
        clean.extend(data[position:offset])
        code = data[offset + 3]
        if code == 0xB0:
            if offset + 9 > len(data):
                raise ValueError('truncated metadata')
            payload = int.from_bytes(data[offset + 4:offset + 9], 'big')
            records.append({'offset': len(clean), 'pts': payload >> 7})
            position = offset + 9
        elif code in (0xB1, 0xB6):
            raise ValueError('PCM must be separated by --pcm-out')
        else:
            clean.extend(data[offset:offset + 4])
            position = offset + 4
    return bytes(clean), records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixtures', type=Path)
    parser.add_argument('helper', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source = args.fixtures / 'dvd_opening_original.mpg'
    result = subprocess.run([
        str(args.helper.resolve()), '--protocol', '1', '--source', 'file:' + str(source.resolve()),
        '--pcm-out', str((args.output / 'separated.pcm').resolve()),
    ], check=True, capture_output=True)
    (args.output / 'helper.log').write_bytes(result.stderr)
    clean, records = extract(result.stdout)
    original = (args.fixtures / 'dvd_opening_original.m2v').read_bytes()
    # A stream-copy extractor may append one terminal sequence-end marker.
    # Preserve the fixture byte-for-byte and report that suffix explicitly.
    if clean != original and clean + b'\x00\x00\x01\xb7' != original:
        raise ValueError(f'helper video differs from fixture: {len(clean)} versus {len(original)} bytes')
    if not records or len(records) > 1024:
        raise ValueError('unsupported diagnostic PTS record count')
    mapping = [int(s, 16) for s in (args.fixtures / 'dvd_opening_map.hex').read_text().split()]
    pictures = []
    codes = start_codes(original)
    for index, (offset, code) in enumerate(codes):
        payload = payload_between(original, codes, index)
        if code == 0:
            pictures.append({'coded': len(pictures), 'display': mapping[len(pictures)],
                             'offset': offset, **parse_picture_header(payload)})
        elif code == 0xB5 and read_bits(payload, 0, 4) == 8:
            pictures[-1].update(parse_picture_coding_extension(payload))
    if len(pictures) != len(mapping):
        raise ValueError('picture mapping mismatch')
    for record in records:
        # The owner consumes a pending record at the next classified header.
        following = next((p for p in pictures if p['offset'] + 5 >= record['offset']), None)
        record['next_coded_picture'] = following['coded'] if following else -1
    (args.output / 'pts.hex').write_text(''.join(f"{(r['offset'] << 33) | r['pts']:017x}\n" for r in records))
    sha = lambda value: hashlib.sha256(value).hexdigest()
    manifest = {
        'source_sha256': sha(source.read_bytes()), 'helper_sha256': sha(args.helper.read_bytes()),
        'transport_sha256': sha(result.stdout), 'transport_bytes': len(result.stdout),
        'clean_video_sha256': sha(clean), 'clean_video_bytes': len(clean),
        'fixture_sha256': sha(original), 'fixture_bytes': len(original),
        'fixture_terminal_suffix_bytes': len(original) - len(clean),
        'pts_records': records, 'pictures': pictures,
        'scope': 'Exact helper PTS byte boundaries; unlimited clean-byte supply. No host scheduling, in-band extractor, PCM or scaler model.',
    }
    (args.output / 'timing_fixture.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: v for k, v in manifest.items() if k not in ('pictures', 'pts_records')}))
    print(f'PTS records={len(records)} pictures={len(pictures)}')


if __name__ == '__main__':
    main()
