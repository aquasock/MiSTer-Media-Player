#!/usr/bin/env python3
"""Measure where each AC-3 channel lands in the helper's stereo downmix.

Example:
  python3 tools/streams/generate_test_dvd_ac3_av.py --sweep --duration 12 \
    --output /tmp/ac3_sweep.mpg --report /tmp/sweep.json
  python3 tools/streams/analyze_ac3_downmix.py --helper host/build/media_player_helper.native \
    --fixture /tmp/ac3_sweep.mpg --report-in /tmp/sweep.json

Requires a --sweep fixture, where each channel sounds alone in its own slot.
The ITU/ATSC stereo downmix places the front channels hard left and right, the
centre equally in both, the surrounds on their own side attenuated, and drops
LFE entirely. This checks that rather than trusting channel labels.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
import subprocess
import tempfile
from pathlib import Path

EDGE_GUARD_SECONDS = 0.2
RATE = 48000


def goertzel(samples, hz: float) -> float:
    k = 2 * math.pi * hz / RATE
    c = 2 * math.cos(k)
    s1 = s2 = 0.0
    for value in samples:
        s0 = value + c * s1 - s2
        s2, s1 = s1, s0
    return math.sqrt(max(s1 * s1 + s2 * s2 - c * s1 * s2, 0.0)) / max(len(samples), 1)


def rms(samples) -> float:
    return math.sqrt(sum(x * x for x in samples) / len(samples)) if samples else 0.0


def classify(left: float, right: float, floor: float) -> str:
    if left < floor and right < floor:
        return 'silent'
    if right < floor:
        return 'left'
    if left < floor:
        return 'right'
    ratio = 20 * math.log10((left + 1e-9) / (right + 1e-9))
    return 'both equally' if abs(ratio) < 1.0 else f'both, {ratio:+.2f} dB'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--helper', required=True, type=Path)
    parser.add_argument('--fixture', required=True, type=Path)
    parser.add_argument('--report-in', required=True, type=Path,
                        help='the generator report for the sweep fixture')
    parser.add_argument('--report', type=Path, default=None)
    args = parser.parse_args()

    fixture_report = json.loads(args.report_in.read_text())
    order = fixture_report.get('sweep_order')
    slot = fixture_report.get('sweep_slot_seconds')
    tones = fixture_report['channel_tones_hz']
    expected = fixture_report.get('expected_downmix_placement') or {}
    if not order or not slot:
        raise SystemExit('fixture report is not from a --sweep fixture')

    with tempfile.TemporaryDirectory(prefix='ac3_downmix_') as directory:
        temp = Path(directory)
        pcm = temp / 'helper.s16le'
        subprocess.run([str(args.helper), '--protocol', '1',
                        '--source', f'file:{args.fixture.resolve()}',
                        '--pcm-out', str(pcm), '--video-out', str(temp / 'video.m2v')],
                       check=True, capture_output=True)
        raw = pcm.read_bytes()
    values = struct.unpack(f'<{len(raw) // 2}h', raw)
    left_all, right_all = values[0::2], values[1::2]
    peak = max(rms(left_all), rms(right_all)) or 1.0
    floor = peak * 0.02

    slots = []
    for index, name in enumerate(order):
        start = int((index * slot + EDGE_GUARD_SECONDS) * RATE)
        end = int(((index + 1) * slot - EDGE_GUARD_SECONDS) * RATE)
        left, right = left_all[start:end], right_all[start:end]
        hz = tones[name]
        measured = classify(rms(left), rms(right), floor)
        slots.append({'channel': name, 'tone_hz': hz,
                      'slot_seconds': [round(index * slot, 3), round((index + 1) * slot, 3)],
                      'rms_left': round(rms(left), 2), 'rms_right': round(rms(right), 2),
                      'tone_left': round(goertzel(left, hz), 3),
                      'tone_right': round(goertzel(right, hz), 3),
                      'measured_placement': measured,
                      'expected_placement': expected.get(name)})
    fronts = [s for s in slots if s['channel'] in ('FL', 'FR')]
    surrounds = [s for s in slots if s['channel'] in ('BL', 'BR')]
    front_level = max((max(s['rms_left'], s['rms_right']) for s in fronts), default=0.0)
    report = {'fixture': str(args.fixture), 'helper': str(args.helper),
              'slots': slots, 'front_reference_rms': front_level,
              'surround_attenuation_db': [
                  round(20 * math.log10((max(s['rms_left'], s['rms_right']) + 1e-9)
                                        / (front_level + 1e-9)), 2) for s in surrounds],
              'centre_attenuation_db': [
                  round(20 * math.log10((max(s['rms_left'], s['rms_right']) + 1e-9)
                                        / (front_level + 1e-9)), 2)
                  for s in slots if s['channel'] == 'FC'],
              'scope': 'Stereo downmix placement only. This is not a discrete 5.1 output '
                       'test: the helper emits two channels, so surround and LFE identity '
                       'beyond the downmix needs IEC 61937 passthrough.'}
    failures = [f"{s['channel']}: expected {s['expected_placement']}, measured {s['measured_placement']}"
                for s in slots
                if s['expected_placement'] and not
                (s['measured_placement'] in s['expected_placement']
                 or s['expected_placement'].startswith(s['measured_placement']))]
    report['failures'] = failures
    report['passed'] = not failures
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
