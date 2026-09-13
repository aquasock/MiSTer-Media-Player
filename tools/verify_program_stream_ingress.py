#!/usr/bin/env python3
"""Exercise stock-file ingress against synthetic packets and FFmpeg extraction.

Optional arguments are local .mpg files. They are read, never modified.
Requires Icarus Verilog and FFmpeg; generated fixtures live in a temporary folder.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / 'rtl/mpeg2_new'
END = bytes.fromhex('000001b7')

def run(*args):
    subprocess.run([str(a) for a in args], check=True, cwd=ROOT)

def packet(code, body):
    return bytes((0, 0, 1, code)) + len(body).to_bytes(2, 'big') + body

with tempfile.TemporaryDirectory(prefix='mmp-ingress-') as tmp:
    work = Path(tmp)
    bench = work / 'ingress'
    run('iverilog', '-g2012', '-s', 'test_program_stream_ingress', '-o', bench,
        ROOT/'tools/test_program_stream_ingress.sv', RTL/'mpeg2_program_stream_ingress.sv',
        RTL/'mpeg2_h262_program_stream_demux.sv', RTL/'mpeg2_h262_inband_metadata.sv')
    unit = work/'unit'
    run('iverilog', '-g2012', '-s', 'test_program_stream_demux', '-o', unit,
        ROOT/'tools/test_program_stream_demux.sv', RTL/'mpeg2_h262_program_stream_demux.sv')
    run('vvp', unit)

    def replay(name, data, expected):
        source = work/(name+'.input'); oracle = work/(name+'.expected')
        source.write_bytes(data); oracle.write_bytes(expected)
        print(name, flush=True)
        run('vvp', bench, '+INPUT='+str(source), '+EXPECTED='+str(oracle))

    for length in (0, 1, 2, 3, 4, 5, 4097):
        data = bytes(i % 251 for i in range(length))
        replay('raw-'+str(length), data, data)
    # Legal payload boundaries may divide an elementary start code anywhere.
    # A second video stream must be skipped rather than mixed into the first.
    pack = bytes.fromhex('000001ba210001000180a833')
    video = bytes.fromhex('000001b32d01e034') + bytes(range(32))*30 + END
    chunks = [video[:1],video[1:3],video[3:400],video[400:]]
    stream = pack
    for chunk in chunks:
        stream += packet(0xe0, b'\x0f'+chunk)
        stream += packet(0xc0, b'\x0f'+bytes(range(64)))
        stream += packet(0xe1, b'\x0fDO NOT MIX VIDEO TRACKS')
    replay('legacy-split-tracks-end', stream+bytes.fromhex('000001b9')+b'\0', video)
    replay('legacy-no-sequence-end', pack+packet(0xe0,b'\x0f'+video[:-4]), video)
    replay('legacy-audio-only', pack+packet(0xc0,b'\x0fAUDIO'), b'')
    # No-timestamp MPEG-2 PES and a pack with two stuffing bytes.
    pack2 = bytes.fromhex('000001ba4400040004010189c3fa')+b'\xff\xff'
    replay('mpeg2-pack', pack2+packet(0xe0,b'\x80\0\0'+video[:-4]), video)

    for index, filename in enumerate(sys.argv[1:]):
        source=Path(filename).resolve(); oracle=work/f'real-{index}.m2v'
        run('ffmpeg','-hide_banner','-loglevel','error','-y','-i',source,
            '-map','0:v:0','-c:v','copy','-f','mpeg2video',oracle)
        expected=oracle.read_bytes()
        if not expected.endswith(END): expected+=END
        replay('real-'+str(index),source.read_bytes(),expected)
    print('PASS: ingress byte fidelity, stalls, stream selection, EOF and restart')
