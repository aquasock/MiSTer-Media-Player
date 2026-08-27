import csv, hashlib, json, statistics, sys
from pathlib import Path

root=Path('/home/vash/MiSTer-Media-Player')
out=Path('/tmp/entry597')
sys.path.insert(0,str(root/'tools/streams'))
import analyze_h262_compatibility as analyzer
from generate_test_dvd_ceiling import access_units

fixture=Path('/tmp/entry593-reports/bbb_480i_tff_15s_9800kbps.m2v')
data=fixture.read_bytes()
assert hashlib.sha256(data).hexdigest()=='3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065'
sizes, picture_ends, delays=access_units(data)
structure=analyzer.analyze_file(fixture)
codes=analyzer.start_codes(data)
quantizers=[]
for i,(_,code) in enumerate(codes):
    if code==0: quantizers.append([])
    elif 1<=code<=0xAF:
        quantizers[-1].append(analyzer.read_bits(analyzer.payload_between(data,codes,i),0,5))
assert len(sizes)==449==len(quantizers)
records=[]
offset=0
for i,(bits,q,pic) in enumerate(zip(sizes,quantizers,structure['pictures'])):
    size=bits//8
    records.append(dict(picture=i+1,zero_based_index=i,clip_time_seconds=i*1001/30000,
                        access_unit_start=offset,access_unit_end_exclusive=offset+size,
                        access_unit_bytes=size,size_rank_descending=1+sum(n>bits for n in sizes),
                        vbv_delay_90khz=delays[i],slice_quantizer_scale_codes=q,
                        coding_extension=pic['coding_extension'],slice_count=pic['slice_count']))
    offset+=size
assert offset==len(data)
assert len({json.dumps(x['coding_extension'],sort_keys=True) for x in records})==1
assert all(x['slice_count']==30 for x in records)

hardware=[]
for number,mode in ((594,'Weave'),(595,'Bob')):
    old=json.loads((root/f'.ai/current_results/entry{number}_analysis.json').read_text())
    for deadline in old['deadline_records']:
        n=deadline['display_picture_ordinal']
        a=deadline['last_reference_completion_age_cycles']
        b=deadline['candidate_ready_delay_cycles']
        assert deadline['completed_reference_count']==n-1
        assert not deadline['decoder_ready'] and deadline['decoder_input_pending']
        assert deadline['input_starved_cycles_since_previous_swap']==0
        hardware.append(dict(mode=mode,picture=n,
            accepted_bytes=deadline['accepted_bytes_at_deadline'],
            bytes_before_access_unit_end=records[n-1]['access_unit_end_exclusive']-deadline['accepted_bytes_at_deadline'],
            prior_reference_headstart_ms=(a-2002000)/60000,
            previous_reference_to_candidate_ready_cycles=a+b,
            previous_reference_to_candidate_ready_ms=(a+b)/60000,
            candidate_ready_lateness_ms=b/60000))

result=dict(fixture_sha256=hashlib.sha256(data).hexdigest(),fixture_bytes=len(data),
    source_commit='feb50c2a37ca9ac059bc3bc2860dfefd4fd29890',
    production_commit='a4f2769f6e55774abfc5990052702734b9024d15',
    build_checkout='04ca33b94c5ad1b709285fe4891d35cc149aae9c',
    ordinal_mapping='Profiler captures display_picture_count_full + 1; completed references are 166/345. Ordinals are one-based: indices 166/345.',
    uniform_structure=dict(pictures=449,picture_type='I',coding_extension_variants=1,
        slices_per_picture=30,macroblocks_per_picture=1350,blocks_per_picture=8100),
    byte_size_distribution=dict(median=statistics.median(sizes)/8,maximum=max(sizes)//8),
    hardware=hardware,pictures=records,
    visual_observations={'167':'Dense foliage during camera motion; following picture 168 cuts to a mostly blue-sky view.',
                         '346':'Flying squirrel approaching the camera against blue sky; following picture 347 has a much larger squirrel close-up.'},
    acceptance='Two unchanged hardware cadence misses; no new hardware test or production change.')

csvpath=out/'pictures.csv'
if csvpath.exists():
    costs=[{k:int(v) for k,v in row.items()} for row in csv.DictReader(csvpath.open())]
    assert len(costs)==449 and [x['picture'] for x in costs]==list(range(1,450))
    assert all(x['pixels']==518400 and x['blocks']==8100 for x in costs)
    assert all(x['pipeline_wait']==1628100 and x['transform_cycles']==1036800 for x in costs)
    assert 'I_THROUGHPUT_PASS pictures=449' in (out/'profile.log').read_text()
    for c,p in zip(costs,records):
        c['decode_ms_at_60mhz']=c['decode_cycles']/60000
        c['decode_cost_rank_descending']=1+sum(x['decode_cycles']>c['decode_cycles'] for x in costs)
        c['ac_coefficient_count_rank_descending']=1+sum(x['ac_coefficients']>c['ac_coefficients'] for x in costs)
        c['average_quantizer_scale_code_per_block']=c['quant_sum']/c['blocks']
        p['decoder_profile']=c
    for h in hardware:
        isolated=costs[h['picture']-1]['interval_cycles']
        h['hardware_interval_minus_isolated_interval_cycles']=h['previous_reference_to_candidate_ready_cycles']-isolated
    result['simulation']=dict(pictures=449,errors=0,
        scope='Current production frontend/parser/IQ/IDCT/intra reconstruction with continuously available byte input. No host transport, DDR persistence, presentation, or pixel-oracle comparison. Optimistic decoder-only cost, not hardware replay.',
        nominal_picture_budget_cycles=2002000,
        median_decode_ms=statistics.median(x['decode_cycles'] for x in costs)/60000,
        maximum_decode_ms=max(x['decode_cycles'] for x in costs)/60000,
        pictures_over_nominal_decode_budget=sum(x['decode_cycles']>2002000 for x in costs),
        constant_pipeline_wait_cycles_per_picture=1628100,
        constant_idct_transform_cycles_per_picture=1036800,
        interpretation='Observed IDCT transform cycles and parser pipeline-wait cycles are fixed across all pictures. Decode-cost variation lies outside those fixed counts, including variable compressed-bit parsing. The two missed pictures are not uniquely complex arithmetic transforms.')
    result['analysis_checks']='PASS'
else:
    result['analysis_checks']='STATIC_ONLY_SIMULATION_PENDING'
(out/'entry597_analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='pictures'},indent=2))
for n in [165,166,167,168,169,344,345,346,347,348]:
    p=records[n-1]
    print(n,p['access_unit_bytes'],p['size_rank_descending'],p.get('decoder_profile',{}))
