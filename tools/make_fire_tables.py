#!/usr/bin/env python3
"""Deterministic Hann/window, FFT twiddle and 32-band ROMs for Fire."""
from pathlib import Path
import math,argparse
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1]/'rtl'
edges=list(range(1,14))+[round(13*(128/13)**(i/20)) for i in range(1,21)]
assert len(edges)==33 and len(set(edges))==33 and edges[-1]==128
outputs={
 'media_fft_window.hex':''.join(f'{round(32767*(0.5-0.5*math.cos(2*math.pi*i/255))):04x}\n' for i in range(256)),
 'media_fft_twiddle.hex':''.join(f'{((round(32767*math.cos(-2*math.pi*i/256))&65535)<<16)|(round(32767*math.sin(-2*math.pi*i/256))&65535):08x}\n' for i in range(128)),
 'media_fft_band_end.hex':''.join(f'{v-1:02x}\n' for v in edges[1:])}
for name,data in outputs.items():
 if a.check:assert (root/name).read_text()==data,name
 else:(root/name).write_text(data)
print('FIRE_TABLES_PASS edges='+str(edges))
