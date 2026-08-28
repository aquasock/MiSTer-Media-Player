from pathlib import Path
import subprocess,json,csv,bisect,re
r=Path('/run/media/vash/GIT/MiSTer-Media-Player');b=Path('/home/vash/mister-builds/entry686');d=b/'diagnostic'
s=(r/'host/arm/media_player_helper.c').read_text()
needle='        target = scheduler_pcm_target(output, prospective_pts);'
assert s.count(needle)==1
s=s.replace(needle,needle+'''
        { static uint64_t previous_target = UINT64_MAX;
          if (target != previous_target) {
            fprintf(stderr, "HORIZON video_bytes=%llu video_pts=%llu first_audio_pts=%llu target=%llu emitted=%llu available=%llu\\n",
              (unsigned long long)output->video_bytes,
              (unsigned long long)prospective_pts,
              (unsigned long long)output->first_audio_pts,
              (unsigned long long)target,
              (unsigned long long)output->pcm_emitted_frames,
              (unsigned long long)hold_available(output));
            previous_target=target;
          }
        }
''')
(d/'helper_horizon.c').write_text(s)
arm=r/'host/arm';a52=arm/'.deps/liba52'
cmd=['cc','-O2','-Wall','-Wextra','-Werror','-std=c11',f'-I{arm}',f'-I{arm}/.deps',f'-I{a52}',str(d/'helper_horizon.c'),str(arm/'media_source.c')]+[str(a52/'obj-cc'/x) for x in ['bit_allocate.o','bitstream.o','downmix.o','imdct.o','parse.o']]+['-lm','-o',str(b/'output/helper_horizon')]
subprocess.run(cmd,check=True)
with (b/'output/horizon.transport').open('wb') as f:
 p=subprocess.run([str(b/'output/helper_horizon'),'--protocol','1','--audio-out','spdif','--source',f'file:{b}/input/dvd_opening_original.mpg'],stdout=f,stderr=subprocess.PIPE,check=True)
assert (b/'output/horizon.transport').read_bytes()==(b/'output/spdif.transport').read_bytes()
(b/'output/horizon.log').write_bytes(p.stderr)
rows=[{k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',line)} for line in p.stderr.decode().splitlines() if line.startswith('HORIZON ')]
(b/'output/horizon.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Instrumentation preserves the complete original passthrough transport byte-for-byte')
print(json.dumps(rows[:7],indent=2))
