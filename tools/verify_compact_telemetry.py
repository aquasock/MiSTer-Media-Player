#!/usr/bin/env python3
"""Compare profiler profiles and decode actual compact overlay pixels."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
from PIL import Image

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('cadence',root/'tools/streams/decode_hardware_cadence.py')
dec=importlib.util.module_from_spec(spec);spec.loader.exec_module(dec)
binary=out/'profiler'
subprocess.run(['iverilog','-g2012','-s','tb_h262_hardware_cadence_profiler','-o',str(binary),
 'tools/streams/tb_h262_hardware_cadence_profiler.sv','rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv'],cwd=root,check=True)
log=subprocess.check_output(['vvp',str(binary),'+OVERLAY_PPM='+str(out/'compact.ppm')],cwd=root,text=True)
(out/'simulation.log').write_text(log)
assert 'HARDWARE_CADENCE_PROFILER_PASS' in log
snapshots=[[int(w,16) for w in line.split()[1:]] for line in log.splitlines() if line.startswith('COMPACT_WORDS')]
assert len(snapshots)>=8
img=Image.open(out/'compact.ppm');img.save(out/'compact.png')
assert dec.decode_words(out/'compact.png')==snapshots[0]
assert img.getpixel((179,383))==(18,52,86)
cli=subprocess.check_output(['python3','tools/streams/decode_hardware_cadence.py',str(out/'compact.png')],cwd=root,text=True)
assert 'unavailable' in cli
result=dec.decode(out/'compact.png')
assert result['telemetry_profile']=='compact' and result['snapshot_words']==25
assert result['audio_frames_decoded']==1250 and result['audio_samples_played']==1440000
assert result['transport_requests']==0x12345678
assert result['scheduler_flags'] is None and result['i_stall_cycles'] is None
assert len(result['largest_display_gaps'])==1
assert result['checksum']==snapshots[0][-1]
# Corruption of one actual cell must fail row parity, not produce a valid report.
bad=img.copy()
for y in range(281,285):
 for x in range(49,53):bad.putpixel((x,y),(255,255,255) if sum(img.getpixel((x,y)))<384 else (0,0,0))
bad.save(out/'corrupt.png')
try:dec.decode(out/'corrupt.png')
except dec.TelemetryDecodeError:pass
else:raise AssertionError('corrupt overlay accepted')
# Retained legacy layouts use the same line encoding. Exercise every supported
# origin, word count and checksum position, including schema 8/9 audio words.
def render(words,origin):
 im=Image.new('RGB',(720,max(480,origin+4*len(words))),(17,31,63))
 for row,word in enumerate(words):
  bits=[1,0,1,0]+[(row>>i)&1 for i in range(5,-1,-1)]+[(word>>i)&1 for i in range(31,-1,-1)]+[word.bit_count()&1]
  for col,bit in enumerate(bits):
   for y in range(origin+4*row,origin+4*row+4):
    for x in range(8+4*col,8+4*col+4):im.putpixel((x,y),(255,255,255) if bit else (0,0,0))
 return im
for version,count,origin in [(7,38,444),(8,41,432),(8,41,312),(9,49,280)]:
 words=[(i*0x1020304)&0xffffffff for i in range(count)]
 words[0]=dec.MAGIC;words[1]=(version<<24)|(count<<16)|60000
 words[-1]=0
 for w in words[:-1]:words[-1]^=w
 dest=out/f'legacy-{version}-{origin}.png';render(words,origin).save(dest)
 assert dec.decode_words(dest)==words
 parsed=dec.decode(dest)
 assert parsed['schema_version']==version and parsed['checksum']==words[-1]
 if version>=8:assert parsed['audio_frames_decoded']==words[37]
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS compact/detailed retained-field equivalence; actual RTL RGB screenshot decode; corrupt-cell rejection; schema 7/8/9 compatibility; unavailable counters explicit')
