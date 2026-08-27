from ftplib import FTP
from pathlib import Path
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,time,posixpath

out=Path('/tmp/regression-failure-'+datetime.now().strftime('%Y%m%d-%H%M%S'));out.mkdir()
m={'captured':datetime.now(ZoneInfo('America/Phoenix')).isoformat(),'user_report':'Tests 1 and 2 fail: top bar never moves and MiSTer menu becomes very slow. Test-to-file mapping not yet confirmed.','files':{},'errors':[],'operations':[]}
def save(): (out/'capture.json').write_text(json.dumps(m,indent=2)+'\n')
def connect():
 f=FTP();f.connect('10.10.0.30',timeout=15);f.login('root','1');return f
def get(f,remote,name):
 data=BytesIO();f.retrbinary('RETR '+remote,data.write);b=data.getvalue();(out/name).write_bytes(b)
 m['files'][remote]={'local':name,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()};m['operations'].append('RETR '+remote);save();return b
print(str(out),flush=True);save()
f=connect()
for remote,name in [('/tmp/MediaPlayer_ARM.log','helper.log'),('/tmp/messages','messages.log')]:
 try:get(f,remote,name)
 except Exception as e:m['errors'].append({'path':remote,'error':repr(e)});save()
shot='/media/fat/screenshots/cadence_probe.png'
try:
 names=lambda:{posixpath.basename(n.rstrip('/')) for n in f.nlst('/media/fat/screenshots/')}
 if 'cadence_probe.png' in names():f.delete(shot);m['operations'].append('DELE '+shot)
 assert 'cadence_probe.png' not in names()
 f.storbinary('STOR /dev/MiSTer_cmd',BytesIO(b'screenshot cadence_probe.png\n'));m['operations'].append('STOR screenshot command only');save()
 time.sleep(3);get(f,shot,'screen.png')
except Exception as e:m['errors'].append({'path':shot,'error':repr(e)});save()
try:f.quit()
except Exception:pass
f=connect()
for remote,name in [('/media/fat/MiSTer','MiSTer'),('/media/fat/MediaPlayer.rbf','MediaPlayer.rbf')]:
 try:get(f,remote,name)
 except Exception as e:m['errors'].append({'path':remote,'error':repr(e)});save()
try:f.quit()
except Exception:pass
save();print(json.dumps(m,indent=2))
if (out/'helper.log').exists():
 lines=(out/'helper.log').read_text(errors='replace').splitlines();print('\n'.join(lines[:14]+['...']+lines[-18:]))
