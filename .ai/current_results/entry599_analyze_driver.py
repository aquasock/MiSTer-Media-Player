from pathlib import Path
import json,csv,collections,hashlib
base=Path('/tmp/entry599-reports');root=Path('/home/vash/MiSTer-Media-Player')
q=json.loads((base/'qualification.json').read_text());old=[{k:int(v) for k,v in r.items()} for r in csv.DictReader((root/'.ai/current_results/entry597_decoder_costs.csv').open())]
result={'source_commit':q['source_commit'],'hardware_accepted':False,'boundary':q['scope'],'cases':[],'normal_ack_clocks_before':202,'normal_ack_clocks_after':200,'normal_wait_clocks_before':203,'normal_wait_clocks_after':201,'removed_normal_clocks_per_picture':16200,'removed_normal_ms_per_picture_at_60MHz':0.27}
for case in q['cases']:
 name=case['case'];n=case['expected_pictures']
 metrics=[{k:int(v) for k,v in r.items()} for r in csv.DictReader((base/(name+'_metrics.csv')).open())]
 events=list(csv.DictReader((base/(name+'_events.csv')).open()))
 for r in events:
  for k in ('picture','cycle','interval','bank'):r[k]=int(r[k])
 assert [m['picture'] for m in metrics]==list(range(1,n+1))
 presents=[r for r in events if r['event']=='present'];assert [r['picture'] for r in presents]==list(range(2,n+1))
 assert all(r['interval']==2002000 for r in presents[1:])
 assert not [r for r in events if r['event']=='empty_window']
 result['cases'].append({**case,'all_intervals_exact_after_initial_admission':True,'total_ddr_words':n*64800,'stored_blocks':n*8100,'mean_capacity_blocked_per_picture':sum(m['capacity_blocked'] for m in metrics)/n,'maximum_capacity_blocked_per_picture':max(m['capacity_blocked'] for m in metrics),'mean_ack_extra_per_picture':sum(m['ack_latency_sum']-m['recon_latency_sum'] for m in metrics)/n,'target_events':[r for r in events if r['picture'] in (167,346)]})
 if name in ('weave','bob','weave_pressure','long_pressure'):
  previous=0;residuals=[]
  for m,b in zip(metrics[:449],old):
   residuals.append(m['complete_cycle']-previous-m['presentation_hold']-b['interval_cycles']-(m['ack_latency_sum']-m['recon_latency_sum']));previous=m['complete_cycle']
  assert residuals==[1]+[0]*448,collections.Counter(residuals)
  result['cases'][-1]['first_449_exact_cost_residuals']=dict(collections.Counter(residuals))
result['total_cadence_pictures']=sum(c['expected_pictures'] for c in q['cases'])
result['pixel_validation']='Separate writer-connected TFF/BFF/progressive test checks 12 pictures and 6,220,800 DDR bytes with established +/-1 IDCT tolerance and 600/997 busy clocks. Saturation correctness, not a realtime throughput claim; normal reconstruction and cadence gates run separately.'
result['long_run_note']='898 pictures made by concatenating the exact ceiling elementary stream twice after removing the first sequence-end marker; about 30 seconds of content, not a full-disc soak.'
result['preexisting_tests']=q['preexisting_failures']
(base/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'pictures':result['total_cadence_pictures'],'cases':[{k:c[k] for k in ('case','completed','missed_pictures','capacity_cycles','maximum_capacity_blocked_per_picture')} for c in result['cases']]},indent=2))
