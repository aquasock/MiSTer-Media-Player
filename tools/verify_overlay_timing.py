#!/usr/bin/env python3
"""Fit the isolated pixel compositor at 148.5 MHz before a full-core rebuild.

This checks local pipeline feasibility, not full-core timing qualification.
"""
from pathlib import Path
import argparse,os,shutil,subprocess
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=a.output.resolve();(out/'rtl').mkdir(parents=True,exist_ok=True)
for src in [root/'rtl/media_overlay_compositor.sv',*root.glob('rtl/media_overlay_*.hex'),*root.glob('rtl/media_overlay_*.mem')]:shutil.copy2(src,out/'rtl'/src.name)
(out/'overlay.qpf').write_text('QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "overlay"\n')
(out/'overlay.qsf').write_text('''set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U23I7
set_global_assignment -name TOP_LEVEL_ENTITY media_overlay_compositor
set_global_assignment -name SYSTEMVERILOG_FILE rtl/media_overlay_compositor.sv
set_global_assignment -name SDC_FILE overlay.sdc
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name NUM_PARALLEL_PROCESSORS 6
set_global_assignment -name SEED 52
set_instance_assignment -name VIRTUAL_PIN ON -to *
''')
(out/'overlay.sdc').write_text('''create_clock -name pixel -period 6.732 [get_ports clk]
derive_clock_uncertainty
# Virtual-port insertion delays are not the production interface. This small
# fit checks only internal register paths; the full core times all interfaces.
set_false_path -from [all_inputs]
set_false_path -to [all_outputs]
''')
q=Path(os.environ.get('QUARTUS_ROOTDIR','/home/vash/intelFPGA_lite/17.0/quartus'))/'bin/quartus_sh'
env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus-compat-libs'+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
with (out/'compile.log').open('w') as log:subprocess.run([str(q),'--flow','compile','overlay'],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
print((out/'output_files/overlay.fit.summary').read_text());print((out/'output_files/overlay.sta.summary').read_text())

(out/'paths.tcl').write_text("""package require ::quartus::project
package require ::quartus::sta
project_open overlay
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -from [all_registers] -to [all_registers] -npaths 10 -detail full_path -file pixel_register_setup.rpt
report_timing -hold -from [all_registers] -to [all_registers] -npaths 10 -detail full_path -file pixel_register_hold.rpt
project_close
""")
with (out/'paths.log').open('w') as log:subprocess.run([str(q.parent/'quartus_sta'),'-t','paths.tcl'],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
for kind in ['setup','hold']:
 print('\n'.join((out/f'pixel_register_{kind}.rpt').read_text().splitlines()[:5]))
