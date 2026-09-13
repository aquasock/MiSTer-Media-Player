# Building

Use Quartus Prime Lite 17.0.2 Build 602 on the build PC, from the project root:

```sh
/home/vash/intelFPGA_lite/17.0/quartus/bin/quartus_sh --flow compile MediaPlayer
/home/vash/intelFPGA_lite/17.0/quartus/bin/quartus_sta -t tools/phase1p_timing.tcl
```

Output is `output_files/MediaPlayer.rbf`. Review setup, hold, recovery,
removal, minimum pulse width and focused Phase-1P paths. Compile success alone
is insufficient. Preserve source hash, seed, reports and RBF checksum, then
obtain hardware acceptance. The baseline build script generates today's date.
Use a fresh tracked-source export and separate Quartus database per seed.
Maintain active RTL in `files.qip`.

Ingress verification requires Icarus Verilog and FFmpeg:

```sh
python3 tools/verify_program_stream_ingress.py
python3 tools/verify_program_stream_ingress.py /path/to/short-test.mpg
```

Optional media is read only; all fixtures are temporary. Tests cover raw
pass-through, both headers, stream selection, packet splits, stalls, EOF and
reset. Real-media video is compared byte-for-byte with FFmpeg extraction.
Existing metadata and PCM checks remain under `tools/streams/`.
No helper or custom Main is built or installed.

## FPGA MP2 validation

Run `python3 tools/verify_mp2.py` (FFmpeg, NumPy and Verilator required).
It compares RTL PCM against FFmpeg for all 17 quantizers, all joint-stereo
bounds, several bitrates, broadband noise and silence, with output stalls and
two reset-separated sessions. Unsupported/truncated frames must fail explicitly.
`tools/generate_mp2_tables.py` deterministically regenerates the committed ROMs.
`tools/test_mpg_audio_ingress.sv` exercises PS, the DDR reservoir, metadata and
MP2 together; it does not simulate the entire H.262 reconstruction engine.

The accepted fitter seed is 52. The next clean qualification batch uses
52, 61 and 87 in independent source exports. A synthesis estimate is not a
passing fitter or timing result.
