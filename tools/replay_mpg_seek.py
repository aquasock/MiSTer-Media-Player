#!/usr/bin/env python3
"""Exact MPG opening through reconstruction + demux/MP2/PTS; bounded ideal CDC.

Usage: tools/replay_mpg_seek.py input.mpg results/replay [--compile-only]
Reuses the live raster memory model. --shared-ddr routes compressed-video
traffic through the production arbiter. --display-ownership adds periodic
display requests and seek gating, not full raster bandwidth. Vendor CDC is not
modeled. Without --shared-ddr, compressed video has separate DDR service.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def generate(dest, shared_ddr=False):
    s = (ROOT/'tools/streams/tb_h262_live_raster_soak.sv').read_text()
    a = s.index('    generate if(PLAYBACK_CONTROL_MODE) begin: playback_test')
    b = s.index('\n    mpeg2_h262_b_presentation_scheduler scheduler', a)
    s = s[:a] + (ROOT/'tools/streams/mpg_replay_control.svh').read_text() + s[b:]
    a = s.index('    always @(negedge clk) begin\n        if(reset)begin\n            stream_valid<=0;')
    b = s.index('\n    always @(posedge clk)', a)
    s = s[:a] + (ROOT/'tools/streams/mpg_replay_ingress.svh').read_text() + '\n' + s[b:]
    s = s.replace('reg clk=0,reset=1,stream_valid=0;', 'reg clk=0,reset=1;wire stream_valid;')
    s = s.replace('reg [7:0] stream_data=0;', 'wire [7:0] stream_data;')
    s = s.replace('always #5 clk=~clk;', 'always #8.333333 clk=~clk;')
    s = s.replace('.frame_rate_code(4\'h3)', '.frame_rate_code(4\'h4)')
    s = s.replace('.timestamp_candidate_active(seek_override)', '.timestamp_candidate_active(seek_override||replay_timestamp_active)')
    s = s.replace('.timestamp_candidate_due(seek_override)', '.timestamp_candidate_due(seek_override||replay_timestamp_due)')
    for port, signal in [('candidate_frame_valid','replay_candidate_valid'),
                         ('candidate_frame_scratch','replay_candidate_scratch'),
                         ('candidate_scratch_bank','replay_candidate_bank'),
                         ('candidate_frame_bank','replay_candidate_frame')]:
        s = s.replace(f'.{port}()', f'.{port}({signal})')
    # These legacy prints repeat every stalled cycle and can produce gigabytes.
    s = re.sub(r'\$display\("PIC_FIRST_SIDEBAND.*?;\s*\$fflush;', '', s, flags=re.S)
    def bounded_display(match):
        return match.group(0) if any(tag in match.group(0) for tag in ('PROGRESS', 'SEEK BEGIN', 'SEEK END', 'MPG_REPLAY')) else 'begin end'
    s = re.sub(r'\$display\(.*?\);', bounded_display, s, flags=re.S)
    if shared_ddr:
        s = s.replace('DDR_WORDS=327680;', 'DDR_WORDS=1572864;')
        s = s.replace('reg [18:0] read_index_pipe', 'reg [20:0] read_index_pipe')
        s = s.replace('.ddram_busy(1\'b0),.ddram_dout_ready(memory_dout_ready)',
            '.stream_addr(raddr),.stream_din(rdin),.stream_rd(rrd),.stream_we(rwr),'
            '.stream_busy(replay_stream_busy),.stream_dout_ready(rdqv),'
            '.ddram_busy(1\'b0),.ddram_dout_ready(memory_dout_ready)')
        s = s.replace('reg [63:0] rdq;reg rdqv=0;',
            'wire [63:0] rdq=memory_dout;wire rdqv,replay_stream_busy;')
        s = s.replace('reg [63:0] replay_vmem[0:1048575];', '')
        s = s.replace('raddr,rdin,rrd,rwr,1\'b0,rdq,rdqv,rv_level)',
            'raddr,rdin,rrd,rwr,replay_stream_busy,rdq,rdqv,rv_level)')
        a = s.index('always @(posedge clk)begin\n rdqv<=0;')
        b = s.index('wire [7:0] reb;', a)
        s = s[:a] + 'always @(posedge clk)if(!reset&&rve&&rvready)replay_veof<=1;\n' + s[b:]
        # Stream storage is not a reconstructed frame write for legacy counters.
        s = s.replace('case(memory_addr[18:16])', 'if(memory_addr<DDR_BASE+327680)case(memory_addr[18:16])')
    path = dest/'tb_mpg_seek.sv'
    path.write_text(s)
    return path


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('input',type=Path);ap.add_argument('output',type=Path)
    ap.add_argument('--compile-only',action='store_true')
    ap.add_argument('--reuse',action='store_true')
    ap.add_argument('--shared-ddr',action='store_true')
    ap.add_argument('--shared-idct',action='store_true')
    ap.add_argument('--idct-intra',action='store_true')
    ap.add_argument('--display-ownership',action='store_true')
    ap.add_argument('--disable-display-release',action='store_true')
    ap.add_argument('--at-q',type=int,default=792792)
    ap.add_argument('--start-offset',type=int,default=0)
    ap.add_argument('--video-start',type=int,default=0)
    ap.add_argument('--movie-origin',type=int,default=0)
    ap.add_argument('--seek-delay',type=int,default=0)
    ap.add_argument('--host-stall',type=int,default=40000)
    ap.add_argument('--no-audio-bypass',action='store_true')
    ap.add_argument('--no-skip',action='store_true')
    args=ap.parse_args();dest=args.output.resolve();dest.mkdir(parents=True,exist_ok=True)
    bench=generate(dest,args.shared_ddr);binary=dest/'obj/Vtb_h262_live_raster_soak'
    rtl=re.findall(r'SYSTEMVERILOG_FILE (rtl/mpeg2_new/\S+)',(ROOT/'files.qip').read_text())
    rtl += ['rtl/audio/'+x+'.sv' for x in ('mp2_decoder','mp2_synthesis','mp2_pcm_output','av_stream_fifo')]
    rtl += ['rtl/media_seek_video_filter.sv','rtl/media_playback_control.sv','rtl/media_file_reader.sv','rtl/video_config_cdc.sv']
    # P/B integration lives partly in included headers; cache identity must cover it.
    headers=sorted((ROOT/'rtl/mpeg2_new').glob('*.svh'))
    fingerprint=hashlib.sha256(str((args.display_ownership,args.disable_display_release,args.shared_idct,args.idct_intra)).encode()+bench.read_bytes()+b''.join((ROOT/p).read_bytes() for p in rtl)+b''.join(p.read_bytes() for p in headers)).hexdigest()
    manifest=dest/'obj/replay-build.json'
    if args.reuse:
        if not manifest.exists() or json.loads(manifest.read_text())['fingerprint']!=fingerprint:
            raise ValueError('replay binary does not match current harness/RTL; compile without --reuse')
    else:
        with (dest/'compile.log').open('w') as log:
            subprocess.run(['verilator','--binary','--timing','-j','8','-Wno-fatal',
                '--top-module','tb_h262_live_raster_soak','--Mdir',str(dest/'obj'),
                '-GPLAYBACK_CONTROL_MODE=1','-GSWAP_WINDOW_CYCLES=1001000',
                '-GSHARED_IDCT_MODE='+str(int(args.shared_idct)),
                '-GIDCT_INTRA_MODE='+str(int(args.idct_intra)),
                '-GDISPLAY_OWNERSHIP_MODE='+str(int(args.display_ownership)),
                '-GSEEK_DISPLAY_RELEASE='+str(int(not args.disable_display_release)),
                '-GFREEZE_TRACE_CYCLES=0','-GMAX_SIM_CYCLES=1200000000',
                '-DH262_SOAK_MAX_STREAM_BYTES=16777216',str(bench),*rtl],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        manifest.write_text(json.dumps({'fingerprint':fingerprint})+'\n')
    if args.compile_only:return
    data=args.input.read_bytes()
    if not 0<len(data)<=16777216:raise ValueError('supply a bounded MPG prefix of at most 16 MiB')
    hexpath=dest/'source.hex'
    source_hash=hashlib.sha256(data).hexdigest()
    hashpath=dest/'source.sha256'
    if not hexpath.exists() or not hashpath.exists() or hashpath.read_text().strip()!=source_hash:
        with hexpath.open('w') as f:
            for byte in data:f.write(f'{byte:02x}\n')
        hashpath.write_text(source_hash+'\n')
    label=f"offset{args.start_offset}-{'shared-' if args.shared_ddr else ''}seek-{args.at_q}-{args.seek_delay}-stall{args.host_stall}-bypass{int(not args.no_audio_bypass)}-baseline{int(args.no_skip)}"
    cmd=[str(binary),f'+HEX={hexpath}',f'+LEN={len(data)}','+GENERIC_STREAM','+PROGRESS=20000000',
         f'+START_OFFSET={args.start_offset}',f'+VIDEO_START={args.video_start}',f'+MOVIE_ORIGIN={args.movie_origin}',
         f'+AT_Q={args.at_q}',f'+SEEK_DELAY={args.seek_delay}',f'+HOST_STALL={args.host_stall}']
    if args.no_audio_bypass:cmd.append('+NO_AUDIO_BYPASS')
    if args.no_skip:cmd.append('+NO_SKIP')
    with (dest/(label+'.log')).open('w') as f:
        rc=subprocess.call(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
    passed=False
    with (dest/(label+'.log')).open() as f:
        for line in f:
            if 'MPG_REPLAY_BOUNDARY_PASS' in line:passed=True
    result=dict(command=cmd,exit=rc,completed=passed,source_sha256=hashlib.sha256(data).hexdigest(),
        scope='Combined PS/MP2/bounded queues/video reconstruction/PTS; ideal CDC; optional periodic display ownership model, not full raster bandwidth', shared_idct=args.shared_idct, idct_intra=args.idct_intra, shared_ddr=args.shared_ddr, display_ownership=args.display_ownership, display_release=not args.disable_display_release, binary_fingerprint=fingerprint)
    (dest/(label+'.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result),flush=True)
    if rc or not passed:raise SystemExit(1)

if __name__=='__main__':main()
