from pathlib import Path
import subprocess,json,time
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');base=Path('/home/vash/mister-builds/entry604')
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()=='d466bed3031908b5f5ffa3360cf8a594d711a1cc'
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
