from pathlib import Path
import os, subprocess, json
base=Path('/home/vash/mister-builds/entry675')
run=json.loads((base/'results/build-run.json').read_text())
assert run['exit_code']==0
assert run['source_commit']=='e6ca12972e8f2822af465ee549e4ecf8b2dec296'
env=os.environ.copy()
env['LD_LIBRARY_PATH']='/home/vash/quartus17-compat/extracted/usr/lib/x86_64-linux-gnu'
cmd=['/home/vash/intelFPGA_lite/17.0_T/quartus/bin/quartus_sta','-t',str(base/'entry675_timing.tcl')]
with (base/'results/timing_audit.log').open('w') as log:
 result=subprocess.run(cmd,cwd=base/'FPGA',env=env,stdout=log,stderr=subprocess.STDOUT)
text=(base/'results/timing_audit.log').read_text()
for line in text.splitlines():
 if any(x in line for x in ('WEIGHT_REGISTERS ','AUDIT_PASS','FILM_CDC_ENDPOINT','Error','successful')): print(line)
assert result.returncode==0,result.returncode
assert 'WEIGHT_REGISTER_AUDIT_PASS' in text and 'FILM_CDC_AUDIT_PASS' in text
print('TIMEQUEST_BOUNDARY_AUDIT_PASS')
