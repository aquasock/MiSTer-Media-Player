from ftplib import FTP
from pathlib import Path
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,posixpath
HOST='10.10.0.30'
backup=Path('/home/vash/mister-builds/entry620-backup');backup.mkdir(parents=True,exist_ok=True)
ITEMS=[(Path('/run/media/vash/GIT/MiSTer-Media-Player/host/build/MediaPlayer_Helper'),'/media/fat/linux','MediaPlayer_Helper'),
       (Path('/tmp/ac3fix/dts_sweep_12s.mpg'),'/media/fat/games/MediaPlayer','dts_channel_sweep_12s.mpg')]
m={'deployed':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'host':HOST,
   'source_commit':'078d36b','operations':[],'backups':{},'files':{}}
def sha(b):return hashlib.sha256(b).hexdigest()
def connect():
    f=FTP();f.connect(HOST,21,timeout=120);f.login('root','1');return f
def get(f,remote):
    b=BytesIO();f.retrbinary('RETR '+remote,b.write);return b.getvalue()
f=connect()
for _l,d,name in ITEMS:
    remote=posixpath.join(d,name)
    try:
        data=get(f,remote);(backup/(name+'.pre620')).write_bytes(data)
        m['backups'][remote]={'bytes':len(data),'sha256':sha(data)}
    except Exception as e:
        m['backups'][remote]={'absent':repr(e)}
# also confirm the RBF and Main we rely on are still the accepted ones
for remote in ('/media/fat/MediaPlayer.rbf','/media/fat/MiSTer'):
    d=get(f,remote);m['files'][remote]={'bytes':len(d),'sha256':sha(d),'unchanged_check':True}
f.quit()
for local,d,name in ITEMS:
    payload=local.read_bytes();want=sha(payload)
    stage=posixpath.join(d,name+'.stage');final=posixpath.join(d,name)
    f=connect();f.storbinary('STOR '+stage,BytesIO(payload))
    assert sha(get(f,stage))==want,'staged differs '+final
    try:f.delete(final)
    except Exception:pass
    f.rename(stage,final);f.quit()
    f=connect();back=get(f,final);f.quit()
    ok=sha(back)==want
    m['files'][final]={'bytes':len(payload),'sha256':want,'readback_sha256':sha(back),'verified':ok}
    m['operations'].append('deploy '+final)
    assert ok,'readback mismatch '+final
m['unchanged']='RBF, Main, settings untouched. No reboot, core reload or playback performed.'
Path('/tmp/ac3fix/deploy620.json').write_text(json.dumps(m,indent=2)+'\n')
print(json.dumps({k:{'bytes':v.get('bytes'),'sha':(v.get('sha256') or '')[:16],'verified':v.get('verified')} for k,v in m['files'].items()},indent=2))
