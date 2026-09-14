#!/usr/bin/env python3
"""Deterministic endpoint tests plus optional real MPEG comparison to ffprobe."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('results/ui-overlay/duration'));p.add_argument('--media',type=Path);a=p.parse_args();o=a.output.resolve();o.mkdir(parents=True,exist_ok=True)
subprocess.run(['iverilog','-g2012','-s','test_media_duration_window','-o',str(o/'sim'),'tools/test_media_duration_window.sv','rtl/media_duration_window.sv','rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv'],check=True)
pack=bytes.fromhex('000001ba2100010001801b91')
def timestamp(n):
 n%=1<<33
 return bytes([0x21|((n>>29)&14),(n>>22)&255,((n>>14)&254)|1,(n>>7)&255,((n<<1)&254)|1])
def pes(data,pts):
 header=timestamp(pts) if pts is not None else b'\x0f'
 return pack+b'\0\0\1\xe0'+(len(header)+len(data)).to_bytes(2,'big')+header+data
sequence=bytes.fromhex('000001b32d01e014000001b5148a00010000')
picture=bytes.fromhex('000001000008ffff000001b5811113800000010123456789')
def run(name,data,origin=None,valid=None,end=None):
 data=data[-4194304:];f=o/(name+'.hex');f.write_text(data.hex('\n')+'\n')
 cmd=['vvp',str(o/'sim'),f'+HEX={f}',f'+LEN={len(data)}']
 if origin is not None:cmd.append(f'+ORIGIN={origin}')
 if valid is not None:cmd.append(f'+VALID={valid}')
 if end is not None:cmd.append(f'+END={end}')
 r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(o/(name+'.log')).write_text(r.stdout)
 print(name,r.stdout.strip());r.check_returncode()
origin=45000
stream=b''.join(pes((sequence if i==0 else b'')+picture,origin+n*3003) for i,n in enumerate([0,3,1,2,6,4,5]))
run('reordered',stream,origin,1,7*12012)
run('head',stream)
run('missing_final_pts',stream+pes(picture,None),origin,0)
run('truncated_pes',stream[:-8],origin,0)
run('raw',sequence+picture,origin,0)
bad=bytearray(stream);bad[18]&=254
run('bad_pts_marker',bytes(bad),origin,0)
wrap=(1<<33)-6006
run('wrap',b''.join(pes((sequence if i==0 else b'')+picture,wrap+n*3003) for i,n in enumerate([0,3,1,2])),wrap,1,4*12012)
run('ambiguous',pes(sequence+picture,origin+(1<<32)+1),origin,0)
if a.media:
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_packets','-show_entries','packet=pts,duration','-of','json',str(a.media)]))['packets']
 from fractions import Fraction
 first=int(probe[0]['pts']);end=max(int(x['pts'])+int(x['duration']) for x in probe)-first
 rate=Fraction(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=r_frame_rate','-of','default=nw=1:nk=1',str(a.media)],text=True).strip())
 endq=(max(int(x['pts']) for x in probe)-first)*4+int(Fraction(360000,1)/rate)
 run('real',a.media.read_bytes(),first,1,endq)
reader_sources=['rtl/media_duration_probe.sv','rtl/media_duration_window.sv','rtl/media_file_reader.sv','rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv']
subprocess.run(['iverilog','-g2012','-s','test_media_duration_reader','-o',str(o/'reader'),'tools/test_media_duration_reader.sv',*reader_sources],check=True)
r=subprocess.run(['vvp',str(o/'reader'),f'+HEX={o/"reordered.hex"}',f'+LEN={len(stream)}'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(o/'reader.log').write_text(r.stdout);print(r.stdout);r.check_returncode()
print('UI_DURATION_PASS')
