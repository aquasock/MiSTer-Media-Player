#!/usr/bin/env python3
"""Verify synthesis history recovery after compressed audio seek bypass."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import numpy as np
from mp2_fixtures import frame

root = Path(__file__).resolve().parents[1]
def run(*args):
    return subprocess.check_output([str(a) for a in args], cwd=root,
        stderr=subprocess.STDOUT, text=True)

report = []
with tempfile.TemporaryDirectory(prefix='mp2-seek-') as directory:
    d = Path(directory)
    run('verilator', '--binary', '--timing', '-j', '6', '-Wno-fatal',
        '--top-module', 'test_mp2_decoder', '--Mdir', d/'obj',
        'tools/test_mp2_decoder.sv', 'rtl/audio/mp2_decoder.sv',
        'rtl/audio/mp2_synthesis.sv')
    fixtures = {
        'quantizers': b''.join(frame(q, seed=q) for q in range(1,18)),
        'joint-stereo': b''.join(frame(5, mode=1, extension=i%4, seed=i) for i in range(20)),
    }
    for name, data in fixtures.items():
        src = d/(name+'.mp2')
        src.write_bytes(data)
        baseline = d/(name+'-baseline.txt')
        run(d/'obj/Vtest_mp2_decoder', '+input='+str(src), '+output='+str(baseline))
        full = np.loadtxt(baseline).reshape(2, -1, 2)
        # Direct seek can start inside the preceding compressed audio frame.
        # Invalid sync-like prefixes must not become a decoder failure.
        for prefix in (b'\x12', b'\x00\xff\xfb\x00\x00\xff\xfd\x00\x00' + b'\x55'*573, data[:4]+b'\x55'*1600):
            partial = d/(name+'-partial.mp2')
            partial.write_bytes(prefix+data)
            out = d/(name+'-resync.txt')
            log = run(d/'obj/Vtest_mp2_decoder', '+input='+str(partial),
                '+output='+str(out), '+start_sync=1')
            actual = np.loadtxt(out).reshape(2, -1, 2)
            assert np.array_equal(actual, full)
            report.append(dict(fixture=name, discarded_prefix_bytes=len(prefix),
                resynchronized_pcm_exact=True, sessions=2))
        for origin in ('15f90', '1ffffd000'):
            out = d/(name+'-'+origin+'.txt')
            log = run(d/'obj/Vtest_mp2_decoder', '+input='+str(src),
                '+output='+str(out), '+seek_frame=10', '+pts_origin='+origin)
            actual = np.loadtxt(out).reshape(2, -1, 2)
            # Frames 0..8 bypassed, frame 9 restores history, frame 10 starts
            # the requested output. Compare both independent reset sessions.
            assert actual.shape[1] == full.shape[1]-9*1152
            assert np.array_equal(actual[:,1152:], full[:,10*1152:])
            report.append(dict(fixture=name, pts_origin=origin,
                bypassed_frames=9, preroll_frames=1, sessions=2,
                resumed_pcm_exact=True))
            print(log, flush=True)
result = {'seek_audio_history': report}
print(json.dumps(result, indent=2))
if len(sys.argv)>1:
    Path(sys.argv[1]).write_text(json.dumps(result, indent=2)+'\n')
