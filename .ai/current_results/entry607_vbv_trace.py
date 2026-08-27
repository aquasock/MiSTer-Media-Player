"""Constant-arrival VBV occupancy trace over the parsed prefix, to test whether
the deterministic picture 692 slot coincides with the stream's VBV low point."""
import json,sys
from pathlib import Path
probe=json.load(open('/tmp/entry607_fixture_probe.json'))
SRC=Path('/tmp/entry605-capture/fixture.mpg')

# re-derive picture sizes over the whole parsed prefix using the probe's parser
sys.argv=['x',str(SRC)]
src=Path('/tmp/claude-1000/-run-media-vash-GIT-MiSTer-Media-Player/d4ee247f-b70f-4543-88f0-65bbea499d2f/scratchpad/entry607_fixture_probe.py').read_text()
g={'__name__':'probe'}
exec(src.split("rows=[]")[0],g)
v=bytes(g['vid']);pics=g['pics'];sizes=g['sizes'];FPS=g['FPS']

# sequence header: bit_rate_value (18b) and vbv_buffer_size_value (10b)
j=v.find(b'\x00\x00\x01\xb3')
h=v[j+4:j+12]
bit_rate=(h[4]<<10)|(h[5]<<2)|(h[6]>>6)
vbv=((h[6]&0x1F)<<5)|(h[7]>>3)
R=bit_rate*400
B=vbv*16*1024
occ=B; mn=(B,None); mx=(0,None); under=0; over=0; trace=[]
per=R/FPS
for k,d in enumerate(sizes):
    bits=d*8
    occ-=bits
    if occ<0: under+=1
    if occ<mn[0]: mn=(occ,k)
    occ+=per
    if occ>B: over+=1; occ=B
    if occ>mx[0]: mx=(occ,k)
    if 680<=k<=700: trace.append({'picture':k,'coded_bytes':d,'occupancy_bits_after_removal':round(occ-per,1),'fill_pct':round(100*(occ-per)/B,3)})
res={'bit_rate_value':bit_rate,'video_bit_rate':R,'vbv_buffer_size_value':vbv,'vbv_buffer_bits':B,
 'pictures_traced':len(sizes),'underflows':under,'overflow_clips':over,
 'min_occupancy_bits':mn[0],'min_occupancy_picture':mn[1],'min_fill_pct':round(100*mn[0]/B,3),
 'max_occupancy_bits':mx[0],'max_occupancy_picture':mx[1],
 'entry602_recorded_max_occupancy_bits':1834917.333,'entry602_recorded_vbv_bits':1835008,
 'bytes_per_second':R/8,'picture690_delivery_seconds':probe['largest_in_prefix'][0][0]/(R/8),
 'frame_period_s':1/FPS,'picture690_frame_periods_to_deliver':probe['largest_in_prefix'][0][0]/(R/8)*FPS,
 'trace_680_700':trace}
Path('/tmp/entry607_vbv_trace.json').write_text(json.dumps(res,indent=1)+'\n')
print(json.dumps({k:x for k,x in res.items() if k!='trace_680_700'},indent=1))
print('--- occupancy after removal ---')
for t in trace: print('%4d bytes=%7d fill=%7.3f%%'%(t['picture'],t['coded_bytes'],t['fill_pct']))
