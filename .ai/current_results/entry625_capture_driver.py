from ftplib import FTP
from pathlib import Path
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,time,sys,posixpath
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');out=Path('/tmp/entry626-capture');out.mkdir(exist_ok=True)
m={'captured':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'host':'10.10.0.30','candidate':'d466bed','expected_rbf_sha256':'61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce','expected_media_sha256':'unknown-other-agent-fixture','expected_media_bytes':12517393,'user_report':'test 3 deinterlace ran ok; menu NOT laggy this time','mode':None,'files':{},'operations':[]}
def connect():
 f=FTP();f.connect(m['host'],21,timeout=30);f.login('root','1');return f
def retrieve(f,remote,name):
 b=BytesIO();f.retrbinary('RETR '+remote,b.write);data=b.getvalue();p=out/name;p.write_bytes(data)
 m['files'][remote]={'local':str(p),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()};m['operations'].append('RETR '+remote);return data
# 1. helper log first, before anything that could perturb the session
f=connect()
helper=retrieve(f,'/tmp/MediaPlayer_ARM.log','entry626_arm_helper.log')
messages=retrieve(f,'/tmp/messages','messages')
m['syslog_boot_lines']=[l for l in messages.decode(errors='replace').splitlines() if 'syslogd started' in l]
# 2. fresh telemetry screenshot: delete the fixed name, re-request, verify replacement
shot='/media/fat/screenshots/cadence_probe.png'
names=lambda:{posixpath.basename(n.rstrip('/')) for n in f.nlst('/media/fat/screenshots/')}
if 'cadence_probe.png' in names():f.delete(shot);m['operations'].append('DELE '+shot)
assert 'cadence_probe.png' not in names(),'Old screenshot still exists'
f.storbinary('STOR /dev/MiSTer_cmd',BytesIO(b'screenshot cadence_probe.png\n'));m['operations'].append('STOR screenshot command only')
time.sleep(2)
retrieve(f,shot,'entry626_terminal.png');f.quit()
# 3. installed-artifact readbacks
f=connect()
for remote,name in [('/media/fat/MiSTer','MiSTer'),('/media/fat/MediaPlayer.rbf','MediaPlayer.rbf'),('/media/fat/games/MediaPlayer/test_3_deinterlace_bob_weave.mpg','fixture.mpg')]:
 try:retrieve(f,remote,name)
 except Exception as e:m['files'][remote]={'error':repr(e)}
f.quit()
rbf=m['files'].get('/media/fat/MediaPlayer.rbf',{})
med=m['files'].get('/media/fat/games/MediaPlayer/test_3_deinterlace_bob_weave.mpg',{})
m['installed_candidate_is_d466bed']=rbf.get('sha256')==m['expected_rbf_sha256']
m['media_matches_entry602']=med.get('sha256')==m['expected_media_sha256'] and med.get('bytes')==m['expected_media_bytes']
m['unchanged_target_state']='No reload, reboot, launch, media/config edit or deployment; only the fixed screenshot was replaced.'
(out/'entry626_capture.json').write_text(json.dumps(m,indent=2)+'\n')
sys.path.insert(0,str(root/'tools/streams'))
from decode_hardware_cadence import decode
r=decode(out/'entry626_terminal.png');(out/'entry626_terminal.json').write_text(json.dumps(r,indent=2,sort_keys=True)+'\n')
keys=['schema_version','checksum','accepted_bytes','reference_pictures','display_pictures','display_swaps','error_flags','sequence_end_seen','presentation_complete','session_quiet','snapshot_reason','cadence_seconds','delivered_fps','deadline_gap_count','gap_outlier_count']
print(json.dumps({'capture':{k:m[k] for k in ('installed_candidate_is_d466bed','media_matches_entry602','syslog_boot_lines')},'telemetry':{k:r.get(k) for k in keys}},indent=2))
lines=helper.decode(errors='replace').splitlines();print('--- helper head/tail ---');print('\n'.join(lines[:8]+['...']+lines[-8:]))
