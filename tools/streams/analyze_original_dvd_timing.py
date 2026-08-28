#!/usr/bin/env python3
"""Check native-field simulation timing; never claim hardware acceptance."""
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
    starts = {r['id']: r for r in events.get('START', [])}
    counts = Counter(r['id'] for r in published)
    cumulative_fields = {}
    total_fields = 0
    for picture in sorted(pictures.values(), key=lambda p: p['display']):
        cumulative_fields[picture['coded']] = total_fields
        total_fields += 2 + int(picture['repeat_first_field'])
    pts_origin = fixture['pts_records'][0]['pts']
    pts_alignment = []
    for record in fixture['pts_records']:
        coded = record['next_coded_picture']
        if coded in pictures:
            pts_alignment.append({
                'coded': coded, 'pts': record['pts'],
                'difference_from_authored_ticks': record['pts'] - pts_origin - cumulative_fields[coded] * 1501.5,
            })
    authored_pts = {r['next_coded_picture']: r['pts'] for r in fixture['pts_records']
                    if r['next_coded_picture'] in pictures}
    descriptor_mismatches = []
    pts_mismatches = []
    for row in published:
        picture = pictures[row['id']]
        if row['tff'] != int(picture['top_field_first']) or row['rff'] != int(picture['repeat_first_field']):
            descriptor_mismatches.append({'coded': row['id'], 'cycle': row['cycle'],
                'expected_tff': int(picture['top_field_first']), 'expected_rff': int(picture['repeat_first_field']),
                'actual_tff': row['tff'], 'actual_rff': row['rff']})
        expected_pts = authored_pts.get(row['id'])
        if bool(row['display_pts_valid']) != (expected_pts is not None) or (
                expected_pts is not None and row['display_pts'] != expected_pts):
            pts_mismatches.append({'coded': row['id'], 'cycle': row['cycle'],
                'expected_pts': expected_pts, 'actual_pts': row['display_pts'],
                'actual_valid': bool(row['display_pts_valid'])})
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
            'start_to_ready_ms': (ready[current['id']]['cycle'] - starts[current['id']]['cycle']) / 60000
                if current['id'] in ready and current['id'] in starts else None,
            'field_windows': windows,
        })
    report = {
        'scope': 'Integrated decoder, writer, memory arbiter, native timing, timestamp owner/timeline and framebuffer; unlimited clean-byte supply. No host/PCM/scaler model. DDR parameters are sensitivity cases, not measured device timing.',
        'expected_pictures': len(pictures),
        'complete_decode_trace': bool(events.get('END')) and set(starts) == set(pictures) and set(ready) == set(pictures),
        'authored_total_fields': total_fields,
        'authored_duration_seconds': total_fields * 1001 / 60000,
        'pts_alignment': pts_alignment,
        'publication_descriptor_mismatches': descriptor_mismatches,
        'publication_pts_mismatches': pts_mismatches,
        'starts': len(events.get('START', [])), 'ready': len(events.get('READY', [])),
        'publications': len(published), 'unique_publications': len(counts),
        'missing_coded_pictures': sorted(set(pictures) - set(counts)),
        'duplicate_publications': {str(k): v for k, v in counts.items() if v > 1},
        'missing_picture_details': [pictures[i] for i in sorted(set(pictures) - set(counts))],
        'display_order': [pictures[r['id']]['display'] for r in published],
        'largest_publication_gaps': sorted(gaps, key=lambda g: g['milliseconds'], reverse=True)[:12],
        'gaps_with_extra_fields': [g for g in gaps if g['extra_fields'] > 0],
        'cadence_mismatches': [g for g in gaps if g['extra_fields'] != 0],
        'end_record': events.get('END', []),
        'cache_flags_seen': {k: sum(r[k] != 0 for r in rows) for k in ('prefill_miss', 'phase_error', 'overlap_error')},
        'timing_accepted': False,
    }
    expected_order = sorted(p['display'] for p in pictures.values())
    complete_trace = (report['complete_decode_trace'] and
                      report['starts'] == len(pictures) and report['ready'] == len(pictures) and
                      len(events.get('END', [])) == 1 and rows[-1]['event'] == 'END' and
                      all(a['cycle'] <= b['cycle'] for a, b in zip(rows, rows[1:])))
    final_hold_complete = bool(published and events.get('END')) and (
        events['END'][-1]['field'] - published[-1]['field'] >=
        2 + int(pictures[published[-1]['id']]['repeat_first_field']))
    report['simulation_timing_pass'] = bool(
        complete_trace and report['display_order'] == expected_order and
        not descriptor_mismatches and not pts_mismatches and
        not report['cadence_mismatches'] and final_hold_complete and
        not any(report['cache_flags_seen'].values()))
    report['final_authored_hold_complete'] = final_hold_complete
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', type=Path)
    parser.add_argument('trace', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--require-pass', action='store_true',
                        help='fail unless the complete trace passes simulation timing checks')
    args = parser.parse_args()
    fixture = json.loads(args.fixture.read_text())
    with args.trace.open() as handle:
        rows = [{k: v if k == 'event' else int(v) for k, v in r.items()} for r in csv.DictReader(handle)]
    report = analyze(fixture, rows)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('simulation_timing_pass', 'complete_decode_trace', 'expected_pictures', 'starts', 'ready', 'publications', 'unique_publications', 'missing_coded_pictures', 'duplicate_publications', 'cache_flags_seen')}))
    if args.require_pass and not report['simulation_timing_pass']:
        raise SystemExit('Native simulation timing qualification failed; see saved report')


if __name__ == '__main__':
    main()
