from pathlib import Path
import hashlib, json, subprocess, sys, time

root = Path('/run/media/vash/GIT/MiSTer-Media-Player')
out = Path('/home/vash/mister-builds/entry597')
fixture = Path('/home/vash/mister-builds/entry593/official/bbb_480i_tff_15s_9800kbps.m2v')
data = fixture.read_bytes()
assert hashlib.sha256(data).hexdigest() == '3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065'
assert subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip() == '04ca33b94c5ad1b709285fe4891d35cc149aae9c'
hexfile=out/'fixture.hex'
hexfile.write_text(data.hex('\n')+'\n')
selected = [165,166,167,344,345,346]
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-threads','1','-i',str(fixture),
                '-vf','select='+ '+'.join(f'eq(n\\,{n})' for n in selected),
                '-fps_mode','passthrough','-threads','1',str(out/'selected_%02d.png')],check=True)
for i,n in enumerate(selected,1):
    (out/f'selected_{i:02}.png').rename(out/f'picture_{n+1}.png')
files = ['mpeg2_h262_frontend','mpeg2_h262_dct_vlc','mpeg2_h262_bitreader',
         'mpeg2_h262_luma4_probe','mpeg2_h262_picture_bookkeeper','mpeg2_h262_inverse_quant',
         'mpeg2_h262_idct','mpeg2_h262_intra_recon']
command = ['verilator','--binary','--timing','-j','6','-Wno-fatal','-Wno-PINMISSING',
           '-Wno-WIDTH','-Wno-UNOPTFLAT','--top-module','tb_entry597_i_throughput',
           '--Mdir',str(out/'obj'),'-o','profile',str(out/'tb_entry597_i_throughput.sv')]
command += [str(root/'rtl/mpeg2_new'/(name+'.sv')) for name in files]
(out/'compile_command.json').write_text(json.dumps(command,indent=2)+'\n')
start=time.monotonic()
with (out/'compile.log').open('w') as log:
    subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
print(f'COMPILE_PASS seconds={time.monotonic()-start:.3f}',flush=True)
command = [str(out/'obj/profile'),f'+HEX={hexfile}',f'+LEN={len(data)}',
           '+PICTURES=449',f'+REPORT={out}/pictures.csv']
start=time.monotonic()
with (out/'profile.log').open('w') as log:
    result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
print(f'SIMULATION_EXIT={result.returncode} seconds={time.monotonic()-start:.3f}',flush=True)
sys.exit(result.returncode)
