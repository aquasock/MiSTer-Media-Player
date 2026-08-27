from pathlib import Path
import concurrent.futures,subprocess,time,json,hashlib
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');base=Path('/home/vash/mister-builds/entry599')
source='f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
files=[str(root/l.split()[3]) for l in (root/'files.qip').read_text().splitlines() if len(l.split())==4 and l.split()[2]=='SYSTEMVERILOG_FILE' and l.split()[3].startswith('rtl/mpeg2_new/')]
jobs=[('native',['bash','tools/streams/run_native_480i_timing.sh']),('reconstruction',['bash','tools/streams/run_interlaced_i_reconstruction.sh'])]
for name in ('tb_h262_ddram_store_overlap','tb_h262_b_presentation_scheduler','tb_h262_double_scratch_tags','tb_h262_prediction_block_fetcher','tb_h262_prediction_word_cache','tb_h262_prediction_error_sources'):
 tb='tb_h262_b_presentation_scheduler' if name=='tb_h262_double_scratch_tags' else name
 jobs.append((name,['iverilog','-g2012','-gsupported-assertions','-I',str(root/'rtl/mpeg2_new'),'-s',name,'-o',str(base/name),str(root/f'tools/streams/{tb}.sv')]+files))
def run(job):
 name,cmd=job;start=time.monotonic();log=base/(name+'.log');commands=[cmd]
 with log.open('w') as f:
  r=subprocess.run(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT)
  if r.returncode==0 and cmd[0]=='iverilog':
   commands.append(['vvp',str(base/name)]);r=subprocess.run(commands[-1],cwd=root,stdout=f,stderr=subprocess.STDOUT)
 result={'name':name,'commands':commands,'exit_code':r.returncode,'seconds':time.monotonic()-start,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'pass_lines':[l for l in log.read_text().splitlines() if 'PASS' in l or 'RESULT' in l]}
 (base/(name+'-result.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(run,jobs))
(base/'regression.json').write_text(json.dumps({'source_commit':source,'checks':results,'all_passed':all(r['exit_code']==0 for r in results)},indent=2)+'\n')
assert all(r['exit_code']==0 for r in results)
