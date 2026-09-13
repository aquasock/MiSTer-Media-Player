#!/usr/bin/env python3
"""Generate matching progressive 601/709 color clips and a 709 clip with no tag."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--seconds',type=int,default=4)
a=p.parse_args()
if a.seconds<1:p.error('--seconds must be positive')
out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
# Blocks share RGB values and primaries/transfer signaling in both files;
# only the YCbCr matrix differs. Wide flat patches make comparisons easy.
colors=[(220,32,32),(32,220,32),(32,32,220),(32,220,220),(220,32,220),
        (220,220,32),(64,180,96),(32,32,32),(224,224,224)]
skin=[(70,43,32),(105,66,48),(145,94,69),(183,128,96),(219,168,133),
      (238,199,164),(128,128,128),(16,16,16),(235,235,235)]
frame=bytearray()
for y in range(480):
 for x in range(720):
  if y<240:rgb=colors[x//80]
  elif y<360:rgb=skin[x//80]
  else:rgb=(round((x//16)*255/44),)*3
  frame.extend(rgb)
manifest={'source_rgb_sha256':hashlib.sha256(frame).hexdigest(),'files':{},
          'expected':'Auto: 01 and 02 approximately match. 03 needs forced BT.709; Auto falls back to BT.601.',
          'scope':'Matrix comparison only; all clips signal the same RGB primaries/transfer. No gamut/gamma processing.'}
with tempfile.TemporaryDirectory(prefix='color-clips-') as tmp:
 raw=Path(tmp)/'patches.rgb';raw.write_bytes(frame)
 for name,matrix in [('01_color_601','smpte170m'),('02_color_709','bt709')]:
  dest=out/(name+'.m2v')
  subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-stream_loop','-1',
   '-f','rawvideo','-pixel_format','rgb24','-video_size','720x480','-framerate','30000/1001',
   '-i',str(raw),'-frames:v',str(a.seconds*30),'-an',
   '-vf',f'scale=out_color_matrix={matrix}:out_range=tv,format=yuv420p',
   '-c:v','mpeg2video','-threads','1','-flags','+bitexact','-g','12','-bf','2',
   '-q:v','2','-maxrate','8000k','-bufsize','1835008','-aspect','16:9',
   '-colorspace',matrix,'-color_primaries','bt709','-color_trc','bt709',
   '-color_range','tv','-f','mpeg2video',str(dest)],check=True)
 tagged=(out/'02_color_709.m2v').read_bytes()
 starts=list(re.finditer(b'\x00\x00\x01',tagged));untagged=bytearray();removed=0
 for i,m in enumerate(starts):
  unit=tagged[m.start():starts[i+1].start() if i+1<len(starts) else len(tagged)]
  if len(unit)>=12 and unit[3]==0xb5 and unit[4]>>4==2 and unit[4]&1:
   # Retain video_format and the display-size fields, remove only the three
   # description bytes. The compressed pictures remain byte-identical.
   unit=unit[:4]+bytes([unit[4]&0xfe])+unit[8:];removed+=1
  untagged.extend(unit)
 if not removed:raise RuntimeError('Encoder emitted no color-description extension')
 (out/'03_color_709_untagged.m2v').write_bytes(untagged)
 manifest['description_extensions_removed']=removed
for f in sorted(out.glob('0[123]_color_*.m2v')):
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries',
 'stream=width,height,field_order,color_space,color_range,color_primaries,color_transfer',
 '-of','json',str(f)],text=True))
 manifest['files'][f.name]={'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'probe':info}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(out/'README.txt').write_text('''Use the MediaPlayer core with the color-matrix correction. Audio test Off.
Keep the same aspect ratio and filters for all comparisons.

1. Set Color matrix to Auto. Compare 01_color_601 and 02_color_709.
   The patches should look nearly the same; small encoding differences are possible.
2. On 02_color_709, force BT.601, then BT.709. The latter is correct.
   Look at the green and red patches and the middle-row skin-tone patches.
   The bottom grayscale steps should stay essentially unchanged.
3. Play 03_color_709_untagged. Auto uses the 601 compatibility fallback.
   Force BT.709 to restore the intended colors.
4. Open the OSD and switch matrices/filters during playback. Check for seams,
   flicker or playback interruptions, then load 01 again and restore Auto.

These clips test matrix conversion, not display calibration or gamut/gamma processing.
The 03 file has the same compressed pictures as 02; only color descriptions are removed.
''')
print('Created color-matrix test clips in '+str(out))
