import collections, csv, hashlib, json, re
from pathlib import Path

root=Path('/home/vash/MiSTer-Media-Player')
out=Path('/tmp/entry598')
base=[{k:int(v) for k,v in row.items()} for row in csv.DictReader((root/'.ai/current_results/entry597_decoder_costs.csv').open())]

def read_case(name,writer):
    events=list(csv.DictReader((out/f'{name}_events.csv').open()))
    assert all(all(row.values()) for row in events)
    for row in events:
        for key in ('picture','cycle','interval','bank'): row[key]=int(row[key])
    metrics=[{k:int(v) for k,v in row.items()} for row in csv.DictReader((out/f'{name}_metrics.csv').open())]
    assert len(metrics)==449 and [x['picture'] for x in metrics]==list(range(1,450))
    completes=[x for x in events if x['event']=='complete']
    presents=[x for x in events if x['event']=='present']
    assert [x['picture'] for x in completes]==list(range(1,450))
    assert [x['picture'] for x in presents]==list(range(2,450))
    assert all(x['ack_count']==8100 and x['capacity_blocked']==0 for x in metrics)
    assert all(x['pipeline_wait']==(1644300 if writer else 1628100) for x in metrics)
    assert all(x['ack_latency_sum']==1636200 and x['recon_latency_sum']==1620000 for x in metrics)
    previous=0
    residuals=[]
    for m,b in zip(metrics,base):
        residual=m['complete_cycle']-previous-m['presentation_hold']-b['interval_cycles']-(16200 if writer else 0)
        residuals.append(residual)
        previous=m['complete_cycle']
    assert residuals==[1]+[0]*448,collections.Counter(residuals)
    ready=[x for x in events if x['event']=='ready']
    gaps=[x for x in presents if x['picture']>2 and x['interval']>2002000]
    empty=[x for x in events if x['event']=='empty_window']
    log=(out/f'{name}.log').read_text()
    assert 'INTEGRATED_PASS' in log and 'words=29095200 stores=3636900' in log
    assert f'displayed=449 gaps={len(gaps)}' in log
    assert len(empty)==len(gaps)
    return dict(name=name,writer_capacity_ack_used=bool(writer),pictures_completed=449,
        pictures_displayed=449,swaps=448,accepted_ddr_words=29095200,stored_blocks=3636900,
        checked_picture_order=True,checked_sample_counts=True,new_pixel_value_oracle=False,
        late_picture_intervals=gaps,missed_windows=empty,
        total_presentation_hold_cycles=sum(x['presentation_hold'] for x in metrics),
        zero_capacity_blocking=True,cycles_per_block_from_coefficient_end_to_reconstruction=200,
        cycles_per_block_from_coefficient_end_to_actual_writer_ack=202,
        parser_pipeline_wait_cycles_per_block=203 if writer else 201,
        fixed_cost_accounting_residuals=dict(collections.Counter(residuals)),
        reference_to_ready_delay_distribution=dict(collections.Counter(x['interval'] for x in ready)),
        target_picture_events=[x for x in events if x['picture'] in (166,167,168,345,346,347)])

cases=[read_case('weave_ideal_ddr',1),read_case('bob_ideal_ddr',1),read_case('weave_direct_recon_ack',0)]
hardware=[]
for number,mode in ((594,'Weave'),(595,'Bob')):
    source=json.loads((root/f'.ai/current_results/entry{number}_analysis.json').read_text())
    for deadline in source['deadline_records']:
        n=deadline['display_picture_ordinal']
        observed=deadline['last_reference_completion_age_cycles']+deadline['candidate_ready_delay_cycles']
        blocked=deadline['writer_capacity_blocked_cycles_since_previous_swap']
        predicted=base[n-1]['interval_cycles']+16200+37+blocked
        hardware.append(dict(mode=mode,picture=n,isolated_interval_cycles=base[n-1]['interval_cycles'],
            fixed_writer_handoff_cycles=16200,next_header_release_cycles=37,
            recorded_capacity_blocked_cycles=blocked,predicted_total_cycles=predicted,
            observed_reference_to_ready_cycles=observed,residual_cycles=observed-predicted))
assert [x['residual_cycles'] for x in hardware]==[0,0,0,26]
total=sum(x['interval_cycles'] for x in base)
budget=449*2002000
result=dict(source_commit='feb50c2a37ca9ac059bc3bc2860dfefd4fd29890',
    production_commit='a4f2769f6e55774abfc5990052702734b9024d15',
    checkout_commit='39f0875e1fc1785c9b1f7d13fdc6cfd4321ec711',
    fixture_sha256='3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065',
    boundary='Actual production frontend, full publication shell, I parser/IQ/IDCT/reconstruction, two-bank writer and presentation scheduler. Continuously available byte source and always-ready modeled DDR. Actual native-startup/video CDC, HPS transport, input queues, DDR arbitration/read contention and scaler are excluded. Startup admission and raster phase are calibrated from saved hardware timestamps, not independently predicted.',
    startup_parameters={'Weave':{'phase':1961195,'first_allowed_swap_cycle':7967195},
                        'Bob':{'phase':270754,'first_allowed_swap_cycle':6276754},
                        'derivation':'Phase is saved first missed-deadline cycle modulo 2002000; first swap is last presented timestamp minus (447 nominal intervals plus 2 extra intervals), less the telemetry one-clock observation delay.'},
    cases=cases,hardware_cost_reconciliation=hardware,
    hardware_reconciliation_limit='The reported writer-blocked counter spans the prior display interval, whereas the reference-to-ready interval starts at preceding reference completion. Their near-exact agreement supports the accounting but is not an independent cycle-by-cycle replay of physical memory stalls.',
    sustained_budget=dict(nominal_picture_ms=2002000/60000,
        isolated_average_ms=total/449/60000,
        with_fixed_writer_average_ms=(total+449*16200)/449/60000,
        with_fixed_writer_equivalent_fps=449*60000000/(total+449*16200),
        fixed_writer_handoff_ms_per_picture=16200/60000,
        baseline_excess_over_449_budgets_ms=(total+449*16200-budget)/60000,
        direct_ack_spare_over_449_budgets_ms=(budget-total)/60000),
    control_limit='Direct reconstruction acknowledgement is an ideal-memory testbench counterfactual, not a deployable fix: it ignores writer capacity when both banks are full. Actual writer data/count behavior remains enabled, but there is no real memory contention or new pixel-value oracle.',
    recommendation='First evaluate a capacity-safe early writer grant that removes both normal handoff clocks when the alternate bank is free, retains exactly one delayed grant under full-bank pressure, and preserves block_stored, all DDR payload/address/order behavior and reset/error protection. Do not bypass capacity checks, change cadence, weaken next-header release, resize queues, or increase the clock. Validate all supported clients/modes and full hardware ceiling cadence before claiming a fix.',
    production_changed=False,hardware_test_performed=False,strict_hardware_pass=False,analysis_checks='PASS')
result['evidence_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.glob('*')) if p.is_file() and p.name!='entry598_analysis.json'}
(out/'entry598_analysis.json').write_text(json.dumps(result,indent=2)+'\n')
rows='\n'.join('| '+c['name']+' | '+str(len(c['late_picture_intervals']))+' | '+(', '.join(str(g['picture']) for g in c['late_picture_intervals']) or 'None')+' |' for c in cases)
report=f'''# DVD-ceiling timing investigation

Production remains `a4f2769`; diagnostic checkout `39f0875`. No MiSTer action or production change was made.

## Finding

The decoder's normal writer-capacity handoff adds **two clocks per block**, or **16,200 clocks / 0.27 ms per 720×480 picture**. With that cost included, this exact clip requires **33.529155 ms per picture on average**, against **33.366667 ms available**, even before physical memory delays. That is a sustained shortfall of about 0.49%; extra buffering alone cannot hide it indefinitely.

The actual production pipeline, writer and scheduler were exercised with always-available input and always-ready DDR:

| Diagnostic | Late intervals | Picture ordinals |
|---|---:|---|
{rows}

All three runs complete 449 ordered picture identities, 448 swaps, 29,095,200 DDR words and 3,636,900 stored blocks without asserted errors. Pixel counts are checked; there is no new pixel-value oracle.

The direct-reconstruction-ack run changes only the testbench's parser-release connection. The writer still runs. **This is not a deployable patch:** it bypasses the capacity protection required when both capture banks are full.

## Hardware agreement

For the two saved Weave misses and Bob picture 167, the following sum exactly matches the measured previous-reference-to-candidate-ready interval:

`isolated decoder interval + 16,200 writer clocks + 37 next-header clocks + reported capacity-blocked clocks`

Bob picture 346 differs by 26 clocks (0.433 microseconds). The hardware counters have slightly different interval starting boundaries, so this is supporting cost accounting, not a reconstructed physical stall trace.

The ideal-memory misses occur at different ordinals from physical 167/346. The model omits real transport, queues, DDR arbitration/read contention, scaler and startup/video CDC; it uses raster phase and startup admission derived from saved hardware timestamps. It does not independently reproduce the physical startup or each hardware stall.

## Recommended next change

Retiming the writer's capacity grant is the smallest measured candidate. Remove both normal handoff clocks only when the alternate capture bank is free; preserve exactly one delayed grant under full-bank pressure. Preserve `block_stored`, all DDR payload/address/order behavior, ownership and reset/error protection.

Extend the existing writer-overlap regression to cover immediate/delayed grants, duplicates, premature grants, random backpressure, reset and all output bytes. Then qualify supported reconstruction and presentation/P/B clients, Quartus timing, the exact ceiling clip in both hardware modes, and a longer sustained run. Keep the clock, cadence, startup, queue sizes and transport guards unchanged.

The existing unmodified writer-overlap regression passes. No hardware fix or full DVD compatibility is claimed by this investigation.
'''
(out/'entry598_findings.md').write_text(report)
print(json.dumps({'cases':[{'name':x['name'],'gaps':[g['picture'] for g in x['late_picture_intervals']]} for x in cases],
                  'budget':result['sustained_budget'],'hardware':hardware,'checks':result['analysis_checks']},indent=2))
