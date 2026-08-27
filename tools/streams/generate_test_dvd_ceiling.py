#!/usr/bin/env python3
"""Re-encode a supported 480i all-I clip for DVD-ceiling video testing.

Example (run on the build PC; generated media is not committed):
  python3 tools/streams/generate_test_dvd_ceiling.py \
    --source bbb_480i_tff_15s.m2v --output bbb_480i_tff_15s_9800kbps.m2v

Retains the input scene, field order and picture count; changes compression.
Uses the existing interlaced-signalling patch and proves decoded plane equality.
The narrow CBR check below is for all-I, non-repeated frame pictures only. It
is not a general MPEG verifier or DVD application-conformance certificate.

References: H.262 (02/2000) 6.3.3, 6.3.9, Annex C.3/C.5/C.6/C.11;
https://www.itu.int/rec/T-REC-H.262-200002-S/en
FFmpeg DVD target buffer setting (1,835,008 bits):
https://ffmpeg.org/ffmpeg.html#Main-options
DVD video ceiling: Adobe DVD Primer (March 2004), Japanese edition, p.14:
https://www.adobe.com/jp/motion/pdfs/DVD_Primer.pdf#page=14
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from fractions import Fraction
from pathlib import Path

import analyze_h262_compatibility as analyzer
import generate_test_interlaced_i_frames as interlaced
import h262common as h

RATE = 9_800_000
BUFFER_BITS = 1_835_008
PERIOD = Fraction(1001, 30000)
CLASSIFICATION = 'interlaced_420_i_frame_candidate_requires_macroblock_execution'


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def check_structure(path: Path, frames: int) -> dict:
    result = analyzer.analyze_file(path)
    require(result['classification'] == CLASSIFICATION,
            f'unsupported structure: {result["classification_reasons"]}')
    require(len(result['pictures']) == frames, 'unexpected picture count')
    for pic in result['pictures']:
        c = pic['coding_extension']
        require(c['top_field_first'], 'fixture requires TFF input')
        require(not c['q_scale_type'] and not c['intra_vlc_format']
                and not c['alternate_scan'] and c['intra_dc_precision'] == 0,
                'fixture requires ordinary linear-quantizer intra coding')
    return result


def access_units(data: bytes) -> tuple[list[int], list[int], list[int]]:
    """Return AU sizes, picture-start-code ends and finite vbv_delay values."""
    codes = analyzer.start_codes(data)
    positions = [i for i, (_, code) in enumerate(codes) if code == 0]
    require(bool(positions), 'no pictures')
    starts, picture_ends, delays = [], [], []
    for n, index in enumerate(positions):
        offset = codes[index][0]
        if n == 0:
            begin = 0
        else:
            previous = index - 1
            while previous >= 0 and not 1 <= codes[previous][1] <= 0xAF:
                previous -= 1
            require(previous >= positions[n - 1], 'picture has no slices')
            begin = codes[previous + 1][0]
        starts.append(begin)
        picture_ends.append((offset + 4) * 8)
        delay = analyzer.read_bits(data[offset + 4:offset + 8], 13, 16)
        require(delay != 0xFFFF, 'finite CBR vbv_delay required')
        delays.append(delay)
    sizes = [(b - a) * 8 for a, b in zip(starts, starts[1:] + [len(data)])]
    return sizes, picture_ends, delays


def check_cbr(sizes: list[int], starts: list[int], delays: list[int],
              rate: int = RATE, capacity: int = BUFFER_BITS) -> dict:
    """Constant-arrival occupancy witness, with 90-kHz delay quantization.

    Prefixes belong to the following picture; the final sequence-end belongs
    to the last. Playback removes one complete AU per frame. Input ends at EOF.
    Exact rational arithmetic prevents accumulated frame-timing rounding.
    """
    require(bool(sizes) and len(sizes) == len(starts) == len(delays),
            'inconsistent CBR arrays')
    require(rate > 0 and capacity > 0, 'invalid CBR parameters')
    require(all(s > 0 for s in sizes), 'empty access unit')
    require(all(0 <= d < 0xFFFF for d in delays), 'finite CBR delay required')
    total = sum(sizes)
    origin = Fraction(starts[0], rate) + Fraction(delays[0], 90000)
    removed = 0
    peak = Fraction(0)
    minimum_after = Fraction(capacity)
    max_delay_error = Fraction(0)
    records = []
    for n, (size, start, delay) in enumerate(zip(sizes, starts, delays)):
        time = origin + n * PERIOD
        arrived = min(Fraction(total), rate * time)
        before = arrived - removed
        after = before - size
        require(before <= capacity, f'CBR overflow at picture {n}')
        require(after >= 0, f'CBR underflow at picture {n}')
        delay_error = abs((time - Fraction(start, rate)) * 90000 - delay)
        # Both the origin and this header independently quantize to 90 kHz.
        require(delay_error <= 2, f'CBR delay inconsistency at picture {n}')
        peak = max(peak, before)
        minimum_after = min(minimum_after, after)
        max_delay_error = max(max_delay_error, delay_error)
        records.append({'picture': n, 'bytes': size // 8,
                        'before_bits': float(before), 'after_bits': float(after)})
        removed += size
    return {'arrival_bits_per_second': rate, 'capacity_bits': capacity,
            'initial_decode_seconds': float(origin),
            'maximum_occupancy_bits': float(peak),
            'minimum_after_removal_bits': float(minimum_after),
            'maximum_delay_error_90khz_ticks': float(max_delay_error),
            'underflow_count': 0, 'overflow_count': 0, 'pictures': records,
            'scope': 'Constant-rate all-I witness with quantized vbv_delay; not a general VBV/application verifier.'}


def verify_rate(data: bytes) -> dict:
    require(data.endswith(interlaced.SEQUENCE_END), 'missing sequence end')
    codes = analyzer.start_codes(data)
    require(sum(code == 0xB7 for _, code in codes) == 1, 'multiple sequences')
    headers = extensions = 0
    for i, (_, code) in enumerate(codes):
        payload = analyzer.payload_between(data, codes, i)
        if code == 0xB3:
            require(analyzer.read_bits(payload, 32, 18) * 400 == RATE,
                    'wrong bitrate header')
            require(analyzer.read_bits(payload, 50, 1) == 1, 'missing marker')
            require(analyzer.read_bits(payload, 51, 10) * 16384 == BUFFER_BITS,
                    'wrong VBV size header')
            headers += 1
        elif code == 0xB5 and analyzer.read_bits(payload, 0, 4) == 1:
            require(analyzer.read_bits(payload, 4, 8) == 0x48,
                    'expected Main Profile at Main Level')
            require(analyzer.read_bits(payload, 19, 12) == 0
                    and analyzer.read_bits(payload, 32, 8) == 0,
                    'extended bitrate/buffer unsupported by this check')
            require(analyzer.read_bits(payload, 40, 8) == 0,
                    'low_delay or frame-rate extension not supported')
            extensions += 1
    require(headers > 0 and headers == extensions, 'inconsistent sequence headers')
    sizes, starts, delays = access_units(data)
    result = check_cbr(sizes, starts, delays)
    average = Fraction(len(data) * 8, len(sizes)) / PERIOD
    # Exercise sustained near-ceiling traffic, rather than just signaling it.
    require(RATE * Fraction(98, 100) <= average <= RATE * Fraction(101, 100),
            f'fixture average is not near the ceiling: {float(average)}')
    windows = [float(Fraction(sum(sizes[i:i+30]), 30) / PERIOD)
               for i in range(len(sizes) - 29)]
    result.update({'sequence_headers': headers, 'frame_count': len(sizes),
                   'average_bits_per_second': float(average),
                   'min_30_frame_bits_per_second': min(windows) if windows else None,
                   'max_30_frame_bits_per_second': max(windows) if windows else None,
                   'maximum_access_unit_bytes': max(sizes) // 8})
    return result


def run_clean(command: list[str]) -> subprocess.CompletedProcess:
    result = subprocess.run(command, check=False, capture_output=True)
    require(result.returncode == 0,
            f'command failed ({result.returncode}): {result.stderr.decode(errors="replace")}')
    require(not result.stderr.strip(), result.stderr.decode(errors='replace'))
    return result


def decoded_digest(ffmpeg: str, path: Path, frames: int, temp: Path) -> str:
    raw = temp / 'decode.yuv'
    # No frame limit: an extra decoded picture must fail the size check too.
    run_clean([ffmpeg, '-hide_banner', '-loglevel', 'error', '-xerror',
               '-threads', '1', '-i', str(path), '-map', '0:v:0', '-an',
               '-fps_mode', 'passthrough', '-pix_fmt', 'yuv420p',
               '-f', 'rawvideo', '-y', str(raw)])
    require(raw.stat().st_size == frames * 720 * 480 * 3 // 2,
            'decoded frame count/size mismatch')
    with raw.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--frames', type=int, default=449)
    args = p.parse_args()
    require(args.frames >= 30, 'at least 30 frames required for rate coverage')
    source, output = args.source.resolve(), args.output.resolve()
    manifest = output.with_suffix('.json')
    require(not output.exists() and not manifest.exists(), 'output already exists')
    check_structure(source, args.frames)
    ffmpeg = h.require_tool('ffmpeg')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='dvd_ceiling_') as name:
        temp = Path(name)
        unpatched, patched = temp / 'original.m2v', temp / 'patched.m2v'
        command = [ffmpeg, '-hide_banner', '-loglevel', 'warning', '-xerror',
                   '-threads', '1', '-r', '30000/1001', '-i', str(source),
                   '-map', '0:v:0', '-frames:v', str(args.frames), '-an',
                   '-r', '30000/1001', '-fps_mode', 'cfr',
                   '-c:v', 'mpeg2video', '-pix_fmt', 'yuv420p', '-threads', '1',
                   '-flags', '+bitexact', '-g', '1', '-bf', '0',
                   '-b:v', str(RATE), '-minrate:v', str(RATE),
                   '-maxrate:v', str(RATE), '-bufsize:v', str(BUFFER_BITS),
                   '-qmin', '1', '-qmax', '31', '-sc_threshold', '1000000000',
                   '-f', 'mpeg2video', str(unpatched)]
        run_clean(command)
        original = unpatched.read_bytes()
        if not original.endswith(interlaced.SEQUENCE_END):
            original += interlaced.SEQUENCE_END
            unpatched.write_bytes(original)
        data = interlaced.patch_interlaced_signalling(original, True, args.frames)
        patched.write_bytes(data)
        structure = check_structure(patched, args.frames)
        rate = verify_rate(data)
        digest = decoded_digest(ffmpeg, unpatched, args.frames, temp)
        require(digest == decoded_digest(ffmpeg, patched, args.frames, temp),
                'signalling patch changes decoded planes')
        with source.open('rb') as f:
            source_digest = hashlib.file_digest(f, 'sha256').hexdigest()
        result = {'source': str(source), 'source_sha256': source_digest,
                  'source_bytes': source.stat().st_size, 'output': output.name,
                  'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                  'ffmpeg_version': subprocess.check_output([ffmpeg, '-version'],
                                      text=True).splitlines()[0],
                  'command': [a.replace(str(unpatched), '<temporary>.m2v') for a in command],
                  'frame_count': args.frames, 'frame_rate': '30000/1001',
                  'duration_seconds': float(args.frames * PERIOD),
                  'classification': structure['classification'], 'field_order': 'TFF',
                  'decoded_yuv420p_sha256': digest,
                  'patched_vs_unpatched_planes_equal': True, 'rate_check': rate,
                  'scope': 'Video-only supported all-I frame-DCT fixture; not combined DVD stream, full DVD compatibility or hardware acceptance.'}
        with output.open('xb') as f:
            f.write(data)
        with manifest.open('x') as f:
            json.dump(result, f, indent=2)
            f.write('\n')
        print(json.dumps({k: result[k] for k in ('output', 'bytes', 'sha256', 'frame_count')}))
        print(f"PASS rate={rate['average_bits_per_second']:.3f} bit/s; CBR buffer and decoded planes")


if __name__ == '__main__':
    main()
