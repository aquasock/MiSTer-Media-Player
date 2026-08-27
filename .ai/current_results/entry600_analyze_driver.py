from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,math,re
root=Path('/home/vash/MiSTer-Media-Player');out=Path('/tmp/entry600-capture')
log=(out/'entry600_ceiling_arm_helper.log').read_text();t=json.loads((out/'entry600_ceiling_terminal.json').read_text());m=json.loads((out/'entry600_capture.json').read_text());fixture=json.loads((root/'.ai/current_results/entry593_fixture.json').read_text());deployment=json.loads((root/'.ai/current_results/entry599_deployment.json').read_text())
def rec(kind):return [{k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',line)} for line in log.splitlines() if re.match(r'^t=\d+ '+kind+' ',line)]
reads=rec('read');acks=rec('profile_ack');s,=rec('profile_summary');end,=rec('finish');fb,=rec('first_byte');fr,=rec('first_read')
assert 'start source=file:/media/fat/games/MediaPlayer/bbb_480i_tff_15s_9800kbps.m2v index=1' in log
assert 'transport=credit_fast_v1' in log and s['transport_mode']==2
assert 'transport_fault' not in log and 'finish reason=eof' in log and 'exit_code=0 signaled=0' in log
assert len(reads)==s['tx_calls']==end['reads']==1124
assert [r['event'] for r in reads]==list(range(1,1125))
assert [a['event'] for a in acks]==list(range(64,1125,64)) and len(acks)==s['ack_chunks']==17
count=0
for r in reads:
 count+=r['count'];assert count==r['submitted'] and r['count']==r['fast_bytes']+r['slow_bytes']
 assert r['fast_bytes']>0 and r['fast_bytes']%2==0
 assert r['queries']==r['batches']+(r['slow_bytes']+1)//2+1
 assert r['ack_sample']==(r['event']%64==0)
assert count==end['submitted']==fixture['bytes']==18402691
assert all(r['count']==16384 for r in reads[:-1]) and reads[-1]['count']==3459
assert reads[-1]['slow_bytes']==1 and reads[-1]['fast_bytes']==3458
for field,total in [('tx_us','tx_us'),('fast_bytes','fast_bytes'),('slow_bytes','slow_bytes'),('batches','burst_calls'),('queries','status_queries')]:assert sum(r[field] for r in reads)==s[total]
assert all(a['words']==(reads[a['event']-1]['slow_bytes']+1)//2 and a['uninitialized']==0 for a in acks)
assert end['would_block']==fb['would_block']
assert s['read_calls']==len(reads)+end['would_block']+1
assert s['data_polls']==math.ceil(len(reads)/4) and s['polls']==s['data_polls']+end['would_block']+1
for f in m['files'].values():
 data=Path(f['local']).read_bytes();assert len(data)==f['bytes'] and hashlib.sha256(data).hexdigest()==f['sha256']
assert m['files']['/media/fat/MiSTer']['sha256']==deployment['main_retained_sha256']
assert m['files']['/media/fat/MediaPlayer.rbf']['sha256']==deployment['active']['sha256']
assert m['files']['/media/fat/games/MediaPlayer/bbb_480i_tff_15s_9800kbps.m2v']['sha256']==fixture['sha256']
assert t['schema_version']==19 and t['frame_rate_code']==4 and t['top_field_first']==1
assert t['accepted_bytes']==count+1 and t['reference_pictures']==t['display_pictures']==449 and t['display_swaps']==448
assert t['error_flags']==0 and t['deadline_gap_count']==t['gap_outlier_count']==0 and not t['deadline_records']
assert all(t[k] for k in ('sequence_end_seen','presentation_complete','session_quiet'))
assert not any(t[k] for k in ('presentation_error','pcm_protocol_error','audio_underrun','cache_bank_overlap_error','display_counts_saturated','timestamp_advance_conflicts','timestamp_delay_conflicts'))
assert [g['cycles'] for g in t['largest_display_gaps']]==[2002000]*3
assert t['cadence_cycles']==t['last_present_cycle']-t['first_present_cycle']
prior=[]
for entry,label in ((594,'confirmed Weave'),(595,'confirmed Bob')):
 old=json.loads((root/f'.ai/current_results/entry{entry}_analysis.json').read_text())
 oldcap=json.loads((root/f'.ai/current_results/entry{entry}_capture.json').read_text())
 assert m['files']['/tmp/MediaPlayer_ARM.log']['sha256']!=oldcap['files']['/tmp/MediaPlayer_ARM.log']['sha256']
 prior.append({'entry':entry,'mode':label,'source':'a4f2769','deadline_gaps':old['telemetry']['deadline_gap_count'],'deadline_ordinals':[d['display_picture_ordinal'] for d in old['deadline_records']],'maximum_interval_ms':max(old['cadence']['largest_intervals_ms']),'same_linux_boot':m['syslog_boot_lines']==oldcap['syslog_boot_lines']})
summary={'analyzed_at':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'production_source':'f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4','fixture_generator_source':'feb50c2a37ca9ac059bc3bc2860dfefd4fd29890','verdict':'PASS for this hardware video-ceiling run: complete transfer and pictures, zero errors and zero missed steady display slots.','user_report':m['user_report'],'requested_mode':'Weave','explicit_mode_confirmation':None,'mode_limit':'Weave was requested immediately before this run, but the response does not independently name the mode and schema 19 does not encode Bob/Weave selection. No controlled two-mode acceptance is claimed.','menu_report_ok':True,'menu_during_and_after_separately_confirmed':False,'boot_lines':m['syslog_boot_lines'],'activation_evidence':'Installed RBF matches qualified/deployed f615ce0; a new helper log and checksum-valid capture follow the request to reload. The packet has no running-bitstream hash, so readback proves the installed file rather than independently identifying loaded fabric.','telemetry':{k:t[k] for k in ('schema_version','checksum','accepted_bytes','reference_pictures','display_pictures','display_swaps','error_flags','deadline_gap_count','gap_outlier_count','first_present_cycle','last_present_cycle','cadence_cycles','cadence_seconds','delivered_fps','session_cycles','decoder_stall_cycles','presentation_hold_total_cycles','writer_wait_cycles')},'transport':{'source_bytes':count,'fpga_accepted_bytes':t['accepted_bytes'],'expected_zero_tail_padding_bytes':1,'all_1124_chunks_and_17_ack_samples_reconciled':True,'helper_exit_code':0,'transport_fault':False,'startup_eagain':fb['would_block'],'steady_eagain':end['would_block']-fb['would_block'],'summary':s,'ack_samples':acks,'fast_fraction':s['fast_bytes']/count,'mean_fast_batch_bytes':s['fast_bytes']/s['burst_calls'],'consumption_paced_delivery_bytes_per_second':(reads[-1]['submitted']-reads[0]['submitted'])*1e6/(reads[-1]['t']-reads[0]['t'])},'cadence':{'nominal_fps':30000/1001,'steady_interval_cycles':2002000,'steady_interval_ms':2002000/60000,'largest_intervals_cycles':[g['cycles'] for g in t['largest_display_gaps']],'confirmed_late_intervals':0,'missing_deadline_records':[],'startup_inclusive_aggregate_fps':t['delivered_fps'],'aggregate_extra_vs_448_nominal_intervals_ms':(t['cadence_cycles']-448*2002000)/60000,'interpretation':'Steady maximum interval is nominal, both late counters are zero, and no deadline record exists. The aggregate FPS includes the initial admission interval; its difference from 29.97 is not a steady playback miss.'},'comparison':prior,'capture_integrity':{'fresh_screenshot':True,'decode_parity_and_checksum_valid':True,'all_readback_hashes_verified':True},'visual_scope':'The terminal screenshot shows the expected final foliage/spikes frame without an obvious large artifact; a still image is not a playback-quality or full pixel-conformance test.','strict_video_ceiling_hardware_pass':True,'pass_scope':'One completed run of the exact 449-picture all-I 9.8 Mbps engineering fixture, with reported menu response.','both_modes_hardware_pass':False,'warm_repeat_hardware_pass':False,'combined_stream_hardware_pass':False,'full_dvd_compatibility_pass':False,'analysis_checks':'PASS','production_changed':False,'lifecycle_actions_performed':False,'next_steps':'Replay this same ceiling fixture in explicitly confirmed Bob mode without rebooting or reloading, check menu during and after playback, and retain the telemetry screen. Preserve a4f2769 restoration backups and f615ce0. Continue longer physical and combined 10.08 Mbps/audio/PTS/remaining DVD feature gates separately.'}
(out/'entry600_analysis.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:summary[k] for k in ('verdict','telemetry','cadence','comparison','pass_scope')},indent=2))
