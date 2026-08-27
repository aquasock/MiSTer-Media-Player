from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import csv, gzip, hashlib, json, shutil

base=Path('/home/vash/mister-builds/entry604')
dest=base/'reports-export'
dest.mkdir(exist_ok=True)
build=json.loads((base/'FPGA/entry604-build.json').read_text())
comparison=json.loads((base/'warning-comparison.json').read_text())
assert build['compile_success'] and build['timing_positive'] and build['errors']==0
assert not comparison['added'], 'New warnings require review before export'
review={'source_commit':build['source_commit'],'baseline_source':comparison['baseline_source'],
        'reviewed':True,'blocking_new_warnings':False,'warnings':build['warnings'],
        'normalized_added':comparison['added'],'normalized_removed':comparison['removed'],
        'new_ignored_timing_filters':build['new_ignored_timing_filters'],
        'timing_positive':build['timing_positive'],
        'review':'No added normalized warnings or ignored timing filters relative to accepted f615ce0; all reported timing categories have positive slack and every TNS is zero. This is a build/timing review, not hardware or full A/V qualification.'}
(base/'warning-review.json').write_text(json.dumps(review,indent=2)+'\n')
completed={p.stem:json.loads(p.read_text())['exit_code'] for p in sorted(base.glob('*-result.json'))}
assert all(v==0 for v in completed.values())
opening=json.loads((base/'opening_result.json').read_text())
assert opening['exit_code']==0 and opening['completed']==opening['presented']==100 and not opening['missed_slots']
events=list(csv.DictReader((base/'opening_events.csv').open()))
steady=[int(e['interval']) for e in events if e['event']=='present' and int(e['picture'])>2]
status={'source_commit':build['source_commit'],'recorded':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),
        'user_scope':'User explicitly canceled remaining simulations and requested only RBF build/timing checks; user will deploy.',
        'build_and_reported_timing_passed':True,'hardware_accepted':False,'deployed_by_agent':False,
        'completed_tests_before_cancellation':completed,
        'native_suite':'Canceled during BFF cache fingerprint run; earlier PASS lines preserved, full suite not qualified.',
        'opening_100_before_cancellation':{'passed':True,'pictures':100,'missed_slots':0,'steady_interval_min':min(steady),'steady_interval_max':max(steady)},
        'canceled_not_qualified':['long_1000_av','long_pressure_1000_av','ceiling_weave_449','ceiling_bob_449','remaining_native_suite'],
        'simulation_scope':'Actual compressed opening video and helper timestamp positions; ideal source and modeled DDR/ticks/swap phase. Physical PCM/HPS/scaler/CDC excluded. Full A/V soak remains untested.',
        'backup_location':'/home/vash/mister-builds/entry604-backup',
        'installation':'No RBF/Main/media deployment or reload performed. Prior f615ce0 pair was backed up before user changed scope.'}
(base/'build-only-status.json').write_text(json.dumps(status,indent=2)+'\n')
names=['source.json','fixtures.json','opening_result.json','opening_events.csv','opening_metrics.csv','opening.log',
       'negative_controls.json','old_scheduler_negative.log','unsafe_timestamp_gate_negative.log','native.log',
       'reconstruction.log','shared_pb.log','shared_pb_result.json','warning-comparison.json','warning-review.json',
       'build-only-status.json','integrated_compile_command.json','integrated_compile.log','tb_entry604_i_pts.sv',
       'FPGA/entry604-build.json','FPGA/entry604-build-run.json','FPGA/entry604-quartus.log',
       'FPGA/output_files/MediaPlayer.sta.summary','FPGA/output_files/MediaPlayer.fit.summary']
names += [p.name for p in sorted(base.glob('*-result.json'))]
names += [p.name for p in sorted(base.glob('tb_h262_*.log'))]
manifest={}
for name in names:
    path=base/name;data=path.read_bytes();outname='entry604_'+path.name
    if name.startswith('FPGA/entry604-'):outname='entry604_'+path.name.removeprefix('entry604-')
    payload=data
    if name.endswith('.log'):
        outname+='.gz';payload=gzip.compress(data,mtime=0)
    (dest/outname).write_bytes(payload)
    manifest[outname]={'source_path':str(path),'original_bytes':len(data),'original_sha256':hashlib.sha256(data).hexdigest(),
                       'stored_bytes':len(payload),'stored_sha256':hashlib.sha256(payload).hexdigest()}
(dest/'entry604_export_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'files':len(manifest),'build':{k:build[k] for k in ('source_commit','rbf_sha256','rbf_bytes','worst_slack_ns')},'completed_tests':completed,'opening_steady_intervals':sorted(set(steady))},indent=2))
