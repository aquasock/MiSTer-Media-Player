from pathlib import Path
import sys,json,hashlib,re,bisect
root=Path('/run/media/vash/GIT/MiSTer-Media-Player')
base=Path('/home/vash/mister-builds/entry686')
sys.path.insert(0,str(root/'tools/streams'))
from analyze_arm_av_transport import analyze_inband

def parse(path):
 data=path.read_bytes();mask=bytearray(data);pos=0;records=[];total=0;video=0;pts=[];audio=bytearray()
 while pos<len(data):
  mark=data.find(b'\x00\x00\x01',pos)
  if mark<0:video+=len(data)-pos;break
  video+=mark-pos
  code=data[mark+3]
  if code==0xb1:
   n=(data[mark+4]>>2) or 1;end=mark+5+n*4
   mask[mark+5:end]=bytes(n*4)
   audio.extend(data[mark+5:end]);total+=n
   records.append((mark,end,total,video,n));pos=end
  elif code==0xb0:
   pts.append((mark,video,int.from_bytes(data[mark+4:mark+9],'big')>>7,total));pos=mark+9
  elif code==0xb6:pos=mark+4
  else:video+=1;pos=mark+1
 with path.open('rb') as f:s=analyze_inband(f,48000)
 s.update({'masked_sha256':hashlib.sha256(mask).hexdigest(),'pts':pts,'first_records':records[:3]})
 return data,records,s,audio

h,hr,hs,ha=parse(base/'output/hdmi.transport')
s,sr,ss,sa=parse(base/'output/spdif.transport')
print('SUMMARY HDMI',json.dumps(hs))
print('SUMMARY SPDIF',json.dumps(ss))
assert hr==sr
print('SCHEDULE_BYTE_IDENTICAL',hs['masked_sha256']==ss['masked_sha256'])
ends=[r[1] for r in sr];counts=[0]+[r[2] for r in sr]
report={'hdmi':hs,'spdif':ss,'same_record_positions':hr==sr,'same_masked_stream':hs['masked_sha256']==ss['masked_sha256'],'logs':{}}
for name in ['arm_helper','spdif_previous','spdif_repeat']:
 text=(base/'input'/f'{name}.log').read_text();events=[]
 for line in text.splitlines():
  if ' transfer event=' in line:
   v={k:int(n) for k,n in re.findall(r'(\w+)=(\d+)',line)}
   if v['t']<3500000:events.append(v)
 result=[]
 for us in [20000,30000,50000,100000,250000,500000,1000000,1500000,1600000,1700000,1800000,1900000,2000000,2500000,3000000]:
  candidates=[e for e in events if e['t']<=us]
  if not candidates:continue
  e=candidates[-1];pcm=counts[bisect.bisect_right(ends,e['submitted'])]
  result.append({'at':us,'event_t':e['t'],'submitted':e['submitted'],'carrier_submitted':pcm,'carrier_minus_time_samples':pcm-int((e['t']-30000)*.048)})
 report['logs'][name]=result
 print(name,json.dumps(result))
(base/'output/compare.json').write_text(json.dumps(report,indent=2)+'\n')
(base/'output/pcm_records.json').write_text(json.dumps(sr)+'\n')
