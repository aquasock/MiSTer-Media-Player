#!/usr/bin/env python3
"""Fast RTL/FFmpeg audio regression, with deterministic generated fixtures."""
import json, subprocess, tempfile, sys
from pathlib import Path
import numpy as np
from mp2_fixtures import frame
ROOT=Path(__file__).resolve().parents[1]
def run(*args):
    r=subprocess.run([str(a) for a in args],cwd=ROOT,check=True,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    return r.stdout
with tempfile.TemporaryDirectory(prefix='mp2-verify-') as d:
    d=Path(d); sim=d/'sim';report=[]
    run('verilator','--binary','--timing','-j','8','-Wno-fatal','--top-module','test_mp2_decoder','--Mdir',sim,
        'tools/test_mp2_decoder.sv','rtl/audio/mp2_decoder.sv','rtl/audio/mp2_synthesis.sv')
    def verify(name,data):
        src=d/(name+'.mp2'); src.write_bytes(data); ref=d/(name+'.pcm');out=d/(name+'.txt')
        run('ffmpeg','-v','error','-i',src,'-f','s16le','-y',ref)
        log=run(sim/'Vtest_mp2_decoder','+input='+str(src),'+output='+str(out))
        x=np.loadtxt(out); y=np.tile(np.fromfile(ref,'<i2').reshape(-1,2).astype(float),(2,1))
        assert x.shape==y.shape,(name,x.shape,y.shape)
        maximum=float(np.max(abs(x-y))); noise=float(np.sum((x-y)**2)); power=float(np.sum(y*y))
        snr=10*np.log10(power/noise) if noise else None
        assert maximum<=2,(name,maximum,snr)
        row=dict(name=name,samples_per_session=len(y)//2,max_sample_error=maximum,snr_db=snr,sessions=2)
        print(json.dumps(row),flush=True);report.append(row)
    verify('all-17-quantizers',b''.join(frame(q,seed=q) for q in range(1,18)))
    verify('joint-stereo-all-bounds',b''.join(frame(5,mode=1,extension=i,seed=i) for i in range(4)))
    for rate in (112,192,320,384):
        src=d/'encoded.mp2'
        run('ffmpeg','-v','error','-f','lavfi','-i','aevalsrc=0.23*sin(2*PI*997*t)|0.19*sin(2*PI*1553*t):s=48000:d=0.12',
            '-c:a','mp2','-b:a',str(rate)+'k','-y',src)
        verify('tone-'+str(rate),src.read_bytes())
    src=d/'noise.mp2'
    run('ffmpeg','-v','error','-f','lavfi','-i','anoisesrc=color=white:amplitude=0.7:seed=127:s=48000:d=0.12',
        '-f','lavfi','-i','anoisesrc=color=pink:amplitude=0.6:seed=251:s=48000:d=0.12',
        '-filter_complex','[0:a][1:a]amerge=inputs=2[a]','-map','[a]','-c:a','mp2','-b:a','320k','-y',src)
    verify('noise-320',src.read_bytes())
    silence=bytearray(frame(1));silence[4:]=b'\0'*(len(silence)-4)
    verify('unallocated-silence',bytes(silence)*2)
    base=bytearray(frame(1))
    bad={
        'bad-sync': bytes([0])+base[1:],
        'crc-not-supported':base[:1]+bytes([base[1]&~1])+base[2:],
        'sample-rate-not-supported':base[:2]+bytes([base[2]&~12])+base[3:],
        'free-format-not-supported':base[:2]+bytes([base[2]&15])+base[3:],
        'truncated-header':base[:3],
        'truncated-frame':base[:-1],
    }
    for name,data in bad.items():
        src=d/(name+'.mp2');src.write_bytes(data)
        log=run(sim/'Vtest_mp2_decoder','+input='+str(src),'+output='+str(d/'bad.txt'),'+expect_error=1')
        assert 'EXPECTED MP2 ERROR PASS' in log
        print(name+' rejected',flush=True)
    if len(sys.argv)>1:Path(sys.argv[1]).write_text(json.dumps({'audio_quality':report,'rejected':list(bad)},indent=2)+'\n')
