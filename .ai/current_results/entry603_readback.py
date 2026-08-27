from ftplib import FTP
from pathlib import Path
import hashlib,json
from datetime import datetime
from zoneinfo import ZoneInfo
out=Path('/home/vash/mister-builds/entry603');media='/media/fat/games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg'
def connect():
 f=FTP();f.connect('10.10.0.30',timeout=20);f.login('root','1');return f
with connect() as f,(out/'arm_helper_later.log').open('wb') as log:
 f.retrbinary('RETR /tmp/MediaPlayer_ARM.log',log.write)
h=hashlib.sha256();size=0
def receive(data):
 global size
 h.update(data);size+=len(data)
with connect() as f:f.retrbinary('RETR '+media,receive,blocksize=65536)
result={'timestamp':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'path':media,'bytes':size,'sha256':h.hexdigest(),'helper_later_sha256':hashlib.sha256((out/'arm_helper_later.log').read_bytes()).hexdigest(),'operations':['RETR /tmp/MediaPlayer_ARM.log','RETR '+media],'read_only':True}
assert size==739065873 and h.hexdigest()=='beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642'
(out/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result),flush=True)
print('\n'.join((out/'arm_helper_later.log').read_text().splitlines()[-7:]),flush=True)
