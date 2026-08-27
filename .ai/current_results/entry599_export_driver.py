from pathlib import Path
import tarfile,json,hashlib
base=Path('/home/vash/mister-builds/entry599')
names=['qualification.json','integrated_results.json','regression.json','source.json','fixtures.json','preexisting_failures.json','shared_pb_result.json','shared_pb.log','writer_pixels.json','tb_entry599_i_cadence.sv','tb_entry599_writer_pixels.sv','integrated_compile_command.json','old-negative.log','unsafe-negative.log','native.log','reconstruction.log','writer_pixels_tff_initial_throughput_assertion.log']
for case in ('weave','bob','weave_pressure','long_pressure','8mbps'):
 names.extend(case+s for s in ('_events.csv','_metrics.csv','_command.json','_result.json','.log'))
for case in ('tff','bff','progressive'):names.append('writer_pixels_'+case+'.log')
for name in ('tb_h262_ddram_store_overlap','tb_h262_b_presentation_scheduler','tb_h262_prediction_block_fetcher','tb_h262_prediction_word_cache','tb_h262_prediction_error_sources','tb_h262_double_scratch_tags'):
 names.extend((name+'.log',name+'-result.json'))
for name in ('tb_h262_prediction_error_sources','tb_h262_double_scratch_tags'):names.append(name+'-baseline.log')
names+=['FPGA/output_files/MediaPlayer.sta.summary','FPGA/output_files/MediaPlayer.fit.summary']
manifest={name:{'bytes':(base/name).stat().st_size,'sha256':hashlib.sha256((base/name).read_bytes()).hexdigest()} for name in names}
(base/'export_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
with tarfile.open('/tmp/entry599-reports.tar.gz','w:gz') as tar:
 for name in names+['export_manifest.json']:tar.add(base/name,arcname=Path(name).name)
print('Exported',len(names),'evidence files')
