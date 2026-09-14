#!/usr/bin/env python3
"""Compare all IDCT outputs cycle-by-cycle with an accepted Git revision."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='dc1dfc2')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    path = 'rtl/mpeg2_new/mpeg2_h262_idct.sv'
    sha = subprocess.check_output(['git', 'rev-parse', args.baseline], cwd=ROOT, text=True).strip()
    old = subprocess.check_output(['git', 'show', f'{sha}:{path}'], cwd=ROOT, text=True)
    reference = out/'idct_reference.sv'
    reference.write_text(old.replace('module mpeg2_h262_idct\n',
                                     'module mpeg2_h262_idct_reference\n', 1))
    binary = out/'test.vvp'
    with (out/'compile.log').open('w') as log:
        subprocess.run(['iverilog', '-g2012', '-s', 'test_idct_storage', '-o', str(binary),
                        'tools/test_idct_storage.sv', path, str(reference)], cwd=ROOT,
                       stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
    with (out/'run.log').open('w') as log:
        subprocess.run(['vvp', str(binary)], cwd=ROOT, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=120)
    lines = (out/'run.log').read_text().splitlines()
    passed = [line for line in lines if line.startswith('IDCT_STORAGE_PASS ')]
    if len(passed) != 1:
        raise RuntimeError('Missing IDCT completion marker')
    (out/'summary.json').write_text(json.dumps({
        'baseline': sha, 'rtl_sha256': hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),
        'result': passed[0], 'passed': True,
    }, indent=2)+'\n')
    print(passed[0])


if __name__ == '__main__':
    main()
