#!/usr/bin/env python3
"""Direct-seek control/byte-filter regressions and optional actual MPG probes.

The optional input is a bounded MPG prefix (at most 16 MiB). Probe tests do
not decode pictures; use replay_mpg_seek.py for codec and A/V recovery checks.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--input', type=Path)
a = p.parse_args()
dest = a.output.resolve()
dest.mkdir(parents=True, exist_ok=True)
tests = {
    'test_media_seek_search': ['rtl/media_seek_search.sv'],
    'test_media_seek_video_filter': ['rtl/media_seek_video_filter.sv'],
    'test_direct_seek_restart': ['rtl/media_seek_search.sv', 'rtl/media_keyboard_control.sv',
        'rtl/media_session_control.sv', 'rtl/media_playback_control.sv', 'rtl/video_config_cdc.sv'],
}
results = {}
for name, rtl in tests.items():
    binary = dest/name
    subprocess.run(['iverilog', '-g2012', '-s', name, '-o', str(binary),
        f'tools/{name}.sv', *rtl], cwd=ROOT, check=True)
    run = subprocess.run(['vvp', str(binary)], cwd=ROOT, text=True, capture_output=True, timeout=60)
    (dest/(name+'.log')).write_text(run.stdout+run.stderr)
    assert run.returncode == 0 and 'PASS:' in run.stdout, run.stdout+run.stderr
    results[name] = run.stdout
    print(run.stdout, end='', flush=True)
if a.input:
    data = a.input.read_bytes()
    if not 0 < len(data) <= 16777216:
        raise ValueError('Input must be a bounded MPG prefix of at most 16 MiB')
    hexpath = dest/'source.hex'
    hexpath.write_text(''.join(f'{byte:02x}\n' for byte in data))
    obj = dest/'probe-obj'
    with (dest/'probe-compile.log').open('w') as log:
        subprocess.run(['verilator', '--binary', '--timing', '-j', '6', '-Wno-fatal',
            '--top-module', 'test_media_seek_probe', '--Mdir', str(obj),
            'tools/test_media_seek_probe.sv', 'rtl/media_seek_search.sv', 'rtl/media_seek_point.sv',
            'rtl/mpeg2_new/mpeg2_program_stream_ingress.sv',
            'rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv'], cwd=ROOT,
            stdout=log, stderr=subprocess.STDOUT, check=True)
    results['source_sha256'] = hashlib.sha256(data).hexdigest()
    results['probes'] = []
    for target in (5, 10, 20, 300):
        run = subprocess.run([str(obj/'Vtest_media_seek_probe'), f'+HEX={hexpath}',
            f'+LEN={len(data)}', f'+SEARCH_TARGET={target}'], cwd=ROOT,
            text=True, capture_output=True, timeout=60)
        (dest/f'search-{target}.log').write_text(run.stdout+run.stderr)
        match = re.search(r'SEARCH_RESULT target=(\d+) pack=(\d+) sequence=(\d+) origin=(\d+) probes=(\d+) bytes=(\d+)', run.stdout)
        assert run.returncode == 0 and match and 'PASS:' in run.stdout, run.stdout+run.stderr
        case = dict(zip(('target', 'pack', 'sequence', 'origin', 'probes', 'bytes'), map(int, match.groups())))
        assert case['probes'] <= 18
        assert data[case['pack']:case['pack']+4] == b'\x00\x00\x01\xba'
        assert case['sequence'] >= case['pack']
        results['probes'].append(case)
        print(json.dumps(case), flush=True)
results['scope'] = 'Control, byte filters and optional file probes; codec/PCM recovery is tested separately.'
(dest/'summary.json').write_text(json.dumps(results, indent=2)+'\n')
