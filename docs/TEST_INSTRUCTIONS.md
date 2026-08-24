# MiSTer Media Player Unreleased Hardware Regression Pack

Use the files in numeric order with the exact candidate core identified in
`RESULTS_TEMPLATE.txt`. Verify the pack before copying it to the MiSTer:

```bash
python3 tools/streams/verify_regression_pack.py /path/to/regression-pack
```

Hard-reboot the MiSTer before test `01`, then open every `.m2v` through the
normal Media Player file selector. Do not use MGL injection for this gate.

## v0.7 user-converted audio-video qualification

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

## Required evidence for every run

Record the exact state of all three LEDs after each stream stops or completes:

- `USER`: `solid on`, `solid off`, or the counted number of blinks.
- `DISK`: `solid on`, `solid off`, or the counted number of blinks.
- `POWER`: `solid on`, `solid off`, or the counted number of blinks.

The USER LED is the top-level acceptance diagnostic. A blinking USER LED is a
failure code; in that state DISK and POWER provide subordinate diagnostic
information. When USER is solid on, DISK may legitimately be off or blink a
final progress code, so DISK alone is not a pass/fail indication. A plausible
still image is not sufficient evidence without all three LED readings.

## Normal playback tests

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

## Expected-failure recovery test

Run `99_EXPECTED_FAILURE_truncated_stream.m2v` last. It is deliberately cut
100,000 bytes into `11_compat_long_gop.m2v`, in the middle of a picture and
without a sequence-end marker. It must not report an ordinary successful
completion. Record the terminal image and all three LED states.

After it stops making progress, do **not** reboot. Immediately load
`01_i_baseline.m2v` again. Recovery passes only if `01` completes normally with
USER solid on; record all three LEDs again.

## Reproducing the files

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
