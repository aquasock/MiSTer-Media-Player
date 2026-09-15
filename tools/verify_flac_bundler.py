#!/usr/bin/env python3
"""Check mixed-format album creation and lossless CD PCM preservation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import wave

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
root = Path(__file__).resolve().parents[1]


def run(command):
    return subprocess.run(command, check=True, capture_output=True)


with tempfile.TemporaryDirectory(dir=args.output) as temp:
    folder = Path(temp) / 'Mixed Album – Árvíz'
    folder.mkdir()
    shutil.copy2(root / 'tools/bundle_flac_album.py', folder)
    source = Path(temp) / 'source.wav'
    cd_pcm = b''.join(struct.pack('<hh', i % 10000 - 5000, 5000 - i % 10000)
                      for i in range(44100))
    with wave.open(str(source), 'wb') as wav:
        wav.setparams((2, 2, 44100, 0, 'NONE', 'not compressed'))
        wav.writeframes(cd_pcm)
    run(['flac', '--silent', '-o', str(folder / '01 - CD.flac'), str(source)])
    shutil.copy2(source, folder / '02 - CD.wav')
    # Exercise stereo resampling, bit-depth conversion, mono upmix and lossy decode.
    cases = [
        ('03 - High resolution.wav', ['-ar', '48000', '-c:a', 'pcm_s24le']),
        ('04 - Lossy.mp3', ['-c:a', 'libmp3lame', '-b:a', '192k']),
        ('05 - Mono.m4a', ['-ac', '1', '-c:a', 'aac', '-b:a', '128k']),
        ('06 - Unaligned.wav', ['-t', '0.123', '-c:a', 'pcm_s16le']),
        ('07 - High resolution.flac', ['-ar', '96000', '-sample_fmt', 's32', '-c:a', 'flac']),
    ]
    for name, options in cases:
        run(['ffmpeg', '-v', 'error', '-i', str(source), *options, str(folder / name)])
    sources = sorted(p for p in folder.iterdir() if p.suffix != '.py')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    result = run(['python3', str(folder / 'bundle_flac_album.py')])
    (args.output / 'run.log').write_bytes(result.stdout + result.stderr)
    album = folder / (folder.name + '.flac')
    actual = run(['flac', '-d', '-c', '--silent', '--force-raw-format',
                  '--endian=little', '--sign=signed', str(album)]).stdout
    assert actual[:len(cd_pcm) * 2] == cd_pcm * 2, 'CD FLAC/WAV samples changed'
    cue = run(['metaflac', '--export-cuesheet-to=-', str(album)]).stdout.decode()
    import importlib.util
    spec = importlib.util.spec_from_file_location('splitter', root / 'tools/split_flac_album.py')
    splitter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(splitter)
    starts = splitter.track_starts(cue)
    assert len(starts) == len(sources)
    end = 0
    for (_, start), track in zip(starts, sources):
        assert start == end
        # Match length against a separate conversion without dither; dithering
        # must not affect timing or sample count.
        decoded = run(['ffmpeg', '-v', 'error', '-i', str(track), '-map', '0:a:0',
                       '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le',
                       '-f', 's16le', 'pipe:1']).stdout
        samples = len(decoded) // 4
        padding = (-samples) % 588
        end = start + samples + padding
        assert actual[(start + samples) * 4:end * 4] == b'\0' * (padding * 4)
    assert len(actual) == end * 4
    metadata = run(['metaflac', '--list', str(album)]).stdout.decode()
    assert 'is CD: true' in metadata and 'type: 3 (SEEKTABLE)' in metadata
    for name, digest in hashes.items():
        assert hashlib.sha256((folder / name).read_bytes()).hexdigest() == digest
    refused = subprocess.run(['python3', str(folder / 'bundle_flac_album.py')], capture_output=True)
    assert refused.returncode != 0 and b'Output already exists' in refused.stderr
    (args.output / 'summary.json').write_text(json.dumps({
        'tracks': len(starts), 'CD_FLAC_WAV_sample_exact': True,
        'mixed_formats_and_rates': True, 'CD_padding_exact': True,
        'sources_unchanged': True, 'overwrite_refused': True,
    }, indent=2) + '\n')
    print('PASS: mixed formats/rates, exact CD PCM, cue boundaries, padding, source preservation and overwrite refusal')
