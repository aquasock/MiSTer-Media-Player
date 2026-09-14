#!/usr/bin/env python3
"""Fit independent 22.5792/24.576 MHz PLLs for native CD and movie clocks.

Isolated feasibility probe only; does not modify production PLLs or pin routing.
"""
import argparse,os,subprocess,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
p.add_argument('--switch-output',action='store_true',help='Include the vendor glitch-free clock selector in the fit')
p.add_argument('--quartus',type=Path,default=Path('/home/vash/intelFPGA_lite/17.0/quartus/bin'))
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[1]
source=(root/'sys/pll_audio/pll_audio_0002.v').read_text()
(out/'pll_movie.v').write_text(source)
(out/'pll_cd.v').write_text(source.replace('pll_audio_0002','pll_cd').replace('24.576000 MHz','22.579200 MHz'))
(out/'clock_probe.sv').write_text('''module clock_probe(input refclk,reset,output [1:0] locked,output [1:0] sample_clock);
wire movie,cd;
pll_audio_0002 a(.refclk(refclk),.rst(reset),.locked(locked[0]),.outclk_0(movie));
pll_cd b(.refclk(refclk),.rst(reset),.locked(locked[1]),.outclk_0(cd));
reg [8:0] md=0,cd_count=0;
always @(posedge movie) md<=md+1'b1;
always @(posedge cd) cd_count<=cd_count+1'b1;
assign sample_clock={cd_count[8],md[8]};
endmodule
''')
if a.switch_output:
 (out/'clock_probe.sv').write_text('''module clock_probe(input refclk,reset,select_cd,enable,output audio_clock,output [1:0] locked,output [1:0] sample_clock);
wire movie,cd;
pll_audio_0002 a(.refclk(refclk),.rst(reset),.locked(locked[0]),.outclk_0(movie));
media_audio_clocks clocks(.refclk(refclk),.reset(reset),.movie_clock(movie),.select_cd(select_cd),.enable(enable),
 .cd_clock(cd),.cd_locked(locked[1]),.output_clock(audio_clock));
reg [8:0] md=0,cd_count=0;
always @(posedge movie) md<=md+1'b1;
always @(posedge cd) cd_count<=cd_count+1'b1;
assign sample_clock={cd_count[8],md[8]};
endmodule
''')
(out/'clock_probe.qpf').write_text('PROJECT_REVISION = "clock_probe"\n')
(out/'clock_probe.qsf').write_text('''set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U23I7
set_global_assignment -name TOP_LEVEL_ENTITY clock_probe
set_global_assignment -name VERILOG_FILE pll_movie.v
set_global_assignment -name VERILOG_FILE pll_cd.v
set_global_assignment -name SYSTEMVERILOG_FILE clock_probe.sv
set_global_assignment -name SDC_FILE clock_probe.sdc
set_global_assignment -name NUM_PARALLEL_PROCESSORS 6
set_global_assignment -name SEED 52
''')
if a.switch_output:
 with (out/'clock_probe.qsf').open('a') as f:f.write('set_global_assignment -name SYSTEMVERILOG_FILE "'+str(root/'rtl/platform/media_audio_clocks.sv')+'"\n')
(out/'clock_probe.sdc').write_text('create_clock -name refclk -period 20 [get_ports refclk]\nderive_pll_clocks\nderive_clock_uncertainty\n')
env=os.environ.copy();env['LD_LIBRARY_PATH']='/home/vash/quartus-compat-libs'+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
with (out/'compile.log').open('w') as f:subprocess.run([str(a.quartus/'quartus_sh'),'--flow','compile','clock_probe'],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
(out/'provenance.json').write_text(json.dumps({'scope':'isolated PLL/optional selector feasibility; no production pin placement or HDMI validation','includes_selector':a.switch_output,'clock_module_sha256':hashlib.sha256((root/'rtl/platform/media_audio_clocks.sv').read_bytes()).hexdigest() if a.switch_output else None,'movie_hz':24576000,'cd_hz':22579200,'reference_hz':50000000,'template_sha256':hashlib.sha256(source.encode()).hexdigest()},indent=2)+'\n')
print((out/'clock_probe.fit.summary').read_text())
