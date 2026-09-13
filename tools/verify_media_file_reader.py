#!/usr/bin/env python3
"""Deterministic mounted-file transport and restart regressions; no hardware I/O."""
from pathlib import Path
import json, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
tests={
 'test_media_hps_io':['rtl/media_file_reader.sv','sys/hps_io.sv'],
 'test_media_file_reader':['rtl/media_file_reader.sv'],
 'test_media_session_control':['rtl/media_session_control.sv','rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv'],
}
results={}
with tempfile.TemporaryDirectory(prefix='media-reader-') as work:
 for name,sources in tests.items():
  binary=Path(work)/name
  subprocess.run(['iverilog','-g2012','-s',name,'-o',str(binary),f'tools/{name}.sv',*sources],cwd=root,check=True)
  command=['vvp',str(binary)]
  result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=60)
  print(result.stdout,end='')
  if result.returncode or 'PASS:' not in result.stdout: raise RuntimeError(result.stdout+result.stderr)
  results[name]=result.stdout.strip()
print(json.dumps(results,indent=2))
