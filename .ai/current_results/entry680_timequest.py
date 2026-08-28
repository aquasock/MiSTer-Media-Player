from pathlib import Path
import os, subprocess, json
base=Path('/home/vash/mister-builds/entry679')
run=json.loads((base/'results/build-run.json').read_text())
assert run['exit_code']==0
assert run['source_commit']=='c124aa516d7280432a63562d5e3f6a9973c32579'
env=os.environ.copy()
env['LD_LIBRARY_PATH']='/home/vash/quartus17-compat/extracted/usr/lib/x86_64-linux-gnu'
cmd=['/home/vash/intelFPGA_lite/17.0_T/quartus/bin/quartus_sta','-t',str(base/'entry679_timing.tcl')]
with (base/'results/timing_audit.log').open('w') as log:
 result=subprocess.run(cmd,cwd=base/'FPGA',env=env,stdout=log,stderr=subprocess.STDOUT)
text=(base/'results/timing_audit.log').read_text()
for line in text.splitlines():
 if any(x in line for x in ('WEIGHT_REGISTERS ','AUDIT_PASS','FILM_CDC_ENDPOINT','Error','successful')): print(line)
assert result.returncode==0,result.returncode
assert 'WEIGHT_REGISTER_AUDIT_PASS' in text and 'FILM_CDC_AUDIT_PASS' in text
print('TIMEQUEST_BOUNDARY_AUDIT_PASS')
