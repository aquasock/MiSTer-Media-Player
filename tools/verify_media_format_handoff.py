#!/usr/bin/env python3
"""Exercise actual top-level handoff expressions with the production session/arbiter."""
from pathlib import Path
import argparse,re,subprocess
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path('results/format-handoff'));a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
top=(root/'MediaPlayer_top_00.svh').read_text();arb=(root/'MediaPlayer_top_06.svh').read_text().split('mpeg2_h262_ddram_arbiter #',1)[1]
mode=re.search(r'always @\(posedge clk_mpeg2\)begin\n if\(reset_mpeg2_base\)media_music_mode<=0;.*?\nend',top,re.S).group()
(out/'handoff_mode.svh').write_text(mode+'\n')
ports='\n'.join(re.search(r'\.'+name+r'\s*\([^)]*\)',arb).group()+',' for name in ['quiesce','ddram_busy','ddram_dout_ready'])+'\n'
for legacy in [False,True]:
 (out/'handoff_ports.svh').write_text(ports.replace('(DDRAM_BUSY)','(DDRAM_BUSY||media_music_mode)') if legacy else ports)
 name='legacy' if legacy else 'fixed'
 with (out/(name+'-compile.log')).open('w') as log:
  subprocess.run(['iverilog','-g2012','-I'+str(out),'-s','test_media_format_handoff','-o',str(out/name),'tools/test_media_format_handoff.sv','rtl/media_session_control.sv','rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv'],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run(['vvp',str(out/name)],capture_output=True,text=True,timeout=30)
 (out/(name+'.log')).write_text(r.stdout+r.stderr);print(name+': '+r.stdout)
 if legacy:assert r.returncode!=0 and 'handoff stalled target=0 mode=1' in r.stdout
 else:r.check_returncode();assert 'PASS format handoff' in r.stdout
(out/'handoff_ports.svh').write_text(ports)
