from pathlib import Path
from ftplib import FTP
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,os
base=Path('/tmp/entry624-backup');base.mkdir(exist_ok=True)
expected={'/media/fat/MiSTer':'0ee87029f0a00a50731707e8114363fc7019ae4c1200de85d90533c9163b5241','/media/fat/MediaPlayer.rbf':'61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce','/media/fat/linux/MediaPlayer_Helper':'f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8'}
names=['test_1_interlace_tff.mpg','test_2_interlace_bff.mpg','test_3_deinterlace_bob_weave.mpg','test_4_progressive.mpg','test_5_audio_ac3_51.mpg','test_6_audio_dts_51.mpg']
f=FTP();f.connect('10.10.0.30',timeout=20);f.login('root','1');records={}
for remote in list(expected)+['/media/fat/games/MediaPlayer/'+n for n in names]:
 path=base/Path(remote).name
 with path.open('wb') as out:
  f.retrbinary('RETR '+remote,out.write);out.flush();os.fsync(out.fileno())
 sha=hashlib.sha256(path.read_bytes()).hexdigest()
 if remote in expected:assert sha==expected[remote],remote
 records[remote]={'backup_file':path.name,'bytes':path.stat().st_size,'sha256':sha}
f.quit()
(base/'backup.json').write_text(json.dumps({'time':datetime.now(ZoneInfo('America/Phoenix')).isoformat(),'source_commit':'140a5b7','operations':'Read-only FTP backup; nothing deployed or activated.','files':records},indent=2)+'\n')
print(json.dumps(records,indent=2))
