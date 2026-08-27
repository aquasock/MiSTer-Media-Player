"""Offline probe of the deterministic missed display slot at picture 692.

Parses the Program Stream prefix, rebuilds the video elementary stream with a
byte-exact map back to pack SCRs, then reports coded picture sizes and
arrival-versus-display margin around the observed starvation point.
"""
import json,struct,sys
from pathlib import Path

SRC=Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/entry605-capture/fixture.mpg')
LIMIT=40*1024*1024          # PS prefix: covers well past picture 692
FOCUS=692
HZ=90000.0
FPS=30000/1001.0

buf=SRC.open('rb').read(LIMIT)
n=len(buf)
pos=0
vid=bytearray()
segs=[]            # (video_cum_start, length, scr_seconds, ps_offset)
audio_bytes=0
pack_count=0
mux_rates=set()
last_scr=None
scr_regress=0
while pos+4<=n:
    if buf[pos:pos+3]!=b'\x00\x00\x01':
        pos+=1; continue
    sc=buf[pos+3]
    if sc==0xBA:
        if pos+14>n: break
        b=buf[pos+4:pos+14]
        scr=(((b[0]>>3)&3)<<30)|((b[0]&3)<<28)|(b[1]<<20)|(((b[2]>>3)&0x1F)<<15)|((b[2]&3)<<13)|(b[3]<<5)|((b[4]>>3)&0x1F)
        ext=((b[4]&3)<<7)|(b[5]>>1)
        scr_s=(scr*300+ext)/(27_000_000.0)
        mux=(b[6]<<14)|(b[7]<<6)|(b[8]>>2)
        mux_rates.add(mux)
        if last_scr is not None and scr_s<last_scr: scr_regress+=1
        last_scr=scr_s
        pack_count+=1
        pos+=14+(buf[pos+13]&7)
        continue
    if sc==0xB9: break
    if pos+6>n: break
    plen=struct.unpack('>H',buf[pos+4:pos+6])[0]
    if sc in (0xBB,0xBE,0xBD) or (0xBC<=sc<=0xBF):
        pos+=6+plen; continue
    if 0xC0<=sc<=0xEF:
        if pos+9>n: break
        hdl=buf[pos+8]
        start=pos+9+hdl
        payload=plen-3-hdl
        if payload<0 or start+payload>n: break
        if 0xE0<=sc<=0xEF:
            segs.append((len(vid),payload,last_scr,pos))
            vid+=buf[start:start+payload]
        else:
            audio_bytes+=payload
        pos+=6+plen; continue
    pos+=4

# picture start codes in the rebuilt elementary stream
pics=[]
i=0
v=bytes(vid)
while True:
    j=v.find(b'\x00\x00\x01\x00',i)
    if j<0: break
    pics.append(j); i=j+4
sizes=[pics[k+1]-pics[k] for k in range(len(pics)-1)]

def arrival_scr(voff):
    """SCR of the pack carrying video byte voff (last byte of that pack's payload)."""
    lo,hi=0,len(segs)-1
    while lo<hi:
        mid=(lo+hi+1)//2
        if segs[mid][0]<=voff: lo=mid
        else: hi=mid-1
    return segs[lo][2]

rows=[]
for k in range(max(0,FOCUS-40),min(len(sizes),FOCUS+41)):
    start=pics[k]; end=pics[k+1]
    a_first=arrival_scr(start); a_last=arrival_scr(end-1)
    rows.append({'picture':k,'coded_bytes':sizes[k],'video_offset':start,
                 'arrival_first_s':a_first,'arrival_last_s':a_last,
                 'arrival_span_s':a_last-a_first,
                 'display_s':k/FPS,
                 'margin_s':k/FPS-a_last})
mean=sum(sizes[:len(sizes)])/len(sizes)
window=[r['coded_bytes'] for r in rows]
res={
 'source':str(SRC),'ps_prefix_bytes':n,'packs':pack_count,'mux_rate_values':sorted(mux_rates),
 'scr_regressions':scr_regress,'video_bytes_parsed':len(vid),'audio_bytes_parsed':audio_bytes,
 'pictures_parsed':len(pics),'mean_coded_bytes_prefix':mean,
 'observed_deadline_video_bytes':{'weave':27772349,'bob':27778070},
 'picture_at_weave_deadline':max(k for k in range(len(pics)) if pics[k]<=27772349),
 'picture_at_bob_deadline':max(k for k in range(len(pics)) if pics[k]<=27778070),
 'focus':FOCUS,
 'focus_coded_bytes':sizes[FOCUS],
 'focus_rank_in_prefix':sorted(sizes,reverse=True).index(sizes[FOCUS])+1,
 'largest_in_prefix':sorted(((s,k) for k,s in enumerate(sizes)),reverse=True)[:10],
 'window_min':min(window),'window_max':max(window),
 'min_margin_row':min(rows,key=lambda r:r['margin_s']),
 'rows':rows,
}
Path('/tmp/entry607_fixture_probe.json').write_text(json.dumps(res,indent=1)+'\n')
print(json.dumps({k:v for k,v in res.items() if k!='rows'},indent=1))
print('--- pictures 685..700 ---')
for r in rows:
    if 685<=r['picture']<=700:
        print('%4d bytes=%7d arrive_last=%9.4f display=%9.4f margin=%+8.4f'%(r['picture'],r['coded_bytes'],r['arrival_last_s'],r['display_s'],r['margin_s']))
