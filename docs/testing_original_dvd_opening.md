# Original DVD opening qualification

This milestone covers a selected VOB opening: 720×480 progressive frame pictures
inside an interlaced sequence, original MPEG-2 video, and the first AC-3 track.
It does not implement ISO/IFO navigation, menus, field pictures, or arbitrary
interlaced P/B macroblocks. Hardware acceptance remains a separate user test.

Run generation and simulations on the build PC from the repository root.
Keep movie-derived fixtures out of Git.

```sh
python3 tools/streams/prepare_original_dvd_opening.py /path/to/VTS_01_1.VOB simulation/dvd_opening
bash tools/streams/run_original_dvd_i.sh simulation/dvd_opening
bash tools/streams/run_original_dvd_qualification.sh simulation/dvd_opening
```

Preparation uses stream copy, checks the selected video and AC-3 bytes against
the source, inventories matrix downloads, and builds a packet-to-display-frame
permutation for the reference decoder. A requested twelve-second cut can retain
a later reference picture needed by earlier B pictures; its final display time
is therefore not necessarily exactly twelve seconds.

## Numerical checks

The paired qualification runner requires both tests to pass on unchanged source:

- The isolated test reconstructs every I/P/B picture, compares every sample
  within one level of FFmpeg, and then replaces completed reference pictures
  with oracle samples. This removes accumulated reference error only in the
  testbench. It is not a playback test by itself.
- The real-reference test keeps all RTL reconstructions. Interpolation,
  averaging and clipping cannot amplify the largest input error. Each sample
  must stay within the measured error of the actual reference bank, plus the
  one-level transform allowance independently checked above. I pictures keep
  their one-level limit. Picture counts, sample counts, publication, ordering,
  ownership and decoder errors retain exact checks.

The original fixed two-level comparison remains the default standalone test.
`+CHAIN_ERROR_BOUND` is meaningful only alongside the passing isolated run; it
must not be used to accept unexplained errors or a failed isolated comparison.
Neither diagnostic changes synthesizable RTL or substitutes oracle pictures in
the hardware core.

## Focused regressions

```sh
bash tools/streams/run_quant_matrices.sh
bash tools/streams/run_quant_matrix_equivalence.sh
bash tools/streams/run_b_motion_math.sh
python3 tools/streams/generate_test_b_f_code_range.py --f-code-six
bash tools/streams/run_full_frame_pixels.sh tools/streams/test_b_f_code_six.m2v
python3 tools/streams/generate_test_b_quantized.py
bash tools/streams/run_full_frame_pixels.sh tools/streams/test_b_quantized.m2v
python3 tools/streams/generate_test_b_intra_motion_reset.py
bash tools/streams/run_full_frame_pixels.sh tools/streams/test_b_intra_motion_reset.m2v
python3 tools/streams/generate_test_b_intra_motion_reset.py --first-intra
bash tools/streams/run_full_frame_pixels.sh tools/streams/test_b_first_intra.m2v
python3 tools/streams/generate_test_matrix_transitions.py
bash tools/streams/run_full_frame_pixels.sh tools/streams/test_matrix_transitions.m2v
bash tools/streams/run_mixed_raster_pixels.sh
bash tools/streams/run_interlaced_i_reconstruction.sh
bash tools/streams/run_film_presentation.sh
bash tools/streams/run_native_480i_timing.sh
```

## Audio and transport

With a native helper build at `host/arm/media_player_helper`:

```sh
python3 tools/streams/verify_ac3_pcm.py --helper host/arm/media_player_helper --fixture simulation/dvd_opening/dvd_opening_original.mpg
python3 tools/streams/verify_ac3_passthrough.py --helper host/arm/media_player_helper --fixture simulation/dvd_opening/dvd_opening_original.mpg
python3 tools/streams/analyze_arm_av_transport.py host/arm/media_player_helper simulation/dvd_opening/dvd_opening_original.mpg --sample-rate 48000 --json
```

These checks cover decoded PCM, compressed passthrough, byte preservation and
queue limits. They do not establish hardware A/V synchronization or listening
quality. Deployment and playback remain under user control after a clean build
from the published source and a positive timing audit.
