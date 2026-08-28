"""Verify a seed-only source difference and retained full qualification evidence."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, subprocess

base = Path('/home/vash/mister-builds/entry681')
prior = Path('/home/vash/mister-builds/entry675')
work = base / 'FPGA'
main = Path('/run/media/vash/GIT/MiSTer-Media-Player')
source = '83c138ebd2492e6b81dfcc1f0256cecae2afce79'
old_source = 'e6ca12972e8f2822af465ee549e4ecf8b2dec296'

def output(*args):
    return subprocess.check_output(['git', '-C', str(work), *args])

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

assert output('rev-parse', 'HEAD').decode().strip() == source
assert not output('status', '--porcelain')
changes = output('diff', '--name-only', old_source, source).decode().splitlines()
assert [p for p in changes if not p.startswith('.ai/')] == ['MediaPlayer.qsf'], changes
old_qsf = output('show', old_source + ':MediaPlayer.qsf')
new_qsf = output('show', source + ':MediaPlayer.qsf')
old_assignment = b'set_global_assignment -name SEED 18\n'
new_assignment = b'set_global_assignment -name SEED 20\n'
assert old_qsf.count(old_assignment) == 1
assert new_qsf == old_qsf.replace(old_assignment, new_assignment)

saved = work / '.ai/current_results/entry678_final_gate.json'
assert sha(saved) == sha(prior / 'final_gate.json')
report = json.loads(saved.read_text())
assert report['source_commit'] == old_source and report['qualification_pass']
for mode in ('ideal', 'contended'):
    evidence = prior / mode
    expected = report['native'][mode]
    for name, digest in expected['sha256'].items():
        assert sha(evidence / name) == digest, (mode, name)
    result = base / f'{mode}_terminal_qualification.json'
    subprocess.run(['python3', str(work/'tools/streams/analyze_original_dvd_timing.py'),
                    str(evidence/'timing_fixture.json'), str(evidence/'native.csv'),
                    str(result), '--allow-dvd-opening-terminal-cut', '--require-pass'], check=True)
    assert sha(result) == expected['sha256']['terminal_qualification.json']

paired = main / 'simulation/original_dvd_qualification'
assert (paired/'source.before.sha256').read_bytes() == (paired/'source.after.sha256').read_bytes()
assert sha(paired/'source.before.sha256') == report['paired']['source_fingerprint_sha256']
for case in ('isolated', 'chain'):
    assert sha(paired/(case+'.csv')) == report['paired'][case+'_csv_sha256']
for name, info in report['focused'].items():
    assert info['passed'] and sha(prior/name) == info['sha256']

with (base/'terminal_gate_tests.log').open('w') as log:
    subprocess.run(['python3', 'tools/streams/test_original_dvd_timing.py'], cwd=work,
                   stdout=log, stderr=subprocess.STDOUT, check=True)
report.pop('simulation_and_synthesis_inputs_unchanged', None)
report.update(source_commit=source, previous_qualification_source_commit=old_source,
              created=datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),
              simulation_inputs_unchanged=True, production_rtl_unchanged=True,
              synthesis_configuration_change='Only SEED 18 -> 20 in MediaPlayer.qsf',
              prior_evidence_hashes_reverified=True, terminal_analyzer_reexecuted=True,
              terminal_gate_tests_passed=True, seed=20, hardware_accepted=False)
(base/'final_gate.json').write_text(json.dumps(report, indent=2)+'\n')
print('SEED_ONLY_QUALIFICATION_PASS source='+source)
