#!/usr/bin/env python3
"""Generate fixed-point ROMs; window values derived from MIT PL_MPEG (see reference)."""
from pathlib import Path
import numpy as np
from mp2_model import tables, LEVELS
out=Path(__file__).resolve().parents[1]/'rtl/audio'
m,w=tables()
def save(name,values,width):
    (out/name).write_text(''.join(f'{int(v)&((1<<width)-1):0{(width+3)//4}x}\n' for v in values))
save('mp2_cos.hex',np.rint(m.flatten()*65536),18)
save('mp2_window.hex',np.rint(w*65536),18)
save('mp2_scale.hex',[round(4*2**(-sf/3)/LEVELS[q]*(1<<30)) if q and sf!=63 else 0 for q in range(18) for sf in range(64)],31)
