import json,re
from pathlib import Path
out=Path('/tmp/entry605-capture')
t=json.load(open(out/'entry605_terminal.json'))
cap=json.load(open(out/'entry605_capture.json'))
log=(out/'entry605_arm_helper.log').read_text(errors='replace').splitlines()
a={}
# helper transport reconciliation
fin=[l for l in log if ' finish reason=' in l]
a['finish_lines']=fin
m=re.search(r'submitted=(\d+) reads=(\d+) would_block=(\d+)',fin[-1])
a['helper_submitted_bytes']=int(m.group(1));a['helper_reads']=int(m.group(2));a['helper_would_block']=int(m.group(3))
a['helper_expected_bytes_entry602']=839409548
a['helper_transport_exact']=a['helper_submitted_bytes']==839409548
a['helper_exit']=[l for l in log if 'child wait=' in l][-1]
a['helper_eof_us']=int(re.match(r't=(\d+)',[l for l in log if 'helper stdout eof' in l][-1]).group(1))
a['helper_eof_seconds']=a['helper_eof_us']/1e6
a['ack_chunks']=int(re.search(r'ack_chunks=(\d+)',log[-1]).group(1))
a['fast_bytes']=int(re.search(r'fast_bytes=(\d+)',log[-1]).group(1))
a['slow_bytes']=int(re.search(r'slow_bytes=(\d+)',log[-1]).group(1))
a['fast_plus_slow']=a['fast_bytes']+a['slow_bytes']
# would_block placement: first delivery vs steady
wb=[int(re.match(r't=(\d+)',l).group(1)) for l in log if ' would_block count=' in l]
first_read=[int(re.match(r't=(\d+)',l).group(1)) for l in log if re.search(r' read event=1 ',l)]
a['would_block_events']=len(wb)
a['first_read_us']=first_read[0] if first_read else None
a['would_block_after_first_read']=sum(1 for x in wb if first_read and x>first_read[0])
# video payload
a['accepted_bytes']=t['accepted_bytes']
a['expected_video_payload_entry602']=715713077
a['accepted_bytes_exact']=t['accepted_bytes']==715713077
# wrap accounting
HZ=t['decoder_clock_hz'];W=2**32
a['wrap_seconds']=W/HZ
swaps=t['display_swaps']
gap=t['largest_display_gaps'][0]['cycles']
a['nominal_interval_cycles']=2002000
a['modeled_true_cycles']=(swaps-1)*2002000+gap
a['reported_cadence_cycles']=t['cadence_cycles']
wraps=round((a['modeled_true_cycles']-t['cadence_cycles'])/W)
a['inferred_wraps']=wraps
a['true_span_cycles']=t['cadence_cycles']+wraps*W
a['true_span_seconds']=a['true_span_cycles']/HZ
a['model_residual_cycles']=a['true_span_cycles']-a['modeled_true_cycles']
a['model_residual_seconds']=a['model_residual_cycles']/HZ
a['fixture_duration_seconds_entry602']=596.462533
a['true_fps']=swaps/a['true_span_seconds']
a['reported_cadence_seconds_is_wrapped']=True
# missed slot identity: gap ordinal is 8-bit (decode_hardware_cadence line 217), deadline record is full width
dr=t['deadline_records'][0]
a['deadline_record_ordinal']=dr['display_picture_ordinal']
a['gap_ordinal_8bit']=t['largest_display_gaps'][0]['display_picture_ordinal']
a['gap_ordinal_aliases_to_deadline_record']=dr['display_picture_ordinal']%256==t['largest_display_gaps'][0]['display_picture_ordinal']
a['missed_slot_cause']={k:dr[k] for k in ('decoder_ready','candidate_presentable','writer_busy','writer_capacity_blocked','presentation_hold','presentation_error','timestamp_candidate_active','timestamp_candidate_due','upstream_fifo_pending','input_starved_cycles_since_previous_swap','candidate_ready_delay_cycles','last_reference_completion_age_cycles','completed_reference_count','accepted_bytes_at_deadline')}
a['gap_seconds']=gap/HZ
a['gap_excess_seconds']=(gap-2002000)/HZ
a['missed_slot_fraction']=1/swaps
a['gap_position_fraction']=dr['display_picture_ordinal']/t['display_pictures']
# saturated counters that must not be read as totals
a['saturated_counters']={'pcm_sample_count':t['pcm_sample_count'],'associated_count':t['associated_count'],'display_pictures_8bit':t['display_pictures_8bit'],'display_swaps_8bit':t['display_swaps_8bit'],'display_counts_saturated':t['display_counts_saturated']}
a['audio_state']={'audio_underrun':t['audio_underrun'],'pcm_protocol_error':t['pcm_protocol_error'],'pcm_fifo_peak':t['pcm_fifo_peak']}
a['error_state']={'error_flags':t['error_flags'],'presentation_error':t['presentation_error'],'cache_bank_overlap_error':t['cache_bank_overlap_error'],'timestamp_advance_conflicts':t['timestamp_advance_conflicts'],'timestamp_delay_conflicts':t['timestamp_delay_conflicts'],'sequence_end_seen':t['sequence_end_seen'],'presentation_complete':t['presentation_complete'],'session_quiet':t['session_quiet'],'snapshot_reason':t['snapshot_reason']}
a['picture_counts']={'reference_pictures':t['reference_pictures'],'display_pictures':t['display_pictures'],'display_swaps':t['display_swaps'],'expected_entry602':17876}
a['counts_exact']=t['reference_pictures']==17876 and t['display_pictures']==17876 and t['display_swaps']==17875
a['installed']={'rbf_is_d466bed':cap['installed_candidate_is_d466bed'],'media_matches':cap['media_matches_entry602'],'boot':cap['syslog_boot_lines']}
a['entry603_freeze_point_pictures']=81
a['cleared_entry603_freeze']=t['display_pictures']>81 and t['error_flags']==0
(out/'entry605_analysis.json').write_text(json.dumps(a,indent=2,sort_keys=True)+'\n')
print(json.dumps(a,indent=2,sort_keys=True))
