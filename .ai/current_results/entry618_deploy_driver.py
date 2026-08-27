from ftplib import FTP
from pathlib import Path
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,posixpath
HOST='10.10.0.30'
backup=Path('/home/vash/mister-builds/entry618-backup');backup.mkdir(parents=True,exist_ok=True)
ITEMS=[(Path('/home/vash/mister-builds/entry618/FPGA/output_files/MediaPlayer.rbf'),'/media/fat','MediaPlayer.rbf'),
       (Path('/run/media/vash/GIT/MiSTer-Media-Player/host/build/MiSTer'),'/media/fat','MiSTer'),
       (Path('/run/media/vash/GIT/MiSTer-Media-Player/host/build/MediaPlayer_Helper'),'/media/fat/linux','MediaPlayer_Helper')]
m={'deployed':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'host':HOST,
   'source_commit':'6c273b3','seed':17,'operations':[],'backups':{},'files':{}}
def sha(b):return hashlib.sha256(b).hexdigest()
def connect():
    f=FTP();f.connect(HOST,21,timeout=120);f.login('root','1');return f
def get(f,remote):
    b=BytesIO();f.retrbinary('RETR '+remote,b.write);return b.getvalue()
# back up every target first, before writing anything
f=connect()
for _local,d,name in ITEMS:
    remote=posixpath.join(d,name)
    data=get(f,remote);(backup/(name+'.pre618')).write_bytes(data)
    m['backups'][remote]={'file':str(backup/(name+'.pre618')),'bytes':len(data),'sha256':sha(data)}
    m['operations'].append('backup '+remote)
f.quit()
# staged upload, verify staged copy, rename, independent readback
for local,d,name in ITEMS:
    payload=local.read_bytes();want=sha(payload)
    stage=posixpath.join(d,name+'.stage');final=posixpath.join(d,name)
    f=connect()
    f.storbinary('STOR '+stage,BytesIO(payload))
    assert sha(get(f,stage))==want,'staged copy differs for '+final
    try:f.delete(final)
    except Exception:pass
    f.rename(stage,final);f.quit()
    f=connect();back=get(f,final);f.quit()
    ok=sha(back)==want and len(back)==len(payload)
    m['files'][final]={'local':str(local),'bytes':len(payload),'sha256':want,
                       'readback_sha256':sha(back),'verified':ok}
    m['operations'].append('deploy '+final)
    assert ok,'readback mismatch for '+final
m['unchanged']='Media and settings untouched. No reboot, core reload or playback performed.'
Path('/tmp/ac3fix/deploy618.json').write_text(json.dumps(m,indent=2)+'\n')
print(json.dumps({'backups':{k:v['sha256'][:16] for k,v in m['backups'].items()},
                  'deployed':{k:{'bytes':v['bytes'],'sha256':v['sha256'][:16],'verified':v['verified']} for k,v in m['files'].items()}},indent=2))
