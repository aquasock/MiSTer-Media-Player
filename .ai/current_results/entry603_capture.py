from ftplib import FTP
from pathlib import Path
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,time,sys,posixpath
root=Path('/home/vash/MiSTer-Media-Player');out=Path('/tmp/entry603-capture');out.mkdir(exist_ok=True)
m={'captured':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'host':'10.10.0.30','user_report':'Both Bob and Weave stop near the beginning; initial audio is audible and video looks good; menu remains responsive during freeze. Current capture mode unspecified.','files':{},'operations':[]}
def connect():
 f=FTP();f.connect(m['host'],21,timeout=20);f.login('root','1');return f
def retrieve(f,remote,name):
 b=BytesIO();f.retrbinary('RETR '+remote,b.write);data=b.getvalue();p=out/name;p.write_bytes(data)
 m['files'][remote]={'local':str(p),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()};m['operations'].append('RETR '+remote);return data
f=connect()
helper=retrieve(f,'/tmp/MediaPlayer_ARM.log','entry603_current_arm_helper.log')
messages=retrieve(f,'/tmp/messages','messages')
m['syslog_boot_lines']=[l for l in messages.decode(errors='replace').splitlines() if 'syslogd started' in l]
shot='/media/fat/screenshots/cadence_probe.png'
names=lambda:{posixpath.basename(n.rstrip('/')) for n in f.nlst('/media/fat/screenshots/')}
if 'cadence_probe.png' in names():f.delete(shot);m['operations'].append('DELE '+shot)
assert 'cadence_probe.png' not in names(),'Old screenshot still exists'
f.storbinary('STOR /dev/MiSTer_cmd',BytesIO(b'screenshot cadence_probe.png\n'));m['operations'].append('STOR screenshot command only')
time.sleep(2)
retrieve(f,shot,'entry603_current_terminal.png');f.quit()
f=connect()
for remote,name in [('/media/fat/MiSTer','MiSTer'),('/media/fat/MediaPlayer.rbf','MediaPlayer.rbf')]:retrieve(f,remote,name)
f.quit()
m['unchanged_target_state']='No reload, reboot, launch, media/config edit or deployment; only the fixed screenshot was replaced.'
(out/'entry603_capture.json').write_text(json.dumps(m,indent=2)+'\n');print(json.dumps(m,indent=2))
sys.path.insert(0,str(root/'tools/streams'))
from decode_hardware_cadence import decode
r=decode(out/'entry603_current_terminal.png');(out/'entry603_current_terminal.json').write_text(json.dumps(r,indent=2,sort_keys=True)+'\n')
keys=['schema_version','checksum','accepted_bytes','display_pictures','display_swaps','error_flags','sequence_end_seen','presentation_complete','session_quiet','snapshot_reason','cadence_seconds','delivered_fps','deadline_gap_count','gap_outlier_count']
print(json.dumps({k:r.get(k) for k in keys},indent=2));lines=helper.decode(errors='replace').splitlines();print('\n'.join(lines[:8]+lines[-8:]))
