#!/usr/bin/env python3
"""Prepare a local stream-copy DVD opening; never transcode or publish media.

Input is an already selected/extracted title VOB, not an ISO navigation claim.
The output is a test fixture, not a general DVD importer.
"""
from __future__ import annotations
import argparse,hashlib,json,subprocess
from pathlib import Path
from analyze_h262_compatibility import start_codes,payload_between,read_bits,parse_picture_header,parse_picture_coding_extension
from finalize_program_stream import finalize_program_stream

def run(args):
 return subprocess.run(args,check=True,capture_output=True).stdout

def digest(b):return hashlib.sha256(b).hexdigest()

def matrix_inventory(video):
 codes=start_codes(video);records=[];pic=-1
 for i,(offset,code) in enumerate(codes):
  if code==0:pic+=1
  payload=payload_between(video,codes,i)
  if code==0xb3: pos=62;count=2
  elif code==0xb5 and read_bits(payload,0,4)==3:pos=4;count=4
  else:continue
  record={'offset':offset,'preceding_picture':pic,'sequence_reset':code==0xb3,'loads':[]}
  for m in range(count):
   load=read_bits(payload,pos,1);pos+=1
   if load:
    weights=[read_bits(payload,pos+8*j,8) for j in range(64)];pos+=512
    if 0 in weights or (m%2==0 and weights[0]!=8) or m>=2:
     raise ValueError('invalid 4:2:0 matrix download')
    record['loads'].append({'matrix':m,'transmission_weights':weights,'sha256':digest(bytes(weights))})
  records.append(record)
 return records

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('vob',type=Path);p.add_argument('output',type=Path);p.add_argument('--seconds',type=float,default=12)
 a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 if a.seconds<=0:raise ValueError('positive duration required')
 base=['ffmpeg','-hide_banner','-loglevel','error','-nostdin','-y']
 out=a.output/'dvd_opening_original.mpg'
 run(base+['-i',str(a.vob),'-t',str(a.seconds),'-map','0:v:0','-map','0:a:0','-c','copy','-f','vob',str(out)])
 finalize_program_stream(out)
 video=run(base+['-i',str(out),'-map','0:v:0','-c','copy','-f','mpeg2video','pipe:1'])
 source=run(base+['-i',str(a.vob),'-t',str(a.seconds),'-map','0:v:0','-c','copy','-f','mpeg2video','pipe:1'])
 bare=lambda b:b[:-4] if b.endswith(b'\0\0\1\xb7') else b
 if bare(video)!=bare(source):raise RuntimeError('remux changed the selected elementary video')
 audio=run(base+['-i',str(out),'-map','0:a:0','-c','copy','-f','ac3','pipe:1'])
 source_audio=run(base+['-i',str(a.vob),'-t',str(a.seconds),'-map','0:a:0','-c','copy','-f','ac3','pipe:1'])
 if audio!=source_audio:raise RuntimeError('remux changed selected AC-3 bytes')
 es=a.output/'dvd_opening_original.m2v';es.write_bytes(video)
 (a.output/'dvd_opening_original.ac3').write_bytes(audio)
 # First coded I picture is an independent full intra reconstruction proof.
 codes=start_codes(video);pictures=[o for o,c in codes if c==0]
 first_end=pictures[1];first=video[:first_end]+b'\0\0\1\xb7'
 (a.output/'dvd_first_i.m2v').write_bytes(first)
 for name,data in [('dvd_first_i',first),('dvd_opening_original',video)]:
  (a.output/(name+'.hex')).write_text(data.hex('\n')+'\n')
 # Decode once with frame passthrough: no extra frames for repeat_first_field.
 for name,frames in [('dvd_first_i',1),('dvd_opening_original',None)]:
  cmd=base+['-err_detect','explode','-threads','1','-i',str(a.output/(name+'.m2v'))]
  if frames:cmd+=['-frames:v',str(frames)]
  raw=run(cmd+['-fps_mode','passthrough','-pix_fmt','yuv420p','-f','rawvideo','pipe:1'])
  (a.output/(name+'.yuv')).write_bytes(raw)
  (a.output/(name+'_pixels.hex')).write_text(raw.hex('\n')+'\n')
 probe=json.loads(run(['ffprobe','-v','error','-show_frames','-show_packets','-show_entries',
  'frame=pkt_pos,pict_type,repeat_pict,top_field_first:packet=pos,size','-of','json',str(es)]))
 events=probe['packets_and_frames'];packets=[x for x in events if x['type']=='packet'];frames=[x for x in events if x['type']=='frame']
 positions={int(x['pkt_pos']):i for i,x in enumerate(frames)}
 if len(positions)!=len(pictures) or len(packets)!=len(pictures):raise RuntimeError('nonbijective packet/frame oracle mapping')
 mapping=[positions[int(x['pos'])] for x in packets]
 if sorted(mapping)!=list(range(len(pictures))):raise RuntimeError('frame mapping is not a permutation')
 (a.output/'dvd_opening_map.hex').write_text(''.join(f'{i:08x}\n' for i in mapping))
 (a.output/'dvd_opening_frames.json').write_text(json.dumps(frames,indent=2)+'\n')
 report={'boundary':'selected VOB opening; no IFO navigation qualification','seconds_requested':a.seconds,
  'video_bytes':len(video),'video_sha256':digest(video),'original_video_preserved':True,
  'ac3_bytes':len(audio),'ac3_sha256':digest(audio),'original_ac3_preserved':True,
  'coded_pictures':len(pictures),'first_i_bytes':len(first),'first_i_sha256':digest(first),
  'matrices':matrix_inventory(video)}
 (a.output/'dvd_opening_inventory.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='matrices'},indent=2))
 print('matrix headers:',len(report['matrices']))
if __name__=='__main__':main()
