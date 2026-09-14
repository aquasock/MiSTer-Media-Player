#!/usr/bin/env python3
"""Replay bounded exact MPG opening bytes through demux/MP2/timed PCM output.

Real 60/24.576/20 MHz clocks, ideal bounded CDC queues and synthetic video
consumption: this diagnoses audio timing, not complete hardware video behavior.
"""
import argparse, hashlib, json, re, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('media',type=Path,nargs='+')
p.add_argument('--output',type=Path,required=True)
p.add_argument('--expect-clean',action='store_true')
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
rtl=['rtl/audio/'+x+'.sv' for x in ('mp2_decoder','mp2_synthesis','av_stream_fifo','mp2_pcm_output')]
rtl+=['rtl/mpeg2_new/'+x+'.sv' for x in ('mpeg2_program_stream_ingress','mpeg2_h262_program_stream_demux','mpeg2_av_ddr_fifo','mpeg2_pes_metadata_expand','mpeg2_h262_inband_metadata','mpeg2_pes_picture_pts')]
with (out/'compile.log').open('w') as f:
 subprocess.run(['verilator','--binary','--timing','-j','6','-Wno-fatal','--top-module','test_mpg_audio_playback','--Mdir',str(out/'obj'),'tools/test_mpg_audio_playback.sv','rtl/media_file_reader.sv',*rtl],cwd=root,stdout=f,stderr=subprocess.STDOUT,check=True)
results=[]
for i,media in enumerate(a.media):
 dest=out/str(i);dest.mkdir(exist_ok=True)
 with media.open('rb') as f:data=f.read(1048576)
 prefix=dest/'opening.mpg';prefix.write_bytes(data)
 with (dest/'run.log').open('w') as f:
  subprocess.run([str(out/'obj/Vtest_mpg_audio_playback'),'+input='+str(prefix),'+output='+str(dest/'pcm'),'+startup_samples=9216'],cwd=root,stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(dest/'run.log').read_text();match=re.search(r'AUDIO_STARTUP samples=(\d+) underrun=(\d+) timestamp_error=(\d+)',text)
 if not match:raise RuntimeError('Startup did not finish: '+str(dest/'run.log'))
 item=dict(source=str(media.resolve()),prefix_sha256=hashlib.sha256(data).hexdigest(),samples=int(match[1]),underrun=bool(int(match[2])),timestamp_error=bool(int(match[3])),timestamps=[dict(zip(('sample','pts','stc','lateness'),map(int,m))) for m in re.findall(r'AUDIO_PTS sample=(\d+) pts=(\d+) stc=(\d+) lateness=(-?\d+)',text)])
 results.append(item);print(json.dumps(item),flush=True)
(out/'result.json').write_text(json.dumps(results,indent=2)+'\n')
if a.expect_clean and any(x['underrun'] or x['timestamp_error'] for x in results):raise SystemExit('Unexpected startup warning')
