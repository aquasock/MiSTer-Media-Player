from pathlib import Path
import json,subprocess
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');out=Path('/home/vash/mister-builds/entry603');out.mkdir(exist_ok=True)
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert source.startswith('ded2ddc')
files=['mpeg2_h262_b_presentation_scheduler.sv','mpeg2_h262_picture_timestamp.sv','mpeg2_h262_pts_presentation_timeline.sv']
command=['iverilog','-g2012','-s','entry603_pts_repro','-o',str(out/'repro'),'/tmp/entry603_pts_repro.sv']+[str(root/'rtl/mpeg2_new'/f) for f in files]
p=subprocess.run(command,capture_output=True);(out/'compile.stdout').write_bytes(p.stdout);(out/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
results=[]
for n in (0,1,2):
 p=subprocess.run(['vvp',str(out/'repro'),f'+CONTROL={n}'],capture_output=True)
 (out/f'control{n}.log').write_bytes(p.stdout+p.stderr)
 assert p.returncode==0,p.stdout+p.stderr
 print(p.stdout.decode(),flush=True)
 results.append({'control':n,'exit_code':p.returncode,'output':p.stdout.decode()})
(out/'reproduction.json').write_text(json.dumps({'source_commit':source,'production_sources_unmodified':True,'compile_command':command,'controls':results,'scope':'Real production timestamp ownership, timeline and scheduler with authored publication/header events; no compressed decoder, PCM, physical DDR or exact hardware-cycle replay.'},indent=2)+'\n')
