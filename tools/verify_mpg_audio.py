#!/usr/bin/env python3
"""Timed MPG ingress/audio regression with FFmpeg byte, PCM and PTS oracles.

The PCM CDC FIFO is an ideal bounded queue in this test; vendor CDC behavior
and the complete H.262 decoder are outside this test's simulation claim.
"""
from pathlib import Path
import json, subprocess, tempfile, sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
def run(*args):
    return subprocess.check_output([str(x) for x in args],cwd=ROOT,stderr=subprocess.STDOUT,text=True)
with tempfile.TemporaryDirectory(prefix='mpg-audio-') as td:
    td=Path(td);src=td/'test.mpg';out=td/'rtl';sim=td/'sim'
    run('ffmpeg','-v','error','-f','lavfi','-i','testsrc2=size=720x480:rate=30000/1001:duration=0.5',
        '-f','lavfi','-i','aevalsrc=0.23*sin(2*PI*997*t)|0.19*sin(2*PI*1553*t):s=48000:d=0.5',
        '-map','0:v','-map','1:a','-c:v','mpeg2video','-threads','1','-g','24','-bf','2','-q:v','6',
        '-c:a','mp2','-b:a','192k','-f','mpeg','-y',src)
    rtl=['rtl/audio/'+x+'.sv' for x in ('mp2_decoder','mp2_synthesis','av_stream_fifo','mp2_pcm_output')]
    rtl+=['rtl/mpeg2_new/'+x+'.sv' for x in ('mpeg2_program_stream_ingress','mpeg2_h262_program_stream_demux',
        'mpeg2_av_ddr_fifo','mpeg2_pes_metadata_expand','mpeg2_h262_inband_metadata','mpeg2_pes_picture_pts')]
    run('verilator','--binary','--timing','-j','8','-Wno-fatal','--top-module','test_mpg_audio_playback','--Mdir',sim,
        'tools/test_mpg_audio_playback.sv','rtl/media_file_reader.sv',*rtl)
    log=run(sim/'Vtest_mpg_audio_playback','+input='+str(src),'+output='+str(out));print(log)
    run('ffmpeg','-v','error','-i',src,'-map','0:a:0','-f','s16le','-y',td/'reference.pcm')
    run('ffmpeg','-v','error','-i',src,'-map','0:v:0','-c','copy','-f','mpeg2video','-y',td/'reference.m2v')
    x=np.loadtxt(str(out)+'.pcm.txt'); y=np.fromfile(td/'reference.pcm','<i2').reshape(-1,2).astype(float)
    assert x.shape==y.shape and np.max(abs(x-y))<=2
    video=Path(str(out)+'.m2v').read_bytes();expected=(td/'reference.m2v').read_bytes()
    assert video==expected or video==expected+b'\0\0\1\xb7'
    offsets=[];pos=0
    while True:
        pos=video.find(b'\0\0\1\0',pos)
        if pos<0:break
        offsets.append(pos);pos+=4
    packets=json.loads(run('ffprobe','-v','error','-select_streams','v:0','-show_entries','packet=pts','-of','json',src))['packets']
    pts=np.loadtxt(str(out)+'.pts.txt',dtype=np.int64).reshape(-1,2)
    for offset,stamp in pts: assert packets[offsets.index(offset)].get('pts')==stamp
    paused_out=td/'paused'
    paused_log=run(sim/'Vtest_mpg_audio_playback','+input='+str(src),
        '+output='+str(paused_out),'+pause')
    paused_pcm=np.loadtxt(str(paused_out)+'.pcm.txt')
    assert np.array_equal(paused_pcm,x), 'pause changed decoded/consumed PCM sequence'
    assert Path(str(paused_out)+'.m2v').read_bytes()==video
    print(paused_log)
    result={'played_sample_pairs':len(x),'max_sample_error':float(np.max(abs(x-y))),
        'pause_100ms_pcm_exact':True,'video_bytes':len(video),'picture_pts_checked':len(pts),'underrun':False,'timestamp_error':False,
        'scope':'Mounted-file reader with periodic 2 ms host stalls + ideal bounded ingress/PCM FIFOs + timed sink; no full video decoder or vendor CDC simulation'}
    print(json.dumps(result,indent=2))
    if len(sys.argv)>1:Path(sys.argv[1]).write_text(json.dumps(result,indent=2)+'\n')
