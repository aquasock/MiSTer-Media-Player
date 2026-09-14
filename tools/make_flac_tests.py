#!/usr/bin/env python3
"""Generate deterministic CD PCM/FLAC pairs and independently verify decoded PCM.

Requires the reference `flac` encoder and FFmpeg. Outputs stay under --output.
These files are a decoder test corpus, not evidence that FPGA FLAC decoding works.
"""
import argparse, hashlib, json, math, random, struct, subprocess, wave
from pathlib import Path

def run(args):
 return subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--output',type=Path,required=True)
 p.add_argument('--flac',default='flac');p.add_argument('--ffmpeg',default='ffmpeg')
 a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 rng=random.Random(9639);count=70003;cases={}
 cases['silence']=[(0,0)]*count
 cases['extremes']=[((-32768 if i%2 else 32767),(32767 if i%3 else -32768)) for i in range(count)]
 cases['ramp']=[((i*13%65536)-32768,(i*7%65536)-32768) for i in range(count)]
 cases['tones']=[(round(25000*math.sin(2*math.pi*997*i/44100)),round(20000*math.sin(2*math.pi*1999*i/44100))) for i in range(count)]
 cases['noise']=[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(count)]
 manifest={'rate':44100,'bits':16,'channels':2,'seed':9639,'encoders':{},'files':[],'negative_files':[]}
 for name,exe in [('flac',a.flac),('ffmpeg',a.ffmpeg)]:
  manifest['encoders'][name]=run([exe,'--version' if name=='flac' else '-version']).stdout.decode().splitlines()[0]
 for name,samples in cases.items():
  raw=b''.join(struct.pack('<hh',*v) for v in samples);wav=out/f'{name}.wav'
  (out/f'{name}.pcm').write_bytes(raw)
  with wave.open(str(wav),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(44100);f.writeframes(raw)
  configurations=[(f'level{level}',[a.flac,'--silent','--force',f'-{level}','--no-padding']) for level in range(9)]
  configurations += [('large-block',[a.flac,'--silent','--force','-8','--lax','--blocksize=65535','--max-lpc-order=32','--no-padding','--no-seektable'])]
  for label,args in configurations:
   target=out/f'{name}-{label}.flac';run(args+['-o',str(target),str(wav)])
   decoded=run([a.ffmpeg,'-v','error','-i',str(target),'-map','0:a:0','-f','s16le','-c:a','pcm_s16le','-']).stdout
   secondary_match=decoded==raw
   reference=run([a.flac,'--decode','--silent','--stdout','--force-raw-format','--endian=little','--sign=signed',str(target)]).stdout
   if reference!=raw:raise RuntimeError(f'Reference PCM mismatch: {target}')
   if not secondary_match and label!='large-block':raise RuntimeError(f'FFmpeg PCM mismatch: {target}')
   manifest['files'].append({'file':target.name,'reference_pcm':f'{name}.pcm','samples_per_channel':count,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'pcm_sha256':hashlib.sha256(raw).hexdigest(),'encoder':label,'reference_decode_matches':True,'ffmpeg_decode_matches':secondary_match})
  target=out/f'{name}-ffmpeg.flac'
  run([a.ffmpeg,'-v','error','-y','-i',str(wav),'-c:a','flac','-compression_level','12',str(target)])
  # Decode FFmpeg's stream with the independent reference decoder.
  decoded=run([a.flac,'--decode','--silent','--stdout','--force-raw-format','--endian=little','--sign=signed',str(target)]).stdout
  if decoded!=raw:raise RuntimeError(f'PCM mismatch: {target}')
  manifest['files'].append({'file':target.name,'reference_pcm':f'{name}.pcm','samples_per_channel':count,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'pcm_sha256':hashlib.sha256(raw).hexdigest(),'encoder':'ffmpeg'})
 source=out/'tones-level8.flac';data=source.read_bytes()
 for label,broken in [('truncated',data[:-7]),('corrupt',data[:-9]+bytes([data[-9]^0x80])+data[-8:])]:
  path=out/f'tones-{label}.flac';path.write_bytes(broken)
  checked=subprocess.run([a.flac,'--test','--silent',str(path)],capture_output=True)
  if checked.returncode==0:raise RuntimeError(f'Negative case accepted: {path}')
  manifest['negative_files'].append({'file':path.name,'expected':'controlled decode error','sha256':hashlib.sha256(broken).hexdigest()})
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(f'FLAC_CORPUS_PASS {len(manifest["files"])} exact PCM pairs; {len(manifest["negative_files"])} rejected damaged files')
if __name__=='__main__':main()
