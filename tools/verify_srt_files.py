#!/usr/bin/env python3
"""Compare complete UTF-8 SRT files against the production streaming parser."""
from pathlib import Path
import argparse,subprocess,re,json,hashlib
p=argparse.ArgumentParser(description=__doc__);p.add_argument('files',nargs='+',type=Path);p.add_argument('--output',type=Path,default=Path('results/srt-files'));a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
subprocess.run(['iverilog','-g2012','-s','test_srt_file','-o',str(out/'sim'),'tools/test_srt_file.sv','rtl/media_srt_parser.sv'],cwd=root,check=True)
translation=str.maketrans({'\u2018':"'",'\u2019':"'",'\u2013':'-','\u2014':'-','\u201c':'"','\u201d':'"'})
pattern=re.compile(r'^(\d\d):(\d\d):(\d\d),(\d\d\d) --> (\d\d):(\d\d):(\d\d),(\d\d\d)')
results=[]
for index,path in enumerate(a.files):
 raw=path.read_bytes();text=raw.decode('utf-8-sig');words=[];cues=0
 for block in re.split(r'\n\s*\n',text.replace('\r','')):
  lines=block.splitlines()
  for n,line in enumerate(lines):
   m=pattern.match(line)
   if not m:continue
   nums=list(map(int,m.groups()));times=[]
   for i in (0,4):
    h,mi,se,ms=nums[i:i+4];assert mi<60 and se<60
    times.append(((h*60+mi)*60*1000+se*1000+ms)*360)
   assert times[1]>times[0]
   content=[]
   for row in lines[n+1:n+3]:
    row=re.sub(r'<[^>]*>','',row).translate(translation).replace('\t',' ')
    content.append(''.join(c if 32<=ord(c)<=126 else '?' for c in row)[:63])
   content=(content+['',''])[:2]
   if any(content):
    words+=times+[len(row) for row in content]+[ord(c) for row in content for c in row];cues+=1
   break
 assert cues>0 and len(raw)+1<=262144 and len(words)<=262144
 inp=out/f'{index}-input.hex';exp=out/f'{index}-expected.hex'
 inp.write_text(''.join(f'{v:03x}\n' for v in raw)+'100\n');exp.write_text(''.join(f'{v:010x}\n' for v in words))
 r=subprocess.run(['vvp',str(out/'sim'),f'+INPUT={inp}',f'+EXPECTED={exp}',f'+BYTES={len(raw)+1}',f'+WORDS={len(words)}',f'+CUES={cues}'],capture_output=True,text=True,timeout=120)
 (out/f'{index}.log').write_text(r.stdout+r.stderr);print(path.name+': '+r.stdout,flush=True);r.check_returncode()
 results.append({'file':str(path.resolve()),'sha256':hashlib.sha256(raw).hexdigest(),'cues':cues,'result':r.stdout})
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
