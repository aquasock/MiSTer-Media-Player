"""Single-pass whole-film VBV trace: is picture 691 the global low point?"""
import json,struct
from pathlib import Path
SRC=Path('/tmp/entry605-capture/fixture.mpg')
FPS=30000/1001.0
pic_offsets=[];vcum=0;carry=b''
buf=SRC.open('rb').read()
n=len(buf);pos=0;packs=0
while pos+4<=n:
    if buf[pos:pos+3]!=b'\x00\x00\x01': pos+=1;continue
    sc=buf[pos+3]
    if sc==0xBA:
        packs+=1;pos+=14+(buf[pos+13]&7);continue
    if sc==0xB9: break
    if pos+6>n: break
    plen=struct.unpack('>H',buf[pos+4:pos+6])[0]
    if 0xC0<=sc<=0xEF:
        hdl=buf[pos+8];start=pos+9+hdl;payload=plen-3-hdl
        if payload<0 or start+payload>n: break
        if 0xE0<=sc<=0xEF:
            chunk=carry+buf[start:start+payload]
            base=vcum-len(carry)
            i=0
            while True:
                j=chunk.find(b'\x00\x00\x01\x00',i)
                if j<0: break
                pic_offsets.append(base+j);i=j+4
            carry=chunk[-3:];vcum+=payload
        pos+=6+plen;continue
    pos+=6+plen if plen else 4
sizes=[pic_offsets[k+1]-pic_offsets[k] for k in range(len(pic_offsets)-1)]
R=9600000;B=1835008;per=R/FPS
occ=B;mn=(B,None);under=0;low=[]
for k,d in enumerate(sizes):
    occ-=d*8
    if occ<0: under+=1
    if occ<mn[0]: mn=(occ,k)
    if occ<0.20*B: low.append({'picture':k,'coded_bytes':d,'fill_pct':round(100*occ/B,3)})
    occ=min(B,occ+per)
res={'video_bytes':vcum,'packs':packs,'pictures':len(pic_offsets),'sizes_traced':len(sizes),
 'expected_pictures_entry602':17876,'expected_video_bytes_entry602':715713077,
 'video_bytes_exact':vcum==715713077,'pictures_exact':len(pic_offsets)==17876,
 'largest_pictures':sorted(((s,k) for k,s in enumerate(sizes)),reverse=True)[:5],
 'mean_coded_bytes':round(sum(sizes)/len(sizes),1),
 'underflows':under,'global_min_fill_pct':round(100*mn[0]/B,3),'global_min_picture':mn[1],
 'global_min_bits':mn[0],'hardware_missed_slot_picture':692,
 'pictures_below_20pct':len(low),'below_20pct':low[:40],
 'pictures_below_15pct':sum(1 for x in low if x['fill_pct']<15)}
Path('/tmp/entry607_full_vbv.json').write_text(json.dumps(res,indent=1)+'\n')
print(json.dumps(res,indent=1)[:2600])
