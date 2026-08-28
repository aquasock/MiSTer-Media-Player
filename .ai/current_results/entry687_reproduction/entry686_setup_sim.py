from pathlib import Path
import re,subprocess,hashlib,json
r=Path('/run/media/vash/GIT/MiSTer-Media-Player');b=Path('/home/vash/mister-builds/entry686')
d=b/'diagnostic';d.mkdir(exist_ok=True)
t=(r/'tools/streams/tb_h262_live_raster_soak.sv').read_text()
t=t.replace('parameter integer NATIVE_PRESENTATION=0,','parameter integer NATIVE_PRESENTATION=0,\n    parameter integer AUDIO_TRANSPORT=0,',1)
start=t.index('    always @(negedge clk) begin\n        if(reset)begin\n            stream_valid<=0;')
end=t.index('\n    always @(posedge clk) begin',start)
t=t[:start]+'    generate if(!AUDIO_TRANSPORT) begin\n'+t[start:end]+'\n    end endgenerate\n'+t[end:]
needle='`include "tools/streams/tb_h262_live_native_presentation.svh"';assert needle in t
t=t.replace(needle,'`include "entry686_audio.svh"\n`include "tb_h262_live_native_presentation.svh"',1)
(d/'tb_h262_live_raster_soak.sv').write_text(t)
n=(r/'tools/streams/tb_h262_live_native_presentation.svh').read_text()
n=n.replace('assign native_metadata_pending=(pts_index<pts_count)&&\n        (stream_index>=pts_records[pts_index][64:33]);','assign native_metadata_pending=AUDIO_TRANSPORT ? audio_metadata_valid : ((pts_index<pts_count)&&\n        (stream_index>=pts_records[pts_index][64:33]));',1)
n=n.replace('wire [32:0] metadata_pts=pts_records[pts_index][32:0];','wire [32:0] metadata_pts=AUDIO_TRANSPORT ? audio_metadata_pts : pts_records[pts_index][32:0];',1)
(d/'tb_h262_live_native_presentation.svh').write_text(n)
(d/'entry686_audio.svh').write_bytes((b/'scripts/entry686_audio.svh').read_bytes())
# Vendor FIFO behavioral models already used by repository unit tests.
sc=(r/'tools/streams/tb_h262_clean_video_queue.sv').read_text();dc=(r/'tools/streams/tb_audio_pcm_fifo.sv').read_text()
(d/'fifo_models.sv').write_text(sc[sc.index('module scfifo #('):]+'\n'+dc[dc.index('module dcfifo #('):])
for mode in ['hdmi','spdif']:
 data=(b/f'output/{mode}.transport').read_bytes();(b/f'output/{mode}.hex').write_text(data.hex('\n')+'\n')
sources=re.findall(r'^set_global_assignment -name SYSTEMVERILOG_FILE (rtl/mpeg2_new/.*)$',(r/'files.qip').read_text(),re.M)
cmd=['verilator','--binary','--timing','-j','6','-Wno-fatal','-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT','-Wno-CASEINCOMPLETE','-Wno-BLKANDNBLK',f'+incdir+{d}','+incdir+rtl/mpeg2_new','+incdir+tools/streams','+define+H262_SOAK_MAX_STREAM_BYTES=16777216','--top-module','tb_h262_live_raster_soak','-GMIXED_PIXEL_MODE=2','-GPIXEL_WIDTH=720','-GPIXEL_HEIGHT=480','-GPIXEL_PICTURES=289','-GMAX_SIM_CYCLES=900000000','-GFREEZE_TRACE_CYCLES=0','-GNATIVE_PRESENTATION=1','-GAUDIO_TRANSPORT=1','--Mdir',str(b/'obj'),'-o','audio_timing',str(d/'tb_h262_live_raster_soak.sv'),str(d/'fifo_models.sv'),'tools/streams/tb_native_480i_cache_refill.sv','rtl/mpeg2_luma_framebuffer.sv','rtl/mpeg2_video_output_timing.sv','rtl/audio/audio_pcm_fifo.sv','rtl/audio/audio_pcm_output_adapter.sv']+sources
(b/'output/sim_build_command.json').write_text(json.dumps(cmd,indent=2)+'\n')
with (b/'output/sim_build.log').open('w') as f:result=subprocess.run(cmd,cwd=r,stdout=f,stderr=subprocess.STDOUT)
print('SIM_BUILD_EXIT',result.returncode,flush=True)
if result.returncode:print((b/'output/sim_build.log').read_text()[-5000:]);raise SystemExit(result.returncode)
fix=Path('/home/vash/mister-builds/entry656/fixtures');pts=Path('/home/vash/mister-builds/entry673/ideal_v2/pts.hex')
cmd=[str(b/'obj/audio_timing'),f'+HEX={fix}/dvd_opening_original.hex',f'+LEN={(fix/"dvd_opening_original.m2v").stat().st_size}',f'+PIXELS={fix}/dvd_opening_original_pixels.hex',f'+MAP={fix}/dvd_opening_map.hex',f'+PTS={pts}','+PTS_COUNT=25',f'+NATIVE_TRACE={b}/output/native_spdif.csv',f'+AUDIO_TRACE={b}/output/audio_spdif.csv',f'+TRANSPORT={b}/output/spdif.hex','+TRANSPORT_LEN=12818502','+GENERIC_STREAM','+CHAIN_ERROR_BOUND','+PROGRESS=10000000']
(b/'output/sim_run_command.json').write_text(json.dumps(cmd,indent=2)+'\n')
with (b/'output/sim_spdif.log').open('w') as f:result=subprocess.run(cmd,cwd=r,stdout=f,stderr=subprocess.STDOUT)
print('SIM_RUN_EXIT',result.returncode,flush=True);print((b/'output/sim_spdif.log').read_text()[-2500:])
