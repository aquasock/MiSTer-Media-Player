from pathlib import Path
import array, bisect, hashlib, json, math, mmap, subprocess, sys, tempfile
from datetime import datetime
from zoneinfo import ZoneInfo
root=Path('/run/media/vash/GIT/MiSTer-Media-Player')
out=Path('/home/vash/mister-builds/entry602')
media=out/'bbb_full_480i_tff_av_10080kbps.mpg'
manifest=json.loads(media.with_suffix('.json').read_text())
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert source.startswith('6669b70'),source
helper=out/'media_player_helper.native'
def run(command, name):
 p=subprocess.run(command,cwd=root,capture_output=True)
 (out/(name+'.stdout')).write_bytes(p.stdout);(out/(name+'.stderr')).write_bytes(p.stderr)
 assert p.returncode==0,(command,p.stderr[-3000:])
 return p.stdout
print('Official generator source',source,flush=True)
run(['python3','-m','unittest','discover','-s','tools/streams','-p','test_dvd_ceiling.py','-v'],'tests')
run(['make','-B','-C','host/arm','OUTPUT='+str(helper)],'native_build')
print('Checking complete scheduled transport',flush=True)
transport=json.loads((out/'full_transport.stdout').read_text())
assert 0 < transport['pts_count'] <= manifest['frame_count']
assert transport['clean_video_bytes']==manifest['video_bytes']
assert transport['pcm_frames']==manifest['audio_pcm_frames']
print('Checking clean video hash and every PTS interval',flush=True)
with tempfile.TemporaryDirectory(prefix='entry602_oracle_',dir=out) as directory:
 temp=Path(directory);pcm=temp/'helper.s16le';ref=temp/'ffmpeg.s16le'
 clean_path=temp/'video.m2v';clean_file=clean_path.open('wb')
 with (out/'explicit_helper.stderr').open('wb') as errors:
  p=subprocess.Popen([str(helper),'--protocol','1','--source','file:'+str(media),'--pcm-out',str(pcm)],stdout=subprocess.PIPE,stderr=errors)
  buffer=b'';digest=hashlib.sha256();clean_bytes=0;pts=[];positions=[]
  while True:
   chunk=p.stdout.read(1048576)
   buffer+=chunk
   while True:
    index=buffer.find(b'\x00\x00\x01\xb0')
    if index<0:
     amount=len(buffer) if not chunk else max(0,len(buffer)-8)
     digest.update(buffer[:amount]);clean_file.write(buffer[:amount]);clean_bytes+=amount;buffer=buffer[amount:]
     break
    if index+9>len(buffer):break
    digest.update(buffer[:index]);clean_file.write(buffer[:index]);clean_bytes+=index;positions.append(clean_bytes)
    pts.append(int.from_bytes(buffer[index+4:index+9],'big')>>7)
    buffer=buffer[index+9:]
   if not chunk:break
  assert p.wait()==0
 clean_file.close()
 assert not buffer
 assert clean_bytes==manifest['video_bytes'] and digest.hexdigest()==manifest['video_sha256']
 assert len(pts)==transport['pts_count']
 intervals=[(b-a)% (1<<33) for a,b in zip(pts,pts[1:])]
 assert all(0 < delta <= 60*3003 and delta%3003==0 for delta in intervals)
 sys.path.insert(0,str(root/'tools/streams'))
 import analyze_h262_compatibility as syntax
 with clean_path.open('rb') as stream,mmap.mmap(stream.fileno(),0,access=mmap.ACCESS_READ) as data:
  pictures=[offset for offset,code in syntax.start_codes(data) if code==0]
 assert len(pictures)==manifest['frame_count']
 mapped=[bisect.bisect_left(pictures,position) for position in positions]
 mismatches=[(n,index,value,position) for n,(index,value,position) in enumerate(zip(mapped,pts,positions)) if value-pts[0] != index*3003]
 (out/'pts_mapping.json').write_text(json.dumps({'picture_count':len(pictures),'pts_records':len(pts),'min_interval':min(intervals),'max_interval':max(intervals),'omitted_picture_timestamps':len(pictures)-len(pts),'first_mismatches':mismatches[:20],'missing_ordinals':[i for i in range(len(pictures)) if i not in set(mapped)]},indent=2)+'\n')
 assert not mismatches,mismatches[:10]
 assert mapped[0]==0 and mapped[-1]==len(pictures)-1
 run(['ffmpeg','-hide_banner','-loglevel','error','-xerror','-i',str(media),'-map','0:a:0','-f','s16le',str(ref)],'ffmpeg_audio')
 def sha(path):
  with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
 assert sha(ref)==manifest['audio_ffmpeg_pcm_sha256']
 assert sha(pcm)==transport['pcm_sha256']
 assert pcm.stat().st_size==ref.stat().st_size==manifest['audio_pcm_frames']*4
 print('Comparing all decoded audio samples to FFmpeg',flush=True)
 peak=error_energy=dot=actual_energy=ref_energy=count=0
 with pcm.open('rb') as actual,ref.open('rb') as reference:
  while True:
   a=actual.read(262144);b=reference.read(262144)
   if not a:break
   av=array.array('h');bv=array.array('h');av.frombytes(a);bv.frombytes(b)
   count+=len(av)
   for x,y in zip(av,bv):
    d=x-y;peak=max(peak,abs(d));error_energy+=d*d;dot+=x*y;actual_energy+=x*x;ref_energy+=y*y
 correlation=dot/math.sqrt(actual_energy*ref_energy)
 assert correlation>=0.97,correlation
 result={'timestamp':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'source_commit':source,'native_helper_sha256':sha(helper),'media_sha256':sha(media),'manifest_sha256':sha(media.with_suffix('.json')),'generator_checks_passed':True,'unit_tests':11,'transport':transport,'clean_video_sha256':digest.hexdigest(),'clean_video_bytes':clean_bytes,'pts_count':len(pts),'first_pts':pts[0],'last_pts':pts[-1],'pts_picture_mapping_exact':True,'pts_min_interval_90khz_ticks':min(intervals),'pts_max_interval_90khz_ticks':max(intervals),'pictures_without_explicit_timestamp':len(pictures)-len(pts),'audio_oracle':{'sample_values':count,'stereo_frames':count//2,'max_absolute_error':peak,'rms_error':math.sqrt(error_energy/count),'correlation':correlation,'minimum_accepted_correlation_existing_project_gate':0.97},'production_changed':False,'hardware_accepted':False}
 (out/'qualification.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result,indent=2),flush=True)
