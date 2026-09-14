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
font='// 5x7 glyphs from DVD-era player and the approved overlay preview.\n'+'\n'.join(f'{v:02x}' for v in rows)+'\n'
values=[]
for scale in (4,6,9):
 for dx in range(1024):
  gx=dx*4//scale
  values.append(((gx//6)<<3)|(gx%6) if gx<384 else 7)
coordinates='// Synchronous glyph coordinate map: scale 1, 1.5, 2.25; 1024 entries each.\n'+'\n'.join(f'{v:03x}' for v in values)+'\n'
for name,data in [('media_overlay_font.hex',font),('media_overlay_coordinates.hex',coordinates)]:
 path=root/'rtl'/name
 if a.check:
  if path.read_text()!=data:raise SystemExit(f'{path} differs from generator')
 else:path.write_text(data)
print('OVERLAY_ROM_PASS' if a.check else 'Overlay ROMs generated')
