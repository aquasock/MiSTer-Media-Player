"""Record the final fixed-source qualification; run only after jobs exit."""
from pathlib import Path
import csv, hashlib, json, re, subprocess
from datetime import datetime
from zoneinfo import ZoneInfo

base = Path('/home/vash/mister-builds/entry675')
main = Path('/run/media/vash/GIT/MiSTer-Media-Player')
source = 'e6ca12972e8f2822af465ee549e4ecf8b2dec296'
simulation_source = 'e876bf34e16cb8cd9f1c21eef8137a15739089c8'
chain_sha = 'ef836c310cb24f9a7ff15be6368c4661e576f20348ef5559889be22057155f92'
isolated_sha = '526be36d62dc666181f0fe5445470d12f10b53331258825912493178173ced76'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def out(args): return subprocess.check_output(args, text=True).strip()
report = dict(source_commit=source, simulation_source_commit=simulation_source, terminal_exception_approved=True, production_commit='e9041b2', qualification_pass=False,
              hardware_accepted=False, created=datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'))
for checkout in (base/'source', main):
    subprocess.run(['git', '-C', str(checkout), 'diff', '--exit-code', 'HEAD'], check=True, capture_output=True)
    changes=out(['git','-C',str(checkout),'diff','--name-only',source,'HEAD']).splitlines()
    assert all(p.startswith('.ai/') for p in changes), changes
allowed_changes={'tools/streams/analyze_original_dvd_timing.py','tools/streams/test_original_dvd_timing.py','docs/testing_original_dvd_opening.md'}
changes=out(['git','-C',str(main),'diff','--name-only',simulation_source,source]).splitlines()
assert all(p.startswith('.ai/') or p in allowed_changes for p in changes),changes
report['simulation_and_synthesis_inputs_unchanged']=True
report['native'] = {}
for case in ('ideal','contended'):
    work=base/case
    subprocess.run(['python3',str(base/'source/tools/streams/analyze_original_dvd_timing.py'),
                    str(work/'timing_fixture.json'),str(work/'native.csv'),str(work/'terminal_qualification.json'),'--allow-dvd-opening-terminal-cut','--require-pass'],check=True)
    d=json.loads((work/'terminal_qualification.json').read_text())
    assert d['qualification_pass'] and d['terminal_cut_exception']['applied']
    assert not d['simulation_timing_pass']
    assert all(d[k]==289 for k in ('expected_pictures','starts','ready','publications','unique_publications'))
    assert d['authored_total_fields']==722 and d['final_authored_hold_complete']
    assert len(d['pts_alignment'])==25
    assert sha(work/'pixels.csv')==chain_sha
    log=(work/'run.log').read_text()
    assert 'CHAIN_ERROR_BOUND_RESULT enabled=1 mismatches=0 oracle_references=0' in log
    assert 'ORIGINAL_PIXEL_RESULT coded=289 I=12960000 P_B=136857600 I_mismatch=0 P_B_mismatch=102 max_I=1 max_P_B=5' in log
    assert '$finish' in log and not re.search(r'%Error|Assertion failed',log)
    native_match=re.search(r'NATIVE_RESULT publications=289 bank_swaps=288 decoded=289 pts_records=25 associated=25 fields=(\d+) cache_error=0 overlap=0',log)
    assert native_match, log[-2500:]
    report['native'][case]={k:d[k] for k in ('qualification_pass','terminal_cut_exception','simulation_timing_pass','complete_decode_trace','starts','ready','publications','unique_publications','authored_total_fields','publication_descriptor_mismatches','publication_pts_mismatches','cadence_mismatches','cache_flags_seen','final_authored_hold_complete')}
    report['native'][case]['associated_pts']=25
    report['native'][case]['bank_swaps']=288
    report['native'][case]['terminal_field_counter']=int(native_match[1])
    report['native'][case]['sha256']={p.name:sha(p) for p in (work/'pixels.csv',work/'native.csv',work/'run.log',work/'analysis.json',work/'terminal_qualification.json',work/'timing_fixture.json')}
paired=main/'simulation/original_dvd_qualification'
assert (paired/'source.before.sha256').read_bytes()==(paired/'source.after.sha256').read_bytes()
assert 'ORIGINAL_DVD_NUMERICAL_PASS isolated_one_LSB=1 measured_chain_bound=1 unchanged_source=1' in (base/'paired.log').read_text()
for case,expected in [('isolated',isolated_sha),('chain',chain_sha)]:
    assert sha(paired/(case+'.csv'))==expected
    log=(paired/(case+'.log')).read_text()
    assert '$finish' in log and not re.search(r'%Error|Assertion failed',log)
report['paired']={'passed':True,'source_fingerprint_sha256':sha(paired/'source.before.sha256'),'unchanged_source':True,
                  'isolated_csv_sha256':isolated_sha,'chain_csv_sha256':chain_sha,
                  'samples_per_case':149817600,'isolated_max_error':1,'chain_max_error':5,
                  'chain_above_old_fixed_two':102,'measured_chain_bound_violations':0}
report['focused']={}
for name in ('film_v2.log','focused.log','mixed.log'):
    p=base/name;log=p.read_text()
    assert '$finish' in log and not re.search(r'%Error|Assertion failed|FATAL:',log)
    report['focused'][name]={'passed':True,'sha256':sha(p)}
report['qualification_pass']=True
(base/'final_gate.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL_QUALIFICATION_PASS source='+source)
