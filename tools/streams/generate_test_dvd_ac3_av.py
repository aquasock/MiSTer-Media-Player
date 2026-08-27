#!/usr/bin/env python3
"""Generate a deterministic 480i TFF / AC-3 5.1 fixture for audio qualification.

Example:
  python3 tools/streams/generate_test_dvd_ac3_av.py \
    --output /path/to/ac3_480i_tff_5p1.mpg

The video path is the accepted all-I frame-DCT native-480i one, unchanged, so
this fixture isolates the audio codec. Audio is six discrete sine tones, one
per channel, which makes channel assignment and downmix behaviour auditable in
the decoded result rather than a matter of opinion. Nothing here qualifies
interlaced P/B, field DCT, DVD navigation or AC-3 passthrough. Large artifacts
stay local; only this generator is committed.
"""
from __future__ import annotations

import argparse
import hashlib
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

VIDEO_RATE = 9_600_000
AUDIO_RATE = 448_000          # DVD's usual 5.1 AC-3 rate
DTS_RATE = 1_509_000          # DVD's usual 5.1 DTS rate
# DTS costs over a megabit more than AC-3, so the video rate has to come down
# to keep the whole programme inside the same 10.08 Mbit/s DVD mux, which is
# what real DTS discs do rather than raising the mux.
DTS_VIDEO_RATE = 8_000_000
MUX_RATE = 10_080_000
AC3_SUBSTREAM = 0x80
DTS_SUBSTREAM = 0x88

# One tone per channel, in FFmpeg's native AC-3 channel order.
TONES = ((220, 'FL'), (277, 'FR'), (330, 'FC'), (55, 'LFE'), (440, 'BL'), (554, 'BR'))


def extract_ac3(data: bytes, substream: int) -> bytes:
    """Concatenate one private stream 1 substream into an elementary stream.

    Decoding this rather than the program keeps container timestamps out of the
    reference entirely, and it is byte for byte what the helper is handed.
    """
    out = bytearray()
    offset = 0
    synced = False
    while offset + 4 <= len(data):
        if data[offset:offset + 3] != b'\x00\x00\x01':
            offset += 1
            continue
        sid = data[offset + 3]
        if sid == 0xBA:
            offset += 14 + (data[offset + 13] & 7)
            continue
        if sid == 0xB9:
            break
        length = int.from_bytes(data[offset + 4:offset + 6], 'big')
        payload = data[offset + 6:offset + 6 + length]
        if sid == 0xBD and len(payload) > 3 and (payload[0] & 0xc0) == 0x80:
            start = 3 + payload[2]
            body = payload[start:]
            if len(body) > 4 and body[0] == substream:
                first = int.from_bytes(body[2:4], 'big')
                frames = body[4:]
                if not synced:
                    if not first:
                        offset += 6 + length
                        continue
                    frames = frames[first - 1:]
                    synced = True
                out += frames
        offset += 6 + length
    return bytes(out)


def build_audio_filter(duration: float) -> str:
    """All six channels sounding at once, one steady tone each."""
    parts = [f'sine=frequency={hz}:duration={duration}:sample_rate=48000[a{i}]'
             for i, (hz, _name) in enumerate(TONES)]
    return ';'.join(parts) + ';' + join_clause()


def join_clause() -> str:
    """Bind each input to a named channel.

    join assigns inputs positionally by default, and entry 612 measured that
    ordering as not matching the 5.1 layout order, which mislabelled the first
    three channels. Naming every channel removes the ambiguity.
    """
    inputs = ''.join(f'[a{i}]' for i in range(len(TONES)))
    mapping = '|'.join(f'{i}.0-{name}' for i, (_hz, name) in enumerate(TONES))
    return (f'{inputs}join=inputs={len(TONES)}:channel_layout=5.1:'
            f'map={mapping}[aout]')


def build_sweep_filter(duration: float) -> str:
    """One channel at a time, so a listener can place each in the stereo image.

    Each channel sounds alone for its slot and is silent otherwise, which is
    what makes the downmix auditable without a 5.1 monitoring rig: FL and BL
    must appear on the left, FR and BR on the right, FC in both equally, and
    LFE not at all, because the AC-3 stereo downmix discards it by convention.
    """
    slot = duration / len(TONES)
    parts = []
    for i, (hz, _name) in enumerate(TONES):
        start = i * slot
        # A short fade at each edge keeps the switch from clicking.
        parts.append(
            f'sine=frequency={hz}:duration={duration}:sample_rate=48000,'
            f'volume=enable=\'between(t,{start:.6f},{start + slot:.6f})\':volume=1,'
            f'volume=enable=\'not(between(t,{start:.6f},{start + slot:.6f}))\':volume=0'
            f'[a{i}]')
    return ';'.join(parts) + ';' + join_clause()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--duration', type=float, default=5.0,
                        help='seconds; keep short, this qualifies decode not endurance')
    parser.add_argument('--report', type=Path, default=None)
    parser.add_argument('--sweep', action='store_true',
                        help='sound each channel alone in turn instead of all at once')
    parser.add_argument('--codec', choices=('ac3', 'dts'), default='ac3',
                        help='DTS is passthrough only; the helper has no DTS decoder')
    args = parser.parse_args()
    duration = args.duration
    dvd.require(0.5 <= duration <= 600, 'invalid duration')
    output = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    commands: list[list[str]] = []

    video_rate = DTS_VIDEO_RATE if args.codec == 'dts' else VIDEO_RATE

    def run(command: list[str]) -> None:
        commands.append(command)
        dvd.run_clean(command)

    with tempfile.TemporaryDirectory(prefix='dvd_ac3_', dir=output.parent) as directory:
        temp = Path(directory)
        original, patched, program = (temp / n for n in ('original.m2v', 'patched.m2v', 'program.mpg'))
        print(f'Encoding {duration}s of 480i TFF video with AC-3 5.1', flush=True)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-xerror', '-threads', '1',
             '-f', 'lavfi', '-i', f'testsrc2=size=720x480:rate=60000/1001:duration={duration}',
             '-filter_complex',
             build_sweep_filter(duration) if args.sweep else build_audio_filter(duration),
             '-map', '0:v:0', '-map', '[aout]',
             '-vf', 'tinterlace=mode=interleave_top,setsar=32/27',
             '-c:v', 'mpeg2video', '-pix_fmt', 'yuv420p', '-threads', '1',
             '-flags', '+bitexact', '-g', '1', '-bf', '0',
             '-b:v', str(video_rate), '-minrate:v', str(video_rate),
             '-maxrate:v', str(video_rate), '-bufsize:v', str(dvd.BUFFER_BITS),
             '-qmin', '1', '-qmax', '31', '-sc_threshold', '1000000000',
             *(('-c:a', 'dca', '-strict', '-2', '-ar', '48000', '-ac', '6',
                '-b:a', str(DTS_RATE))
               if args.codec == 'dts' else
               ('-c:a', 'ac3', '-ar', '48000', '-ac', '6', '-b:a', str(AUDIO_RATE))),
             '-muxrate', str(MUX_RATE), '-packetsize', '2048', '-f', 'vob', str(program)])
        finalize_program_stream(program)
        data, audio, ids = compatibility.demux_program_stream(program.read_bytes())
        dvd.require(not audio, 'AC-3 must arrive on private stream 1, not as MPEG audio')
        original.write_bytes(data)
        frames = sum(code == 0 for _, code in analyzer.start_codes(data))
        patched.write_bytes(interlaced.patch_interlaced_signalling(data, True, frames))
        del data
        replace_video_payloads(program, patched)
        print(f'Checking {frames} pictures', flush=True)
        structure = dvd.check_structure(patched, frames)['classification']
        pixels = dvd.decoded_digest('ffmpeg', original, frames, temp)
        dvd.require(pixels == dvd.decoded_digest('ffmpeg', patched, frames, temp),
                    'signalling patch changed decoded planes')
        (temp / 'decode.yuv').unlink()

        # Independent reference decode of the muxed program, downmixed to stereo.
        elementary = temp / 'audio.ac3'
        substream = DTS_SUBSTREAM if args.codec == 'dts' else AC3_SUBSTREAM
        elementary.write_bytes(extract_ac3(program.read_bytes(), substream))
        dvd.require(elementary.stat().st_size > 0,
                    f'no {args.codec} substream payload found')
        reference = temp / 'reference.s16le'
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror',
             '-f', args.codec, '-i', str(elementary),
             '-ac', '2', '-ar', '48000', '-f', 's16le', str(reference)])
        dvd.require(reference.stat().st_size % 4 == 0, 'reference PCM is not stereo s16le')
        reference_frames = reference.stat().st_size // 4
        dvd.require(abs(reference_frames / 48000 - duration) < 0.2,
                    f'reference PCM covers {reference_frames / 48000:.3f}s, expected {duration}s')
        probe = json.loads(subprocess.check_output(
            ['ffprobe', '-hide_banner', '-loglevel', 'error', '-show_streams',
             '-select_streams', 'a:0', '-of', 'json', str(program)], text=True))['streams'][0]
        dvd.require(probe['codec_name'] == args.codec and int(probe['sample_rate']) == 48000
                    and int(probe['channels']) == 6,
                    f'unexpected audio stream: {probe.get("codec_name")}')
        packs = verify_packs(program, stream_ids=(0xBB, 0xBE, 0xBF, 0xE0, 0xBD))
        report = {'output': output.name, 'bytes': program.stat().st_size,
                  'sha256': digest(program), 'frame_count': frames,
                  'frame_rate': '30000/1001', 'field_order': 'TFF',
                  'classification': structure, 'duration_seconds': float(frames * dvd.PERIOD),
                  'video_sha256': digest(patched), 'decoded_yuv420p_sha256': pixels,
                  'audio_codec': probe['codec_name'], 'audio_channels': int(probe['channels']),
                  'audio_sample_rate': int(probe['sample_rate']),
                  'audio_bits_per_second': DTS_RATE if args.codec == 'dts' else AUDIO_RATE,
                  'video_bits_per_second': video_rate,
                  'audio_private_substream': substream,
                  'channel_tones_hz': {name: hz for hz, name in TONES},
                  'channel_mode': 'sweep' if args.sweep else 'simultaneous',
                  'sweep_slot_seconds': (duration / len(TONES)) if args.sweep else None,
                  'sweep_order': [name for _hz, name in TONES] if args.sweep else None,
                  'expected_downmix_placement': {
                      'FL': 'left', 'FR': 'right', 'FC': 'both equally',
                      'LFE': 'silent; the AC-3 stereo downmix discards LFE',
                      'BL': 'left', 'BR': 'right'} if args.sweep else None,
                  'audio_elementary_sha256': digest(elementary),
                  'audio_elementary_bytes': elementary.stat().st_size,
                  'reference_pcm_sha256': digest(reference),
                  'reference_pcm_frames': reference_frames,
                  'program_end_seen': ids['program_end_seen'],
                  'pack_check': packs,
                  'ffmpeg_version': subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0],
                  'commands': [[a.replace(str(temp), '<temporary>') for a in c] for c in commands],
                  'scope': 'AC-3 decode fixture only; no passthrough, navigation or DVD conformance claim.'}
        program.replace(output)
        (temp / 'reference.s16le').replace(output.with_suffix('.reference.s16le'))
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
