#!/usr/bin/env python3
"""Check identifiable fields at the actual scaler output, not bank counters.

This is a synthetic-content HDMI test, not an MPEG reconstruction oracle.
Allow four source pictures of pipeline latency. A 22-picture stale hold must
fail even when every upstream picture counter advances. Initial mode lock and
eight output frames after each detected input-format change are excluded and
reported; they are not claimed to be clean. A hold is intentional only when
the independently generated source-picture identity itself stops advancing.
"""
import argparse
import itertools
import json
from pathlib import Path


def check(path: Path, mode: str) -> dict:
    rows = []
    for line in path.read_text().splitlines():
        fields = dict(word.split('=', 1) for word in line.split())
        rows.append({k: int(v, 16 if k == 'hash' else 10)
                     for k, v in fields.items()})
    errors = []
    checked = []
    excluded = []
    last_format = None
    settle_until = 12
    max_age = [0.0, 0.0]
    for row in rows:
        fmt = (row['input_width'], row['input_lines'], row['inter'])
        if fmt != last_format:
            if last_format is not None:
                settle_until = max(settle_until, row['frame'] + 8)
            last_format = fmt
        if row['frame'] < settle_until or row['finished']:
            excluded.append(row['frame'])
            continue
        checked.append(row)
        n = row['pixels']
        if n not in (720 * 480, 1280 * 720, 1920 * 1080):
            errors.append({'frame': row['frame'], 'kind': 'pixel_count', 'value': n})
        if row['bad'] or row['bad_blue']:
            errors.append({'frame': row['frame'], 'kind': 'invalid_color',
                           'green': row['bad'], 'blue': row['bad_blue']})
        if row['field0_pixels'] + row['field1_pixels'] != n:
            errors.append({'frame': row['frame'], 'kind': 'missing_content'})
        if mode not in ('bob', 'hold-bob', 'progressive', 'identical'):
            if row['field0_pixels'] != n // 2 or row['field1_pixels'] != n // 2:
                errors.append({'frame': row['frame'], 'kind': 'parity_population'})
        for parity in (0, 1):
            count = row[f'field{parity}_pixels']
            if not count:
                continue
            value = row[f'field{parity}_min']
            age = (row['source_r'] - value) / 2
            max_age[parity] = max(max_age[parity], age)
            if age > 4:
                errors.append({'frame': row['frame'], 'kind': 'stale_field',
                               'parity': parity, 'age_pictures': age})
            if value < 32 or value % 2 or age < 0:
                errors.append({'frame': row['frame'], 'kind': 'invalid_identity',
                               'parity': parity, 'value': value})
            if row[f'field{parity}_max'] > row['source_r']:
                errors.append({'frame': row['frame'], 'kind': 'future_identity',
                               'parity': parity})
    if len(checked) < 8:
        errors.append({'kind': 'insufficient_steady_frames', 'count': len(checked)})
    if len({r['source_r'] for r in checked}) < 3:
        errors.append({'kind': 'source_did_not_exercise_progression'})

    holds = []
    for identity, group in itertools.groupby(checked, key=lambda r: r['source_r']):
        group = list(group)
        if len(group) < 12:
            continue
        settled = group[8:]
        hashes = [r['hash'] for r in settled]
        record = {'source_r': identity, 'first_frame': group[0]['frame'],
                  'frames': len(group), 'settled_frames': len(settled),
                  'distinct_spatial_hashes': len(set(hashes)),
                  'lag1_equal': sum(a == b for a, b in zip(hashes, hashes[1:])),
                  'lag2_equal': sum(a == b for a, b in zip(hashes, hashes[2:]))}
        holds.append(record)
        if mode == 'hold' and len(set(hashes)) != 1:
            errors.append({'kind': 'weave_held_image_changes', **record})
    if mode in ('hold', 'hold-bob') and not holds:
        errors.append({'kind': 'held_interval_not_observed'})
    return {'mode': mode, 'frames': len(rows), 'checked_frames': len(checked),
            'excluded_frames': excluded, 'max_age_pictures': max_age,
            'holds': holds, 'errors': errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--mode', required=True,
                        choices=['weave', 'bob', 'progressive', 'identical',
                                 'bff', 'hold', 'hold-bob', 'stale', 'restart'])
    parser.add_argument('--expect-stale', action='store_true',
                        help='Negative control: require stale-field detection, with no unrelated error.')
    args = parser.parse_args()
    result = check(args.report, args.mode)
    kinds = {error['kind'] for error in result['errors']}
    if args.expect_stale:
        passed = kinds == {'stale_field'}
        result['expected_stale_detected'] = passed
    else:
        passed = not kinds
    result['passed'] = passed
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
