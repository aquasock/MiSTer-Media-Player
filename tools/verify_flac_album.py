#!/usr/bin/env python3
"""Embedded CD cue/seek fixtures and exact decoded track landing through DDR."""
import argparse,json,math,struct,subprocess,wave
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);root=Path(__file__).resolve().parents[1]
pcm=b''.join(struct.pack('<hh',int(24000*math.sin(i*.071)),int(18000*math.cos(i*.049))) for i in range(132300))
(out/'album.pcm').write_bytes(pcm)
with wave.open(str(out/'album.wav'),'wb') as f:f.setparams((2,2,44100,0,'NONE','not compressed'));f.writeframes(pcm)
(out/'album.cue').write_text('FILE "album.wav" WAVE\n TRACK 01 AUDIO\n  INDEX 01 00:00:00\n TRACK 02 AUDIO\n  INDEX 00 00:00:60\n  INDEX 01 00:01:00\n TRACK 03 AUDIO\n  INDEX 01 00:02:00\n')
subprocess.run(['flac','-f','-8','-V','--seekpoint=0.25s','--cuesheet='+str(out/'album.cue'),'-o',str(out/'album.flac'),str(out/'album.wav')],check=True,capture_output=True)
def metadata(data):
 blocks=[];offset=4
 while True:
  h=data[offset:offset+4];end=offset+4+int.from_bytes(h[1:],'big');blocks.append((h[0]&127,data[offset+4:end]));offset=end
  if h[0]&128:return blocks,offset
base=(out/'album.flac').read_bytes();blocks,first=metadata(base)
info=blocks[0][1];total=int.from_bytes(info[10:18],'big')&((1<<36)-1);minimum=int.from_bytes(info[:2],'big');maximum=int.from_bytes(info[2:4],'big')
variants={'indexed':blocks,'no-seek':[(t,b) for t,b in blocks if t!=3], 'cue-first':[blocks[0]]+sorted(blocks[1:],key=lambda x:x[0]!=5)}
for top,sources in [('test_flac_album_control',['rtl/audio/flac/flac_album_control.sv','rtl/media_ui_divider.sv','tools/test_flac_album_control.sv']),('test_flac_seek_keyboard',['rtl/audio/flac/flac_album_control.sv','rtl/media_ui_divider.sv','rtl/media_keyboard_control.sv','rtl/media_session_control.sv','rtl/video_config_cdc.sv','tools/test_flac_seek_keyboard.sv']),('test_flac_ddr',[*map(str,Path('rtl/audio/flac').glob('*.sv')),'rtl/audio/media_pcm_sink.sv','rtl/media_ui_divider.sv','tools/test_flac_ddr.sv'])]:
 with (out/(top+'-compile.log')).open('w') as log:
  subprocess.run(['verilator','--binary','--timing','-Wno-CASEINCOMPLETE','-Wno-TIMESCALEMOD','-j','4','--top-module',top,'--Mdir',str(out/top),*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
results={}
def run(name,top,args):
 r=subprocess.run([str(out/top/('V'+top)),*args],capture_output=True,text=True,timeout=120)
 (out/(name+'.log')).write_text(r.stdout+r.stderr);r.check_returncode();assert 'PASS ' in r.stdout
 results[name]=r.stdout.splitlines()[0];print(name+': '+results[name],flush=True)
# Metadata-only plain FLAC fixture: long duration exercises all jump sizes.
long_info=bytearray(info);packed=int.from_bytes(long_info[10:18],'big');long_info[10:18]=((packed>>36<<36)|88200000).to_bytes(8,'big')
plain=out/'keyboard.flac';plain.write_bytes(b'fLaC'+bytes([128])+len(long_info).to_bytes(3,'big')+long_info)
run('keyboard','test_flac_seek_keyboard',[f'+input={plain}'])
bad_cue=[(t,(b[:136]+bytes([b[136]&127])+b[137:]) if t==5 else b) for t,b in blocks]
variants.update({'plain':[(t,b) for t,b in blocks if t!=5],'non-cd-cue':bad_cue})
for name,bs in variants.items():
 data=b'fLaC'+b''.join(bytes([t|(128 if i==len(bs)-1 else 0)])+len(b).to_bytes(3,'big')+b for i,(t,b) in enumerate(bs))+base[first:]
 path=out/(name+'.flac');path.write_bytes(data);_,frame_offset=metadata(data)
 points=[(0,0)]
 for t,b in bs:
  if t==3:
   points += [(int.from_bytes(b[i:i+8],'big'),int.from_bytes(b[i+8:i+16],'big')) for i in range(0,len(b),18) if b[i:i+8]!=b'\xff'*8]
 sample,offset=max((s,o) for s,o in points if s<=44100)
 run(name+'-navigation','test_flac_album_control',[f'+input={path}',f'+tracks={0 if name in ("plain","non-cd-cue") else 3}','+target=44100',f'+base={sample}',f'+offset={frame_offset+offset}'])
 for target in [0,44100,88200,total-1]:
  sample,offset=max((s,o) for s,o in points if s<=target)
  raw=out/f'{name}-{target}.frames';raw.write_bytes(data[frame_offset+offset:]);ref=out/f'{name}-{target}.pcm';ref.write_bytes(pcm[target*4:])
  run(name+f'-landing-{target}','test_flac_ddr',[f'+input={raw}',f'+pcm={ref}','+resume=1',f'+resume_sample={sample}',f'+resume_total={total}',f'+resume_min={minimum}',f'+resume_max={maximum}',f'+target={target}'])
run('ordinary-album','test_flac_ddr',[f'+input={out/"album.flac"}',f'+pcm={out/"album.pcm"}'])
for top,sources in [('flac_album_control',['rtl/audio/flac/flac_album_control.sv','rtl/media_ui_divider.sv']),('flac_pcm_landing',['rtl/audio/flac/flac_pcm_landing.sv']),('flac_stream_decoder',[*map(str,Path('rtl/audio/flac').glob('*.sv'))])]:
 with (out/(top+'-lint.log')).open('w') as log:
  subprocess.run(['verilator','--lint-only','-Wall','-Wno-PINCONNECTEMPTY','-Wno-UNUSEDSIGNAL','--top-module',top,*sources],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
