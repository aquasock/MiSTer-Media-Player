#!/usr/bin/env python3
"""Compile and run the mixed I/P/B raster pixel oracle after timing changes."""
from pathlib import Path
import argparse
import re
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--playback-controls',action='store_true')
parser.add_argument('--display-ownership',action='store_true')
parser.add_argument('--disable-display-release',action='store_true')
parser.add_argument('--seek-eof',action='store_true')
parser.add_argument('--eof-control',action='store_true')
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
        'tb_h262_mixed_raster_pixels',
        '-GEOF_CONTROL_MODE='+str(int(args.eof_control)),
        '-GDISPLAY_OWNERSHIP_MODE='+str(int(args.display_ownership)),
        '-GSEEK_DISPLAY_RELEASE='+str(int(not args.disable_display_release)),
        '-GPLAYBACK_CONTROL_MODE='+str(2 if args.seek_eof else int(args.playback_controls)),
        'rtl/media_playback_control.sv','rtl/media_eof_control.sv','rtl/video_config_cdc.sv','--Mdir',str(obj),'-o','mixed',
        'tools/streams/tb_h262_mixed_raster_pixels.sv',
        'tools/streams/tb_h262_live_raster_soak.sv',*sources],
        cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
data=stream.read_bytes();hexfile=out/'mixed.hex'
hexfile.write_text(data.hex('\n')+'\n')
with (out/'run.log').open('w') as log:
    subprocess.run([str(obj/'mixed'),f'+HEX={hexfile}',f'+LEN={len(data)}',
        f'+PIXELS={oracle}'],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
text=(out/'run.log').read_text()
if 'MIXED_RASTER_PIXEL_PASS' not in text:raise RuntimeError('reconstruction did not complete; inspect run.log')
if (args.playback_controls or args.seek_eof) and 'PLAYBACK RECONSTRUCTION PASS' not in text:raise RuntimeError('seek did not complete')
if args.eof_control and 'EOF MIXED DRAIN PASS' not in text:raise RuntimeError('EOF drain did not complete')
print('PASS mixed I/P/B raster pixel oracle; evidence '+str(out/'run.log'))
