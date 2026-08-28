#!/usr/bin/env python3
"""Summarize a diagnostic native-field trace without accepting playback."""
import argparse
from collections import Counter
import csv
import json
from pathlib import Path


def analyze(fixture, rows):
    events = {}
    for row in rows:
        events.setdefault(row['event'], []).append(row)
    pictures = {p['coded']: p for p in fixture['pictures']}
    published = events.get('PUBLISH', [])
    ready = {r['id']: r for r in events.get('READY', [])}
    counts = Counter(r['id'] for r in published)
    gaps = []
    for previous, current in zip(published, published[1:]):
        picture = pictures[previous['id']]
        expected = 2 + int(picture['repeat_first_field'])
        field_delta = current['field'] - previous['field']
        windows = [r for r in events.get('FIELD', []) if previous['cycle'] < r['cycle'] < current['cycle']]
        gaps.append({
            'previous_coded': previous['id'], 'coded': current['id'],
            'previous_display': picture['display'], 'display': pictures[current['id']]['display'],
            'milliseconds': (current['cycle'] - previous['cycle']) / 60000,
            'field_delta': field_delta, 'previous_authored_fields': expected,
            'extra_fields': field_delta - expected,
            'ready_cycle': ready.get(current['id'], {}).get('cycle'),
            'publication_cycle': current['cycle'],
            'field_windows': windows,
        })
    report = {
        'scope': 'Integrated decoder, writer, memory arbiter, native timing, timestamp owner/timeline and framebuffer; unlimited clean-byte supply. No host/PCM/scaler model. DDR parameters are sensitivity cases, not measured device timing.',
        'expected_pictures': len(pictures),
        'starts': len(events.get('START', [])), 'ready': len(events.get('READY', [])),
        'publications': len(published), 'unique_publications': len(counts),
        'missing_coded_pictures': sorted(set(pictures) - set(counts)),
        'duplicate_publications': {str(k): v for k, v in counts.items() if v > 1},
        'display_order': [pictures[r['id']]['display'] for r in published],
        'largest_publication_gaps': sorted(gaps, key=lambda g: g['milliseconds'], reverse=True)[:12],
        'gaps_with_extra_fields': [g for g in gaps if g['extra_fields'] > 0],
        'end_record': events.get('END', []),
        'cache_flags_seen': {k: sum(r[k] != 0 for r in rows) for k in ('prefill_miss', 'phase_error', 'overlap_error')},
        'timing_accepted': False,
    }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', type=Path)
    parser.add_argument('trace', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    fixture = json.loads(args.fixture.read_text())
    with args.trace.open() as handle:
        rows = [{k: v if k == 'event' else int(v) for k, v in r.items()} for r in csv.DictReader(handle)]
    report = analyze(fixture, rows)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('expected_pictures', 'starts', 'ready', 'publications', 'unique_publications', 'missing_coded_pictures', 'duplicate_publications', 'cache_flags_seen')}))


if __name__ == '__main__':
    main()
