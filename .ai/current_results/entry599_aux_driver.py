from pathlib import Path
import subprocess,json,concurrent.futures,time
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');base=Path('/home/vash/mister-builds/entry599');old=base/'baseline'
subprocess.run(['git','clone','--quiet','--no-hardlinks',str(root),str(old)],check=True)
subprocess.run(['git','checkout','--quiet','--detach','f615ce0^'],cwd=old,check=True)
files=[l.split()[3] for l in (old/'files.qip').read_text().splitlines() if len(l.split())==4 and l.split()[2]=='SYSTEMVERILOG_FILE' and l.split()[3].startswith('rtl/mpeg2_new/')]
results=[]
for name in ('tb_h262_double_scratch_tags','tb_h262_prediction_error_sources'):
 tb='tb_h262_b_presentation_scheduler' if name=='tb_h262_double_scratch_tags' else name
 cmd=['iverilog','-g2012','-gsupported-assertions','-I','rtl/mpeg2_new','-s',name,'-o',str(base/(name+'-baseline')),'tools/streams/'+tb+'.sv']+files
 with (base/(name+'-baseline.log')).open('w') as log:
  r=subprocess.run(cmd,cwd=old,stdout=log,stderr=subprocess.STDOUT)
  if r.returncode==0:r=subprocess.run(['vvp',str(base/(name+'-baseline'))],cwd=old,stdout=log,stderr=subprocess.STDOUT)
 results.append({'name':name,'baseline_exit':r.returncode});print(results[-1],flush=True)
 assert r.returncode!=0
(base/'preexisting_failures.json').write_text(json.dumps(results,indent=2)+'\n')
# Same new contract test must catch the old delayed implementation and an unsafe grant.
newtb=root/'tools/streams/tb_h262_ddram_store_overlap.sv';writer=root/'rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv'
mutant=base/'unsafe_writer.sv';mutant.write_text(writer.read_text().replace('capture_complete && !pend[~cap_bank]','capture_complete'))
for name,rtl in [('old',old/'rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv'),('unsafe',mutant)]:
 exe=base/(name+'-negative');log=base/(name+'-negative.log')
 with log.open('w') as f:
  subprocess.run(['iverilog','-g2012','-s','tb_h262_ddram_store_overlap','-o',str(exe),str(newtb),str(rtl)],check=True,stdout=f,stderr=subprocess.STDOUT)
  r=subprocess.run(['vvp',str(exe)],stdout=f,stderr=subprocess.STDOUT)
 assert r.returncode!=0;print(name+' expected failure: '+log.read_text().splitlines()[0],flush=True)
# Authored 720x480 I/P/B stream exercises the actual shared writer, arbiter,
# and P/B persistence consumers without obsolete exact-cycle soak assertions.
fixture=base/'test_b_residual_streaming.m2v'
subprocess.run(['python3','tools/streams/generate_test_b_residual_streaming.py','--output',str(fixture)],cwd=root,check=True)
cmd=['bash','tools/streams/run_live_raster_soak_verilator.sh',str(fixture),'+GENERIC_STREAM']
start=time.monotonic()
with (base/'shared_pb.log').open('w') as log:r=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
result={'command':cmd,'exit_code':r.returncode,'seconds':time.monotonic()-start,'pass_lines':[l for l in (base/'shared_pb.log').read_text().splitlines() if 'RESULT' in l or 'ASSERT' in l]}
(base/'shared_pb_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
assert r.returncode==0
