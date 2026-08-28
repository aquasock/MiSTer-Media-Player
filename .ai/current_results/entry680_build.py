from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import subprocess, os, json, hashlib, time, re, sys
base=Path('/home/vash/mister-builds/entry679')
(base/'results').mkdir(parents=True,exist_ok=True)
project=Path('/run/media/vash/GIT/MiSTer-Media-Player')
source=sys.argv[1]; kind=sys.argv[2]
work=base/'FPGA'
now=lambda:datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds')
def run(cmd,**kw): return subprocess.run(cmd,check=True,**kw)
def out(cmd): return subprocess.check_output(cmd,text=True).strip()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
if kind=='prepare':
 run(['git','-C',str(project),'diff','--quiet']);run(['git','-C',str(project),'diff','--cached','--quiet'])
 run(['git','-C',str(project),'pull','--ff-only','origin','master'])
 # Metadata commits may follow the source commit but cannot change build input.
 assert out(['git','-C',str(project),'rev-parse',source])==source
 run(['git','-C',str(project),'merge-base','--is-ancestor',source,'HEAD'])
 changes=out(['git','-C',str(project),'diff','--name-only',source,'HEAD']).splitlines()
 assert all(x.startswith('.ai/') for x in changes),changes
 run(['git','clone','--quiet','--no-hardlinks',str(project),str(work)])
 run(['git','-C',str(work),'checkout','--quiet','--detach',source])
 assert not out(['git','-C',str(work),'status','--porcelain'])
 assert not work.joinpath('db').exists()
 (base/'results/source.json').write_text(json.dumps({'source_commit':source,'published_source_pulled':True,'clean_clone_matches_published_source':True,'time':now()},indent=2)+'\n')
elif kind=='quartus':
 assert out(['git','-C',str(work),'rev-parse','HEAD'])==source
 assert not out(['git','-C',str(work),'status','--porcelain'])
 gate=json.loads((base/'final_gate.json').read_text()); assert gate['qualification_pass'] and gate['source_commit']==source
 assert not (base/'results/build-run.json').exists(), 'Only one compile authorized'
 assert all(not(work/p).exists() for p in ('db','incremental_db','output_files'))
 env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus17-compat/extracted/usr/lib/x86_64-linux-gnu'
 cmd=['/home/vash/intelFPGA_lite/17.0_T/quartus/bin/quartus_sh','--flow','compile','MediaPlayer']
 report={'source_commit':source,'build_directory':str(work),'clean_build':True,'started':now(),'command':cmd}
 path=base/'results/build-run.json';path.write_text(json.dumps(report,indent=2)+'\n');start=time.monotonic()
 with (base/'results/quartus.log').open('w') as log: report['exit_code']=subprocess.call(cmd,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT)
 report.update(elapsed_seconds=time.monotonic()-start,finished=now());path.write_text(json.dumps(report,indent=2)+'\n')
 sys.exit(report['exit_code'])
elif kind=='audit':
 run(['git','diff','--exit-code','HEAD'],cwd=work,capture_output=True)
 report=json.loads((base/'results/build-run.json').read_text());assert report.get('exit_code')==0,report
 log=(base/'results/quartus.log').read_text(); summary=(work/'output_files/MediaPlayer.sta.summary').read_text()
 rows=[]
 for m in re.finditer(r'Type\s*:\s*(.*?)\nSlack\s*:\s*(-?\d+\.\d+)\nTNS\s*:\s*(-?\d+\.\d+)',summary):
  typ=m[1].strip();key=typ.split(" '")[0].lower().replace(' ','_')
  clock=typ.split(" '",1)[1].rstrip("'") if " '" in typ else None
  rows.append({'type':key,'clock':clock,'slack_ns':float(m[2]),'tns_ns':float(m[3])})
 assert rows,summary
 worst={key:min(r['slack_ns'] for r in rows if r['type']==key) for key in {r['type'] for r in rows}}
 assert set(worst)=={'setup','hold','recovery','removal','minimum_pulse_width'},worst
 positive=all(v>0 for v in worst.values()) and all(r['tns_ns']==0 for r in rows)
 fit=(work/'output_files/MediaPlayer.fit.summary').read_text();assert 'Fitter Status : Successful' in fit
 seed=int(re.search(r'set_global_assignment -name SEED (\d+)',(work/'MediaPlayer.qsf').read_text())[1])
 counts=re.findall(r'Quartus Prime Full Compilation was successful\. (\d+) errors?, (\d+) warnings?',log);assert counts,log[-3000:]
 resources={}
 for key,pattern in {'alms':r'Logic utilization \(in ALMs\) : ([\d,]+)','registers':r'Total registers : ([\d,]+)','ram_bits':r'Total block memory bits : ([\d,]+)','ram_blocks':r'Total RAM Blocks : ([\d,]+)','dsp_blocks':r'Total DSP Blocks : ([\d,]+)'}.items():
  resources[key]=int(re.search(pattern,fit)[1].replace(',',''))
 assert seed==19,seed
 rbf=work/'output_files/MediaPlayer.rbf'
 report.update(quartus_version='17.0.2 Build 602 Lite',seed=seed,compile_success=True,errors=int(counts[-1][0]),warnings=int(counts[-1][1]),timing_positive=positive,worst_slack_ns=worst,timing_rows=rows,resources=resources,rbf_bytes=rbf.stat().st_size,rbf_sha256=sha(rbf),tracked_build_source_unchanged=True)
 report['report_sha256']={str(p.relative_to(base)):sha(p) for p in [base/'results/quartus.log',work/'output_files/MediaPlayer.sta.summary',work/'output_files/MediaPlayer.fit.summary']}
 (base/'results/build.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ('source_commit','elapsed_seconds','errors','warnings','seed','timing_positive','worst_slack_ns','resources','rbf_bytes','rbf_sha256')},indent=2))
 assert positive,'Do not deploy a timing-failing image'
else: raise ValueError(kind)
