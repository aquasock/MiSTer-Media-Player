#!/usr/bin/env python3
"""Protocol-level gate test; does not model the Cyclone V HPS I2C controller."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
with (out/'compile.log').open('w') as f:
 subprocess.run(['iverilog','-g2012','-s','test_hdmi_i2c_owner','-o',str(out/'sim'),
 'tools/test_hdmi_i2c_owner.sv','rtl/platform/hdmi_i2c_owner.sv'],stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run(['vvp',str(out/'sim')],capture_output=True,text=True,timeout=30)
(out/'run.log').write_text(r.stdout+r.stderr)
if r.returncode or 'HDMI_I2C_OWNER_PASS' not in r.stdout:raise RuntimeError(r.stdout+r.stderr)
(out/'summary.json').write_text(json.dumps({'passed':True,'scope':'digital ownership gate only; real HPS behavior and HDMI control not yet validated'},indent=2)+'\n')
print(r.stdout.strip())
