from pathlib import Path
import hashlib,json,subprocess
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');out=Path('/home/vash/mister-builds/entry604')
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip();assert source=='d466bed3031908b5f5ffa3360cf8a594d711a1cc'
scheduler=root/'rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv'
old=out/'old_scheduler.sv';old.write_bytes(subprocess.check_output(['git','show','f615ce0:rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv'],cwd=root))
unsafe=out/'unsafe_timestamp_scheduler.sv';text=scheduler.read_text();term='wire presentation_slot=cadence_slot&&\n                       (!timestamp_candidate_active||timestamp_candidate_due);';assert term in text
unsafe.write_text(text.replace(term,'wire presentation_slot=cadence_slot;'))
results=[]
for name,path,message in [('old_scheduler',old,'timestamped secondary completion'),('unsafe_timestamp_gate',unsafe,'future PTS presented early')]:
 cmd=['iverilog','-g2012','-s','tb_native_ordinary_pts_ownership','-o',str(out/name),str(path),str(root/'rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv'),str(root/'rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv'),str(root/'tools/streams/tb_native_ordinary_overlap_ownership.sv')]
 with (out/(name+'_compile.log')).open('w') as log:subprocess.run(cmd,check=True,stdout=log,stderr=subprocess.STDOUT)
 p=subprocess.run(['vvp',str(out/name)],capture_output=True)
 (out/(name+'_negative.log')).write_bytes(p.stdout+p.stderr)
 assert p.returncode!=0 and message.encode() in p.stdout,p.stdout+p.stderr
 results.append({'case':name,'expected_failure':message,'returncode':p.returncode,'output':p.stdout.decode()})
print(json.dumps(results),flush=True)
(out/'negative_controls.json').write_text(json.dumps({'source_commit':source,'all_expected_failures_observed':True,'cases':results},indent=2)+'\n')
