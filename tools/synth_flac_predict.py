#!/usr/bin/env python3
"""Isolated Cyclone V prediction primitive fit; does not build/change the core."""
import argparse, os, subprocess, json, re, hashlib
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
p.add_argument('--quartus',type=Path,default=Path('/home/vash/intelFPGA_lite/17.0/quartus/bin'))
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[1];source=root/'rtl/audio/flac/flac_predict_mac.sv'
(out/'predict.qpf').write_text('PROJECT_REVISION = "predict"\n')
(out/'predict.qsf').write_text(f'''set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U23I7
set_global_assignment -name TOP_LEVEL_ENTITY flac_predict_mac
set_global_assignment -name SYSTEMVERILOG_FILE "{source}"
set_global_assignment -name SDC_FILE predict.sdc
set_global_assignment -name NUM_PARALLEL_PROCESSORS 6
set_global_assignment -name SEED 52
set_global_assignment -name ALM_REGISTER_PACKING_EFFORT MEDIUM
set_instance_assignment -name VIRTUAL_PIN ON -to *
''')
(out/'predict.sdc').write_text('create_clock -name clk -period 16.667 [get_ports clk]\nderive_clock_uncertainty\n')
env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus-compat-libs'+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
with (out/'compile.log').open('w') as f:
 subprocess.run([str(a.quartus/'quartus_sh'),'--flow','compile','predict'],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
fit=(out/'predict.fit.rpt').read_text(errors='replace');summary=(out/'predict.fit.summary').read_text()
result={'scope':'isolated primitive, virtual I/O; not a whole-core resource/timing result','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
for label,key in [('Logic utilization (in ALMs)','estimated_ALMs'),('Total registers','registers'),('Total RAM Blocks','M10Ks'),('Total DSP Blocks','DSPs')]:
 result[key]=int(re.search(re.escape(label)+r'\s*:\s*([\d,]+)',summary).group(1).replace(',',''))
result['placed_ALMs']=int(re.search(r'\[A\] ALMs used in final placement[^;]*;\s*([\d,]+)',fit).group(1).replace(',',''))
(out/'resources.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
