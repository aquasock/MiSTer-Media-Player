"""Install only a fully qualified candidate; preserve the previous dated core."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import ftplib, hashlib, io, json
root=Path('/home/vash/MiSTer-Media-Player/output_files/entry681')
build=json.loads((root/'build.json').read_text())
gate=json.loads((root/'final_gate.json').read_text())
assert build['timing_positive'] and build['errors']==0 and build['compile_success']
assert gate['qualification_pass'] and gate['source_commit']==build['source_commit']
now=lambda:datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds')
date=datetime.now(ZoneInfo('America/Phoenix')).strftime('%Y%m%d')
stamp=datetime.now(ZoneInfo('America/Phoenix')).strftime('%Y%m%dT%H%M%S')
name='MediaPlayer_'+date+'.rbf'; binary=(root/name).read_bytes()
assert len(binary)==build['rbf_bytes']
assert hashlib.sha256(binary).hexdigest()==build['rbf_sha256']
target='/media/fat/'+name; stage=target+'.upload-entry681-'+stamp
report=dict(source_commit=build['source_commit'],device='10.10.0.30',started=now(),target=target,stage=stage,
            installation_verified=False,core_reloaded=False,playback_started=False,hardware_accepted=False)
def save(): (root/'installation.json').write_text(json.dumps(report,indent=2)+'\n')
def connect():
 f=ftplib.FTP();f.connect('10.10.0.30',timeout=30);f.login('root','1');return f
def readback(path,retain=False):
 h=hashlib.sha256();n=0;data=bytearray()
 def receive(chunk):
  nonlocal n
  h.update(chunk);n+=len(chunk)
  if retain:data.extend(chunk)
 with connect() as f:f.retrbinary('RETR '+path,receive,blocksize=65536)
 return dict(path=path,bytes=n,sha256=h.hexdigest()),bytes(data)
def names(f,path): return {Path(x).name for x in f.nlst(path)}
save()
with connect() as f:
 listing=names(f,'/media/fat')
 assert Path(stage).name not in listing
 protected=['/media/fat/MiSTer','/media/fat/linux/MediaPlayer_Helper','/media/fat/games/MediaPlayer/dvd_opening_original.mpg']
 protected+=['/media/fat/'+x for x in listing if x.lower().startswith('mediaplayer') and x.lower().endswith('.rbf') and x!=name]
report['protected_before']=[readback(p)[0] for p in protected]
assert report['protected_before'][2]['sha256']=='218d3a8eab32efceb6263d884be1b589b75e598ae25eeb465d14e4b430dfdc21'
old=None
if name in listing:
 old,old_data=readback(target,True)
 (root/'previous-dated-core.rbf').write_bytes(old_data)
 report['previous_target']=old
save()
with connect() as f:f.storbinary('STOR '+stage,io.BytesIO(binary),blocksize=65536)
report['staged_readback']=readback(stage)[0];save()
assert report['staged_readback']['sha256']==build['rbf_sha256'] and report['staged_readback']['bytes']==len(binary)
backup=None
if old:
 # Recheck before any rename, in case the user changed the file during staging.
 assert readback(target)[0]==old
 backup_dir='/media/fat/_MediaPlayer_Backups'
 backup=backup_dir+'/'+name[:-4]+'_'+old['sha256'][:12]+'_'+stamp+'.rbf'
 with connect() as f:
  if '_MediaPlayer_Backups' not in names(f,'/media/fat'):f.mkd(backup_dir)
  assert Path(backup).name not in names(f,backup_dir)
  f.rename(target,backup)
 report['backup']=readback(backup)[0];save()
 assert report['backup']['bytes']==old['bytes'] and report['backup']['sha256']==old['sha256']
try:
 with connect() as f:
  assert name not in names(f,'/media/fat')
  f.rename(stage,target)
except Exception:
 if backup:
  with connect() as f:
   if name not in names(f,'/media/fat'):f.rename(backup,target)
 raise
report['final_readback']=readback(target)[0];save()
assert report['final_readback']['sha256']==build['rbf_sha256'] and report['final_readback']['bytes']==len(binary)
report['protected_after']=[readback(p)[0] for p in protected]
assert report['protected_after']==report['protected_before']
report.update(installation_verified=True,protected_files_unchanged=True,finished=now());save()
print('INSTALLATION_PASS '+target+' SHA256='+build['rbf_sha256'])
print('Previous dated core preserved; Main/helper/other cores/clip unchanged; no reload or playback.')
