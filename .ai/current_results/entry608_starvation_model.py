"""Read-ahead starvation model: does buffer depth plus consumption-paced
delivery predict exactly the missed slots the hardware measured?"""
import json,struct
from pathlib import Path
SRC=Path('/tmp/entry605-capture/fixture.mpg')
FPS=30000/1001.0
VIDEO_RATE=1_200_000.0            # bytes/s, from the declared 9.6 Mbit/s
FRAME_BYTES=VIDEO_RATE/FPS        # 40,040
STREAM_FIFO=32768                 # rtl/mpeg2_stream_fifo.sv  16384 x 16 bit
CLEAN_QUEUE=65536                 # mpeg2_h262_clean_video_queue.sv VIDEO_DEPTH x 8 bit
BUF=STREAM_FIFO+CLEAN_QUEUE

buf=SRC.open('rb').read();n=len(buf);pos=0;vcum=0;carry=b'';offs=[]
while pos+4<=n:
    if buf[pos:pos+3]!=b'\x00\x00\x01': pos+=1;continue
    sc=buf[pos+3]
    if sc==0xBA: pos+=14+(buf[pos+13]&7);continue
    if sc==0xB9: break
    if pos+6>n: break
    plen=struct.unpack('>H',buf[pos+4:pos+6])[0]
    if 0xC0<=sc<=0xEF:
        hdl=buf[pos+8];start=pos+9+hdl;payload=plen-3-hdl
        if payload<0 or start+payload>n: break
        if 0xE0<=sc<=0xEF:
            chunk=carry+buf[start:start+payload];base=vcum-len(carry);i=0
            while True:
                j=chunk.find(b'\x00\x00\x01\x00',i)
                if j<0: break
                offs.append(base+j);i=j+4
            carry=chunk[-3:];vcum+=payload
        pos+=6+plen;continue
    pos+=6+plen if plen else 4
sizes=[offs[k+1]-offs[k] for k in range(len(offs)-1)]

# A picture larger than the buffer must stream in while it is being decoded.
# Decode must finish inside one frame period, so the slot is missed when
#   (size - BUF) / VIDEO_RATE  >  one frame period
threshold=BUF+FRAME_BYTES
over=[{'picture':k,'coded_bytes':s,
       'stream_in_during_decode_s':(s-BUF)/VIDEO_RATE,
       'predicted_starvation_ms':round(((s-BUF)/VIDEO_RATE-1/FPS)*1000,3)}
      for k,s in enumerate(sizes) if s>threshold]
ranked=sorted(((s,k) for k,s in enumerate(sizes)),reverse=True)[:6]
res={
 'stream_fifo_bytes':STREAM_FIFO,'clean_video_queue_bytes':CLEAN_QUEUE,
 'read_ahead_bytes':BUF,'read_ahead_frame_periods':round(BUF/FRAME_BYTES,4),
 'frame_bytes_at_declared_rate':FRAME_BYTES,'miss_threshold_bytes':threshold,
 'pictures':len(offs),'pictures_over_threshold':len(over),'over_threshold':over,
 'largest_pictures':[{'picture':k,'coded_bytes':s,'margin_to_threshold':round(threshold-s,1)} for s,k in ranked],
 'observed_missed_slots_per_run':1,
 'observed_missed_slot_picture':692,
 'observed_starvation_ms':{'weave':677670/60e6*1000,'bob':699593/60e6*1000},
 'runner_up_margin_bytes':round(threshold-ranked[1][0],1),
 'prior_hypothesis_window_frame_periods':[3.118,3.754],
 'prior_hypothesis_falsified':True,
 'helper_delivery_us':{'median_gap':11463,'p99_gap':20986,'max_gap':41289,'gaps_over_buffer_drain':0},
}
Path('/tmp/entry608_starvation_model.json').write_text(json.dumps(res,indent=1)+'\n')
print(json.dumps(res,indent=1))
