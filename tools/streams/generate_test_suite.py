#!/usr/bin/env python3
"""Generate the six hand-test files for a release.

Example:
  python3 tools/streams/generate_test_suite.py --output-dir /tmp/suite

Each file stays inside what the decoder actually accepts: 4:2:0, I-pictures
only, frame structured, frame DCT and frame prediction only, 720x480 at
30000/1001. They are meant to be watched and listened to, not scored
automatically, so the content of each is chosen to make its own failure mode
obvious rather than to look pleasant. Media stays local; only this generator
is committed.
"""
from __future__ import annotations

import argparse
import hashlib
import math
import json
import subprocess
import tempfile
from pathlib import Path

import analyze_h262_compatibility as analyzer
import check_media_compatibility as compatibility
import generate_test_dvd_ceiling as dvd
import generate_test_interlaced_i_frames as interlaced
from finalize_program_stream import finalize_program_stream
from generate_test_dvd_av_soak import replace_video_payloads, verify_packs, digest
from generate_test_dvd_ac3_av import TONES, build_sweep_filter, extract_ac3

MUX_RATE = 10_080_000
# 8 Mbit/s for every test. It leaves room for DTS, the widest audio track in
# the set, inside the same DVD mux, and it keeps the muxer's buffer model happy
# on the deliberately low-complexity synthetic content used here.
VIDEO_RATE = 8_000_000
DTS_VIDEO_RATE = 8_000_000
MP2_RATE = 192_000
AC3_RATE = 448_000
DTS_RATE = 1_509_000

# A frame-indexed source advances four scanlines per 59.94 Hz field.
# drawbox's t is thickness, not a per-frame timestamp; validate the decoded
# positions below rather than trusting a filter expression or its labels.
BAR = ("color=c=black:s=720x480:r=60000/1001:d={d},"
       "geq=lum='16+219*gte(Y,mod(N*4,472))*lt(Y,mod(N*4,472)+8)':cb=128:cr=128")
# One pixel horizontal lines scrolling vertically. Weave combs hard on this,
# Bob flickers and softens it, so the two modes cannot be confused.
# Eight pixel bands scrolling at 60 px/s, confined to the middle third. Woven
# from 59.94 fields this is already near worst case for an all-I encoder, and
# across the whole frame it breaks the encoder and muxer buffer models outright;
# in a strip it still combs obviously under Weave and flickers under Bob.
LINES = ("color=c=black:s=720x480:r=60000/1001:d={d},"
         "geq=lum='16+219*2*((floor((Y+floor(T*60))/8))/2"
         "-floor((floor((Y+floor(T*60))/8))/2))':cb=128:cr=128,"
         "drawbox=x=0:y=0:w=720:h=160:color=black:t=fill,"
         "drawbox=x=0:y=320:w=720:h=160:color=black:t=fill")
# Ordinary moving detail, encoded progressively.
PROG = "testsrc2=size=720x480:rate=30000/1001:duration={d}"

TESTS = [
    ('1_interlace_tff', BAR, 'interlaced', True, 'mp2',
     'Interlaced 480i, top field first. The bar should sweep down smoothly.'),
    ('2_interlace_bff', BAR, 'interlaced', False, 'mp2',
     'Interlaced 480i, bottom field first. Same bar; judder here but not in test 1 means field order.'),
    ('3_deinterlace_bob_weave', LINES, 'interlaced', True, 'mp2',
     'Scrolling eight-pixel bands. Compare motion and combing in Weave with Bob.'),
    ('4_progressive', PROG, 'progressive', None, 'mp2',
     'Progressive 480p sequence, to confirm progressive playback still works.'),
    ('5_audio_ac3_51', BAR, 'interlaced', True, 'ac3',
     'AC-3 5.1 channel sweep: FL, FR, FC, LFE, BL, BR, two seconds each.'),
    ('6_audio_dts_51', BAR, 'interlaced', True, 'dts',
     'DTS 5.1 channel sweep, same order. Passthrough only; select S/PDIF.'),
    ('7_progressive_ipb', PROG, 'progressive', None, 'mp2',
     'Progressive 480p with an ordinary GOP, so P and B pictures are actually '
     'exercised. Every other test in this set is all-I.'),
]

# Every test above is all-I, which is what the interlaced path accepts. Test
# seven deliberately is not: it carries P and B pictures so the progressive
# path's picture-type support can be established by playing it rather than
# inferred from the RTL.
GOP_OVERRIDES = {'7_progressive_ipb': ('15', '2')}


def audio_args(codec: str, duration: float) -> tuple[list[str], list[str]]:
    """Returns (input/filter args, encoder args)."""
    if codec == 'mp2':
        return (['-f', 'lavfi', '-i',
                 f'sine=frequency=440:duration={duration}:sample_rate=48000'],
                ['-c:a', 'mp2', '-ar', '48000', '-ac', '2', '-b:a', str(MP2_RATE)])
    if codec == 'ac3':
        return ([], ['-c:a', 'ac3', '-ar', '48000', '-ac', '6', '-b:a', str(AC3_RATE)])
    return ([], ['-c:a', 'dca', '-strict', '-2', '-ar', '48000', '-ac', '6',
                 '-b:a', str(DTS_RATE)])


def verify_motion(path: Path, frames: int, tff: bool | None, bar: bool) -> dict:
    """Read decoded pixels, independent of the generator's motion expression.

    For bar fixtures, check every field's actual scanline positions in temporal
    order, including wrap. This rejects a static bar and a TFF/BFF label swap.
    Only one decoded frame is retained in memory.
    """
    command = ['ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:v:0',
               '-an', '-pix_fmt', 'yuv420p', '-f', 'rawvideo', '-']
    frame_bytes = 720 * 480 * 3 // 2
    hashes: set[str] = set()
    positions = []
    decoded = 0
    with tempfile.TemporaryFile() as errors:
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
        try:
            assert proc.stdout is not None
            while True:
                data = proc.stdout.read(frame_bytes)
                if not data:
                    break
                dvd.require(len(data) == frame_bytes, 'partial decoded frame')
                hashes.add(hashlib.sha256(data).hexdigest())
                if bar:
                    bright = {y for y in range(480)
                              if sum(data[y * 720:(y + 1) * 720]) > 128 * 720}
                    for field in range(2):
                        parity = field if tff else 1 - field
                        top = ((decoded * 2 + field) * 4) % 472
                        expected = [y for y in range(top, top + 8) if y % 2 == parity]
                        actual = sorted(y for y in bright if y % 2 == parity)
                        dvd.require(actual == expected,
                                    f'field motion/order mismatch picture={decoded} field={field}: '
                                    f'{actual} != {expected}')
                        if len(positions) < 12:
                            positions.append({'field': decoded * 2 + field,
                                              'parity': parity, 'bright_rows': actual})
                decoded += 1
            dvd.require(proc.wait() == 0, 'independent motion decode failed')
            errors.seek(0)
            dvd.require(not errors.read(), 'independent motion decode emitted errors')
        finally:
            proc.stdout.close()
            if proc.poll() is None:
                proc.terminate()
                proc.wait()
    dvd.require(decoded == frames, 'motion decode picture count mismatch')
    dvd.require(len(hashes) > 1, 'fixture is stationary')
    return {'decoded_frames': decoded, 'distinct_decoded_frames': len(hashes),
            'verified_bar_fields': decoded * 2 if bar else 0,
            'field_order': None if tff is None else ('TFF' if tff else 'BFF'),
            'first_field_positions': positions}


def build(name: str, video_filter: str, mode: str, tff, codec: str,
          note: str, duration: float, out_dir: Path) -> dict:
    output = out_dir / f'test_{name}.mpg'
    commands: list[list[str]] = []

    def run(command: list[str]) -> None:
        commands.append(command)
        dvd.run_clean(command)

    video_rate = DTS_VIDEO_RATE if codec == 'dts' else VIDEO_RATE
    with tempfile.TemporaryDirectory(prefix='suite_', dir=out_dir) as directory:
        temp = Path(directory)
        original, patched, program = (temp / n for n in ('o.m2v', 'p.m2v', 'program.mpg'))
        vf = video_filter.format(d=duration)
        sweep = codec in ('ac3', 'dts')
        a_in, a_enc = audio_args(codec, duration)
        filters = ['-filter_complex', build_sweep_filter(duration)] if sweep else []
        maps = ['-map', '0:v:0', '-map', '[aout]'] if sweep else ['-map', '0:v:0', '-map', '1:a:0']
        interlace_vf = ['-vf', 'tinterlace=mode=' + ('interleave_top' if tff else 'interleave_bottom') + ',setsar=32/27'] \
            if mode == 'interlaced' else ['-vf', 'setsar=32/27']
        print(f'Encoding {name}', flush=True)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-xerror', '-threads', '1',
             '-f', 'lavfi', '-i', vf, *a_in, *filters, *maps, *interlace_vf,
             '-c:v', 'mpeg2video', '-pix_fmt', 'yuv420p', '-threads', '1',
             '-flags', '+bitexact',
             '-g', GOP_OVERRIDES.get(name, ('1', '0'))[0],
             '-bf', GOP_OVERRIDES.get(name, ('1', '0'))[1],
             # Capped variable rate, not constant rate: these are hand tests,
             # and the synthetic content is compressible enough that forcing
             # constant rate makes the encoder's rate control underflow. The
             # ceiling and soak fixtures elsewhere remain constant rate.
             '-b:v', str(video_rate),
             '-maxrate:v', str(video_rate), '-bufsize:v', str(dvd.BUFFER_BITS),
             '-qmin', '1', '-qmax', '31', '-sc_threshold', '1000000000',
             *a_enc, '-muxrate', str(MUX_RATE), '-packetsize', '2048',
             '-f', 'vob', str(program)])
        finalize_program_stream(program)
        data, mpeg_audio, ids = compatibility.demux_program_stream(program.read_bytes())
        frames = sum(code == 0 for _, code in analyzer.start_codes(data))
        if mode == 'interlaced':
            original.write_bytes(data)
            patched.write_bytes(interlaced.patch_interlaced_signalling(data, tff, frames))
            replace_video_payloads(program, patched)
            pixels = dvd.decoded_digest('ffmpeg', original, frames, temp)
            dvd.require(pixels == dvd.decoded_digest('ffmpeg', patched, frames, temp),
                        'signalling patch changed decoded planes')
            (temp / 'decode.yuv').unlink()
            video = patched
        else:
            original.write_bytes(data)
            video = original
        if mode == 'interlaced':
            structure = dvd.check_structure(video, frames, top_field_first=tff)['classification']
        else:
            structure = analyzer.analyze_file(video)['classification']
        stream_ids = (0xBB, 0xBE, 0xBF, 0xE0, 0xBD) if sweep else (0xBB, 0xBE, 0xBF, 0xE0, 0xC0)
        packs = verify_packs(program, stream_ids=stream_ids)
        motion = verify_motion(program, frames, tff, video_filter == BAR)
        entry = {'motion': motion, 'name': name, 'file': output.name, 'note': note,
                 'mode': mode, 'field_order': (None if tff is None else ('TFF' if tff else 'BFF')),
                 'audio_codec': codec, 'video_bits_per_second': video_rate,
                 'frame_count': frames,
                 'duration_seconds': float(frames * dvd.PERIOD),
                 'classification': structure, 'pack_check': packs,
                 'program_end_seen': ids['program_end_seen'],
                 'commands': [[a.replace(str(temp), '<temporary>') for a in c] for c in commands]}
        if sweep:
            entry['channel_order'] = [n for _hz, n in TONES]
            entry['channel_tones_hz'] = {n: hz for hz, n in TONES}
            entry['audio_private_substream'] = 0x88 if codec == 'dts' else 0x80
            es = extract_ac3(program.read_bytes(), entry['audio_private_substream'])
            dvd.require(len(es) > 0, f'no {codec} substream payload in {name}')
            entry['audio_elementary_bytes'] = len(es)
        else:
            dvd.require(len(mpeg_audio) > 0, f'no MPEG audio in {name}')
            entry['audio_elementary_bytes'] = len(mpeg_audio)
        program.replace(output)
    entry['bytes'] = output.stat().st_size
    entry['sha256'] = digest(output)
    return entry


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--duration', type=float, default=12.0)
    parser.add_argument('--only', default=None, help='substring of one test name')
    parser.add_argument('--manifest', type=Path, default=None)
    args = parser.parse_args()
    if not math.isfinite(args.duration) or args.duration < 0.2:
        parser.error('--duration must be finite and at least 0.2 seconds')
    if args.only and not any(args.only in t[0] for t in TESTS):
        parser.error('--only matches no test')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, vf, mode, tff, codec, note in TESTS:
        if args.only and args.only not in name:
            continue
        entries.append(build(name, vf, mode, tff, codec, note,
                             args.duration, args.output_dir))
    manifest = {'tests': entries,
                'accepted_video': '4:2:0, I-pictures only, frame structured, '
                                  'frame DCT and frame prediction only, 720x480 at 30000/1001',
                'ffmpeg_version': subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0],
                'scope': 'Hand tests to be watched and listened to. Not an automatic gate '
                         'and not a DVD conformance suite.'}
    path = args.manifest or (args.output_dir / 'manifest.json')
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    for e in entries:
        print(f"{e['file']:34s} {e['bytes']:>10d}  {e['frame_count']:>4d} pics  {e['classification']}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
