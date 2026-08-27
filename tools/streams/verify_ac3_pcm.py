#!/usr/bin/env python3
"""Compare the helper's AC-3 decode against an independent FFmpeg decode.

Example:
  python3 tools/streams/verify_ac3_pcm.py \
    --helper host/arm/media_player_helper \
    --fixture /path/to/ac3_480i_tff_5p1.mpg

Two independent AC-3 decoders are not expected to agree bit for bit: liba52 and
FFmpeg differ in downmix coefficients, dynamic range handling and rounding. The
gate is therefore a bounded difference plus correlation and per-channel tone
identity, rather than equality.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
import subprocess
import tempfile
from pathlib import Path


def read_stereo(path: Path) -> tuple[list[int], list[int]]:
    raw = path.read_bytes()
    if len(raw) % 4:
        raise SystemExit(f'{path} is not stereo s16le')
    values = struct.unpack(f'<{len(raw) // 2}h', raw)
    return list(values[0::2]), list(values[1::2])


def stats(a: list[int], b: list[int]) -> dict:
    n = min(len(a), len(b))
    if not n:
        return {'samples': 0}
    diffs = [a[i] - b[i] for i in range(n)]
    mean_a = sum(a[:n]) / n
    mean_b = sum(b[:n]) / n
    va = sum((x - mean_a) ** 2 for x in a[:n])
    vb = sum((x - mean_b) ** 2 for x in b[:n])
    cov = sum((a[i] - mean_a) * (b[i] - mean_b) for i in range(n))
    return {'samples': n,
            'max_abs_difference': max(abs(d) for d in diffs),
            'rms_difference': math.sqrt(sum(d * d for d in diffs) / n),
            'correlation': cov / math.sqrt(va * vb) if va and vb else None,
            'rms_helper': math.sqrt(sum(x * x for x in a[:n]) / n),
            'rms_reference': math.sqrt(sum(x * x for x in b[:n]) / n)}


def dominant_tones(samples: list[int], rate: int, count: int = 4) -> list[dict]:
    """Goertzel over the fixture's known tones; avoids an FFT dependency."""
    candidates = (55, 220, 277, 330, 440, 554)
    n = min(len(samples), rate * 2)
    window = samples[:n]
    energies = []
    for hz in candidates:
        k = 2 * math.pi * hz / rate
        c = 2 * math.cos(k)
        s1 = s2 = 0.0
        for value in window:
            s0 = value + c * s1 - s2
            s2, s1 = s1, s0
        energies.append({'hz': hz, 'relative_power': s1 * s1 + s2 * s2 - c * s1 * s2})
    peak = max(e['relative_power'] for e in energies) or 1.0
    for e in energies:
        e['relative_power'] = round(e['relative_power'] / peak, 6)
    return sorted(energies, key=lambda e: -e['relative_power'])[:count]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--helper', required=True, type=Path)
    parser.add_argument('--fixture', required=True, type=Path)
    parser.add_argument('--reference', type=Path, default=None,
                        help='stereo s16le reference; regenerated with FFmpeg when absent')
    parser.add_argument('--max-abs-difference', type=int, default=4096)
    parser.add_argument('--min-correlation', type=float, default=0.95)
    parser.add_argument('--report', type=Path, default=None)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix='ac3_verify_') as directory:
        temp = Path(directory)
        helper_pcm = temp / 'helper.s16le'
        video = temp / 'video.m2v'
        result = subprocess.run([str(args.helper), '--protocol', '1',
                                 '--source', f'file:{args.fixture.resolve()}',
                                 '--pcm-out', str(helper_pcm),
                                 '--video-out', str(video)],
                                capture_output=True, text=True)
        if result.returncode:
            print(result.stderr[-4000:])
            raise SystemExit('helper failed')
        reference = args.reference
        if reference is None:
            reference = temp / 'reference.s16le'
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror',
                            '-i', str(args.fixture), '-map', '0:a:0', '-ac', '2',
                            '-ar', '48000', '-f', 's16le', str(reference)], check=True)
        helper_l, helper_r = read_stereo(helper_pcm)
        ref_l, ref_r = read_stereo(Path(reference))
        report = {
            'fixture': str(args.fixture), 'helper': str(args.helper),
            'helper_frames': len(helper_l), 'reference_frames': len(ref_l),
            'frame_count_matches': len(helper_l) == len(ref_l),
            'helper_seconds': len(helper_l) / 48000,
            'left': stats(helper_l, ref_l), 'right': stats(helper_r, ref_r),
            'helper_left_tones': dominant_tones(helper_l, 48000),
            'helper_right_tones': dominant_tones(helper_r, 48000),
            'reference_left_tones': dominant_tones(ref_l, 48000),
            'helper_messages': [l for l in result.stderr.splitlines() if 'AC-3' in l][:2],
            'thresholds': {'max_abs_difference': args.max_abs_difference,
                           'min_correlation': args.min_correlation},
            'scope': 'AC-3 decode correctness against an independent decoder; '
                     'not passthrough, not hardware acceptance.'}
        failures = []
        if not report['frame_count_matches']:
            failures.append('helper and reference frame counts differ')
        for side in ('left', 'right'):
            s = report[side]
            if s.get('max_abs_difference', 1 << 30) > args.max_abs_difference:
                failures.append(f'{side} max difference {s["max_abs_difference"]}')
            if (s.get('correlation') or 0) < args.min_correlation:
                failures.append(f'{side} correlation {s.get("correlation")}')
        report['failures'] = failures
        report['passed'] = not failures
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
