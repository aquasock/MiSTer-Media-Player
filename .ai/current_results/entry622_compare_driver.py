import numpy as np, json, sys
from pathlib import Path
A=Path('/home/vash/mister-builds/entry622/helper.s16le')
B=Path('/home/vash/mister-builds/entry622/reference.s16le')
CH=4_000_000  # int16 elements per chunk, ~8 MB
n=0; sh=sr=shh=srr=shr=sdd=0.0; mx=0
fa=A.open('rb'); fb=B.open('rb')
while True:
    a=np.fromfile(fa,dtype='<i2',count=CH)
    b=np.fromfile(fb,dtype='<i2',count=CH)
    m=min(len(a),len(b))
    if m==0: break
    a=a[:m].astype(np.float64); b=b[:m].astype(np.float64)
    d=a-b
    n+=m; sh+=a.sum(); sr+=b.sum(); shh+=(a*a).sum(); srr+=(b*b).sum()
    shr+=(a*b).sum(); sdd+=(d*d).sum(); mx=max(mx,int(np.abs(d).max()))
    if m<CH: break
fa.close(); fb.close()
mh=sh/n; mr=sr/n
cov=shr/n-mh*mr; vh=shh/n-mh*mh; vr=srr/n-mr*mr
res={'samples_compared':n,'frames_compared':n//2,
     'helper_bytes':A.stat().st_size,'reference_bytes':B.stat().st_size,
     'seconds':n/2/48000,
     'max_abs_difference':mx,'rms_difference':(sdd/n)**0.5,
     'rms_helper':(shh/n)**0.5,'rms_reference':(srr/n)**0.5,
     'correlation':cov/((vh*vr)**0.5)}
print(json.dumps(res,indent=2))
Path('/home/vash/mister-builds/entry622/compare.json').write_text(json.dumps(res,indent=2)+'\n')
