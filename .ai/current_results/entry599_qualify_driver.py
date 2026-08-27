from pathlib import Path
import hashlib,json,re,subprocess
base=Path('/home/vash/mister-builds/entry599');root=Path('/run/media/vash/GIT/MiSTer-Media-Player')
source='f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4'
read=lambda name:json.loads((base/name).read_text())
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==source
subprocess.run(['git','diff','--quiet',source,'--','.'],cwd=root,check=True)
fpga=read('FPGA/entry599-build.json');integ=read('integrated_results.json');reg=read('regression.json');shared=read('shared_pb_result.json')
assert fpga['source_commit']==integ['source_commit']==reg['source_commit']==source
assert fpga['timing_positive'] and fpga['compile_success'] and fpga['errors']==0 and not fpga['new_ignored_timing_filters']
assert integ['all_passed'] and len(integ['cases'])==5
for c in integ['cases']:assert c['exit_code']==0 and not c['missed_pictures'] and c['completed']==c['expected_pictures']
expected_pass={'native','reconstruction','tb_h262_ddram_store_overlap','tb_h262_b_presentation_scheduler','tb_h262_prediction_block_fetcher','tb_h262_prediction_word_cache'}
excluded={'tb_h262_double_scratch_tags','tb_h262_prediction_error_sources'}
assert {r['name'] for r in reg['checks']}==expected_pass|excluded
for r in reg['checks']:assert (r['exit_code']==0)==(r['name'] in expected_pass)
assert {r['name'] for r in read('preexisting_failures.json')}==excluded
for name in excluded:
 old=(base/(name+'-baseline.log')).read_text();new=(base/(name+'.log')).read_text()
 # The same diagnostic, independent of source checkout path or line prefix.
 signature='Unable to bind wire/reg/memory `dut.ascratch\'' if 'scratch' in name else 'FAIL error=0 source=0 detail=0 expected=3/7'
 assert signature in old and signature in new
pixels=read('writer_pixels.json')
assert pixels['source_commit']==source and pixels['all_passed'] and len(pixels['checks'])==3
assert shared['exit_code']==0 and 'errors=0/0/0/0' in '\n'.join(shared['pass_lines'])
for name,signature in [('old','capture-edge grant expected=1 actual=0'),('unsafe','capture-edge grant expected=0 actual=1')]:assert signature in (base/(name+'-negative.log')).read_text()
fixtures=read('fixtures.json')
assert fixtures['8mbps']['sha256']=='04758691e3e51c72ca2e7c3723b4dda2fbd473783425215df8ec2dcb5585cbe0'
result={'source_commit':source,'qualified_for_hardware_test':True,'hardware_accepted':False,'scope':'Capacity-safe writer acknowledgement; no host change. Integrated cadence excludes HPS transport, physical DDR contention, scaler and startup CDC; saved raster phases are calibrated.','checks_passed':sorted(expected_pass)+['writer_connected_ffmpeg_pixels_with_heavy_pressure','shared_p_b_writer','old_ack_negative_control','unsafe_ack_negative_control','five_actual_writer_cadence_cases','positive_quartus_timing'],'preexisting_failures':{'tb_h262_double_scratch_tags':'Old internal signal names no longer bind on baseline either; expanded writer contract checks all six scratch bank/plane address+payload outputs instead.','tb_h262_prediction_error_sources':'Existing B error-sideband expectation fails identically on unchanged baseline; unrelated to writer acknowledgement.'},'total_cadence_pictures':sum(c['completed'] for c in integ['cases']),'cases':integ['cases'],'fpga_rbf_sha256':fpga['rbf_sha256'],'main_retained_sha256':'3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f','fixtures':fixtures,'evidence_sha256':{name:hashlib.sha256((base/name).read_bytes()).hexdigest() for name in ('FPGA/entry599-build.json','integrated_results.json','regression.json','shared_pb_result.json','preexisting_failures.json','writer_pixels.json')}}
(base/'qualification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'qualified':True,'pictures':result['total_cadence_pictures'],'timing':fpga['worst_slack_ns']},indent=2))
