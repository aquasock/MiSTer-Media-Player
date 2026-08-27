from pathlib import Path
import hashlib,json,os
base=Path('/home/vash/mister-builds/entry604-backup')
r=json.loads((base/'backup.json').read_text());proof={}
for name,item in r['backups'].items():
 p=base/(name+'.pred466bed')
 with p.open('r+b') as f:
  data=f.read();os.fsync(f.fileno())
 digest=hashlib.sha256(data).hexdigest()
 assert len(data)==item['bytes'] and digest==item['sha256']
 proof[name]=digest
(base/'persistent-backups-verified.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(proof,indent=2))
