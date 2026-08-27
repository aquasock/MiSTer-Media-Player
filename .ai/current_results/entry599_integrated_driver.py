from pathlib import Path
import concurrent.futures, hashlib, json, subprocess, time, csv
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');out=Path('/home/vash/mister-builds/entry599')
source='f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
fixture=Path('/home/vash/mister-builds/entry593/official/bbb_480i_tff_15s_9800kbps.m2v').read_bytes()
assert hashlib.sha256(fixture).hexdigest()=='3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065'
assert fixture.endswith(bytes.fromhex('000001b7'))
long=fixture[:-4]+fixture
(out/'long.hex').write_text(''.join(f'{b:02x}\n' for b in long))
eight_hex=Path('/tmp/entry555-i-profile/source.hex')
eight=bytes.fromhex(eight_hex.read_text());assert len(eight)==15150646
(out/'fixtures.json').write_text(json.dumps({name:{'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()} for name,data in [('ceiling',fixture),('ceiling_twice',long),('8mbps',eight)]},indent=2)+'\n')
tb=(root/'.ai/current_results/entry598_integrated_observer.sv').read_text()
tb=tb.replace('tb_entry598_i_cadence','tb_entry599_i_cadence').replace('33554432','67108864').replace('1200000000','2000000000')
tb=tb.replace('integer use_writer=1','integer expected_pictures=449;\n    integer use_writer=1')
tb=tb.replace('if ($value$plusargs("WRITER=%d",use_writer)) begin end','if ($value$plusargs("PICTURES=%d",expected_pictures)) begin end\n        if ($value$plusargs("WRITER=%d",use_writer)) begin end\n        if(use_writer!=1)$fatal(1,"writer bypass forbidden");')
tb=tb.replace('presented==449','presented==expected_pictures').replace('stores==449*8100','stores==expected_pictures*8100').replace('completed!=449','completed!=expected_pictures').replace('words!=449*64800','words!=expected_pictures*64800').replace('headers!=449','headers!=expected_pictures')
tb=tb.replace('// This is not the physical HPS/DDR/scaler system or a fix validation.','// Candidate acknowledgement validation; excludes physical HPS/DDR/scaler/startup.\n// Same event sampling as entry 598. Full picture identities/counts, no pixel oracle.')
(out/'tb_entry599_i_cadence.sv').write_text(tb)
files=[str(root/l.split()[3]) for l in (root/'files.qip').read_text().splitlines() if len(l.split())==4 and l.split()[2]=='SYSTEMVERILOG_FILE' and l.split()[3].startswith('rtl/mpeg2_new/')]
cmd=['verilator','--binary','--timing','-j','6','-CFLAGS','-O3','-Wno-fatal','-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT','-I'+str(root/'rtl/mpeg2_new'),'--top-module','tb_entry599_i_cadence','--Mdir',str(out/'obj'),'-o','integrated',str(out/'tb_entry599_i_cadence.sv')]+files
(out/'integrated_compile_command.json').write_text(json.dumps(cmd,indent=2)+'\n')
start=time.monotonic()
with (out/'integrated_compile.log').open('w') as log:subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
print(f'COMPILE_PASS seconds={time.monotonic()-start:.3f}',flush=True)
ceilinghex='/home/vash/mister-builds/entry597/fixture.hex'
cases=[('weave',1961195,7967195,ceilinghex,len(fixture),449,0,0),('bob',270754,6276754,ceilinghex,len(fixture),449,0,0),('weave_pressure',1961195,7967195,ceilinghex,len(fixture),449,1000003,500),('long_pressure',1961195,7967195,str(out/'long.hex'),len(long),898,1000003,500),('8mbps',1961195,7967195,str(eight_hex),len(eight),449,0,0)]
def run(case):
 name,phase,first,hexfile,length,count,period,busy=case
 cmd=[str(out/'obj/integrated'),f'+HEX={hexfile}',f'+LEN={length}',f'+PICTURES={count}',f'+REPORT={out}/{name}_events.csv',f'+METRICS={out}/{name}_metrics.csv',f'+PHASE={phase}',f'+FIRST_SWAP={first}','+WRITER=1',f'+BUSY_PERIOD={period}',f'+BUSY_LENGTH={busy}']
 (out/f'{name}_command.json').write_text(json.dumps(cmd,indent=2)+'\n');start=time.monotonic()
 with (out/f'{name}.log').open('w') as log:r=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 result={'case':name,'source_commit':source,'exit_code':r.returncode,'seconds':time.monotonic()-start,'expected_pictures':count,'command':cmd}
 events=list(csv.DictReader((out/f'{name}_events.csv').open()))
 presents=[e for e in events if e['event']=='present'];metrics=list(csv.DictReader((out/f'{name}_metrics.csv').open()))
 result.update(present_count=len(presents),completed=len(metrics),missed_pictures=[int(e['picture']) for e in presents if int(e['picture'])>2 and int(e['interval'])>3003000],capacity_cycles=sum(int(m['capacity_blocked']) for m in metrics),ack_latency_extra=sum(int(m['ack_latency_sum'])-200*int(m['ack_count']) for m in metrics))
 (out/f'{name}_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
 assert r.returncode==0 and len(metrics)==count and len(presents)==count-1
 assert all(int(m['ack_count'])==8100 and int(m['recon_latency_sum'])==200*8100 for m in metrics)
 assert not result['missed_pictures'],result
 if period:assert result['capacity_cycles']>0
 else:assert result['ack_latency_extra']==0
 return result
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:results=list(pool.map(run,cases))
(out/'integrated_results.json').write_text(json.dumps({'source_commit':source,'cases':results,'all_passed':True},indent=2)+'\n')
