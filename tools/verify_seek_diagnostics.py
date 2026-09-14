#!/usr/bin/env python3
"""First-fault retention and actual RTL screenshot decode regression."""
from pathlib import Path
import json
import subprocess
from PIL import Image
from streams.decode_hardware_cadence import decode, TelemetryDecodeError
ROOT=Path(__file__).resolve().parents[1]
subprocess.run(['iverilog','-g2012','-s','test_media_seek_diagnostics','-o','/tmp/seek-diag-test',
 'tools/test_media_seek_diagnostics.sv','rtl/media_seek_diagnostics.sv'],cwd=ROOT,check=True)
subprocess.run(['vvp','/tmp/seek-diag-test'],cwd=ROOT,check=True)
im=Image.open('/tmp/seek-diagnostic.ppm');im.save('/tmp/seek-diagnostic.png')
r=decode('/tmp/seek-diagnostic.png');d=r['seek_diagnostics']
assert r['telemetry_profile']=='seek_only'
assert d['words']==[int(w,16) for w in Path('/tmp/seek-diagnostic-words.hex').read_text().split()]
assert d['elapsed_q']==0x512345678 and d['target_q']==0x623456789
assert d['display_pts']==0x198765432 and d['video_ram_words']==12345
assert d['audio_ram_bytes']==123 and d['pcm_write_domain_used']==4096
assert d['ingress_reservoir_min']==42 and d['error_flags']==4
assert d['entry_errors']==0 and d['reason']=='error_after_seek_entry'
assert im.getpixel((364,280))==(18,52,86) and im.getpixel((192,336))==(18,52,86)
# Vendor used-word counters need not encode zero when full; the full flag wins.
full_words=d['words'].copy();full_words[9]|=4095;full_words[-1]=0
for w in full_words[:-1]:full_words[-1]^=w
full=im.copy()
for row in (9,13):
 word=full_words[row]
 bits=[1,0,1,0]+[(row>>i)&1 for i in range(5,-1,-1)]+[(word>>i)&1 for i in range(31,-1,-1)]+[word.bit_count()&1]
 for col,bit in enumerate(bits):
  for y in range(280+row*4,284+row*4):
   for x in range(192+col*4,196+col*4):full.putpixel((x,y),(255,255,255) if bit else (0,0,0))
full.save('/tmp/seek-diagnostic-full.png')
assert decode('/tmp/seek-diagnostic-full.png')['seek_diagnostics']['pcm_write_domain_used']==4096
for y in (293,294):
 for x in (233,234):
  im.putpixel((x,y),(255,255,255) if sum(im.getpixel((x,y)))<384 else (0,0,0))
im.save('/tmp/seek-diagnostic-corrupt.png')
try:decode('/tmp/seek-diagnostic-corrupt.png')
except TelemetryDecodeError:pass
else:raise AssertionError('corrupt seek snapshot accepted')
Path('/tmp/seek-diagnostic-result.json').write_text(json.dumps(r,indent=2)+'\n')
print('PASS first-fault retention, seek stall/paused seek, actual RTL RGB decode, queue/timestamp fields, corrupt-cell rejection')
