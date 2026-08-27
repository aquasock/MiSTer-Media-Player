from pathlib import Path
import bisect,concurrent.futures,csv,hashlib,json,subprocess,sys,time
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');out=Path('/home/vash/mister-builds/entry604');source='d466bed3031908b5f5ffa3360cf8a594d711a1cc'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
sys.path.insert(0,str(root/'tools/streams'))
import check_media_compatibility as demux
import analyze_h262_compatibility as syntax
full=Path('/home/vash/mister-builds/entry602/bbb_full_480i_tff_av_10080kbps.mpg')
with full.open('rb') as f: program_prefix=f.read(64*1024*1024)
video,_,_=demux.demux_program_stream(program_prefix);del program_prefix
codes=syntax.start_codes(video);sequences=[offset for offset,code in codes if code==0xb3];pictures=[offset for offset,code in codes if code==0]
cut=sequences[1000];video=video[:cut];pictures=pictures[:1000]
helper=Path('/home/vash/mister-builds/entry602/media_player_helper.native')
with (out/'prefix_helper.stderr').open('wb') as errors:
 p=subprocess.Popen([str(helper),'--protocol','1','--source','file:'+str(full),'--pcm-out',str(out/'prefix_pcm.s16le')],stdout=subprocess.PIPE,stderr=errors)
 clean=bytearray();positions=[];pts=[];buffer=b''
 while len(clean)<cut:
  chunk=p.stdout.read(1048576);assert chunk,'helper ended before requested prefix';buffer+=chunk
  while True:
   index=buffer.find(bytes.fromhex('000001b0'))
   if index<0:
    n=max(0,len(buffer)-8);clean.extend(buffer[:n]);buffer=buffer[n:];break
   if index+9>len(buffer):break
   clean.extend(buffer[:index]);positions.append(len(clean));pts.append(int.from_bytes(buffer[index+4:index+9],'big')>>7);buffer=buffer[index+9:]
 p.terminate();p.stdout.close();helper_status=p.wait()
assert bytes(clean[:cut])==video
items=[]
for position,value in zip(positions,pts):
 if value>=pts[0]+1000*3003:continue
 index=bisect.bisect_left(pictures,position)
 assert value-pts[0]==index*3003,(index,position,value)
 items.append((position,value,index))
assert len(items)==995
fixtures=[]
for name,n in [('opening',100),('long',1000)]:
 end=sequences[n];data=video[:end]+bytes.fromhex('000001b7');subset=[(p,v,i) for p,v,i in items if i<n]
 (out/(name+'.hex')).write_text(''.join(f'{b:02x}\n' for b in data))
 (out/(name+'_positions.hex')).write_text(''.join(f'{p:08x}\n' for p,_,_ in subset))
 (out/(name+'_pts.hex')).write_text(''.join(f'{v:09x}\n' for _,v,_ in subset))
 fixtures.append({'name':name,'frames':n,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'original_prefix_sha256':hashlib.sha256(data[:-4]).hexdigest(),'timestamps':len(subset),'missing_timestamp_ordinals_zero_based':[i for i in range(n) if i not in {x[2] for x in subset}]})
old=Path('/home/vash/mister-builds/entry593/official/bbb_480i_tff_15s_9800kbps.m2v').read_bytes();assert hashlib.sha256(old).hexdigest()=='3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065'
(out/'ceiling.hex').write_text(''.join(f'{b:02x}\n' for b in old))
fixtures.append({'name':'ceiling','frames':449,'bytes':len(old),'sha256':hashlib.sha256(old).hexdigest(),'timestamps':0})
(out/'fixtures.json').write_text(json.dumps({'source_commit':source,'helper_prefix_termination_status':helper_status,'full_source_media_sha256':'beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642','fixtures':fixtures,'scope':'Exact video prefixes and helper timestamp positions; only terminal sequence end appended. Helper intentionally terminated after prefix extraction, not treated as full helper qualification.'},indent=2)+'\n')
s=(root/'.ai/current_results/entry603_integrated_observer.sv').read_text().replace('tb_entry603_i_pts','tb_entry604_i_pts').replace('8388608','67108864')
s=s.replace('integer control=0,metadata_index=0,clock_accum=0;', 'integer control=0,metadata_index=0,clock_accum=0;\n    integer expected_pictures=100,metadata_count=100;\n    reg [1023:0] positions_path,pts_path;')
s=s.replace('[0:99]','[0:2047]')
s=s.replace('$readmemh("/home/vash/mister-builds/entry603/positions.hex",metadata_positions);\n        $readmemh("/home/vash/mister-builds/entry603/timestamps.hex",metadata_values);', '''if($value$plusargs("PICTURES=%d",expected_pictures))begin end
        if($value$plusargs("PTS_COUNT=%d",metadata_count))begin end
        if(control!=1)begin
            if(!$value$plusargs("POSITIONS=%s",positions_path))$fatal(1,"missing positions");
            if(!$value$plusargs("TIMESTAMPS=%s",pts_path))$fatal(1,"missing timestamps");
            $readmemh(positions_path,metadata_positions,0,metadata_count-1);
            $readmemh(pts_path,metadata_values,0,metadata_count-1);
        end''')
s=s.replace('metadata_index<100','metadata_index<metadata_count').replace('presented==100','presented==expected_pictures').replace('stores==100*8100','stores==expected_pictures*8100').replace('completed!=100','completed!=expected_pictures').replace('words!=100*64800','words!=expected_pictures*64800').replace('headers!=100','headers!=expected_pictures').replace('total_cycles>400000000','total_cycles>2140000000')
s=s.replace('if(scheduler.ordinary_secondary_valid && pts_active)\n                $display', 'if(scheduler.ordinary_secondary_valid && pts_active && presentation_error)\n                $display')
tb=out/'tb_entry604_i_pts.sv';tb.write_text(s)
files=[str(root/l.split()[3]) for l in (root/'files.qip').read_text().splitlines() if len(l.split())==4 and l.split()[2]=='SYSTEMVERILOG_FILE' and l.split()[3].startswith('rtl/mpeg2_new/')]
cmd=['verilator','--binary','--timing','-j','4','-CFLAGS','-O3','-Wno-fatal','-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT','-I'+str(root/'rtl/mpeg2_new'),'--top-module','tb_entry604_i_pts','--Mdir',str(out/'integrated_obj'),'-o','integrated',str(tb)]+files
(out/'integrated_compile_command.json').write_text(json.dumps(cmd,indent=2)+'\n');print('COMPILE opening/long/ceiling observer',flush=True)
with (out/'integrated_compile.log').open('w') as log:subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
fixture_map={f['name']:f for f in fixtures}
cases=[('opening','opening',0,301711,0,0,0),('long','long',0,301711,0,0,0),('long_pressure','long',0,301711,0,1000003,500),('ceiling_weave','ceiling',1,1961195,7967195,0,0),('ceiling_bob','ceiling',1,270754,6276754,0,0)]
def run(case):
 name,fixture,control,phase,first,busy_period,busy_length=case;f=fixture_map[fixture]
 cmd=[str(out/'integrated_obj/integrated'),f'+HEX={out}/{fixture}.hex',f'+LEN={f["bytes"]}',f'+PICTURES={f["frames"]}',f'+PTS_COUNT={f["timestamps"]}',f'+POSITIONS={out}/{fixture}_positions.hex',f'+TIMESTAMPS={out}/{fixture}_pts.hex',f'+REPORT={out}/{name}_events.csv',f'+METRICS={out}/{name}_metrics.csv',f'+CONTROL={control}',f'+PHASE={phase}',f'+FIRST_SWAP={first}',f'+BUSY_PERIOD={busy_period}',f'+BUSY_LENGTH={busy_length}']
 print('RUN '+name,flush=True);start=time.monotonic()
 with (out/(name+'.log')).open('w') as log:p=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 events=list(csv.DictReader((out/(name+'_events.csv')).open()));metrics=list(csv.DictReader((out/(name+'_metrics.csv')).open()));presents=[e for e in events if e['event']=='present']
 late=[int(e['picture']) for e in presents if int(e['picture'])>2 and int(e['interval'])>3003000]
 r={'case':name,'fixture':fixture,'source_commit':source,'command':cmd,'exit_code':p.returncode,'seconds':time.monotonic()-start,'completed':len(metrics),'presented':len(presents)+1,'expected':f['frames'],'missed_slots':late,'capacity_blocked_cycles':sum(int(m['capacity_blocked']) for m in metrics),'log_tail':(out/(name+'.log')).read_text()[-1500:]}
 (out/(name+'_result.json')).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['case','exit_code','seconds','completed','presented','missed_slots']}),flush=True)
 assert p.returncode==0 and len(metrics)==f['frames'] and len(presents)==f['frames']-1 and not late,r
 assert [int(e['picture']) for e in presents]==list(range(2,f['frames']+1))
 assert all(int(m['ack_count'])==8100 for m in metrics)
 if busy_period:assert r['capacity_blocked_cycles']>0
 return r
# Short recovery first, then independent longer/legacy cases alongside Quartus.
results=[run(cases[0])]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results+=list(pool.map(run,cases[1:]))
(out/'integrated_results.json').write_text(json.dumps({'source_commit':source,'all_passed':True,'cases':results,'scope':'Exact compressed video/PTS with real I reconstruction, writer, publication and scheduler; ideal source and modeled DDR/ticks/swap phase; physical audio/HPS/scaler/CDC excluded.'},indent=2)+'\n')
