from pathlib import Path
import sys, subprocess, hashlib, json
sys.path.insert(0,'/home/vash/mister-builds/entry673/source/tools/streams')
from analyze_h262_compatibility import start_codes,payload_between,parse_picture_header,parse_picture_coding_extension,read_bits
base=Path('/home/vash/mister-builds/entry675')
fixture=Path('/home/vash/mister-builds/entry656/fixtures/dvd_opening_original.m2v').read_bytes()
video=subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-nostdin','-i','/home/vash/mister-builds/entry622/VTS_01_1.VOB','-t','13','-map','0:v:0','-c','copy','-f','mpeg2video','pipe:1'])
prefix=fixture[:-4] if fixture.endswith(b'\0\0\1\xb7') else fixture
assert video.startswith(prefix), 'Source VOB does not match the tested fixture'
codes=start_codes(video);pictures=[];gop=-1;groups=[]
for i,(offset,code) in enumerate(codes):
    payload=payload_between(video,codes,i)
    if code==0xb8:
        gop+=1;groups.append(dict(index=gop,offset=offset,closed_gop=read_bits(payload,25,1),broken_link=read_bits(payload,26,1)))
    elif code==0:
        pictures.append(dict(coded=len(pictures),gop=gop,offset=offset,**parse_picture_header(payload)))
    elif code==0xb5 and read_bits(payload,0,4)==8:
        pictures[-1].update(parse_picture_coding_extension(payload))
report=dict(source='/home/vash/mister-builds/entry622/VTS_01_1.VOB',extracted_seconds=13,
    original_fixture_is_exact_prefix=True,original_prefix_bytes=len(prefix),
    original_fixture_sha256=hashlib.sha256(fixture).hexdigest(),extended_video_sha256=hashlib.sha256(video).hexdigest(),
    groups=[g for g in groups if g['offset']>=10000000],pictures=[p for p in pictures if 282<=p['coded']<=295])
(base/'terminal_source_check.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({**{k:v for k,v in report.items() if k not in ('pictures',)},'pictures':[{k:p[k] for k in ('coded','gop','temporal_reference','type','top_field_first','repeat_first_field')} for p in report['pictures']]},indent=2))
