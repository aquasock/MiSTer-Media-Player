from pathlib import Path
from ftplib import FTP
from io import BytesIO
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,subprocess,posixpath
base=Path('/tmp/entry599-deployment');reports=Path('/tmp/entry599-reports')
source='f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4'
subprocess.run(['git','merge-base','--is-ancestor',source,'HEAD'],check=True)
subprocess.run(['git','diff','--quiet',source,'HEAD','--','.',':(exclude).ai'],check=True)
m=json.loads((base/'backup.json').read_text());fpga=json.loads((reports/'entry599-build.json').read_text());q=json.loads((reports/'qualification.json').read_text());review=json.loads((reports/'warning-review.json').read_text())
assert m['source_commit']==fpga['source_commit']==q['source_commit']==review['source_commit']==source
analysis=json.loads((reports/'analysis.json').read_text())
assert analysis['source_commit']==source and all(c['all_intervals_exact_after_initial_admission'] for c in analysis['cases'])
assert q['qualified_for_hardware_test'] and not q['hardware_accepted'] and review['reviewed'] and not review['blocking_new_warnings']
assert fpga['compile_success'] and fpga['timing_positive'] and fpga['errors']==0 and not fpga['new_ignored_timing_filters']
proof=json.loads((base/'persistent-backups-verified.json').read_text())
for name,b in m['backups'].items():
 assert proof[name]==b['sha256']
 assert hashlib.sha256(Path(b['local']).read_bytes()).hexdigest()==b['sha256']
m['persistent_backup_directory']='/home/vash/mister-builds/entry599-backup'
data=(reports/'MediaPlayer.rbf').read_bytes()
assert hashlib.sha256(data).hexdigest()==fpga['rbf_sha256']==q['fpga_rbf_sha256'] and len(data)==fpga['rbf_bytes']
m['candidate']={'MediaPlayer.rbf':{'sha256':fpga['rbf_sha256'],'bytes':len(data)}}
m['main_retained_sha256']=q['main_retained_sha256']
assert m['backups']['MiSTer']['sha256']==q['main_retained_sha256']
def connect():
 f=FTP();f.connect(m['host'],21,timeout=20);f.login('root','1');f.voidcmd('TYPE I');return f
def read(f,p):
 b=BytesIO();f.retrbinary('RETR '+p,b.write);return b.getvalue()
def absent(f,p):
 names={posixpath.basename(n.rstrip('/')) for n in f.nlst(posixpath.dirname(p)+'/')}
 assert posixpath.basename(p) not in names,'Occupied staging path '+p
def listing(f,p):
 lines=[];f.retrlines('LIST '+p,lines.append);assert len(lines)==1;return lines
def save():
 (base/'deployment.json').write_text(json.dumps(m,indent=2)+'\n')
b=m['backups']['MediaPlayer.rbf'];f=connect()
for old in m['backups'].values():assert hashlib.sha256(read(f,old['target'])).hexdigest()==old['sha256']
absent(f,b['stage']);f.storbinary('STOR '+b['stage'],BytesIO(data));m['operations'].append('STOR '+b['stage']);save();f.quit()
f=connect();staged=read(f,b['stage']);assert staged==data
lines=listing(f,b['stage']);assert lines[0].split()[0]==b['listing'][0].split()[0]
m['staged']={'sha256':hashlib.sha256(staged).hexdigest(),'bytes':len(staged),'listing':lines,'fresh_connection_readback':True}
for old in m['backups'].values():assert hashlib.sha256(read(f,old['target'])).hexdigest()==old['sha256']
f.rename(b['stage'],b['target']);m['operations'].append('RNFR/RNTO '+b['stage']+' to '+b['target']);save();f.quit()
f=connect();active=read(f,b['target']);assert active==data;absent(f,b['stage'])
lines=listing(f,b['target']);assert lines[0].split()[0]==b['listing'][0].split()[0]
assert hashlib.sha256(read(f,m['backups']['MiSTer']['target'])).hexdigest()==q['main_retained_sha256']
m['active']={'sha256':hashlib.sha256(active).hexdigest(),'bytes':len(active),'listing':lines,'fresh_connection_readback':True}
f.quit();m['deployed']=True;m['staging_absent']=True;m['main_unchanged']=True;m['finished']=datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds')
m['authorization']='User-approved capacity-safe writer acknowledgement implementation and standing qualified deployment authorization.'
m['lifecycle']='No reboot, core reload, playback, host binary or configuration changes. User must reload core to activate the new RBF.'
save();print(json.dumps(m,indent=2))
