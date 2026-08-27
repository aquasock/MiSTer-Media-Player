from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import subprocess, os, json, hashlib, time, re, sys
base=Path('/home/vash/mister-builds/entry599')
project=Path('/run/media/vash/GIT/MiSTer-Media-Player')
source=sys.argv[1]; kind=sys.argv[2]
now=lambda:datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds')
def run(cmd,**kw):return subprocess.run(cmd,check=True,**kw)
def out(cmd):return subprocess.check_output(cmd,text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if kind=='prepare':
 run(['git','-C',str(project),'diff','--quiet']);run(['git','-C',str(project),'diff','--cached','--quiet'])
 run(['git','-C',str(project),'pull','--ff-only','origin','master'])
 assert out(['git','-C',str(project),'rev-parse','HEAD'])==source
 for p in (base/'candidate-source').rglob('*'):
  if p.is_file():assert p.read_bytes()==(project/p.relative_to(base/'candidate-source')).read_bytes(),p
 work=base/'FPGA'
 run(['git','clone','--quiet','--no-hardlinks',str(project),str(work)])
 run(['git','-C',str(work),'checkout','--quiet','--detach',source])
 assert not out(['git','-C',str(work),'status','--porcelain'])
 (base/'source.json').write_text(json.dumps({'source_commit':source,'published_source_pulled':True,'candidate_files_match':True,'time':now()},indent=2)+'\n')
elif kind=='quartus':
 work=base/'FPGA'
 assert out(['git','-C',str(work),'rev-parse','HEAD'])==source
 assert not out(['git','-C',str(work),'status','--porcelain'])
 assert all(not(work/p).exists() for p in ('db','incremental_db','output_files'))
 env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus17-compat/extracted/usr/lib/x86_64-linux-gnu'
 cmd=['/home/vash/intelFPGA_lite/17.0_T/quartus/bin/quartus_sh','--flow','compile','MediaPlayer']
 report={'source_commit':source,'build_directory':str(work),'clean_build':True,'started':now(),'command':cmd}
 path=work/'entry599-build-run.json';path.write_text(json.dumps(report,indent=2)+'\n');start=time.monotonic()
 with (work/'entry599-quartus.log').open('w') as log:report['exit_code']=subprocess.call(cmd,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT)
 report.update(elapsed_seconds=time.monotonic()-start,finished=now());path.write_text(json.dumps(report,indent=2)+'\n')
 sys.exit(report['exit_code'])
elif kind=='arm':
 main=base/'Main_MiSTer';cache=Path('/home/vash/mister-builds/entry586/Main_MiSTer')
 pin='0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f'
 assert out(['git','-C',str(project),'rev-parse','HEAD'])==source
 compiler=Path('/tmp/mediaplayer-arm-10.2.Qtyo4b/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc')
 run(['git','clone','--quiet','--no-hardlinks','--no-checkout',str(cache),str(main)])
 run(['git','-C',str(main),'checkout','--quiet','--detach',pin])
 assert not list(main.rglob('*.o'))
 run(['git','-C',str(main),'apply','--check',str(project/'host/main_mister/0001-mediaplayer-arm-loader.patch')])
 run(['git','-C',str(main),'apply',str(project/'host/main_mister/0001-mediaplayer-arm-loader.patch')])
 report={'source_commit':source,'main_mister_commit':pin,'clean_build':True,'started':now(),'compiler':out([str(compiler),'--version']).splitlines()[0]}
 env=os.environ.copy();env['PATH']=str(compiler.parent)+os.pathsep+env['PATH'];start=time.monotonic();log=base/'arm-build.log'
 with log.open('w') as f:result=subprocess.run(['make','-j8'],cwd=main,env=env,stdout=f,stderr=subprocess.STDOUT)
 report.update(exit_code=result.returncode,elapsed_seconds=time.monotonic()-start,finished=now(),log_sha256=sha(log))
 report['warnings']=[l for l in log.read_text().splitlines() if re.search(r'\bwarning:',l)]
 report['errors']=[l for l in log.read_text().splitlines() if re.search(r'\berror:',l)]
 if result.returncode==0:
  binary=main/'bin/MiSTer';report['binary']={'path':str(binary),'bytes':binary.stat().st_size,'sha256':sha(binary),'file':out(['file',str(binary)])}
  assert b'transport=credit_fast_v1' in binary.read_bytes()
 (base/'arm-build.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True);sys.exit(result.returncode)
elif kind=='regression':
 assert out(['git','-C',str(project),'rev-parse','HEAD'])==source
 report={'source_commit':source,'started':now(),'checks':[]}
 commands=[['python3','tools/streams/test_main_mister_profile.py','--main-source',str(base/'Main_MiSTer'),'--rtl','--report',str(base/'tests.json')],['python3','tools/streams/test_main_mister_profile.py','--main-source',str(base/'Main_MiSTer'),'--sanitize','--report',str(base/'tests-sanitized.json')],['bash','tools/streams/run_native_480i_timing.sh']]
 for i,cmd in enumerate(commands):
  log=base/f'regression-{i}.log';start=time.monotonic()
  with log.open('w') as f:r=subprocess.run(cmd,cwd=project,stdout=f,stderr=subprocess.STDOUT)
  report['checks'].append({'command':cmd,'exit_code':r.returncode,'seconds':time.monotonic()-start,'log':str(log),'sha256':sha(log)})
  assert r.returncode==0,log
 for family in ('default','cyclone-v'):
  exe=base/f'fifo-{family}.vvp';log=base/f'fifo-{family}.log'
  cmd=['iverilog','-g2012','-s','tb_mpeg2_stream_fifo_burst','-o',str(exe)]
  if family=='cyclone-v':cmd+=['-DFIFO_CYCLONE_V']
  cmd+=['rtl/mpeg2_stream_fifo.sv','tools/streams/tb_mpeg2_stream_fifo_burst.sv','/home/vash/intelFPGA_lite/17.0_T/quartus/eda/sim_lib/altera_mf.v']
  start=time.monotonic()
  with log.open('w') as f:
   run(cmd,cwd=project,stdout=f,stderr=subprocess.STDOUT);run(['vvp',str(exe)],cwd=project,stdout=f,stderr=subprocess.STDOUT)
  report['checks'].append({'command':cmd,'exit_code':0,'seconds':time.monotonic()-start,'log':str(log),'sha256':sha(log)})
 report['finished']=now();(base/'regression.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
else:raise ValueError(kind)
