#!/usr/bin/env python3
"""Compile and run the mixed I/P/B raster pixel oracle after timing changes."""
from pathlib import Path
import argparse
import re
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
stream=out/'mixed.m2v';oracle=out/'pixels.hex'
subprocess.run(['python3','tools/streams/generate_test_mixed_raster_soak.py',
    '--output',str(stream),'--oracle-output',str(oracle)],cwd=root,check=True)
sources=re.findall(r'-name SYSTEMVERILOG_FILE (rtl/mpeg2_new/\S+)',(root/'files.qip').read_text())
obj=out/'obj';obj.mkdir(exist_ok=True)
with (out/'compile.log').open('w') as log:
    subprocess.run(['verilator','--binary','--timing','-j','6','-Wno-fatal',
        '-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT','-Wno-CASEINCOMPLETE',
        '-Wno-BLKANDNBLK','+incdir+rtl/mpeg2_new','--top-module',
        'tb_h262_mixed_raster_pixels','--Mdir',str(obj),'-o','mixed',
        'tools/streams/tb_h262_mixed_raster_pixels.sv',
        'tools/streams/tb_h262_live_raster_soak.sv',*sources],
        cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
data=stream.read_bytes();hexfile=out/'mixed.hex'
hexfile.write_text(data.hex('\n')+'\n')
with (out/'run.log').open('w') as log:
    subprocess.run([str(obj/'mixed'),f'+HEX={hexfile}',f'+LEN={len(data)}',
        f'+PIXELS={oracle}'],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
print('PASS mixed I/P/B raster pixel oracle; evidence '+str(out/'run.log'))
