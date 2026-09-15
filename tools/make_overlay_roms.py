#!/usr/bin/env python3
"""Reproduce the UI glyph and coordinate ROMs; --check verifies committed data."""
from pathlib import Path
import argparse,json,re
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1]
preview=(root/'docs/ui/overlay-preview.html').read_text()
glyphs=json.loads(re.search(r'const glyphs=(\{.*?\});',preview).group(1))
rows=[]
for code in range(256):rows+=glyphs.get(chr(code),[0]*7)+[0]
font='// 5x7 glyphs from DVD-era player and the approved overlay preview.\n'+'\n'.join(f'{v:05b}' for v in rows)+'\n'
values=[]
for scale in (4,8,12):
 for dx in range(2048 if scale==12 else 1024):
  gx=dx*4//scale
  values.append(((gx//6)<<3)|(gx%6) if gx<384 else 7)
coordinates='// Synchronous glyph coordinate map: scale 1, 2, 3; 1024, 1024, 2048 entries.\n'+'\n'.join(f'{v:09b}' for v in values)+'\n'
blend_rg='// Dark palette alpha 160/255: red then green byte tables.\n'+'\n'.join(f'{(v*95+c*160)//255:02x}' for c in (24,27) for v in range(256))+'\n'
blend_b='// Dark palette alpha 160/255: blue byte table.\n'+'\n'.join(f'{(v*95+32*160)//255:02x}' for v in range(256))+'\n'
for name,data in [('media_overlay_font.mem',font),('media_overlay_coordinates.mem',coordinates),('media_overlay_blend_rg.hex',blend_rg),('media_overlay_blend_b.hex',blend_b)]:
 path=root/'rtl'/name
 if a.check:
  if path.read_text()!=data:raise SystemExit(f'{path} differs from generator')
 else:path.write_text(data)
print('OVERLAY_ROM_PASS' if a.check else 'Overlay ROMs generated')
