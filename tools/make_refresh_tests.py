#!/usr/bin/env python3
"""Generate 720x480 progressive 25/29.97 fps motion and A/V refresh checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--seconds', type=int, default=20)
a = p.parse_args()
if a.seconds < 2:
    p.error('--seconds must be at least two')
a.output.mkdir(parents=True, exist_ok=True)
manifest = {}
for label, rate, flash in [('25fps', '25', '0.039'), ('2997fps', '30000/1001', '0.034')]:
    mpg = a.output / ('refresh_' + label + '.mpg')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
        '-f', 'lavfi', '-i', f'testsrc2=size=720x480:rate={rate}:duration={a.seconds}',
        '-f', 'lavfi', '-i', f'aevalsrc=0.2*sin(2*PI*440*t)*lt(mod(t\\,1)\\,0.08)|0.2*sin(2*PI*880*t)*lt(mod(t\\,1)\\,0.08):s=48000:d={a.seconds}',
        '-map', '0:v:0', '-map', '1:a:0',
        '-vf', f"drawbox=x=0:y=0:w=iw:h=ih:color=white:t=fill:enable='lt(mod(t,1),{flash})',setsar=32/27",
        '-c:v', 'mpeg2video', '-threads:v', '1', '-flags:v', '+bitexact',
        '-g', '24', '-bf', '2', '-b_strategy', '0', '-q:v', '6',
        '-maxrate:v', '8000k', '-bufsize:v', '1835008',
        '-aspect', '16:9', '-colorspace', 'smpte170m', '-color_range', 'tv',
        '-c:a', 'mp2', '-ar', '48000', '-ac', '2', '-b:a', '192k',
        '-f', 'mpeg', str(mpg)], check=True)
    raw = mpg.with_suffix('.m2v')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(mpg),
                    '-map', '0:v:0', '-c:v', 'copy', '-f', 'mpeg2video', str(raw)], check=True)
    for path in (mpg, raw):
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
            '-show_entries', 'stream=width,height,r_frame_rate,field_order', '-of', 'json', str(path)], text=True))
        video = probe['streams'][0]
        assert (video['width'], video['height'], video['r_frame_rate'], video['field_order']) == (720, 480, rate+'/1' if rate=='25' else rate, 'progressive')
        manifest[path.name] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'video': video}
(a.output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
(a.output/'README.txt').write_text('''Refresh-rate hardware checks (720x480 progressive)

Keep Audio test Off, aspect 16:9 and Color matrix Auto. Use the existing
[MediaPlayer] vsync_adjust=1 setting. Record the RBF source/seed tested.

1. Start at 59.94 Hz and play refresh_2997fps.mpg as the default-mode control.
2. Select 50 Hz and play refresh_25fps.mpg. Each picture should last two
   refreshes: motion should have even spacing. Confirm 50 Hz using the
   display's signal information if available. Playback speed/pitch must stay
   unchanged; white flashes and the two-channel beeps should stay together.
3. Play refresh_25fps.m2v at 50 Hz. This checks untimestamped-video cadence.
4. During playback switch 50 -> 59.94 -> 50 several times, including with the
   OSD open. HDMI may briefly blank while the display relocks. Playback must
   continue without restarting the file, sustained audio gaps or lasting A/V
   drift. A different output rate can change motion smoothness.
5. Change aspect and color matrix, open video/audio filters, reload each file,
   use Reset and play through EOF. Refresh selection should persist across
   file reload/reset; return to 59.94 Hz for the 29.97 fps control.

This does not add 720x576 or interlaced decoding. The 50 Hz core raster retains
720x480 active pixels and extends blanking; the HDMI scaler supplies the
configured display resolution. Generated source frame rates remain distinct.
''')
print('Generated refresh checks in', a.output)
