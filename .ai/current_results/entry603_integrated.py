from pathlib import Path
import hashlib,json,subprocess,sys,time
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');out=Path('/home/vash/mister-builds/entry603');out.mkdir(exist_ok=True)
sys.path.insert(0,str(root/'tools/streams'))
import check_media_compatibility as demux
import analyze_h262_compatibility as syntax
full=Path('/home/vash/mister-builds/entry602/bbb_full_480i_tff_av_10080kbps.mpg')
with full.open('rb') as f: prefix=f.read(6*1024*1024)
video,_,_=demux.demux_program_stream(prefix)
sequences=[offset for offset,code in syntax.start_codes(video) if code==0xb3]
assert len(sequences)>100
cut=sequences[100];video=video[:cut]+bytes.fromhex('000001b7')
helper=Path('/home/vash/mister-builds/entry602/media_player_helper.native')
p=subprocess.run([str(helper),'--protocol','1','--source','file:/run/media/vash/GIT/entry602-smoke.mpg','--pcm-out',str(out/'smoke_pcm.s16le')],capture_output=True,check=True)
(out/'prefix_helper.stderr').write_bytes(p.stderr)
clean=bytearray();pts=[];positions=[];i=0
while i<len(p.stdout):
 n=p.stdout.find(bytes.fromhex('000001b0'),i)
 if n<0:clean.extend(p.stdout[i:]);break
 clean.extend(p.stdout[i:n]);positions.append(len(clean));pts.append(int.from_bytes(p.stdout[n+4:n+9],'big')>>7);i=n+9
assert clean[:cut]==video[:-4], 'smoke/full encoded video prefix differs'
items=list(zip(positions,pts))[:100]
assert all(position<cut for position,_ in items)
assert len(items)==100
(out/'prefix.hex').write_text(''.join(f'{b:02x}\n' for b in video))
(out/'positions.hex').write_text(''.join(f'{p:08x}\n' for p,_ in items))
(out/'timestamps.hex').write_text(''.join(f'{p:09x}\n' for _,p in items))
(out/'prefix_identity.json').write_text(json.dumps({'full_program_sha256':'beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642','original_video_prefix_bytes':cut,'original_video_prefix_sha256':hashlib.sha256(video[:-4]).hexdigest(),'test_bytes':len(video),'test_sha256':hashlib.sha256(video).hexdigest(),'pictures':100,'timestamps':100,'smoke_and_full_video_prefix_exact':True,'test_change':'Only append sequence_end after the first 100 complete original access units.'},indent=2)+'\n')
s=(root/'.ai/current_results/entry598_integrated_observer.sv').read_text().replace('tb_entry598_i_cadence','tb_entry603_i_pts')
s=s.replace('33554432','8388608')
s=s.replace('integer use_writer=1,phase=1961195,busy_period=0,busy_length=0;', '''integer use_writer=1,phase=301711,busy_period=0,busy_length=0;
    integer control=0,metadata_index=0,clock_accum=0;
    reg metadata_valid=0,tick90=0;
    reg [32:0] metadata_pts=0;
    reg [31:0] metadata_positions[0:99];
    reg [32:0] metadata_values[0:99];
    wire candidate_valid,candidate_scratch,candidate_scratch_bank;
    wire [1:0] candidate_bank;
    wire [32:0] candidate_pts,stc;
    wire candidate_pts_valid,pts_active,pts_due,anchored;''')
s=s.replace('integer first_swap=7967195;', 'integer first_swap=0;')
s=s.replace('.timestamp_candidate_active(1\'b0)', '.timestamp_candidate_active(pts_active)')
s=s.replace('.timestamp_candidate_due(1\'b0)', '.timestamp_candidate_due(pts_due)')
s=s.replace('.native_ordinary_overlap_enable(1\'b1)', '.native_ordinary_overlap_enable(control!=2)')
s=s.replace('.cadence_slot_debug(cadence_slot));', '''.cadence_slot_debug(cadence_slot),.candidate_frame_valid(candidate_valid),
        .candidate_frame_scratch(candidate_scratch),.candidate_scratch_bank(candidate_scratch_bank),
        .candidate_frame_bank(candidate_bank));
    mpeg2_h262_picture_timestamp timestamps(
        .clk(clk),.reset(reset),.metadata_valid(metadata_valid),.metadata_pts(metadata_pts),
        .picture_coding_extension_valid(1'b0),.picture_top_field_first(1'b1),
        .picture_start(header_now),.picture_is_b(1'b0),.decode_scratch_bank(1'b0),
        .b_picture_complete(1'b0),.active_frame_bank(active_bank),
        .display_frame_bank(display_bank),.display_scratch(display_scratch),.display_scratch_bank(1'b0),
        .candidate_frame_valid(candidate_valid),.candidate_frame_scratch(candidate_scratch),
        .candidate_scratch_bank(candidate_scratch_bank),.candidate_frame_bank(candidate_bank),
        .candidate_pts(candidate_pts),.candidate_pts_valid(candidate_pts_valid));
    mpeg2_h262_pts_presentation_timeline timeline(
        .clk(clk),.reset(reset),.tick_90k(tick90),.metadata_valid(metadata_valid),.metadata_pts(metadata_pts),
        .candidate_valid(candidate_pts_valid),.candidate_pts(candidate_pts),.anchored(anchored),
        .stc_90k(stc),.candidate_active(pts_active),.candidate_due(pts_due));''')
s=s.replace('if (!$value$plusargs("HEX=%s",hex_path))', '''if($value$plusargs("CONTROL=%d",control))begin end
        $readmemh("/home/vash/mister-builds/entry603/positions.hex",metadata_positions);
        $readmemh("/home/vash/mister-builds/entry603/timestamps.hex",metadata_values);
        if (!$value$plusargs("HEX=%s",hex_path))''')
s=s.replace('if (stream_index<stream_len && parser_ready && !presentation_hold) begin', '''metadata_valid<=0;
            clock_accum=clock_accum+3;
            tick90=clock_accum>=2000;
            if(tick90)clock_accum=clock_accum-2000;
            if(control!=1 && metadata_index<100 && stream_index==metadata_positions[metadata_index])begin
                metadata_valid<=1;metadata_pts<=metadata_values[metadata_index];
                metadata_index=metadata_index+1;stream_valid<=0;
            end else if (stream_index<stream_len && parser_ready && !presentation_hold) begin''')
s=s.replace('if(syntax_error||probe_error||iq_error', '''if(scheduler.ordinary_secondary_valid && pts_active)
                $display("SECONDARY_PTS_GUARD cycle=%0d completed=%0d displayed=%0d active_bank=%0d display_bank=%0d pending_bank=%0d secondary_bank=%0d pts=%0d stc=%0d",total_cycles,completed,presented,active_bank,display_bank,scheduler.pending_frame_bank,scheduler.ordinary_secondary_bank,candidate_pts,stc);
            if(syntax_error||probe_error||iq_error''')
s=s.replace('presented==449','presented==100').replace('stores==449*8100','stores==100*8100').replace('completed!=449','completed!=100').replace('words!=449*64800','words!=100*64800').replace('headers!=449','headers!=100').replace('1200000000','400000000')
tb=out/'tb_entry603_i_pts.sv';tb.write_text(s)
files=[str(root/l.split()[3]) for l in (root/'files.qip').read_text().splitlines() if len(l.split())==4 and l.split()[2]=='SYSTEMVERILOG_FILE' and l.split()[3].startswith('rtl/mpeg2_new/')]
cmd=['verilator','--binary','--timing','-j','4','-CFLAGS','-O3','-Wno-fatal','-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT','-I'+str(root/'rtl/mpeg2_new'),'--top-module','tb_entry603_i_pts','--Mdir',str(out/'obj'),'-o','integrated',str(tb)]+files
(out/'integrated_compile_command.json').write_text(json.dumps(cmd,indent=2)+'\n')
print('Compiling exact 100-picture video/PTS-prefix observer',flush=True)
with (out/'integrated_compile.log').open('w') as log:subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
results=[]
for name,control in [('timestamped',0),('raw_control',1),('serialized_control',2)]:
 cmd=[str(out/'obj/integrated'),f'+HEX={out}/prefix.hex',f'+LEN={len(video)}',f'+REPORT={out}/{name}_events.csv',f'+METRICS={out}/{name}_metrics.csv',f'+CONTROL={control}']
 print('Running',name,flush=True);start=time.monotonic()
 with (out/(name+'.log')).open('w') as log:p=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 result={'case':name,'exit_code':p.returncode,'seconds':time.monotonic()-start,'command':cmd,'log_tail':(out/(name+'.log')).read_text()[-3500:]}
 results.append(result);print(json.dumps(result),flush=True)
 (out/'integrated_results.json').write_text(json.dumps({'cases':results,'scope':'Exact first 100 video access units and helper timestamps; real I pipeline/writer/publication/scheduler, ideal source/DDR, modeled exact 90kHz clock and swap phase; excludes PCM/HPS/scaler and physical timing.'},indent=2)+'\n')
