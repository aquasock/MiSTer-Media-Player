#!/usr/bin/env python3
"""Generate exact-rate moving bars/fences for manual 50/59.94 Hz qualification."""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--seconds',type=int,default=60)
p.add_argument('--font',type=Path,default=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
a=p.parse_args()
if a.seconds<4:p.error('--seconds must be at least four')
if not a.font.is_file():p.error('font missing; supply --font with a TrueType font path')
a.output.mkdir(parents=True,exist_ok=True)
fonts={size:ImageFont.truetype(str(a.font),size) for size in (17,22,30)}
manifest={'font_sha256':hashlib.sha256(a.font.read_bytes()).hexdigest(),'files':{}}
for label,rate,best in [('25fps',Fraction(25),'50 Hz'),('2997fps',Fraction(30000,1001),'59.94 Hz')]:
    count=round(a.seconds*rate)
    raw=a.output/f'motion_{label}.m2v'
    cmd=['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo',
         '-pixel_format','rgb24','-video_size','720x480','-framerate',str(rate),'-i','pipe:0',
         '-vf','scale=out_color_matrix=bt601:out_range=tv,format=yuv420p,setsar=32/27',
         '-an','-c:v','mpeg2video','-threads:v','1','-flags:v','+bitexact',
         '-g','24','-bf','2','-b_strategy','0','-q:v','3',
         '-maxrate:v','8000k','-bufsize:v','1835008','-aspect','16:9',
         '-colorspace','smpte170m','-color_range','tv','-f','mpeg2video',str(raw)]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    try:
        for n in range(count):
            im=Image.new('RGB',(720,480),(24,24,24));d=ImageDraw.Draw(im)
            d.text((22,10),f'{float(rate):g} fps  |  BEST AT {best}',font=fonts[30],fill=(235,235,235))
            d.text((22,52),f'FRAME {n:05d}   TIME {float(n/rate):06.2f}s',font=fonts[22],fill=(190,190,190))
            d.text((22,88),'Follow the white bar: watch for uneven steps',font=fonts[17],fill=(190,190,190))
            # Same physical motion rate in both files; rounding is at most one
            # source pixel. No motion blur is applied to conceal cadence errors.
            x=int(Fraction(n*240,1)/rate)%720
            for center in (x-720,x,x+720):
                d.rectangle((center-8,122,center+7,256),fill=(235,235,235))
            d.line((360,110,360,267),fill=(100,100,100),width=2)
            d.text((22,276),'Panning fence - fixed speed, no motion blur',font=fonts[17],fill=(190,190,190))
            shift=int(Fraction(n*360,1)/rate)%90
            for left in range(shift-90,720,90):
                d.rectangle((left,310,left+19,400),fill=(185,185,185))
            # Small 25-position frame marker helps slow-motion recordings identify
            # held source frames without a distracting full-screen flash.
            for k in range(25):
                left=22+k*27
                d.rectangle((left,419,left+21,434),fill=(235,235,235) if k==n%25 else (65,65,65))
            d.text((22,446),'Keep this file playing while changing output refresh',font=fonts[17],fill=(190,190,190))
            proc.stdin.write(im.tobytes())
            if n==round(rate):im.save(a.output/f'preview_{label}.png')
    finally:
        proc.stdin.close()
        rc=proc.wait()
    if rc:raise RuntimeError(f'ffmpeg encode failed: {rc}')
    mpg=raw.with_suffix('.mpg')
    # Copy the exact same compressed pictures; a silent MP2 track exercises the
    # timestamped program-stream path without distracting from the motion test.
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(raw),
        '-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-t',str(float(count/rate)),
        '-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','mp2','-b:a','192k',
        '-f','mpeg',str(mpg)],check=True)
    for file in (raw,mpg):
        probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames',
            '-select_streams','v:0','-show_entries','stream=width,height,r_frame_rate,field_order,nb_read_frames',
            '-of','json',str(file)],text=True))['streams'][0]
        assert (probe['width'],probe['height'],Fraction(probe['r_frame_rate']),probe['field_order'],int(probe['nb_read_frames']))==(720,480,rate,'progressive',count)
        subprocess.run(['ffmpeg','-v','error','-xerror','-i',str(file),'-f','null','-'],check=True)
        manifest['files'][file.name]={'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
            'size_bytes':file.stat().st_size,'probe':probe}
    print('Verified',label, count,'frames',flush=True)
(a.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(a.output/'README.txt').write_text('''Motion cadence A/B test - no core update required

1. Start with motion_25fps.m2v. Set Aspect ratio 16:9, Color matrix Auto,
   Audio test Off, and leave video filters constant. Use vsync_adjust=1.
2. Select 50 Hz. Close the OSD, let the display settle, and track the moving
   white bar with your eyes for about ten seconds. Also watch the lower fence.
3. Select 59.94 Hz while the SAME FILE continues. Close the OSD and compare.
   At 50 Hz each 25 fps frame lasts two refreshes (40 ms). At 59.94 Hz it
   normally lasts two or three refreshes (about 33 or 50 ms), adding uneven
   motion. The bar travels at the same average speed in both settings.
   Ignore the deliberate jump when the bar wraps at the screen edge.
4. Reverse the comparison with motion_2997fps.m2v: 59.94 Hz gives exact double
   repeats, while 50 Hz requires uneven holds. The opposite preference is a
   useful control. Repeat with the .mpg versions to check the timestamped path;
   these contain the same video and a silent 48 kHz stereo MP2 track.

Twenty-five fps still has visible discrete steps at 50 Hz: expect EVEN steps,
not 50 unique pictures per second. Viewing alone can be subtle. A display's
signal-info page showing 50 versus approximately 59.94/60 Hz is the most direct
confirmation that HDMI refresh changed. A fixed-refresh display or motion
interpolation/frame conversion can obscure the expected difference; use Game
mode or disable interpolation for this comparison if available.

For an additional check, record the moving bar/frame counter with a phone at
120 or 240 fps (interpolation off). Inspect how long each source frame persists:
25 fps/50 Hz should hold around 40 ms each; 25 fps/59.94 Hz alternates roughly
33/50 ms. Camera/display phase and rolling shutter add measurement uncertainty,
so count over several seconds rather than treating one captured frame as proof.
A static screenshot cannot prove refresh or cadence.

The tests last about 60 seconds by default. Both are progressive 720x480,
BT.601 limited-range, with sharp edges and no motion blur. Reproduce using:
python3 tools/make_cadence_motion_tests.py --output results/cadence-motion-tests
''')
print('Ready:',a.output)
