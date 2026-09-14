#!/usr/bin/env python3
"""Generate an ASCII SRT for checking manual loading, pause and seek timing."""
from pathlib import Path
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path('results/subtitles/Subtitle Test.srt'));a=p.parse_args()
def stamp(s):return f'{s//3600:02}:{s//60%60:02}:{s%60:02},000'
a.output.parent.mkdir(parents=True,exist_ok=True)
text=''.join(f'{i+1}\n{stamp(t)} --> {stamp(t+4)}\nSubtitle at {stamp(t)[:8]}\nPause holds this cue; seek selects another.\n\n' for i,t in enumerate(range(0,3600,5)))
with a.output.open('x',encoding='ascii',newline='\n') as f:f.write(text)
print(a.output)
