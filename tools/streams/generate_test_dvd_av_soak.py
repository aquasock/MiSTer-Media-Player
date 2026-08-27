#!/usr/bin/env python3
"""Generate a full-source native-480i/MP2 endurance fixture on the build PC.

Example:
  python3 tools/streams/generate_test_dvd_av_soak.py \
    --source /path/to/big_buck_bunny_480p_stereo.avi \
    --output /path/to/bbb_full_480i_tff_av_10080kbps.mpg

Use --duration 4 for a short generator smoke test, never for full-soak claims.
The source is converted to 59.94 fields and woven into supported TFF all-I
frame-DCT pictures. No interlaced P/B, field DCT, AC-3 or DVD navigation is
qualified. This is an implementation test, not a DVD conformance certificate.
The 10,080,000 bit/s mux and 1,835,008-bit VBV targets follow FFmpeg's DVD
preset: https://ffmpeg.org/ffmpeg-all.html#target-1 . Video uses 9.6 Mbps to
leave room for 192 kbps audio and packet overhead. Large artifacts stay local.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import mmap
import subprocess
import tempfile
import shutil
from pathlib import Path

import analyze_h262_compatibility as analyzer
import check_media_compatibility as compatibility
import generate_test_dvd_ceiling as dvd
import generate_test_interlaced_i_frames as interlaced
from finalize_program_stream import finalize_program_stream

VIDEO_RATE = 9_600_000
AUDIO_RATE = 192_000
MUX_RATE = 10_080_000


def digest(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def probe(path: Path) -> dict:
    result = dvd.run_clean(['ffprobe', '-v', 'error', '-show_streams',
                            '-show_format', '-of', 'json', str(path)])
    return json.loads(result.stdout)


def pack_clock(payload: bytes) -> tuple[int, int]:
    """Return MPEG-2 pack SCR in 27 MHz ticks and program_mux_rate in bit/s."""
    read = analyzer.read_bits
    dvd.require(read(payload, 0, 2) == 1, 'MPEG-2 pack required')
    dvd.require(all(read(payload, bit, 1) for bit in (5, 21, 37, 47, 70, 71)),
                'invalid pack marker')
    base = (read(payload, 2, 3) << 30) | (read(payload, 6, 15) << 15) | read(payload, 22, 15)
    extension = read(payload, 38, 9)
    dvd.require(extension < 300, 'invalid SCR extension')
    return base * 300 + extension, read(payload, 48, 22) * 400


def verify_packs(path: Path) -> dict:
    """Check packet boundaries, mux signalling and SCR-paced pack arrivals.

    Allows two 90-kHz ticks of rounding in adjacent SCR values. This measures
    the declared delivery schedule, not physical FTP/helper throughput or a
    full T-STD buffer simulation.
    """
    count = 0
    first_clock = last_clock = first_offset = last_offset = None
    with path.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        offset = 0
        while offset < len(data):
            dvd.require(data[offset:offset + 3] == b'\x00\x00\x01',
                        f'invalid packet boundary at {offset}')
            sid = data[offset + 3]
            if sid == 0xBA:
                clock, rate = pack_clock(data[offset + 4:offset + 14])
                dvd.require(rate == MUX_RATE, 'wrong program mux rate')
                if last_clock is not None:
                    delta = (clock - last_clock) % ((1 << 33) * 300)
                    dvd.require(0 < delta < 27_000_000, 'nonmonotonic or excessive SCR gap')
                    dvd.require((offset - last_offset) * 8 * 27_000_000
                                <= rate * (delta + 600), 'pack schedule exceeds mux rate')
                else:
                    first_clock, first_offset = clock, offset
                last_clock, last_offset = clock, offset
                count += 1
                offset += 14 + (data[offset + 13] & 7)
            elif sid == 0xB9:
                dvd.require(offset + 4 == len(data), 'bytes after program end')
                break
            else:
                dvd.require(sid in (0xBB, 0xBE, 0xBF, 0xE0, 0xC0),
                            f'unexpected stream id {sid:#x}')
                length = int.from_bytes(data[offset + 4:offset + 6], 'big')
                dvd.require(length > 0, 'unbounded or empty packet')
                offset += 6 + length
                dvd.require(offset <= len(data), 'truncated packet')
        else:
            raise ValueError('missing program end')
    dvd.require(count > 1, 'insufficient pack coverage')
    span = (last_clock - first_clock) % ((1 << 33) * 300)
    return {'packs': count, 'program_mux_rate_bits_per_second': MUX_RATE,
            'scr_span_seconds': span / 27_000_000,
            'scr_paced_average_bits_per_second':
                (last_offset - first_offset) * 8 * 27_000_000 / span,
            'scope': 'Pack-boundary and SCR schedule check; not a full T-STD verifier.'}


def replace_video_payloads(program: Path, video: Path) -> None:
    """Replace equal-length video ES without remuxing timestamps or audio."""
    position = 0
    with program.open('r+b') as stream, video.open('rb') as source, \
            mmap.mmap(stream.fileno(), 0) as data:
        offset = 0
        while offset + 4 <= len(data):
            dvd.require(data[offset:offset + 3] == b'\x00\x00\x01', 'invalid packet boundary')
            sid = data[offset + 3]
            if sid == 0xBA:
                offset += 14 + (data[offset + 13] & 7)
            elif sid == 0xB9:
                break
            else:
                end = offset + 6 + int.from_bytes(data[offset + 4:offset + 6], 'big')
                dvd.require(end <= len(data), 'truncated packet')
                if sid == 0xE0:
                    dvd.require(data[offset + 6] & 0xC0 == 0x80, 'MPEG-2 PES required')
                    begin = offset + 9 + data[offset + 8]
                    dvd.require(begin <= end, 'invalid PES header length')
                    replacement = source.read(end - begin)
                    dvd.require(len(replacement) == end - begin, 'replacement video too short')
                    data[begin:end] = replacement
                    position += len(replacement)
                offset = end
        dvd.require(position > 0 and not source.read(1), 'replacement video too long or absent')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--duration', type=float, help='short smoke test only')
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    manifest = output.with_suffix('.json')
    dvd.require(not output.exists() and not manifest.exists(), 'output already exists')
    info = probe(source)
    source_duration = float(info['format']['duration'])
    duration = args.duration if args.duration is not None else source_duration
    dvd.require(1 <= duration <= source_duration, 'invalid duration')
    dvd.require(any(s['codec_type'] == 'audio' for s in info['streams']), 'source has no audio')
    output.parent.mkdir(parents=True, exist_ok=True)
    commands = []

    def run(command: list[str]) -> None:
        commands.append(command)
        dvd.run_clean(command)

    with tempfile.TemporaryDirectory(prefix='dvd_av_', dir=output.parent) as directory:
        temp = Path(directory)
        original, patched, program = (temp / name for name in ('original.m2v', 'patched.m2v', 'program.mpg'))
        limit = ['-t', str(duration)] if args.duration is not None else []
        print('Encoding full-source A/V' if not limit else 'Encoding smoke-test A/V', flush=True)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-xerror',
             '-threads', '1', '-i', str(source), '-map', '0:v:0', '-map', '0:a:0', *limit,
             '-vf', 'fps=60000/1001,scale=720:480:flags=bicubic,tinterlace=mode=interleave_top,setsar=32/27',
             '-c:v', 'mpeg2video', '-pix_fmt', 'yuv420p', '-threads', '1',
             '-flags', '+bitexact', '-g', '1', '-bf', '0',
             '-b:v', str(VIDEO_RATE), '-minrate:v', str(VIDEO_RATE),
             '-maxrate:v', str(VIDEO_RATE), '-bufsize:v', str(dvd.BUFFER_BITS),
             '-qmin', '1', '-qmax', '31', '-sc_threshold', '1000000000',
             '-c:a', 'mp2', '-ar', '48000', '-ac', '2', '-b:a', str(AUDIO_RATE),
             '-muxrate', str(MUX_RATE), '-packetsize', '2048', '-f', 'vob', str(program)])
        finalize_program_stream(program)
        data, audio, _ids = compatibility.demux_program_stream(program.read_bytes())
        original.write_bytes(data)
        audio_digest = hashlib.sha256(audio).hexdigest()
        del audio
        frames = sum(code == 0 for _, code in analyzer.start_codes(data))
        dvd.require(abs(float(frames * dvd.PERIOD) - duration) <= float(dvd.PERIOD),
                    'encoded duration does not cover requested source')
        patched.write_bytes(interlaced.patch_interlaced_signalling(data, True, frames))
        del data
        replace_video_payloads(program, patched)
        print(f'Checking {frames} pictures and CBR buffer', flush=True)
        structure = dvd.check_structure(patched, frames)['classification']
        rate = dvd.verify_rate(patched.read_bytes(), rate=VIDEO_RATE)
        rate.pop('pictures')  # Keep full validation, summarize rather than dumping 18k rows.
        print('Comparing patched/unpatched decoded planes', flush=True)
        pixels = dvd.decoded_digest('ffmpeg', original, frames, temp)
        dvd.require(pixels == dvd.decoded_digest('ffmpeg', patched, frames, temp),
                    'signalling patch changed decoded planes')
        (temp / 'decode.yuv').unlink()
        print('Checking program video, audio and pack schedule', flush=True)
        data = program.read_bytes()
        video, audio, ids = compatibility.demux_program_stream(data)
        del data
        dvd.require(ids['program_end_seen'] and not ids['ignored_stream_ids'], 'unexpected PS structure')
        dvd.require(hashlib.sha256(video).hexdigest() == digest(patched), 'mux changed video bytes')
        del video
        dvd.require(hashlib.sha256(audio).hexdigest() == audio_digest, 'patch changed audio')
        audio_es = temp / 'audio.mp2'
        audio_es.write_bytes(audio)
        del audio
        audio_info = compatibility.probe_audio(audio_es)
        dvd.require(audio_info == {'codec_name': 'mp2', 'sample_rate': 48000, 'channels': 2},
                    f'unexpected audio: {audio_info}')
        pcm = temp / 'audio.s16le'
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror', '-i', str(program),
             '-map', '0:a:0', '-f', 's16le', str(pcm)])
        audio_frames = pcm.stat().st_size // 4
        dvd.require(pcm.stat().st_size % 4 == 0 and abs(audio_frames / 48000 - duration) < 0.1,
                    'audio duration does not cover requested source')
        packs = verify_packs(program)
        report = {'source': str(source), 'source_sha256': digest(source),
                  'source_probe': info, 'source_duration_seconds': source_duration,
                  'full_source': args.duration is None, 'frame_count': frames,
                  'frame_rate': '30000/1001', 'duration_seconds': float(frames * dvd.PERIOD),
                  'field_order': 'TFF', 'classification': structure,
                  'video_sha256': digest(patched), 'video_bytes': patched.stat().st_size,
                  'decoded_yuv420p_sha256': pixels, 'patched_vs_unpatched_planes_equal': True,
                  'audio': audio_info, 'audio_bits_per_second': AUDIO_RATE,
                  'audio_pcm_frames': audio_frames, 'audio_seconds': audio_frames / 48000,
                  'audio_ffmpeg_pcm_sha256': digest(pcm), 'audio_mp2_sha256': digest(audio_es),
                  'video_rate_check': rate, 'pack_check': packs, 'output': output.name,
                  'bytes': program.stat().st_size, 'sha256': digest(program),
                  'ffmpeg_version': subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0],
                  'commands': [[arg.replace(str(temp), '<temporary>') for arg in command] for command in commands],
                  'scope': 'Supported all-I/MP2 implementation soak, not full DVD conformance or hardware acceptance.',
                  'hardware_timer_caution': '32-bit 60 MHz session timer wraps at 71.582788 s; do not interpret long-run aggregate FPS without wrap accounting.'}
        # No artifact is published until every generator check has passed.
        with output.open('xb') as destination, program.open('rb') as stream:
            shutil.copyfileobj(stream, destination)
        with manifest.open('x') as stream:
            json.dump(report, stream, indent=2)
            stream.write('\n')
        print(json.dumps({key: report[key] for key in ('output', 'bytes', 'sha256', 'frame_count', 'duration_seconds')}), flush=True)


if __name__ == '__main__':
    main()
