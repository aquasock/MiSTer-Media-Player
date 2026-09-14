#!/usr/bin/env python3
"""Build clean archived source for seeds 52/61/87; usage: build_three_seeds.py [commit]."""
from pathlib import Path
import argparse
import subprocess, os, re, tarfile, io, time, json, threading, concurrent.futures, hashlib, sys
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('commit',nargs='?',default='HEAD')
parser.add_argument('--seeds',type=int,nargs='+',default=[52,61,87])
args=parser.parse_args()
sha=subprocess.check_output(['git','rev-parse',args.commit],cwd=root,text=True).strip()
base=root/'results'/('build-'+sha[:7]+'-'+time.strftime('%Y%m%d-%H%M%S'))
base.mkdir(parents=True)
source=subprocess.check_output(['git','archive',sha],cwd=root)
state={'source':sha,'started':time.time(),'seeds':{}}
lock=threading.Lock()
def save(seed,**kw):
 with lock:
  state['seeds'].setdefault(str(seed),{}).update(kw)
  p=base/'status.json';t=base/'status.json.tmp';t.write_text(json.dumps(state,indent=2)+'\n');t.replace(p)
  print(seed,kw,flush=True)
def build(seed):
 dest=base/('seed'+str(seed));dest.mkdir()
 with tarfile.open(fileobj=io.BytesIO(source)) as tf:tf.extractall(dest,filter='data')
 qsf=dest/'MediaPlayer.qsf';text=qsf.read_text();text=re.sub(r'(?m)^set_global_assignment -name SEED .*$',f'set_global_assignment -name SEED {seed}',text);text=re.sub(r'(?m)^set_global_assignment -name NUM_PARALLEL_PROCESSORS .*$', 'set_global_assignment -name NUM_PARALLEL_PROCESSORS 6',text);qsf.write_text(text)
 env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus-compat-libs'+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
 started=time.time();save(seed,stage='compile',directory=str(dest),started=started)
 with (dest/'compile.log').open('w') as log:
  rc=subprocess.call(['bash','tools/build.sh','compile'],cwd=dest,env=env,stdout=log,stderr=subprocess.STDOUT)
 save(seed,compile_exit=rc,compile_seconds=round(time.time()-started,1))
 if rc!=0:save(seed,stage='failed');return
 save(seed,stage='timing')
 with (dest/'timing.log').open('w') as log:
  rc=subprocess.call(['bash','tools/build.sh','timing'],cwd=dest,env=env,stdout=log,stderr=subprocess.STDOUT)
 rbf=dest/'output_files/MediaPlayer.rbf'
 save(seed,stage='complete' if rc==0 else 'timing_audit_failed',timing_exit=rc,total_seconds=round(time.time()-started,1),rbf_sha256=hashlib.sha256(rbf.read_bytes()).hexdigest() if rbf.exists() else None)
print('Build evidence: '+str(base),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(build,args.seeds))
print('BATCH FINISHED '+str(base),flush=True)
