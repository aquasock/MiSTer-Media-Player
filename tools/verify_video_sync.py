#!/usr/bin/env python3
"""Run raster-reset, configuration CDC, geometry, cadence and telemetry regressions."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-fb', type=Path, help='Also require the old framebuffer to fail the new reset test')
parser.add_argument('--output', type=Path, required=True, help='JSON evidence path outside the source tree')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
raster = ['tools/test_480p_scanout.sv', 'rtl/mpeg2_video_720x480p.sv',
          'rtl/mpeg2_luma_framebuffer.sv', 'rtl/mpeg2_progressive_geometry.sv',
          'rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv']
tests = [
    ('test_480p_scanout', raster),
    ('test_video_config_cdc', ['tools/test_video_config_cdc.sv', 'rtl/video_config_cdc.sv']),
    ('test_mpeg2_progressive_framebuffer', ['tools/test_mpeg2_progressive_framebuffer.sv', 'rtl/mpeg2_progressive_geometry.sv']),
    ('tb_h262_b_presentation_scheduler', ['tools/streams/tb_h262_b_presentation_scheduler.sv', 'rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv']),
    ('tb_h262_hardware_cadence_profiler', ['tools/streams/tb_h262_hardware_cadence_profiler.sv', 'rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv']),
]
results = {}
with tempfile.TemporaryDirectory(prefix='video-sync-') as tmp:
    def run(name, sources, expect_failure=False):
        binary = str(Path(tmp) / name)
        subprocess.run(['iverilog', '-g2012', '-s', name, '-o', binary, *sources], cwd=root, check=True)
        result = subprocess.run(['vvp', binary], cwd=root, text=True, capture_output=True, timeout=180)
        output = result.stdout + result.stderr
        print(output, end='', flush=True)
        if expect_failure:
            assert result.returncode != 0 and 'sync/data pipeline alignment' in output, output
        else:
            assert result.returncode == 0 and 'PASS' in output, output
        return {'exit': result.returncode, 'output': output}
    for name, sources in tests:
        results[name] = run(name, sources)
    subprocess.run(['iverilog', '-g2012', '-s', 'osd', '-o', str(Path(tmp)/'osd'),
                    'sys/osd.v', 'rtl/video_config_cdc.sv'], cwd=root, check=True)
    results['osd_elaboration'] = 'pass'
    if args.baseline_fb:
        sources = list(raster)
        sources[2] = str(args.baseline_fb.resolve())
        results['baseline_reproduces_sync_failure'] = run('test_480p_scanout', sources, True)
results['limitations'] = 'Ideal dual-clock RAM, no physical metastability simulation, no full H.262 reconstruction or HDMI scaler capture; hardware and Quartus timing remain required.'
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(results, indent=2) + '\n')
