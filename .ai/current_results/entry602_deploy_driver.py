import ftplib
import hashlib
import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

root=Path('/home/vash/mister-builds/entry602')
name='bbb_full_480i_tff_av_10080kbps.mpg'
media='/media/fat/games/MediaPlayer/'+name
stage=media+'.new'
manifest=json.loads((root/Path(name).with_suffix('.json')).read_text())
qualification=json.loads((root/'qualification.json').read_text())
expected=manifest['sha256']
assert qualification['media_sha256']==expected and manifest['full_source']
assert manifest['frame_count']==17876
def connect():
    f=ftplib.FTP()
    f.connect('10.10.0.30',timeout=20)
    f.login('root','1')
    return f
def readback(path):
    h=hashlib.sha256()
    size=0
    def receive(data):
        nonlocal size
        size+=len(data)
        h.update(data)
    with connect() as f:
        f.retrbinary('RETR '+path,receive)
    return {'path':path,'bytes':size,'sha256':h.hexdigest()}
with (root/name).open('rb') as source:
    assert hashlib.file_digest(source,'sha256').hexdigest()==expected
size_expected=(root/name).stat().st_size
assert size_expected==manifest['bytes']
production={
    '/media/fat/MiSTer':(1170340,'3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f'),
    '/media/fat/MediaPlayer.rbf':(4324340,'44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01'),
}
active=[]
for path,(size,digest) in production.items():
    result=readback(path)
    assert (result['bytes'],result['sha256'])==(size,digest),result
    active.append(result)
with connect() as f:
    names={Path(p).name for p in f.nlst('/media/fat/games/MediaPlayer')}
    assert name not in names and name+'.new' not in names,'refusing to overwrite existing fixture/stage'
    print('Uploading new media stage',flush=True)
    with (root/name).open('rb') as src:
        f.storbinary('STOR '+stage,src,blocksize=65536)
print('Verifying staged media readback',flush=True)
staged=readback(stage)
assert staged['bytes']==size_expected and staged['sha256']==expected
with connect() as f:
    names={Path(p).name for p in f.nlst('/media/fat/games/MediaPlayer')}
    assert name not in names,'destination appeared during staging'
    f.rename(stage,media)
print('Verifying final media readback',flush=True)
final=readback(media)
assert final['bytes']==size_expected and final['sha256']==expected
with connect() as f:
    names={Path(p).name for p in f.nlst('/media/fat/games/MediaPlayer')}
    assert name in names and name+'.new' not in names
for path,(size,digest) in production.items():
    after=readback(path)
    assert (after['bytes'],after['sha256'])==(size,digest),after
result={'deployed_at':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),
        'test_device':'10.10.0.30','staged_readback':staged,'active_readback':final,
        'installed_production_verified_unchanged':active,
        'rebooted':False,'core_reloaded':False,'playback_started':False,
        'hardware_acceptance':False}
(root/'deployment.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
