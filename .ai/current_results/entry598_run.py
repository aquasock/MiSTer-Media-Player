from pathlib import Path
import concurrent.futures, hashlib, json, subprocess, time

root=Path('/run/media/vash/GIT/MiSTer-Media-Player')
out=Path('/home/vash/mister-builds/entry598')
fixture=Path('/home/vash/mister-builds/entry593/official/bbb_480i_tff_15s_9800kbps.m2v')
assert hashlib.sha256(fixture.read_bytes()).hexdigest()=='3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()=='39f0875e1fc1785c9b1f7d13fdc6cfd4321ec711'
files=[]
for line in (root/'files.qip').read_text().splitlines():
    fields=line.split()
    if len(fields)==4 and fields[1]=='-name' and fields[2]=='SYSTEMVERILOG_FILE' and fields[3].startswith('rtl/mpeg2_new/'):
        files.append(str(root/fields[3]))
command=['verilator','--binary','--timing','-j','6','-Wno-fatal','-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT',
    '-I'+str(root/'rtl/mpeg2_new'),'--top-module','tb_entry598_i_cadence','--Mdir',str(out/'obj'),'-o','integrated',
    str(out/'tb_entry598_i_cadence.sv')]+files
(out/'compile_command.json').write_text(json.dumps(command,indent=2)+'\n')
start=time.monotonic()
with (out/'compile.log').open('w') as log:
    subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
print(f'COMPILE_PASS seconds={time.monotonic()-start:.3f}',flush=True)

def run(case):
    name,phase,first_swap,writer=case
    # Raster phase and first permitted swap are derived from saved hardware
    # timestamps. The startup module/video CDC is NOT simulated here.
    command=[str(out/'obj/integrated'),'+HEX=/home/vash/mister-builds/entry597/fixture.hex',
        '+LEN=18402691',f'+REPORT={out}/{name}_events.csv',f'+METRICS={out}/{name}_metrics.csv',
        f'+PHASE={phase}',f'+FIRST_SWAP={first_swap}',f'+WRITER={writer}']
    (out/f'{name}_command.json').write_text(json.dumps(command,indent=2)+'\n')
    start=time.monotonic()
    with (out/f'{name}.log').open('w') as log:
        result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    print(f'CASE={name} EXIT={result.returncode} seconds={time.monotonic()-start:.3f}',flush=True)
    return result.returncode

cases=[('weave_ideal_ddr',1961195,7967195,1),('bob_ideal_ddr',270754,6276754,1)]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results=list(pool.map(run,cases))
assert results==[0,0],results
