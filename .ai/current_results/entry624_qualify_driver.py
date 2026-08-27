from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import concurrent.futures,subprocess,json,hashlib,os,time,sys,shutil
base=Path('/home/vash/mister-builds/entry624');root=base/'official'
source='140a5b711e84821688641c8903000e02e78f580c';pin='0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
assert not subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True).strip()
(base/'source.json').write_text(json.dumps({'source_commit':source,'published_source_pulled':True,'clean_source':True,'started':datetime.now(ZoneInfo('America/Phoenix')).isoformat()},indent=2)+'\n')
compiler=base/'toolchain/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc'
def run(name,commands,cwd=root,env=None):
 start=time.monotonic();result={'name':name,'source_commit':source,'commands':commands}
 with (base/(name+'.log')).open('w') as log:
  for cmd in commands:
   p=subprocess.run(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT)
   if p.returncode:break
 result.update(exit_code=p.returncode,seconds=time.monotonic()-start,log_sha256=hashlib.sha256((base/(name+'.log')).read_bytes()).hexdigest())
 (base/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
 assert not p.returncode,(name,p.returncode)
 return result

def main_build():
 main=base/'Main_MiSTer'
 subprocess.run(['git','clone','--quiet','--no-hardlinks','--no-checkout','/home/vash/mister-builds/entry588/Main_MiSTer',str(main)],check=True)
 subprocess.run(['git','checkout','--quiet','--detach',pin],cwd=main,check=True)
 assert not list(main.rglob('*.o'))
 patch=root/'host/main_mister/0001-mediaplayer-arm-loader.patch'
 subprocess.run(['git','apply','--check',str(patch)],cwd=main,check=True)
 subprocess.run(['git','apply',str(patch)],cwd=main,check=True)
 env=os.environ.copy();env['PATH']=str(compiler.parent)+os.pathsep+env['PATH']
 r=run('main-build',[['make','-j8']],cwd=main,env=env)
 binary=main/'bin/MiSTer';r.update(pinned_main_commit=pin,clean_build=True,compiler=subprocess.check_output([str(compiler),'--version'],text=True).splitlines()[0],bytes=binary.stat().st_size,sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),file=subprocess.check_output(['file',str(binary)],text=True).strip())
 assert b'transport=credit_step_v1' in binary.read_bytes()
 r['warnings']=[l for l in (base/'main-build.log').read_text().splitlines() if 'warning:' in l]
 (base/'main-build.json').write_text(json.dumps(r,indent=2)+'\n');return r

def host():
 return run('host-rtl', [['python3','tools/streams/test_main_mister_profile.py','--main-source','/home/vash/mister-builds/entry588/Main_MiSTer','--rtl','--report',str(base/'host-rtl-results.json')],['python3','tools/streams/test_main_mister_profile.py','--main-source','/home/vash/mister-builds/entry588/Main_MiSTer','--sanitize','--report',str(base/'host-sanitized-results.json')]])

def media():
 return run('media', [['python3','tools/streams/generate_test_suite.py','--output-dir',str(base/'suite')],['make','-B','-C','host/arm','DEPS_DIR='+str(base/'deps'),'OUTPUT='+str(base/'helper.native')],['python3','tools/streams/test_dvd_ceiling.py']])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 results=list(pool.map(lambda fn:fn(),[main_build,host,media]))
(base/'official-results.json').write_text(json.dumps({'source_commit':source,'results':results,'all_passed':True},indent=2)+'\n')
