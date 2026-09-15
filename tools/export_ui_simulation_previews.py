#!/usr/bin/env python3
"""Export unscaled PNGs from verified RTL UI simulation frames (no mockup)."""
from pathlib import Path
import argparse
from PIL import Image
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--render-dir',type=Path,default=Path('results/ui-integer'))
a=p.parse_args();out=a.render_dir/'screenshots';out.mkdir(parents=True,exist_ok=True)
for w,h,scale in [(720,480,1),(1280,720,2),(1920,1080,3)]:
 src=a.render_dir/f'subtitles-{w}x{h}-hud1-lines2-epoch1-len13.ppm'
 with Image.open(src) as im:
  assert im.size==(w,h)
  im.save(out/f'ui-{w}x{h}.png')
  # A separate native-pixel detail view makes small glyphs easier to inspect.
  im.crop((0,h*420//480,w,h)).save(out/f'ui-{w}x{h}-detail.png')
 print(f'{w}x{h}: {scale}x, glyph {5*scale}x{7*scale}, '+str(out/f'ui-{w}x{h}.png'))
(out/'README.md').write_text('''# Integer font scaling simulation previews

These are lossless, unscaled exports from the production RTL testbench, with
simulated subtitles and progress/time overlay on a solid video background.
They are not MiSTer HDMI captures. Full frames are 720x480, 1280x720 and
1920x1080. Detail files are native-pixel bottom crops, with no enlargement.

Inspect at 100% zoom to assess integer font scaling; browser fit-to-window
scaling can make otherwise uniform blocks look uneven. The 720x480 frame is
shown in raw output pixels, before any external pixel-aspect correction.

Generate and verify: `python3 tools/verify_subtitles.py --output results/ui-integer`
Export: `python3 tools/export_ui_simulation_previews.py`
''')
