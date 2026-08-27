from pathlib import Path
import subprocess,json,hashlib,sys,tempfile,contextlib,io
base=Path('/home/vash/mister-builds/entry624');root=base/'official';sys.path.insert(0,str(root/'tools/streams'))
import generate_test_suite as suite
import check_media_compatibility as demux
import test_main_mister_profile as profile
source='140a5b711e84821688641c8903000e02e78f580c'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
results=[]
for name,path,tff in [('old_static_tff',Path('/home/vash/mister-builds/regression_failure_20260827_092037/test_1_interlace_tff.mpg'),True),('old_static_bff',Path('/home/vash/mister-builds/regression_failure_20260827_092037/test_2_interlace_bff.mpg'),False),('wrong_temporal_order',base/'suite/test_2_interlace_bff.mpg',True)]:
 try:suite.verify_motion(path,360,tff,True)
 except ValueError as e:results.append({'case':name,'rejected':True,'reason':str(e)})
 else:raise AssertionError(name+' unexpectedly passed')
with tempfile.TemporaryDirectory(prefix='entry624-negative-') as d:
 temp=Path(d);(temp/'host/main_mister').mkdir(parents=True)
 patch=(root/'host/main_mister/0001-mediaplayer-arm-loader.patch').read_text()
 old='+\t\tif (!consumed) return; // No credits: leave the exact pending bytes for next poll.'
 assert old in patch
 patch=patch.replace(old,'+\t\tif (!consumed) { pending_size = pending_offset = 0; return; } // intentionally unsafe test control')
 (temp/'host/main_mister/0001-mediaplayer-arm-loader.patch').write_text(patch)
 profile.ROOT=temp
 try:
  with contextlib.redirect_stdout(io.StringIO()):profile.run(Path('/home/vash/mister-builds/entry588/Main_MiSTer'),'g++',False,False)
 except subprocess.CalledProcessError as e:
  assert e.returncode==-6,(e.returncode,e.stderr)
  results.append({'case':'drop_pending_bytes_on_yield','rejected':True,'exit_code':e.returncode,'stderr':e.stderr})
 else:raise AssertionError('unsafe pending-byte drop passed')
(base/'negative-controls.json').write_text(json.dumps(results,indent=2)+'\n');print('PASS negative controls',flush=True)

out=base/'audio';out.mkdir(exist_ok=True);helper=base/'helper.native';manifest=json.loads((base/'suite/manifest.json').read_text());checks=[]
for entry in manifest['tests']:
 path=base/'suite'/entry['file'];codec=entry['audio_codec'];video,audio,_=demux.demux_program_stream(path.read_bytes())
 modes=['hdmi','spdif'] if codec!='dts' else ['spdif'];hashes={}
 for mode in modes:
  stem=entry['name']+'_'+mode;v=out/(stem+'.m2v');pcm=out/(stem+'.pcm')
  cmd=[str(helper),'--protocol','1','--source','file:'+str(path),'--audio-out',mode,'--pcm-out',str(pcm),'--video-out',str(v)]
  r=subprocess.run(cmd,capture_output=True);(out/(stem+'.stderr')).write_bytes(r.stderr);assert r.returncode==0,r.stderr
  data=v.read_bytes();clean=bytearray();index=0;pts=0
  while True:
   p=data.find(b'\x00\x00\x01\xb0',index)
   if p<0:clean.extend(data[index:]);break
   clean.extend(data[index:p]);assert p+9<=len(data);index=p+9;pts+=1
  assert bytes(clean)==video,(stem,len(clean),len(video))
  hashes[mode]=hashlib.sha256(pcm.read_bytes()).hexdigest()
  assert pcm.stat().st_size==576000*4,(stem,pcm.stat().st_size)
  checks.append({'test':entry['file'],'mode':mode,'video_byte_exact':True,'video_bytes':len(video),'timestamps':pts,'pcm_or_burst_bytes':pcm.stat().st_size,'pcm_or_burst_sha256':hashes[mode]})
 if codec=='mp2':assert hashes['hdmi']==hashes['spdif']
 if codec=='dts':
  r=subprocess.run([str(helper),'--protocol','1','--source','file:'+str(path),'--audio-out','hdmi'],capture_output=True)
  assert r.returncode!=0 and b'DTS requires --audio-out spdif' in r.stderr
  checks.append({'test':entry['file'],'mode':'hdmi','unsupported_mode_rejected':True})
# Verify audio from both corrected field fixtures is byte identical to its original.
for number,order in [(1,'tff'),(2,'bff')]:
 name=f'test_{number}_interlace_{order}.mpg';old=Path('/home/vash/mister-builds/regression_failure_20260827_092037')/name
 old_audio=demux.demux_program_stream(old.read_bytes())[1];new_audio=demux.demux_program_stream((base/'suite'/name).read_bytes())[1]
 assert old_audio==new_audio
 checks.append({'test':name,'audio_elementary_matches_original':True,'audio_sha256':hashlib.sha256(new_audio).hexdigest()})
# AC-3 decode uses elementary audio to avoid irrelevant container timestamp issues.
from generate_test_dvd_ac3_av import extract_ac3
ac3=base/'suite/test_5_audio_ac3_51.mpg';es=out/'reference.ac3';es.write_bytes(extract_ac3(ac3.read_bytes(),0x80));reference=out/'reference.pcm'
subprocess.run(['ffmpeg','-v','error','-xerror','-i',str(es),'-ac','2','-ar','48000','-f','s16le',str(reference)],check=True)
commands=[['python3','tools/streams/verify_ac3_pcm.py','--helper',str(helper),'--fixture',str(ac3),'--reference',str(reference),'--max-abs-difference','3','--min-correlation','0.9999','--report',str(base/'ac3-decode.json')],['python3','tools/streams/verify_ac3_passthrough.py','--helper',str(helper),'--fixture',str(ac3),'--report',str(base/'ac3-passthrough.json')],['python3','tools/streams/verify_ac3_passthrough.py','--helper',str(helper),'--fixture',str(base/'suite/test_6_audio_dts_51.mpg'),'--codec','dts','--substream','0x88','--report',str(base/'dts-passthrough.json')]]
with (base/'audio-checks.log').open('w') as log:
 for cmd in commands:subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
(base/'audio-video-checks.json').write_text(json.dumps({'source_commit':source,'checks':checks,'all_passed':True,'scope':'Software preservation/decoder/burst tests, not physical A/V or receiver acceptance.'},indent=2)+'\n');print('PASS audio/video checks',flush=True)
