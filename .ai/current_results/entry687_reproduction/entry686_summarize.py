from pathlib import Path
import csv,json,hashlib,re,subprocess
b=Path('/home/vash/mister-builds/entry686');r=Path('/run/media/vash/GIT/MiSTer-Media-Player')
out=b/'output'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
reports={}
for case,limit in [('spdif',180000000),('hdmi_stride15',126000000)]:
 rows=list(csv.DictReader((out/f'audio_{case}.csv').open()))
 assert rows[-1]['event']=='STOP' and int(rows[-1]['cycle'])==limit
 events=[{k:(v if k=='event' else int(v)) for k,v in x.items()} for x in rows if x['event']!='SAMPLE']
 empty=None;intervals=[]
 for e in events:
  if e['event']=='EMPTY':assert empty is None;empty=e
  if e['event']=='REFILL':
   assert empty is not None
   intervals.append({'start_cycle':empty['cycle'],'end_cycle':e['cycle'],'duration_cycles':e['cycle']-empty['cycle'],'start_video_byte':empty['video_byte'],'refill_video_byte':e['video_byte'],'clean_queue_full_at_start':empty['clean_used']==65536,'audio_fifo_empty_at_start':empty['audio_used']==0,'extractor_blocked_at_start':empty['input_ready']==0})
   empty=None
 assert empty is None and all(int(x['pcm_error'])==0 for x in rows)
 underrun=next((e for e in events if e['event']=='UNDERRUN'),None)
 native=list(csv.DictReader((out/f'native_{case}.csv').open()))
 reports[case]={
  'complete_prefix_seconds':limit/60000000,
  'source_stride_cycles':1 if case=='spdif' else 15,
  'source_max_bytes_per_second':60000000 if case=='spdif' else 4000000,
  'audio_start_seconds':events[0]['cycle']/60000000,
  'first_underrun':underrun,
  'first_underrun_seconds':underrun['cycle']/60000000 if underrun else None,
  'starvation_intervals':intervals,
  'starvation_interval_count':len(intervals),
  'total_starvation_ms':sum(x['duration_cycles'] for x in intervals)/60000,
  'max_starvation_ms':max((x['duration_cycles'] for x in intervals),default=0)/60000,
  'missing_sample_slots':sum(x['duration_cycles'] for x in intervals)/1250,
  'all_empty_intervals_clean_queue_full':all(x['clean_queue_full_at_start'] for x in intervals),
  'all_empty_intervals_extractor_blocked':all(x['extractor_blocked_at_start'] for x in intervals),
  'stop':events[-1],
  'native_publications':sum(x['event']=='PUBLISH' for x in native),
  'scope':'Completed prefix, not a full opening or hardware pass. Production decoder, in-band extractor, clean-video queue and audio adapter; existing behavioral vendor FIFO models without CDC delays, ideal DDR response and continuous or uniform rate-capped source. No Main/SPI, soundbar, S/PDIF physical transmitter, or HDMI scaler model.'
 }
comparison=json.loads((out/'compare.json').read_text())
horizon=json.loads((out/'horizon.json').read_text())
logs={}
for name in ['arm_helper','spdif_previous','spdif_repeat']:
 text=(b/'input'/f'{name}.log').read_text()
 first=next(x for x in text.splitlines() if ' first_byte ' in x)
 end=next(x for x in text.splitlines() if ' finish reason=' in x)
 val=lambda s:{k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',s)}
 logs[name]={'first':val(first),'finish':val(end),'new_pipe_would_block_after_first_transfer':val(end)['would_block']-val(first)['would_block']}
source_files=['host/arm/media_player_helper.c','host/arm/media_source.c','host/arm/media_player_protocol.h','rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv','rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv','rtl/audio/audio_pcm_fifo.sv','rtl/audio/audio_pcm_output_adapter.sv','tools/streams/tb_h262_live_raster_soak.sv','tools/streams/tb_h262_live_native_presentation.svh']
summary={
 'source_commit':'83c138ebd2492e6b81dfcc1f0256cecae2afce79',
 'source_files_sha256':{p:sha(r/p) for p in source_files},
 'fixture_sha256':sha(b/'input/dvd_opening_original.mpg'),
 'helper_native_sha256':sha(out/'helper_native'),
 'same_hdmi_spdif_video_pts_record_schedule':comparison['same_masked_stream'] and comparison['same_record_positions'],
 'payload_verification':json.loads((out/'passthrough_verification.json').read_text()),
 'hardware_pipe_observations':logs,
 'helper_horizon_events':horizon,
 'horizon_instrumentation_byte_identical':sha(out/'spdif.transport')==sha(out/'horizon.transport'),
 'simulations':reports,
 'diagnosis':'The unchanged audio/video helper schedule can exhaust the audio FIFO while the 65536-byte clean-video queue is full. In the reproduced early interval the extractor is blocked behind video, preventing it from reaching later audio. Its first underrun video byte 368134 exactly matches entry 684; the ideal simulation latch time is about 1.802375 s versus 1.803186 s on hardware. The source has data available, and actual S/PDIF logs contain no additional pipe EAGAIN after startup. Burst construction verifies byte-for-byte, and HDMI and S/PDIF differ in payload rather than record schedule. This isolates a delivery-headroom defect at this opening boundary, not a loudness detector or proven receiver malfunction.',
 'mechanism':'After the helper target at video byte 121392 reaches 76168 emitted samples, further audio relies largely on 128-sample byte-budget refills until the target advances at video byte 493708 to 96187. The exact transport plus finite clean-video queue cannot keep audio supplied through all intervening decoder/presentation holds. The next larger audio horizon becomes reachable when decoder consumption approaches 428k clean bytes, and starvation ends.',
 'qualification counterpart':'The accepted hardware HDMI result is preserved. The modeled HDMI rate cap is a sensitivity case, not a replay of the actual HDMI host timing. Offline regenerated payloads and simplified timing do not attest every physical hardware detail or the exact audible dropout length.',
 'next_proposal':'Correct helper audio refill scheduling across the measured video/horizon interval and add this integrated audio/video regression. Test the unchanged compressed video and AC-3 bytes in both output modes through the full opening and paced-source cases before any hardware installation. Prefer a helper-only correction if verified; do not increase physical FIFOs, add arbitrary startup delay, mask underruns, or reseed Quartus to hide the problem. No production correction or deployment was made during investigation.'
}
(out/'investigation.json').write_text(json.dumps(summary,indent=2)+'\n')
files=[p for p in out.iterdir() if p.is_file() and p.name not in ['evidence_hashes.json']]
files+=[p for p in (b/'scripts').iterdir() if p.is_file()]+[p for p in (b/'diagnostic').iterdir() if p.is_file()]
(out/'evidence_hashes.json').write_text(json.dumps({str(p.relative_to(b)):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(files)},indent=2)+'\n')
print(json.dumps({k:{'underrun_seconds':v['first_underrun_seconds'],'intervals':v['starvation_interval_count'],'starvation_ms':v['total_starvation_ms'],'prefix_seconds':v['complete_prefix_seconds']} for k,v in reports.items()},indent=2))
