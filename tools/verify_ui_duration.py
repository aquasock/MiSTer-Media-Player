#!/usr/bin/env python3
"""Deterministic endpoint tests plus optional real MPEG comparison to ffprobe."""
import argparse,json,subprocess,re
from fractions import Fraction
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('results/ui-overlay/duration'));p.add_argument('--media',type=Path,action='append',default=[]);a=p.parse_args();o=a.output.resolve();o.mkdir(parents=True,exist_ok=True)
subprocess.run(['iverilog','-g2012','-s','test_media_duration_window','-o',str(o/'sim'),'tools/test_media_duration_window.sv','rtl/media_duration_window.sv','rtl/media_duration_timeline.sv','rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv'],check=True)
pack=bytes.fromhex('000001ba2100010001801b91')
def timestamp(n):
 n%=1<<33
 return bytes([0x21|((n>>29)&14),(n>>22)&255,((n>>14)&254)|1,(n>>7)&255,((n<<1)&254)|1])
def pes(data,pts):
 header=timestamp(pts) if pts is not None else b'\x0f'
 return pack+b'\0\0\1\xe0'+(len(header)+len(data)).to_bytes(2,'big')+header+data
sequence=bytes.fromhex('000001b32d01e014000001b5148a00010000')
def picture(tr=0,kind=1):
 return b'\0\0\1\0'+((tr<<6)|(kind<<3)).to_bytes(2,'big')+bytes.fromhex('ffff000001b5811113800000010123456789')
def run(name,data,origin=None,valid=None,end=None):
 data=data[-4194304:];f=o/(name+'.hex');f.write_text(data.hex('\n')+'\n')
 cmd=['vvp',str(o/'sim'),f'+HEX={f}',f'+LEN={len(data)}']
 if origin is not None:cmd.append(f'+ORIGIN={origin}')
 if valid is not None:cmd.append(f'+VALID={valid}')
 if end is not None:cmd.append(f'+END={end}')
 r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(o/(name+'.log')).write_text(r.stdout)
 print(name,r.stdout.strip(),flush=True);r.check_returncode()
 return {k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',r.stdout.splitlines()[0])}
origin=45000
stream=b''.join(pes((sequence if i==0 else b'')+picture(n,1 if n==0 else 2 if n%3==0 else 3),origin+n*3003) for i,n in enumerate([0,3,1,2,6,4,5]))
run('reordered',stream,origin,1,7*12012)
run('head',stream)
run('missing_final_pts',stream+pes(picture(7,2),None),origin,1,8*12012)
run('truncated_pes',stream[:-8],origin,0)
run('raw',sequence+picture(),origin,0)
bad=bytearray(stream);bad[18]&=254
run('bad_pts_marker',bytes(bad),origin,0)
wrap=(1<<33)-6006
run('wrap',b''.join(pes((sequence if i==0 else b'')+picture(n,1 if n==0 else 2 if n==3 else 3),wrap+n*3003) for i,n in enumerate([0,3,1,2])),wrap,1,4*12012)
run('ambiguous',pes(sequence+picture(),origin+(1<<32)+1),origin,0)
gop=bytes.fromhex('000001b800080040')
order=[0,3,1,2,6,4,5]
for rate_code,period in [(1,15015),(2,15000),(3,14400),(4,12012),(5,12000)]:
 seq=bytearray(sequence);seq[7]=(seq[7]&240)|rate_code
 # One PTS covers multiple reordered pictures; the last coded B is not the
 # presentation endpoint. Quantized timestamps can differ by three q-ticks.
 sparse=pes(bytes(seq)+gop+b''.join(picture(n,1 if n==0 else 2 if n%3==0 else 3) for n in order),origin)
 run(f'sparse_rate{rate_code}',sparse,origin,1,7*period)
 run(f'unstamped_next_group_rate{rate_code}',sparse+pes(gop+picture(2,1)+picture(0,3)+picture(1,3)+picture(3,2),None),origin,1,11*period)
run('no_timestamp_anchor',pes(sequence+gop+picture(0)+picture(1,2),None),origin,0)
run('conflicting_anchor',stream+pes(picture(7,2),origin+7*3003+100),origin,0)
run('truncated_picture',stream+pes(b'\0\0\1\0\0',None),origin,0)
run('missing_final_slice',stream+pes(picture(7,2)[:8],None),origin,0)
# A B-picture anchor arrives after an unannotated future reference; infer
# that earlier-coded reference's endpoint from its temporal reference.
late=pes(sequence+gop+picture(0),None)+pes(picture(3,2),None)+pes(picture(1,3),origin+3003)+pes(picture(2,3),None)
run('late_b_anchor',late,origin,1,4*12012)
run('open_first_group',pes(sequence+gop+picture(2),origin)+pes(picture(0,3)+picture(1,3),None),origin,1,12012)
# No GOP header is required at TR modulo wrap. The post-wrap P is followed
# by B-pictures from before and after the wrap in presentation order.
wrap_tr=pes(sequence+picture(1020),origin)+pes(picture(0,2)+picture(1021,3)+picture(1022,3)+picture(1023,3)+picture(3,2)+picture(1,3)+picture(2,3),None)
run('temporal_reference_wrap',wrap_tr,origin,1,8*12012)
# PES boundaries can split the picture prefix; a newer PTS arriving inside
# that prefix belongs to the NEXT start code, not the split picture.
for split in (1,2,3):
 pic=picture(3,2)
 data=pes(sequence+gop+picture(0)+pic[:split],origin)+pes(pic[split:]+picture(1,3)+picture(2,3),origin+3003)
 run(f'split_prefix_{split}',data,origin,1,4*12012)
# Existing unsupported/malformed evidence must remain unknown.
seq_interlaced=bytearray(sequence);seq_interlaced[sequence.index(b'\0\0\1\xb5')+5]&=~8
run('interlaced_sequence',pes(bytes(seq_interlaced)+picture(),origin),origin,0)
seq_extended=bytearray(sequence);seq_extended[sequence.index(b'\0\0\1\xb5')+9]|=1
run('extended_rate',pes(bytes(seq_extended)+picture(),origin),origin,0)
repeat_picture=bytearray(picture());repeat_picture[repeat_picture.index(b'\0\0\1\xb5')+7]|=2
run('repeat_first_field',pes(sequence+bytes(repeat_picture),origin),origin,0)
seq_changed=bytearray(sequence);seq_changed[7]=(seq_changed[7]&240)|3
run('mixed_rate',stream+pes(bytes(seq_changed)+gop+picture(),origin+7*3003),origin,0)
for media_index,media in enumerate(a.media):
 name=f'real{media_index}'
 with media.open('rb') as f:
  head=f.read(65536);f.seek(max(0,media.stat().st_size-4194304));tail=f.read(4194304)
 h=run(name+'_head',head)
 assert h['origin_valid']==1, f'{media}: no head timestamp; expected unknown fallback'
 first=h['first']
 tail_file=o/(name+'_tail.mpg');tail_file.write_bytes(tail)
 # Decode only the bounded tail for an independent display-order oracle.
 # ffprobe best_effort_timestamp reconstructs timestamps omitted in PES.
 frames=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-select_streams','v:0','-show_frames','-show_entries','frame=best_effort_timestamp:stream=r_frame_rate','-of','json',str(tail_file)]))
 rate=Fraction(frames['streams'][0]['r_frame_rate'])
 # ffprobe can leave the final reference frame untimestamped. Its decoded
 # display order still provides an independent frame count after the last
 # available timestamp, without relying on the RTL's temporal-reference math.
 timed=[(i,int(x['best_effort_timestamp'])) for i,x in enumerate(frames['frames']) if 'best_effort_timestamp' in x]
 assert timed, f'{media}: independent timestamp anchor unavailable'
 last_index,last=timed[-1]
 endq=((last-first)%(1<<33))*4+(len(frames['frames'])-last_index)*int(Fraction(360000,1)/rate)
 result=run(name+'_tail',tail,first,1)
 assert abs(result['end']-endq)<=4, f'{media}: RTL {result["end"]}, independent endpoint {endq}'
 (o/(name+'_comparison.json')).write_text(json.dumps({'file':str(media.resolve()),'head_bytes':len(head),'tail_bytes':len(tail),'origin':first,'frame_rate':str(rate),'expected_end_q':endq,'actual_end_q':result['end'],'difference_q':result['end']-endq},indent=2)+'\n')
 print('REAL_DURATION_PASS',media,'seconds',result['end']/360000,flush=True)
reader_sources=['rtl/media_duration_probe.sv','rtl/media_duration_window.sv','rtl/media_duration_timeline.sv','rtl/media_file_reader.sv','rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv']
subprocess.run(['iverilog','-g2012','-s','test_media_duration_reader','-o',str(o/'reader'),'tools/test_media_duration_reader.sv',*reader_sources],check=True)
r=subprocess.run(['vvp',str(o/'reader'),f'+HEX={o/"reordered.hex"}',f'+LEN={len(stream)}'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(o/'reader.log').write_text(r.stdout);print(r.stdout);r.check_returncode()
print('UI_DURATION_PASS')
