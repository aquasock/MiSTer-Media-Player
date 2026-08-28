# MiSTer Media Player hardware tests

## v0.8.0 hand tests

Use the matched v0.8.0 RBF, helper and patched Main identified in the
[release notes](RELEASE_NOTES_v0.8.0.md). Back up the installed files before
replacement, verify their hashes, and reboot after installing Main. The user
controls installation, reboot, core reload, mode selection and playback.

Generate the current test files on the build PC, from the repository root:

```bash
python3 tools/streams/generate_test_suite.py --output-dir /tmp/suite --duration 12
```

Retain `/tmp/suite/manifest.json` with the files: it records each file's hash,
picture count, codec, field order and generation commands. These seven files
are not shipped in the release ZIP. The twelve-second fixtures contain 360
pictures each; use the actual manifest counts if changing the duration.
`check_media_compatibility.py` still rejects the native interlaced subset; use
the generator's structural and motion checks for those files.

| File | Check |
| --- | --- |
| `test_1_interlace_tff.mpg` | Downward-moving bar, top field first, audible MPEG Layer II tone, responsive menu |
| `test_2_interlace_bff.mpg` | Same motion with bottom field first; compare field order with test one |
| `test_3_deinterlace_bob_weave.mpg` | Scrolling bands; record Bob and Weave runs separately |
| `test_4_progressive.mpg` | Progressive all-I motion and colour transitions |
| `test_5_audio_ac3_51.mpg` | AC-3 sweep in HDMI decoded-stereo and S/PDIF passthrough modes, separately captured |
| `test_6_audio_dts_51.mpg` | DTS sweep in S/PDIF passthrough mode; HDMI is unsupported |
| `test_7_progressive_ipb.mpg` | Progressive I/P/B motion and reordered completion |

The core menu labels the passthrough selection `S/PDIF AC-3`, but it also
carries DTS. Select the audio mode before starting a file. Both sweeps use
FL, FR, FC, LFE, BL, BR in two-second slots. HDMI AC-3 downmix should produce
left, right, both, silence, left, right; its LFE slot is deliberately silent.
S/PDIF sends the original compressed channels to the receiver. A 2.1 soundbar
cannot prove discrete 5.1 routing, and the recorded DTS-LFE behavior on one
receiver must not be generalized to all devices.

### Capture each run before starting the next

Record installed hashes, the exact fixture, selected deinterlace/audio modes,
reboot and core-reload history, all three LEDs, and observations of sound,
synchronization, motion and menu response during and after playback.

Retrieve `/tmp/MediaPlayer_ARM.log` first: the next playback overwrites it.
Then obtain a fresh screenshot while terminal telemetry is visible, rather
than treating a playback screenshot or an old fixed filename as fresh data.
Decode the copied terminal image on the analysis host:

```bash
python3 tools/streams/decode_hardware_cadence.py /path/to/terminal.png \
  --expected-pictures 360 --json
```

Require a valid schema-19 checksum/parity result, the expected picture count,
clean decoder/presentation/audio flags, sequence end and quiet terminal
completion, and a successful helper exit with reconciled transport bytes.
The release Main logs `profile_version=2` and `transport=credit_step_v1`:
`pipe_read` records cover source reads, while `transfer` records are sampled.
Do not use a version-one read-record analyzer unchanged.

For native interlaced hand tests, require no missed steady display slots and
nominal 2,002,000-clock frame intervals. The native deadline counters do not
qualify the progressive path. Progressive cadence needs its own interval
interpretation; neither a zero native counter nor startup-inclusive aggregate
FPS is sufficient. Long runs also wrap the 32-bit 60 MHz session timer, and
some audio counters saturate; do not treat them as whole-film totals.

The seven hand tests cover a bounded subset, not full DVD compatibility or
comprehensive playback pixel accuracy. The full interlaced movie has a recorded
one-or-two-slot repeat at a large-picture cut; that limitation is distinct from
the clean short-fixture cadence gate. The public package matches the tested
runtime hashes, but a confirmation run after installing from that final package
remains unrecorded. Retain separate evidence if performing that confirmation.

## Historical regression pack and v0.7 procedures

The remaining sections preserve earlier test recipes, identities and expected
phase behavior. They are not the v0.8.0 gate above. `docs/SHA256SUMS` and
`docs/compatibility_manifest.json` identify this older pack, not the v0.8.0
release ZIP or seven hand tests. Apply reboot instructions, telemetry schemas
and acceptance criteria below only when deliberately reproducing that
historical qualification.

Use the files in numeric order with the exact candidate core identified in
`RESULTS_TEMPLATE.txt`. Verify the pack before copying it to the MiSTer:

```bash
python3 tools/streams/verify_regression_pack.py /path/to/regression-pack
```

Hard-reboot the MiSTer before test `01`, then open every `.m2v` through the
normal Media Player file selector. Do not use MGL injection for this gate.

### v0.7 user-converted audio-video qualification

Build the deterministic input-envelope corpus and the full-length audio-video
soak file locally; generated binary media remains uncommitted:

```bash
tools/streams/generate_compatibility_corpus.sh
python3 tools/streams/generate_test_big_buck_bunny.py \
  --source /path/to/big_buck_bunny_480p_stereo.avi \
  --output tools/streams/generated_compatibility/bbb_full_48k.mpg \
  --start 0 --frames 14315 --with-audio --audio-rate 48000
python3 tools/streams/check_media_compatibility.py \
  tools/streams/generated_compatibility/envelope/good_480p_44k.mpg \
  tools/streams/generated_compatibility/envelope/good_480p_48k.mpg \
  tools/streams/generated_compatibility/bbb_full_48k.mpg
```

The generators finalize each Program Stream with a bounded video PES carrying
the H.262 sequence-end code followed by the MPEG Program Stream end code. For a
file produced directly by another FFmpeg command, finalize it before checking:

```bash
python3 tools/streams/finalize_program_stream.py /path/to/converted.mpg
python3 tools/streams/check_media_compatibility.py /path/to/converted.mpg
```

Both terminal markers are required. The checker rejects a file missing either
marker because the core cannot otherwise flush reordered pictures and publish
its final diagnostic state reliably.

Before installation, build the native helper and prove that scheduling changes
only record placement, never elementary-stream content. The analyzer performs
an independent explicit-output pass, compares the exact video/PTS and decoded
PCM hashes, requires one PCM end marker, caps the initial batch below the FPGA
FIFO, caps every steady-state batch at 2,048 samples, and requires a PCM record
at least every 65,535 video bytes after startup:

```bash
host/build_arm_stack.sh --native
python3 tools/streams/analyze_arm_av_transport.py \
  host/build/media_player_helper.native \
  tools/streams/generated_compatibility/envelope/good_480p_48k.mpg \
  --sample-rate 48000
python3 tools/streams/analyze_arm_av_transport.py \
  host/build/media_player_helper.native \
  tools/streams/generated_compatibility/envelope/good_480p_44k.mpg \
  --sample-rate 44100
python3 tools/streams/analyze_arm_av_transport.py \
  host/build/media_player_helper.native \
  tools/streams/generated_compatibility/bbb_full_48k.mpg \
  --sample-rate 48000
```

Use Audio Test `Off`. First run `good_480p_48k.mpg`, then
`good_480p_44k.mpg`; both must complete with correct sound, video, and normal
LEDs. Next run each `bad_*.mpg` case individually. Give a bad case no more
than ten seconds to reject or settle, record the visible result and all three
LEDs, and immediately select `good_480p_48k.mpg` without rebooting. A bad case
passes only when it does not claim ordinary success and the known-good control
then plays normally. An unavailable menu, ignored input, or failed control is
a wedge and fails the case; power-cycle only after recording that failure so
the remaining cases can be tested.

After all six recovery pairs pass, power-cycle once and run
`bbb_full_48k.mpg`. Watch the opening, scene transitions, the high-motion
squirrel sequence near 7:22, and the rolling credits. Audio must remain aligned
with video throughout the complete 9:56 run, without gaps, repeated sections,
progressive drift, or a delayed tail. Record all LEDs and capture schema-eight
telemetry after completion; PCM protocol, underrun, presentation, decoder, and
aggregate error flags must all remain clear.

### Required evidence for every run

Record the exact state of all three LEDs after each stream stops or completes:

- `USER`: `solid on`, `solid off`, or the counted number of blinks.
- `DISK`: `solid on`, `solid off`, or the counted number of blinks.
- `POWER`: `solid on`, `solid off`, or the counted number of blinks.

The USER LED is the top-level acceptance diagnostic. A blinking USER LED is a
failure code; in that state DISK and POWER provide subordinate diagnostic
information. When USER is solid on, DISK may legitimately be off or blink a
final progress code, so DISK alone is not a pass/fail indication. A plausible
still image is not sufficient evidence without all three LED readings.

### Normal playback tests

Files `01` through `14` must load, play to completion, and finish with USER
solid on and without a freeze, decoder error, torn/corrupt picture, or abnormal
ending. Very short synthetic files may finish while the loading window still
obscures most of their motion.

1. `01_i_baseline.m2v` — 4 all-I pictures; basic full-frame decode.
2. `02_p_motion_residual.m2v` — 2 pictures; P motion, residuals, half-pel phases, coded-block patterns, and quantiser changes.
3. `03_p_mba_escape.m2v` — 2 pictures; ordinary, leading, and escaped skipped macroblocks.
4. `04_b_bidirectional.m2v` — 5 pictures; forward, backward, and bidirectional B prediction.
5. `05_p_visual_discriminator.m2v` — 2 pictures; the final displayed P picture must have two hard seams crossing at the center to form four quadrants. An unbroken diagonal gradient means the P picture was not presented.
6. `06_p_f_code_range.m2v` — 5 pictures; independent P motion-vector ranges and predictor wraparound.
7. `07_b_f_code_range.m2v` — 5 pictures; independent forward/backward B motion-vector ranges.
8. `08_compat_multi_slice.m2v` — 5 pictures; multiple slices within selected macroblock rows.
9. `09_compat_dense_residual.m2v` — 12 pictures; maximum coefficient and residual traffic.
10. `10_compat_mixed_macroblocks.m2v` — 24 pictures; mixed intra, predicted, skipped, and residual macroblocks.
11. `11_compat_long_gop.m2v` — 72 pictures; longer ownership, reordering, and publication sequence.
12. `12_bbb_squirrel_5sec_native24_q6.m2v` — 120 pictures; focused dense-motion squirrel/wooden-spike stress.
13. `13_bbb_squirrel_15sec_native24_q6.m2v` — 360 pictures; watch the complete 7:15–7:30 sequence, especially the wooden spikes near 7:22. Motion must remain continuous with no clean frame skips.
14. `14_bbb_full_native24_user_recipe.m2v` — 14,315 pictures; full 9:56 endurance test. Check smooth pans, the squirrel sequence, rolling credits, and clean terminal behavior.

### Expected-failure recovery test

Run `99_EXPECTED_FAILURE_truncated_stream.m2v` last. It is deliberately cut
100,000 bytes into `11_compat_long_gop.m2v`, in the middle of a picture and
without a sequence-end marker. It must not report an ordinary successful
completion. Record the terminal image and all three LED states.

After it stops making progress, do **not** reboot. Immediately load
`01_i_baseline.m2v` again. Recovery passes only if `01` completes normally with
USER solid on; record all three LEDs again.

### Reproducing the files

Tests `01` through `07` come from their correspondingly named deterministic
`tools/streams/generate_test_*.py` programs. Tests `08` through `11` come from:

```bash
python3 tools/streams/generate_test_progressive_compatibility.py
```

Its default repository-local output directory makes the generated manifest
portable and byte-reproducible; the directory is ignored by Git. Rename its
four streams to the numbered pack names. Generate tests `12` and `13` from the
same local `big_buck_bunny_480p_stereo.avi` source with:

```bash
python3 tools/streams/generate_test_big_buck_bunny.py \
  --source /path/to/big_buck_bunny_480p_stereo.avi \
  --output 12_bbb_squirrel_5sec_native24_q6.m2v --start 440 --frames 120
python3 tools/streams/generate_test_big_buck_bunny.py \
  --source /path/to/big_buck_bunny_480p_stereo.avi \
  --output 13_bbb_squirrel_15sec_native24_q6.m2v --start 435 --frames 360
```

Test `14` uses the no-frame-counter FFmpeg recipe in `README.md`. Test `99` is
the first 100,000 bytes of test `11`. Binary files are deliberately not stored
in Git; `SHA256SUMS` is the authoritative identity list, and
`compatibility_manifest.json` records the generated compatibility structure.

For a failure, also record what was visible and the approximate point in the
stream. Photograph the diagnostic matrix if one appears.
