"""Collect observations only; this does not authorize a terminal-cut exception."""
from pathlib import Path
import csv,hashlib,json,re,subprocess
from datetime import datetime
from zoneinfo import ZoneInfo
base=Path('/home/vash/mister-builds/entry675')
main=Path('/run/media/vash/GIT/MiSTer-Media-Player')
source='e876bf34e16cb8cd9f1c21eef8137a15739089c8'
chain_sha='ef836c310cb24f9a7ff15be6368c4661e576f20348ef5559889be22057155f92'
isolated_sha='526be36d62dc666181f0fe5445470d12f10b53331258825912493178173ced76'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report={'source_commit':source,'production_commit':'e9041b2',
        'created':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),
        'terminal_exception_approved':False,'exception_applied':False,
        'qualification_pass':False,'fpga_build_started':False,'hardware_accepted':False,'native':{}}
for checkout in (base/'source',main):
    subprocess.run(['git','-C',str(checkout),'diff','--exit-code','HEAD'],check=True,capture_output=True)
    changes=subprocess.check_output(['git','-C',str(checkout),'diff','--name-only',source,'HEAD'],text=True).splitlines()
    assert all(p.startswith('.ai/') for p in changes),changes
for case in ('ideal','contended'):
    p=base/case
    gate=subprocess.run(['python3',str(base/'source/tools/streams/analyze_original_dvd_timing.py'),str(p/'timing_fixture.json'),str(p/'native.csv'),str(p/'analysis.json'),'--require-pass'],capture_output=True,text=True)
    d=json.loads((p/'analysis.json').read_text())
    interior=[g for g in d['cadence_mismatches'] if not(g['previous_coded']==285 and g['coded']==288 and g['previous_authored_fields']==3 and g['extra_fields']==1)]
    other_checks=(d['complete_decode_trace'] and all(d[k]==289 for k in ('starts','ready','publications','unique_publications'))
        and d['display_order']==list(range(289)) and d['publication_descriptor_coverage_complete']
        and not d['publication_descriptor_mismatches'] and not d['publication_pts_mismatches']
        and not any(d['cache_flags_seen'].values()) and d['final_authored_hold_complete'])
    log=(p/'run.log').read_text()
    actual=re.search(r'NATIVE_RESULT publications=(\d+) bank_swaps=(\d+) decoded=(\d+) pts_records=(\d+) associated=(\d+) fields=(\d+) cache_error=(\d+) overlap=(\d+)',log)
    assert actual and '$finish' in log
    names=('publications','bank_swaps','decoded','pts_records','associated','fields','cache_error','overlap')
    counters=dict(zip(names,map(int,actual.groups())))
    assert counters['associated']==25 and counters['bank_swaps']==288
    assert sha(p/'pixels.csv')==chain_sha
    report['native'][case]={'strict_gate_exit':gate.returncode,'strict_timing_pass':d['simulation_timing_pass'],
        'all_other_trace_checks_passed':bool(other_checks),'interior_cadence_mismatches':interior,
        'raw_cadence_mismatches':d['cadence_mismatches'],'actual_counters':counters,
        'sha256':{n:sha(p/n) for n in ('native.csv','pixels.csv','run.log','analysis.json','timing_fixture.json')}}
paired=main/'simulation/original_dvd_qualification'
assert (paired/'source.before.sha256').read_bytes()==(paired/'source.after.sha256').read_bytes()
assert 'ORIGINAL_DVD_NUMERICAL_PASS isolated_one_LSB=1 measured_chain_bound=1 unchanged_source=1' in (base/'paired.log').read_text()
assert sha(paired/'isolated.csv')==isolated_sha and sha(paired/'chain.csv')==chain_sha
report['paired']={'passed':True,'unchanged_source':True,'samples_per_case':149817600,
    'source_fingerprint_sha256':sha(paired/'source.before.sha256'),'isolated_csv_sha256':isolated_sha,'chain_csv_sha256':chain_sha,
    'isolated_max_error':1,'chain_max_error':5,'above_old_fixed_two':102,'measured_bound_violations':0}
report['terminal_source_proof_sha256']=sha(base/'terminal_source_check.json')
report['focused']={n:sha(base/n) for n in ('film_v2.log','focused.log','mixed.log')}
(base/'qualification_observations.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'source':source,'cases':{k:{a:v[a] for a in ('strict_timing_pass','all_other_trace_checks_passed','interior_cadence_mismatches','actual_counters')} for k,v in report['native'].items()},'paired':report['paired'],'exception_applied':False},indent=2))
