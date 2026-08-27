from pathlib import Path
from ftplib import FTP
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,os,posixpath
base=Path('/tmp/entry604-deployment');base.mkdir(exist_ok=True)
expected={'MiSTer':'3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f','MediaPlayer.rbf':'44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01'}
f=FTP();f.connect('10.10.0.30',21,timeout=20);f.login('root','1');f.voidcmd('TYPE I')
r={'host':'10.10.0.30','prepared':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'source_commit':'d466bed3031908b5f5ffa3360cf8a594d711a1cc','backups':{},'operations':[],'deployed':False}
for name,digest in expected.items():
 target='/media/fat/'+name;stage=target+'.new'
 names={posixpath.basename(n.rstrip('/')) for n in f.nlst('/media/fat/')}
 assert posixpath.basename(stage) not in names,'Occupied staging path '+stage
 f.voidcmd('TYPE I')
 b=BytesIO();size=f.size(target);f.retrbinary('RETR '+target,b.write);data=b.getvalue()
 assert len(data)==size and hashlib.sha256(data).hexdigest()==digest,target
 local=base/(name+'.pred466bed')
 if local.exists():assert local.read_bytes()==data,'Existing restoration copy differs'
 else:
  with local.open('xb') as out:out.write(data);out.flush();os.fsync(out.fileno())
 assert hashlib.sha256(local.read_bytes()).hexdigest()==digest
 listing=[];f.retrlines('LIST '+target,listing.append);assert len(listing)==1
 if name=='MiSTer':assert listing[0].split()[0]=='-rwxr-xr-x'
 r['backups'][name]={'target':target,'stage':stage,'local':str(local),'bytes':len(data),'sha256':digest,'listing':listing}
 r['operations'].append('Full readback and fsynced local backup of '+target)
f.quit();(base/'backup.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
