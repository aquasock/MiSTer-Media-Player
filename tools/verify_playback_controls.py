#!/usr/bin/env python3
"""Playback keyboard, presentation timeline and PCM retention/seek regressions."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
tests = {
    'test_playback_restart': ['rtl/media_keyboard_control.sv',
        'rtl/media_playback_control.sv', 'rtl/media_session_control.sv', 'rtl/video_config_cdc.sv'],
    'test_media_keyboard_control': ['rtl/media_keyboard_control.sv'],
    'test_media_playback_control': ['rtl/media_playback_control.sv',
        'rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv'],
    'test_mp2_playback_control': ['rtl/audio/mp2_pcm_output.sv'],
    'test_mp2_pcm_output': ['rtl/audio/mp2_pcm_output.sv'],
}
results = {}
with tempfile.TemporaryDirectory(prefix='playback-controls-') as tmp:
    for name, sources in tests.items():
        binary = str(Path(tmp)/name)
        subprocess.run(['iverilog', '-g2012', '-s', name, '-o', binary,
            f'tools/{name}.sv', *sources], cwd=root, check=True)
        log = subprocess.check_output(['vvp', binary], cwd=root, text=True, timeout=60)
        assert 'PASS' in log
        print(log, end='', flush=True)
        results[name] = log
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(results, indent=2)+'\n')
