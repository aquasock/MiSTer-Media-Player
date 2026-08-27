from pathlib import Path
import re,json,hashlib
base=Path('/home/vash/mister-builds/entry604');work=base/'FPGA'
old=Path('/home/vash/mister-builds/entry599/FPGA/entry599-quartus.log').read_text(errors='replace')
new=(work/'entry604-quartus.log').read_text(errors='replace')
def warnings(s):
 result=set()
 for l in s.splitlines():
  if re.match(r'\s*(?:Critical )?Warning \(',l):
   l=l.strip().split(' File:')[0]
   l=re.sub(r'\([0-9]+\):', '(:', l) if False else l
   l=re.sub(r'(\.[svhtdf]+)\([0-9]+\)',r'\1(LINE)',l)
   result.add(l)
 return result
added=sorted(warnings(new)-warnings(old));removed=sorted(warnings(old)-warnings(new))
r={'baseline_source':'f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4','source_commit':'d466bed3031908b5f5ffa3360cf8a594d711a1cc','normalization':'Drop source path/line suffix; replace HDL line numbers in warning body. Retain message IDs and signal names.','added':added,'removed':removed}
(base/'warning-comparison.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
