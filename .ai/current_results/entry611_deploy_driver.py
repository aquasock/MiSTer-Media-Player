from ftplib import FTP
from pathlib import Path
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,posixpath
HOST='10.10.0.30'
helper=Path('/run/media/vash/GIT/MiSTer-Media-Player/host/build/MediaPlayer_Helper')
fixture=Path('/tmp/ac3fix/ac3_10s.mpg')
backup=Path('/home/vash/mister-builds/entry611-backup');backup.mkdir(parents=True,exist_ok=True)
m={'deployed':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'host':HOST,'operations':[],'files':{}}
def sha(b):return hashlib.sha256(b).hexdigest()
def connect():
    f=FTP();f.connect(HOST,21,timeout=60);f.login('root','1');return f
def get(f,remote):
    b=BytesIO();f.retrbinary('RETR '+remote,b.write);return b.getvalue()

# 1. back up whatever is installed, before touching anything
f=connect()
for remote,name in [('/media/fat/linux/MediaPlayer_Helper','MediaPlayer_Helper.pre_ac3'),
                    ('/media/fat/MiSTer','MiSTer.pre_ac3'),
                    ('/media/fat/MediaPlayer.rbf','MediaPlayer.rbf.pre_ac3')]:
    try:
        data=get(f,remote);(backup/name).write_bytes(data)
        m['files'][remote]={'backup':str(backup/name),'bytes':len(data),'sha256':sha(data)}
        m['operations'].append('backup '+remote)
    except Exception as e:
        m['files'][remote]={'error':repr(e)}
f.quit()

# 2. staged upload, then rename, then independent readback on a fresh connection
def deploy(local,remote_dir,final_name):
    payload=local.read_bytes();want=sha(payload)
    stage=posixpath.join(remote_dir,final_name+'.stage')
    final=posixpath.join(remote_dir,final_name)
    f=connect()
    f.storbinary('STOR '+stage,BytesIO(payload))
    staged=get(f,stage)
    assert sha(staged)==want,'staged copy differs for '+final
    try:f.delete(final)
    except Exception:pass
    f.rename(stage,final);f.quit()
    f=connect();back=get(f,final);f.quit()
    ok=sha(back)==want and len(back)==len(payload)
    m['files'][final]={'local':str(local),'bytes':len(payload),'sha256':want,
                       'readback_sha256':sha(back),'verified':ok}
    m['operations'].append('deploy '+final)
    assert ok,'readback mismatch for '+final
    return ok

deploy(helper,'/media/fat/linux','MediaPlayer_Helper')
deploy(fixture,'/media/fat/games/MediaPlayer','ac3_480i_tff_5p1_10s.mpg')
m['unchanged']='No RBF, Main, settings, reboot, core reload or playback action performed.'
Path('/tmp/ac3fix/deploy.json').write_text(json.dumps(m,indent=2)+'\n')
print(json.dumps(m,indent=2))
