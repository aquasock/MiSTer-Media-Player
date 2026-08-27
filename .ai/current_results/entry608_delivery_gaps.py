"""Time-domain helper delivery gaps for both hardware runs. The helper demuxes
on the HPS, so its submitted counter is video plus PCM plus metadata and cannot
be indexed by program-stream file offsets; this works in wall time instead."""
import gzip,re,json,statistics
from pathlib import Path
RES=Path('/run/media/vash/GIT/MiSTer-Media-Player/.ai/current_results')
BUF=98304;VIDEO_RATE=1_200_000.0
out={'read_ahead_bytes':BUF,'buffer_drain_ms_at_declared_rate':BUF/VIDEO_RATE*1000,'runs':{}}
for tag,f in (('weave_entry605','entry605_arm_helper.log.gz'),('bob_entry606','entry606_arm_helper.log.gz')):
    rows=[]
    with gzip.open(RES/f,'rt',errors='replace') as fh:
        for line in fh:
            m=re.match(r't=(\d+) read event=(\d+) count=(\d+) submitted=(\d+)',line)
            if m: rows.append((int(m.group(1)),int(m.group(4))))
    gaps=[rows[i][0]-rows[i-1][0] for i in range(1,len(rows))]
    s=sorted(gaps,reverse=True)
    win=[r for r in rows if 22_000_000<=r[0]<=24_000_000]
    wg=sorted(((win[i][0]-win[i-1][0],win[i][0]) for i in range(1,len(win))),reverse=True)[:5]
    out['runs'][tag]={'reads':len(rows),'transport_bytes':rows[-1][1],
      'mean_transport_rate_bps':rows[-1][1]/(rows[-1][0]/1e6),
      'median_gap_us':statistics.median(gaps),'p99_gap_us':s[len(s)//100],'max_gap_us':s[0],
      'gaps_over_30ms':sum(1 for x in gaps if x>30000),
      'gaps_over_buffer_drain':sum(1 for x in gaps if x>BUF/VIDEO_RATE*1e6),
      'window_22_24s_top_gaps':[{'gap_us':g,'at_s':t/1e6} for g,t in wg]}
Path('/tmp/entry608_delivery_gaps.json').write_text(json.dumps(out,indent=1)+'\n')
print(json.dumps(out,indent=1))
