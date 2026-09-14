#!/usr/bin/env python3
"""Compare full-start fps-filter and output-CFR MPG conversions (no input seek).

Writes short samples and verbose FFmpeg logs; never overwrites existing files.
This is a reproduction tool, not an automatic perceptual pass/fail test.
"""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--seconds', type=float, default=68)
    parser.add_argument('--rate', default='24000/1001')
    args = parser.parse_args()
    if not args.input.is_file() or not 0 < args.seconds <= 120:
        parser.error('Input must exist and duration must be within (0, 120] seconds')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    vf = ("scale=w='if(gte(dar,16/9),720,2*round(405*dar/2))':"
          "h='if(gte(dar,16/9),2*round(1280/(3*dar)),480)':"
          'flags=lanczos+accurate_rnd:in_color_matrix=auto:out_color_matrix=bt601:'
          'in_range=auto:out_range=limited,pad=720:480:(ow-iw)/2:(oh-ih)/2:black,'
          'setsar=32/27,format=yuv420p')
    for name in ('original', 'output-cfr'):
        target = args.output_dir / f'{args.input.stem}-{name}.mpg'
        log = target.with_suffix('.log')
        manifest = target.with_suffix('.command.json')
        if any(p.exists() for p in (target, log, manifest)):
            parser.error(f'Output already exists: {target}')
        command = ['ffmpeg', '-hide_banner', '-loglevel', 'verbose', '-n',
                   '-threads', '8', '-i', str(args.input.resolve()),
                   '-t', str(args.seconds), '-map', '0:v:0', '-map', '0:a:0?',
                   '-sn', '-dn', '-vf', vf + (f',fps={args.rate}' if name == 'original' else ''),
                   '-c:v', 'mpeg2video', '-profile:v', 'main', '-level:v', 'main',
                   '-pix_fmt', 'yuv420p', '-threads:v', '1', '-flags:v', '+bitexact',
                   '-g', '24', '-bf', '2', '-b_strategy', '0', '-mbd', 'rd', '-trellis', '2',
                   '-q:v', '3', '-qmin', '2', '-qmax', '12', '-maxrate:v', '8000k',
                   '-bufsize:v', '1835008', '-sc_threshold', '1000000000',
                   '-mpv_flags', '+strict_gop', '-aspect', '16:9',
                   '-colorspace', 'smpte170m', '-color_range', 'tv']
        if name == 'output-cfr':
            command += ['-r:v', args.rate, '-fps_mode:v', 'cfr']
        command += ['-c:a', 'mp2', '-ar', '48000', '-ac', '2', '-b:a', '192k',
                    '-f', 'mpeg', str(target.resolve())]
        manifest.write_text(json.dumps(command, indent=2) + '\n')
        with log.open('x') as stream:
            subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, check=True)
        print(target, flush=True)


if __name__ == '__main__':
    main()
