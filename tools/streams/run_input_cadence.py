#!/usr/bin/env python3
"""Reproduce bounded input-cadence experiments with the real I decode pipeline.

Requires Verilator and a supported 720x480 interlaced all-I elementary stream.
Production startup is the default; capacity and legacy-window overrides are experiments. Host
resume delays are scenarios, not measured hardware traces. Pixel fingerprints
compare scheduling variants; they are not an independent decoder pixel oracle.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--stream', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--pictures', type=int, default=449)
    ap.add_argument('--first-picture', type=int, default=1,
                    help='One-based source picture; excerpts start with fresh decoder/bank state')
    ap.add_argument('--build', type=Path, help='Shared compiled simulator directory')
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--direct', action='store_true')
    ap.add_argument('--phase', type=int, default=194681)
    ap.add_argument('--host-stride', type=int, default=8)
    ap.add_argument('--resume-ms', type=float, default=0)
    ap.add_argument('--hps-bytes', type=int, default=32768)
    ap.add_argument('--clean-bytes', type=int, default=65536)
    ap.add_argument('--legacy-startup', action='store_true', help='Disable production readiness startup for baseline experiments')
    ap.add_argument('--warm-reload', action='store_true', help='Keep the drained HPS FIFO and video phase across repeated sessions')
    ap.add_argument('--startup-windows', type=int, default=0)
    ap.add_argument('--sessions', type=int, default=1)
    ap.add_argument('--busy-period', type=int, default=0)
    ap.add_argument('--busy-length', type=int, default=0)
    ap.add_argument('--compare', type=Path, help='Baseline result.json with matching picture count')
    args = ap.parse_args()
    if args.pictures < 1 or args.first_picture < 1 or args.resume_ms < 0 or args.sessions < 1:
        ap.error('pictures/sessions must be positive and resume-ms nonnegative')
    if args.startup_windows and not args.legacy_startup:
        ap.error('--startup-windows requires --legacy-startup')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    # A failed rerun must not leave a previous success looking current.
    (out / 'result.json').unlink(missing_ok=True)
    runner_signature = sha(Path(__file__))
    data = args.stream.read_bytes()
    starts = [m.start() for m in re.finditer(b'\x00\x00\x01\xb3', data)]
    picture_starts = [m.start() for m in re.finditer(b'\x00\x00\x01\x00', data)]
    first = args.first_picture - 1
    stop = first + args.pictures
    if len(starts) != len(picture_starts) or stop > len(starts):
        ap.error('test stream must repeat a sequence header for every all-I picture')
    for offset in picture_starts:
        if (data[offset + 5] >> 3) & 7 != 1:
            ap.error('test stream must contain only I pictures')
    if stop < len(starts):
        data = data[starts[first]:starts[stop]] + b'\x00\x00\x01\xb7'
    elif first:
        data = data[starts[first]:]
    if not data.endswith(b'\x00\x00\x01\xb7'):
        ap.error('test stream must have terminal sequence_end')
    padding = len(data) % 2
    if padding:
        data += b'\x00'  # Explicit trailing pad for the 16-bit transport model.
    hex_path = out / 'source.hex'
    hex_path.write_text(data.hex(' ').replace(' ', '\n') + '\n')
    build = args.build.resolve() if args.build else out / 'obj'
    binary = build / 'input_cadence'
    sources = [ROOT / 'tools/streams/tb_h262_input_cadence.sv', ROOT / 'rtl/mpeg2_stream_fifo.sv']
    for line in (ROOT / 'files.qip').read_text().splitlines():
        match = re.search(r'SYSTEMVERILOG_FILE\s+(rtl/mpeg2_new/\S+)', line)
        if match:
            sources.append(ROOT / match[1].rstrip(']"'))
    # Included .sv/.svh files must invalidate a cached executable too.
    dependencies = set(sources)
    dependencies.update((ROOT / 'rtl/mpeg2_new').glob('*.sv'))
    dependencies.update((ROOT / 'rtl/mpeg2_new').glob('*.svh'))
    source_hashes = {str(p.relative_to(ROOT)): sha(p) for p in sorted(dependencies)}
    signature = hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest()
    signature_file = build / 'input-source-sha256'
    compile_command = ['verilator', '--binary', '--timing', '-j', str(args.jobs),
                       '-CFLAGS', '-O3', '-Wno-fatal', '-Wno-PINMISSING', '-Wno-WIDTH',
                       '-Wno-UNOPTFLAT', '-I' + str(ROOT / 'rtl/mpeg2_new'),
                       '--top-module', 'tb_h262_input_cadence', '--Mdir', str(build),
                       '-o', 'input_cadence', *map(str, sources)]
    if not binary.exists() or not signature_file.exists() or signature_file.read_text() != signature:
        build.mkdir(parents=True, exist_ok=True)
        with (out / 'build.log').open('w') as log:
            subprocess.run(compile_command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        signature_file.write_text(signature)
    command = [str(binary), f'+HEX={hex_path}', f'+LEN={len(data)}', f'+REPORT={out / "pictures.csv"}',
               f'+PICTURES={args.pictures}', f'+DIRECT={int(args.direct)}', f'+PHASE={args.phase}',
               f'+HOST_STRIDE={args.host_stride}', f'+RESUME_CYCLES={round(args.resume_ms * 60000)}',
               f'+HPS_BYTES={args.hps_bytes}', f'+CLEAN_BYTES={args.clean_bytes}',
               f'+PRODUCTION_STARTUP={int(not args.legacy_startup)}', f'+WARM_RELOAD={int(args.warm_reload)}',
               f'+STARTUP_WINDOWS={args.startup_windows}', f'+SESSIONS={args.sessions}',
               f'+BUSY_PERIOD={args.busy_period}', f'+BUSY_LENGTH={args.busy_length}']
    print('RUN', ' '.join(command), flush=True)
    start = time.monotonic()
    with (out / 'run.log').open('w') as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - start
    text = (out / 'run.log').read_text()
    if result.returncode:
        raise RuntimeError(f'simulation exit {result.returncode}:\n{text[-5000:]}')
    sessions = []
    for line in text.splitlines():
        if line.startswith(('INPUT_PASS ', 'INPUT_COUNTERS ', 'INPUT_DEADLINE ')):
            values = {key: int(value) for key, value in re.findall(r'(\w+)=(\d+)', line)}
            index = values['session'] - 1
            while len(sessions) <= index:
                sessions.append({'deadlines': [], 'pixel_fingerprints': [], 'gaps': [], 'missed_windows': []})
            if line.startswith('INPUT_PASS '):
                sessions[index]['summary'] = values
            elif line.startswith('INPUT_COUNTERS '):
                sessions[index]['counters'] = values
            else:
                sessions[index]['deadlines'].append(values)
    assert text.count('INPUT_SESSION_PASS ') == args.sessions
    session = -1
    with (out / 'pictures.csv').open() as stream:
        for row in csv.DictReader(stream):
            if row['event'] == 'session':
                session = int(row['picture']) - 1
            elif row['event'] == 'visible':
                sessions[session]['visible_start_cycle'] = int(row['cycle'])
            elif row['event'] == 'pixels':
                sessions[session]['pixel_fingerprints'].append(row['detail'])
            elif row['event'] == 'present':
                if int(row['picture']) == 2:
                    sessions[session]['startup_interval_cycles'] = int(row['interval'])
                if int(row['picture']) > 2 and int(row['interval']) > 3003000:
                    sessions[session]['gaps'].append({'picture': int(row['picture']), 'cycles': int(row['interval'])})
            elif row['event'] == 'empty_window':
                sessions[session]['missed_windows'].append({
                    'picture': int(row['picture']), 'cycle': int(row['cycle']),
                    'input_wait': int(row['interval']), 'critical_wait': int(row['bank']),
                    'transform_overlap': int(row['detail'])})
    for session in sessions:
        if not args.legacy_startup:
            assert session['visible_start_cycle'] >= session['summary']['first']
            session['visible_span_cycles'] = session['summary']['last'] - session['visible_start_cycle'] if args.pictures > 1 else 0
        assert len(session['pixel_fingerprints']) == args.pictures
        assert session['summary']['gaps'] == len(session['gaps'])
        assert session['pixel_fingerprints'] == sessions[0]['pixel_fingerprints']
    if args.compare:
        baseline = json.loads(args.compare.read_text())
        assert baseline['input_sha256'] == hashlib.sha256(data).hexdigest()
        for session in sessions:
            assert session['pixel_fingerprints'] == baseline['sessions'][0]['pixel_fingerprints']
    report = {
        'checkout_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'checkout_status': subprocess.check_output(['git', 'status', '--short'], cwd=ROOT, text=True).splitlines(),
        'source_hashes': source_hashes, 'source_signature': signature,
        'runner_sha256': runner_signature,
        'input_original_sha256': sha(args.stream), 'input_sha256': hashlib.sha256(data).hexdigest(),
        'input_bytes': len(data), 'trailing_padding_bytes': padding,
        'source_picture_range': [args.first_picture, stop],
        'parameters': {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()},
        'compile_command': compile_command, 'run_command': command, 'exit_code': result.returncode,
        'runtime_seconds': elapsed, 'sessions': sessions,
        'comparison_passed': bool(args.compare),
        'limits': 'Behavioral FIFO flags/pointer visibility; synthetic host resume pauses; ideal or periodic modeled DDR. Production startup with synthetic full-pair windows, behavioral video clock and drained-FIFO warm reload. No physical HPS/scaler, HDMI pixel raster, partial-transfer abort or independent pixel oracle. Legacy/capacity overrides are experiments. Profiler first_present remains first-reference time, not visibility.',
        'artifacts_sha256': {name: sha(out / name) for name in ('run.log', 'pictures.csv')},
    }
    (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'runtime_seconds': elapsed, 'sessions': [{k: v for k, v in s.items() if k != 'pixel_fingerprints'} for s in sessions]}, indent=2))


if __name__ == '__main__':
    main()
