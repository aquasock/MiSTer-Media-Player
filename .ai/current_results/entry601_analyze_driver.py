from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,math,re
root=Path('/home/vash/MiSTer-Media-Player');out=Path('/tmp/entry601-capture')
log=(out/'entry601_bob_arm_helper.log').read_text();t=json.loads((out/'entry601_bob_terminal.json').read_text());m=json.loads((out/'entry601_capture.json').read_text());fixture=json.loads((root/'.ai/current_results/entry593_fixture.json').read_text());deployment=json.loads((root/'.ai/current_results/entry599_deployment.json').read_text())
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
weave=json.loads((root/'.ai/current_results/entry600_analysis.json').read_text());wc=json.loads((root/'.ai/current_results/entry600_capture.json').read_text())
assert weave['strict_video_ceiling_hardware_pass'] and weave['production_source']==deployment['source_commit']
assert m['syslog_boot_lines']==wc['syslog_boot_lines']
assert m['files']['/tmp/MediaPlayer_ARM.log']['sha256']!=wc['files']['/tmp/MediaPlayer_ARM.log']['sha256']
assert m['files']['/media/fat/screenshots/cadence_probe.png']['sha256']!=wc['files']['/media/fat/screenshots/cadence_probe.png']['sha256']
for path in ('/media/fat/MiSTer','/media/fat/MediaPlayer.rbf','/media/fat/games/MediaPlayer/bbb_480i_tff_15s_9800kbps.m2v'):assert m['files'][path]['sha256']==wc['files'][path]['sha256']
assert t['checksum']!=weave['telemetry']['checksum']
compare=[]
for mode,entry,data in [('Weave',600,weave['telemetry']),('Bob',601,t)]:
 assert data['reference_pictures']==data['display_pictures']==449 and data['display_swaps']==448
 assert data['error_flags']==data['deadline_gap_count']==data['gap_outlier_count']==0
 compare.append({'entry':entry,'user_confirmed_mode':mode,'reference_pictures':data['reference_pictures'],'display_pictures':data['display_pictures'],'display_swaps':data['display_swaps'],'errors':data['error_flags'],'deadline_gaps':data['deadline_gap_count'],'gap_outliers':data['gap_outlier_count'],'maximum_steady_interval_cycles':2002000,'startup_inclusive_fps':data['delivered_fps'],'cadence_seconds':data['cadence_seconds'],'initial_admission_extra_ms':(data['cadence_cycles']-448*2002000)/60000,'decoder_stall_cycles':data['decoder_stall_cycles'],'presentation_hold_total_cycles':data['presentation_hold_total_cycles'],'writer_wait_cycles':data['writer_wait_cycles']})
result={'analyzed_at':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'production_source':deployment['source_commit'],'user_report':m['user_report'],'verdict':'PASS: the exact 9.8 Mbps video-ceiling fixture completes with zero missed slots and zero errors in both user-confirmed Weave and Bob hardware runs.','current_mode':'Bob','previous_mode_confirmation':{'entry':600,'mode':'Weave','authority':'Current explicit user confirmation; historical entry600 is retained unchanged.'},'same_linux_boot_as_entry600':True,'boot_lines':m['syslog_boot_lines'],'distinct_session':{'previous_helper_pid':1406,'current_helper_pid':int(re.search(r'helper forked pid=(\d+)',log)[1]),'helper_log_changed':True,'screenshot_changed':True,'packet_checksum_changed':True},'mode_telemetry_limit':'Mode attribution is from the user; schema 19 does not encode the Bob/Weave option. Same Linux boot establishes no system reboot; no independent no-core-reload proof is claimed.','installed_main_rbf_and_fixture_match_previous':True,'telemetry':{k:t[k] for k in ('schema_version','checksum','accepted_bytes','reference_pictures','display_pictures','display_swaps','error_flags','deadline_gap_count','gap_outlier_count','first_present_cycle','last_present_cycle','cadence_cycles','cadence_seconds','delivered_fps','session_cycles','decoder_stall_cycles','presentation_hold_total_cycles','writer_wait_cycles')},'deadline_records':t['deadline_records'],'largest_display_gaps':t['largest_display_gaps'],'transport':{'source_bytes':count,'fpga_accepted_bytes':t['accepted_bytes'],'expected_final_zero_padding_bytes':1,'all_1124_chunks_and_17_ack_samples_reconciled':True,'helper_exit_code':0,'transport_fault':False,'startup_eagain':fb['would_block'],'steady_eagain':end['would_block']-fb['would_block'],'summary':s,'ack_samples':acks,'fast_fraction':s['fast_bytes']/count,'mean_fast_batch_bytes':s['fast_bytes']/s['burst_calls'],'consumption_paced_delivery_bytes_per_second':(reads[-1]['submitted']-reads[0]['submitted'])*1e6/(reads[-1]['t']-reads[0]['t'])},'comparison':compare,'aggregate_difference_ms':(t['cadence_seconds']-weave['telemetry']['cadence_seconds'])*1000,'comparison_interpretation':'Both have nominal 2,002,000-clock largest steady intervals, no deadline records, all counts complete and zero late/error counters. The small aggregate-duration difference is in initial admission; it does not represent a recurring Bob slowdown. Neither run retains the old delayed intervals at 167 or 346.','menu_scope':'Menu response was reported okay for entry600; no new Bob-specific menu or visual-playback report is asserted by the current message.','visual_scope':'Fresh terminal image shows the expected final foliage/spikes frame without an obvious large artifact; a still does not establish complete playback pixel correctness.','capture_integrity':{'fresh_screenshot':True,'parity_checksum_valid':True,'all_readback_hashes_valid':True},'strict_video_ceiling_hardware_pass':True,'both_modes_hardware_pass':True,'same_boot_repeat_hardware_pass':True,'pass_scope':'One 449-picture run per user-confirmed mode of the unchanged all-I 9.8 Mbps engineering fixture, with Bob following Weave in the same Linux boot.','combined_stream_hardware_pass':False,'full_dvd_compatibility_pass':False,'physical_long_duration_soak_pass':False,'analysis_checks':'PASS','production_changed':False,'lifecycle_actions_performed':False,'next_steps':'Keep f615ce0 and restoration artifacts. The writer-retirement ceiling-cadence fix is accepted for this bounded two-mode fixture. Future qualification should target longer physical playback and the separate combined 10.08 Mbps audio/video, PTS, and remaining DVD syntax/features; no further identical short replay is required solely to reconfirm the cleared 167/346 misses.'}
(out/'entry601_analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ('verdict','comparison','aggregate_difference_ms','pass_scope')},indent=2))
