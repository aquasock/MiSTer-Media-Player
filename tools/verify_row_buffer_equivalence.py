#!/usr/bin/env python3
"""Compare deterministic parser results against a pre-conversion Git revision.

Both variants use current testbenches and identical generated fixtures. This
checks syntax/transport behavior; use verify_decoder_timing.py and
replay_mpg_seek.py separately for reconstruction and A/V seek recovery.
"""
import argparse
import concurrent.futures
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--baseline', default='1349c82')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=True)
baseline = out/'baseline'
baseline.mkdir(exist_ok=True)
sha = subprocess.check_output(['git', 'rev-parse', a.baseline], cwd=ROOT, text=True).strip()
archive = subprocess.check_output(['git', 'archive', sha, 'rtl', 'files.qip'], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
    tf.extractall(baseline, filter='data')

cases = [
    ('tb_h262_b_intra_macroblocks', 'tb_h262_b_intra_macroblocks', 'test_b_intra_macroblocks'),
    ('tb_h262_p_intra_macroblocks', 'tb_h262_p_intra_macroblocks', 'test_p_intra_macroblocks'),
    ('tb_h262_b_residual_streaming', 'tb_h262_b_residual_streaming', 'test_b_residual_streaming'),
    ('tb_h262_parser_windows', 'tb_h262_parser_windows', 'test_pb_parser_window'),
    ('tb_h262_b_transport_abort', 'tb_h262_dense_transport_recovery', 'test_b_bidirectional'),
]
# The historical runner also paired dense_full_b_sequence with bidirectional
# and dense_publication_order with consecutive_chain. Those fixtures do not
# match the benches' hard-coded picture/count assertions and fail unchanged
# baseline RTL. Do not count matching failures as equivalence. Current full
# reconstruction and publication checks live in verify_decoder_timing.py.

def run_case(case):
    top, bench, fixture = case
    work = out/top
    work.mkdir(exist_ok=True)
    stream = work/(fixture+'.m2v')
    generator = ROOT/f'tools/streams/generate_{fixture}.py'
    # This older generator writes beside __file__ and ignores --output. Run a
    # local copy, retaining their helper import path, to isolate each case.
    if fixture == 'test_b_bidirectional':
        local_generator = work/generator.name
        local_generator.write_text(generator.read_text())
        generator = local_generator
    env = os.environ.copy()
    env['PYTHONPATH'] = str(ROOT/'tools/streams') + os.pathsep + env.get('PYTHONPATH', '')
    with (work/'generate.log').open('w') as log:
        subprocess.run(['python3', str(generator),
                        '--output', str(stream)], cwd=ROOT, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=120, env=env)
    data = stream.read_bytes()
    hexfile = work/'stream.hex'
    hexfile.write_text(data.hex('\n')+'\n')
    # One legacy bench has a fixed path. Make it local to this case so the
    # regression never races other tests using /tmp/b_intra.hex.
    tb = work/(bench+'.sv')
    tb.write_text((ROOT/f'tools/streams/{bench}.sv').read_text().replace(
        '/tmp/b_intra.hex', str(hexfile)))
    results = {}
    for label, source in [('baseline', baseline), ('converted', ROOT)]:
        sources = re.findall(r'-name SYSTEMVERILOG_FILE (rtl/mpeg2_new/\S+)',
                             (source/'files.qip').read_text())
        binary = work/(label+'.vvp')
        with (work/(label+'-compile.log')).open('w') as log:
            subprocess.run(['iverilog', '-g2012', '-gsupported-assertions',
                            '-I', 'rtl/mpeg2_new', '-s', top, '-o', str(binary),
                            str(tb), *sources], cwd=source, stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=120)
        logpath = work/(label+'.log')
        with logpath.open('w') as log:
            run = subprocess.run(['vvp', str(binary), f'+HEX={hexfile}', f'+LEN={len(data)}'],
                                 cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        text = logpath.read_text()
        if run.returncode or 'FATAL' in text or 'TIMEOUT' in text:
            raise RuntimeError(f'{top} {label} failed: {logpath}')
        results[label] = re.findall(r'^[A-Z0-9_]*RESULT[^\n]*', text, re.M)
        if not results[label]:
            raise RuntimeError(f'{top} {label} produced no RESULT: {logpath}')
    if results['baseline'] != results['converted']:
        raise RuntimeError(f'{top}: parser output changed: {results}')
    print(f'PASS {top}: '+ '; '.join(results['converted']), flush=True)
    return dict(top=top, fixture_sha256=hashlib.sha256(data).hexdigest(),
                results=results['converted'])

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(run_case, cases))
(out/'summary.json').write_text(json.dumps(dict(baseline=sha, cases=results), indent=2)+'\n')
print('PASS all five parser/transport differential cases', flush=True)
