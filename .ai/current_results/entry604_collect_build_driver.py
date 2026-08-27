from pathlib import Path
import hashlib,json,re,subprocess
work=Path('/home/vash/mister-builds/entry604/FPGA')
subprocess.run(['git','diff','--exit-code','HEAD'],cwd=work,check=True,capture_output=True)
run=json.loads((work/'entry604-build-run.json').read_text())
assert run.get('exit_code')==0,run
log=(work/'entry604-quartus.log').read_text()
summary=(work/'output_files/MediaPlayer.sta.summary').read_text()
rows=[]
for m in re.finditer(r"Type\s*:\s*(.*?)\nSlack\s*:\s*(-?\d+\.\d+)\nTNS\s*:\s*(-?\d+\.\d+)",summary):
 typ=m[1].strip();key=typ.split(" '")[0].lower().replace(' ','_')
 clock=typ.split(" '",1)[1].rstrip("'") if " '" in typ else None
 rows.append({'type':key,'clock':clock,'slack_ns':float(m[2]),'tns_ns':float(m[3])})
assert rows,summary
worst={key:min(r['slack_ns'] for r in rows if r['type']==key) for key in {r['type'] for r in rows}}
expected={'setup','hold','recovery','removal','minimum_pulse_width'}
assert set(worst)==expected,worst
positive=all(v>0 for v in worst.values()) and all(r['tns_ns']==0 for r in rows)
fit=(work/'output_files/MediaPlayer.fit.summary').read_text()
assert 'Fitter Status : Successful' in fit
qsf=(work/'MediaPlayer.qsf').read_text()
seed=re.search(r'set_global_assignment -name SEED (\d+)',qsf)
counts=re.findall(r'Quartus Prime Full Compilation was successful\. (\d+) errors?, (\d+) warnings?',log)
assert counts,log[-3000:]
resources={}
for key,pattern in {'alms':r'Logic utilization \(in ALMs\) : ([\d,]+)','registers':r'Total registers : ([\d,]+)','ram_bits':r'Total block memory bits : ([\d,]+)','ram_blocks':r'Total RAM Blocks : ([\d,]+)','dsp_blocks':r'Total DSP Blocks : ([\d,]+)'}.items():
 resources[key]=int(re.search(pattern,fit)[1].replace(',',''))
rbf=work/'output_files/MediaPlayer.rbf'
manifest={**run,'quartus_version':'17.0.2 Build 602 Lite','seed':int(seed[1]) if seed else None,'compile_success':True,'errors':int(counts[-1][0]),'warnings':int(counts[-1][1]),'timing_positive':positive,'worst_slack_ns':worst,'timing_rows':rows,'resources':resources,'rbf_bytes':rbf.stat().st_size,'rbf_sha256':hashlib.sha256(rbf.read_bytes()).hexdigest(),'report_sha256':{name:hashlib.sha256((work/name).read_bytes()).hexdigest() for name in ('entry604-quartus.log','output_files/MediaPlayer.sta.summary','output_files/MediaPlayer.fit.summary')}}
baseline_log=Path('/home/vash/mister-builds/entry599/FPGA/entry599-quartus.log').read_text(errors='replace')
filters=lambda s:set(re.findall(r'Ignored filter at [^:]+: (.*?) File:',s))
old_filters,new_filters=filters(baseline_log),filters(log)
manifest['ignored_timing_filters']=sorted(new_filters)
manifest['new_ignored_timing_filters']=sorted(new_filters-old_filters)
assert not manifest['new_ignored_timing_filters'],manifest['new_ignored_timing_filters']
manifest['tracked_build_source_unchanged']=True
(work/'entry604-build.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:manifest[k] for k in ('source_commit','elapsed_seconds','errors','warnings','seed','timing_positive','worst_slack_ns','resources','rbf_bytes','rbf_sha256')},indent=2))
assert positive,'Do not deploy a timing-failing image'
