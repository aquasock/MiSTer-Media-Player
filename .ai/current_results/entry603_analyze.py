from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,re
root=Path('/home/vash/MiSTer-Media-Player');capture=Path('/tmp/entry603-capture');reports=Path('/tmp/entry603-reports')
m=json.loads((capture/'entry603_capture.json').read_text());t=json.loads((capture/'entry603_current_terminal.json').read_text())
old=(capture/'entry603_current_arm_helper.log').read_bytes();raw=(reports/'arm_helper_later.log').read_bytes();log=raw.decode()
assert raw.startswith(old),'later helper log is a different playback'
assert 'helper forked pid=2210 ' in log and 'finish reason=eof' in log and 'exit_code=0 signaled=0' in log
assert 'transport_fault' not in log
assert log.startswith('t=3 start source=file:/media/fat/games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg index=65 ')
def records(kind):
 return [{k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',line)} for line in log.splitlines() if re.match(r'^t=\d+ '+kind+' ',line)]
reads=records('read');acks=records('profile_ack');summary,=records('profile_summary');finish,=records('finish');first,=records('first_byte')
expected=json.loads((root/'.ai/current_results/entry602_qualification.json').read_text())
assert len(reads)==summary['tx_calls']==finish['reads']==51234
assert [r['event'] for r in reads]==list(range(1,len(reads)+1))
assert [r['event'] for r in acks]==list(range(64,len(reads)+1,64))
assert len(acks)==summary['ack_chunks']==800
count=0
for r in reads:
 count+=r['count'];assert count==r['submitted'] and r['count']==r['fast_bytes']+r['slow_bytes']
 assert r['fast_bytes']%2==0
 assert r['queries']==r['batches']+(r['slow_bytes']+1)//2+1
 assert r['ack_sample']==(r['event']%64==0)
assert count==finish['submitted']==expected['transport']['transport_bytes']==839409548
for field,total in [('tx_us','tx_us'),('fast_bytes','fast_bytes'),('slow_bytes','slow_bytes'),('batches','burst_calls'),('queries','status_queries')]:
 assert sum(r[field] for r in reads)==summary[total]
assert all(a['uninitialized']==0 and a['words']==(reads[a['event']-1]['slow_bytes']+1)//2 for a in acks)
assert summary['read_calls']==len(reads)+finish['would_block']+1
for f in m['files'].values():
 data=Path(f['local']).read_bytes();assert len(data)==f['bytes'] and hashlib.sha256(data).hexdigest()==f['sha256']
assert m['files']['/media/fat/MiSTer']['sha256']=='3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f'
assert m['files']['/media/fat/MediaPlayer.rbf']['sha256']=='44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01'
readback=json.loads((reports/'readback.json').read_text())
assert readback['sha256']=='beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642' and readback['bytes']==739065873
assert readback['helper_later_sha256']==hashlib.sha256(raw).hexdigest()
assert t['schema_version']==19 and t['error_flags']==0x200 and t['presentation_error']
assert t['reference_pictures']==83 and t['display_pictures']==81 and t['display_swaps']==80
assert not t['audio_underrun'] and not t['pcm_protocol_error']
assert t['deadline_gap_count']==0 and t['gap_outlier_count']==0 and not t['deadline_records']
assert not t['sequence_end_seen'] and not t['session_quiet']
assert all(g['cycles']==2002001 for g in t['largest_display_gaps'])
assert t['session_cycles']<2**32
result={'analyzed_at':datetime.now(ZoneInfo('America/Phoenix')).isoformat(timespec='seconds'),'verdict':'FAIL: full A/V hardware test stops early with the sole presentation-scheduler error bit set.','user_reports':['Both Bob and Weave freeze near the beginning; initial audio is audible and video looks good; menu stays responsive.','Video played at the perfect speed until it froze.','It instantly locked up.'],'current_captured_mode':'Unspecified; only one of the reported two runs remains in the current log/snapshot.','installed_main_core_and_full_media_verified_unchanged':True,'hardware':{k:t[k] for k in ['schema_version','checksum','accepted_bytes','reference_pictures','display_pictures','display_swaps','error_flags','presentation_error','audio_underrun','pcm_protocol_error','deadline_gap_count','gap_outlier_count','session_cycles','cadence_seconds','delivered_fps','sequence_end_seen','presentation_complete','session_quiet','snapshot_reason','writer_wait_cycles','associated_count','stc_seconds']},'snapshot_session_seconds':t['session_cycles']/60000000,'largest_display_gaps':t['largest_display_gaps'],'no_wrap_at_failure':True,'presentation_complete_interpretation':'This means the separate B-reorder transaction is idle here; it is not successful completion of this all-I file.','snapshot_mode_limit':'No Bob/Weave or running RBF hash is encoded; no independent claim of which reported mode is captured. Installed files are independently verified.','transport':{'helper_pid':2210,'initial_log_is_exact_prefix_of_completed_log':True,'initial_log_bytes':len(old),'completed_log_bytes':len(raw),'completed_log_sha256':hashlib.sha256(raw).hexdigest(),'all_51234_read_records_and_800_ack_samples_reconciled':True,'helper_exit_code':0,'submitted_bytes':count,'expected_helper_transport_bytes':expected['transport']['transport_bytes'],'startup_eagain':first['would_block'],'steady_eagain':finish['would_block']-first['would_block'],'summary':summary,'interpretation':'The core drains/discards transport after a fatal scheduler result. Host EOF and all source bytes submitted do not mean the remaining movie was decoded or displayed, and snapshot accepted_bytes is frozen at the first fault.'},'readback':readback,'investigation':'The current scheduler admits native overlap using the per-candidate !timestamp_candidate_active flag, which can be false before a pending frame is released even in an anchored timestamped session. Classification releases the old candidate and activates its timestamp after overlap admission; completion into the third bank creates an ordinary secondary while the guard rejects timestamp_candidate_active. The same production ownership/timeline/scheduler modules reproduce this with legal three-bank ownership, while raw and serialized controls do not. Actual-prefix pipeline reproduction is recorded separately.','production_changed':False,'test_media_changed':False,'lifecycle_or_playback_actions':False,'hardware_accepted':False}
(reports/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['verdict','current_captured_mode','snapshot_session_seconds','no_wrap_at_failure']},indent=2))
