from pathlib import Path
import re,json
base=Path('/home/vash/mister-builds/entry675'); old=Path('/home/vash/mister-builds/entry664/FPGA/output_files')
new=base/'FPGA/output_files'
def warnings(s):
 result=set()
 for line in s.splitlines():
  m=re.search(r'((?:Critical )?Warning) \((\d+)\): (.*)',line)
  if m:
   body=m[3].split(' File:')[0].strip().rstrip(';').strip()
   body=re.sub(r'(\.(?:sv|svh|v|vh|vhd|tdf|sdc))\([0-9]+\)',r'\1(LINE)',body)
   result.add(m[1]+' ('+m[2]+'): '+body)
 return result
report={}
for stage in ('map','fit','sta'):
 p=old/f'MediaPlayer.{stage}.rpt'; q=new/f'MediaPlayer.{stage}.rpt'
 if p.exists() and q.exists():
  before=warnings(p.read_text(errors='replace'));after=warnings(q.read_text(errors='replace'))
  report[stage]={'added':sorted(after-before),'removed':sorted(before-after),'baseline_count':len(before),'candidate_count':len(after)}
(base/'results/warning-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
