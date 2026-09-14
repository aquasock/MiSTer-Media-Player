#!/usr/bin/env python3
"""Audit all corners and physical resources, then package clean seed candidates."""
from pathlib import Path
import argparse,json,re,hashlib,shutil,datetime
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('build',type=Path);p.add_argument('--cdc-registers',type=int,default=None)
p.add_argument('--baseline-alms',type=int,default=35774);p.add_argument('--baseline-ram',type=int,default=508)
p.add_argument('--require-no-profiler',action='store_true')
p.add_argument('--require-no-reporting',action='store_true')
p.add_argument('--require-no-audio-test',action='store_true')
p.add_argument('--scope',default='See the source-specific test instructions for feature scope and hardware acceptance.')
a=p.parse_args();base=a.build.resolve();state=json.loads((base/'status.json').read_text());summary={}
for seed in (52,61,87):
 root=base/f'seed{seed}';info=state['seeds'].get(str(seed),{})
 if info.get('stage')!='complete':
  summary[str(seed)]={'seed':seed,'stage':info.get('stage'),'timing_passed':False};continue
 lines=(root/'phase1p_timing_reports/configuration_cdc_audit.rpt').read_text().splitlines()
 # All functional mailboxes are mandatory. Gate one may retain the old
 # reporting mailbox; gate two replaces it with the reader-failure mailbox.
 # Older builds can supply --cdc-registers explicitly.
 expected_cdc=a.cdc_registers if a.cdc_registers is not None else 177+(6 if any('media_telemetry_config' in x or 'reader_error_config' in x for x in lines) else 0)
 cdc=len(lines)==expected_cdc and all(x.endswith(': 1 registers') for x in lines)
 corners={}
 for i in range(4):
  corner={}
  for kind in ('setup','hold','recovery','removal','mpw'):
   path=root/f'corner_timing_reports/corner{i}_{kind}.rpt'
   vals=[float(v) for v in re.findall(r'^;[^;\n]+;\s*(-?\d+\.\d+)\s*;',path.read_text(),re.M)]
   if not vals:raise RuntimeError(f'No timing data in {path}')
   corner[kind]=min(vals)
  paths=(root/f'corner_timing_reports/corner{i}_setup_paths.rpt').read_text()
  corner['model']=re.search(r'Delay Model:\s*\n\s*([^\n]+)',paths).group(1)
  corners[str(i)]=corner
 minima={k:min(c[k] for c in corners.values()) for k in ('setup','hold','recovery','removal','mpw')}
 fit=(root/'output_files/MediaPlayer.fit.summary').read_text();resources={}
 for label,key in [('Logic utilization (in ALMs)','estimated_ALMs'),('Total registers','registers'),('Total RAM Blocks','RAM_blocks'),('Total DSP Blocks','DSP_blocks'),('Total PLLs','PLLs')]:
  resources[key]=int(re.search(re.escape(label)+r'\s*:\s*([\d,]+)',fit).group(1).replace(',',''))
 detail=(root/'output_files/MediaPlayer.fit.rpt').read_text(errors='replace')
 resources['actual_placed_ALMs']=int(re.search(r'\[A\] ALMs used in final placement[^;]*;\s*([\d,]+)',detail).group(1).replace(',',''))
 rows=[r for r in detail.splitlines() if 'altsyncram:intermediate[' in r and 'row_data' in r and re.search(r'M10K_X\d+_Y\d+_N\d+',r)]
 if len(rows)!=24:raise RuntimeError(f'Seed {seed}: expected 24 existing IDCT intermediate M10Ks, found {len(rows)}')
 overlay_sites=set()
 for r in detail.splitlines():
  if 'player_overlay' in r:overlay_sites.update(re.findall(r'M10K_X\d+_Y\d+_N\d+',r))
 resources['overlay_physical_M10Ks']=len(overlay_sites)
 resources['added_actual_ALMs']=resources['actual_placed_ALMs']-a.baseline_alms
 resources['added_M10Ks']=resources['RAM_blocks']-a.baseline_ram
 resources['ALMs_free']=41910-resources['actual_placed_ALMs'];resources['M10Ks_free']=553-resources['RAM_blocks']
 budget=resources['added_actual_ALMs']<=2000 and resources['added_M10Ks']<=12
 enable_file=root/'phase1p_timing_reports/player_scene_enable_audit.rpt'
 enable_text=enable_file.read_text() if enable_file.exists() else ''
 enable_count=re.search(r'Four-cycle formatter registers: (\d+)',enable_text)
 enable_ok='Enable counter: 2 registers' in enable_text and enable_count is not None and int(enable_count.group(1))>=400
 profiler_absent=(root/'phase1p_timing_reports/diagnostic_removal_audit.rpt').exists() and (root/'phase1p_timing_reports/diagnostic_removal_audit.rpt').read_text().strip()=='Cadence profiler registers: 0'
 reporting_file=root/'phase1p_timing_reports/reporting_removal_audit.rpt'
 reporting_lines=reporting_file.read_text().splitlines() if reporting_file.exists() else []
 reporting_absent=len(reporting_lines)==17 and all(x.endswith(': 0 registers') for x in reporting_lines)
 audio_file=root/'phase1p_timing_reports/audio_test_removal_audit.rpt'
 audio_lines=audio_file.read_text().splitlines() if audio_file.exists() else []
 audio_absent=len(audio_lines)==14 and all(x.endswith(': 0 registers') for x in audio_lines[:11]) and all(re.search(r': [1-9][0-9]* registers$',x) for x in audio_lines[11:])
 passed=(not a.require_no_audio_test or audio_absent) and cdc and enable_ok and (not a.require_no_reporting or reporting_absent) and (not a.require_no_profiler or profiler_absent) and all(v>=0 for v in minima.values())
 item={'source':state['source'],'seed':seed,'corners':corners,'minimum_slack_ns':minima,
 'audio_test_absent_and_pcm_retained':audio_absent,'reporting_absent':reporting_absent,'profiler_absent':profiler_absent,'scene_enable_audit_passed':enable_ok,'cdc_registers':len(lines),'cdc_audit_passed':cdc,'timing_passed':passed,'resource_budget_passed':budget,
 'hardware_accepted':False,'rbf_sha256':info['rbf_sha256'],'resources':resources,
 'scope':a.scope}
 summary[str(seed)]=item
 out=base.parent/f'hardware-test-{state["source"][:7]}'/f'seed{seed}';out.mkdir(parents=True,exist_ok=True)
 date=datetime.datetime.fromtimestamp(info['started']).strftime('%Y%m%d');rbf=out/f'MediaPlayer_{date}.rbf'
 shutil.copy2(root/'output_files/MediaPlayer.rbf',rbf)
 if hashlib.sha256(rbf.read_bytes()).hexdigest()!=info['rbf_sha256']:raise RuntimeError('Copied RBF hash mismatch')
 (out/'build-info.json').write_text(json.dumps(item,indent=2)+'\n')
 if not passed:(out/'TIMING_FAILED.txt').write_text('This seed fails timing or CDC qualification. Do not use as the preferred candidate.\n')
 if not budget:(out/'RESOURCE_BUDGET_EXCEEDED.txt').write_text('This seed exceeds the initial incremental UI resource budget; inspect build-info.json.\n')
(base/'corner-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for seed,item in summary.items():print(seed,'PASS' if item['timing_passed'] else 'FAIL',item.get('minimum_slack_ns',item.get('stage')),item.get('resources',{}))
