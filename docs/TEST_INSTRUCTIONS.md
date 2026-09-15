# Shared IDCT candidate

## Subtitle punctuation fix queued for the next build

Straight ASCII apostrophes already have a font glyph. The new parser also maps
UTF-8 U+2018/U+2019 and standalone Windows-1252 bytes 0x91/0x92 to that glyph.
UTF-8 en/em dashes U+2013/U+2014 become `-`, and double quotation marks
U+201C/U+201D become `"`; Windows-1252 0x96/0x97 and 0x93/0x94 also map
to those existing glyphs.
Other unsupported Unicode still becomes `?`. Test contractions and quoted text
in a matching SRT; the completed 6bfcea3 candidates do not include this fix.
Parser regressions cover both encodings, ordinary ASCII, unsupported characters,
truncated sequences, tag boundaries and the 63-character line limit.
`python3 tools/verify_srt_files.py file.srt [more.srt ...]` replays complete UTF-8
SRT files against an independent normalized-text/timestamp oracle. All 3,130
cues across the user's A New Hope, Empire Strikes Back and Return of the Jedi
SRT files pass, with zero parser warnings.

## Combined UI and timing build qualification

The next candidate combines integer fonts, the taller centered bar, direct
subtitle value pages, Load media and the FLAC-to-MPG handoff fix. Validate all
three HDMI output resolutions if available: glyph pixels should be uniform,
clocks centered within the bar, and the bar centered between the reserved
subtitle bottom and screen edge. Check two-line and long subtitles, hidden cues,
pause/seek, EOF, and active/paused replacement in both media directions.

The timing correction adds the platform power-up reset source and its fitted
duplicates to the existing native reset-release input exceptions. Ordinary
stage-to-stage synchronizer paths stay timed and are now required by the audit.
The new bar-layout registers share the same modulo-four formatter enable and
are included in its existing scoped multicycle constraint. Timing qualification
requires nonnegative setup, hold, recovery, removal and pulse-width margins at
all four corners, with clean CDC audits; wait for the actual build report.

## Integer-font simulation preview

The overlay now uses exact glyph replication: 1x at 480p (5x7 glyphs), 2x at
720p (10x14), and 3x at 1080p (15x21). Subtitle anchors and colors remain the same. The progress bar is now taller
and centered in the reserved gap below the subtitle block, with its clocks
vertically centered. Its position is stable when subtitles are hidden. The 3x coordinate bank
covers full 64-character lines; text-height limits now cover all 21 rows.

Run `python3 tools/verify_subtitles.py --output results/ui-integer`, then
`python3 tools/export_ui_simulation_previews.py` to reproduce lossless PNG
screenshots at all three resolutions. Both full frames and native-pixel bottom
crops are exported. These are production-RTL simulations on a solid background,
not HDMI captures; view at 100% zoom to judge individual font pixels. The 480p
frame is raw 720x480 output, before external pixel-aspect correction. The suite
also compares maximum-length subtitle lines at all three resolutions.

This preview change is excluded from the running 3f393c5 RBF builds.

## Centered progress-bar simulation preview

The bar grows from 14 to 18 logical pixels tall. Its outer rectangle is centered
between the lower subtitle background edge and the screen bottom, allowing a
one-pixel rounding difference. All three clocks are centered vertically inside
it; the fill has enough vertical padding for the larger integer-scaled glyphs.
The reserved subtitle area remains fixed even when cues are absent or hidden.
Horizontal margins, time centers and subtitle positions are unchanged.

| Frame | Bar top | Bar height | Bottom margin | Time top |
|---|---:|---:|---:|---:|
| 720x480 | 458 | 18 | 4 | 463 |
| 1280x720 | 688 | 27 | 5 | 694 |
| 1920x1080 | 1032 | 40 | 8 | 1041 |

Reproduce with `python3 tools/verify_subtitles.py --output results/ui-centered-bar`
and `python3 tools/export_ui_simulation_previews.py --render-dir results/ui-centered-bar`.
This layout and integer fonts are not in the completed 3f393c5 RBF candidates.

## Direct subtitle value pages and media picker

The picker displays **Load media *.MPG,FL***. Stock Main generates that suffix
from three-character filters; `FL*` includes normal `.flac` filenames.

Open **Subtitles** for **Load SRT**, **Visible Yes/No**, **Offset**, and **Speed**.
Offset and Speed now open pages of directly selectable values. Move up/down to
a row and press Select/Enter to apply it; the page stays open. The first row
restores the default, followed by the other values in ascending order:

- Offset: **-5.0 to +5.0 seconds**, **0.2-second steps**, default **0.0 s**.
- Speed: **0.50x to 1.50x**, **0.02x steps**, default **1.00x**.

Each page has 51 value actions, an explicit **Subtitles** return link, and Main's
**Back** entry (53 selectable rows total). Main's Back returns to the root menu;
use the Subtitles link to return directly to the parent settings page. Selecting
a value applies it immediately. These are action rows, not cycling options or
persistent checkboxes. Visibility is still a Yes/No option.

Positive offset delays display. Timing uses `(video elapsed - offset) * speed`;
speed changes the subtitle clock only. Changing values restarts the streaming
SRT reader and may briefly hide cues while it catches up. Movie replacement
preserves the selected settings while clearing old cues. Reloading the core
restores timing defaults.

1. Load a movie and matching SRT. Toggle visibility and confirm movie/audio
   playback and the overlay continue normally.
2. Select offset/speed defaults, both extremes and several intermediate rows.
   Use values above and below the previous selection. Hold the navigation key
   to scroll a long list, then apply the desired row with Select/Enter.
3. Change timing while paused, after seeking backward and after the final cue.
   Resume and seek again; cues should follow the adjusted timeline. Select the
   same value twice and verify it remains applied. Restore defaults afterward.
4. Replace actively playing and paused FLAC with MPG repeatedly, then reverse
   direction. Include a large FLAC, short FLAC and each of the four movie tests.
   Confirm movie frames and sound resume, with OSD, subtitles and seeking intact.

The FLAC-to-MPG deadlock fix is retained. Reset-recovery timing fixes remain
deferred at the user's request; compilation does not imply timing qualification.
`tools/verify_subtitles.py` checks all 102 direct actions through actual HPS
status transport, complete generated menu readback, subtitle arithmetic,
streaming retiming and rendering. `tools/verify_media_format_handoff.py` checks
production mode switching with delayed memory responses and cancellation.

## Native FLAC first hardware gate

The new candidate adds standalone native **44.1 kHz, 16-bit stereo FLAC** to
**Load media**. Keep accepted b639ccc seed 52 available for rollback.
Hardware acceptance of native HDMI and real stock Main I2C behavior is pending.

1. Open a CD-quality FLAC made from an original WAV. Check continuous playback,
   correct pitch/speed, left/right identity, silence and elapsed/total times.
   Compare its playing length with the original. If an HDMI receiver displays
   the input audio rate, verify **44.1 kHz**.
2. Press Space repeatedly; check silent pause, frozen elapsed time and clean
   continuation. Check volume and mute. Music filters are a later gate; movie
   audio filters remain supported. Arrow keys intentionally do not seek FLAC yet.
3. Let a short FLAC finish naturally. Its final audio must play before startup
   returns. Open another FLAC while playing and while paused; old audio and
   state must be discarded. Unknown STREAMINFO total should remain dashes.
4. Alternate MPG → FLAC → MPG repeatedly. Open the OSD and change HDMI/video
   settings during music, checking that native playback resumes after Main
   reconfigures the transmitter. Test HDMI reconnect if practical.
5. Repeat Fellow, Groove, Jiggler and Star Wars at 50/59.94 Hz, including movie
   pause, every seek combination, filters, subtitles and EOF. Movie audio must
   retain its previous rate and behavior.

A corrupt/unsupported FLAC currently returns to startup. Future 44.1 kHz WAV
can share the PCM path, but WAV parsing is not implemented in this candidate.


Replace three production IDCT engines with one shared service while preserving
uncontended output cycles, transform arithmetic and reset/seek cancellation.
Independent coefficient staging handles overlapping requests. See
[shared-IDCT design and validation](SHARED_IDCT.md) for evidence and limits.

Test Fellow, Groove, Jiggler and Star Wars at 50/59.94 Hz: opening, dense motion,
audio/video continuity, pause/resume, all seek sizes/directions and repeated
seeks, reset/file replacement, subtitles/filters and EOF return to startup.
Retain accepted 7eb5088 MEDIUM seed 61 as rollback. Differential transform,
three-client timing, paired EOF/50 Hz seek and the real Pee Strike opening/seek
replay pass. The latter confirms resumed audio/video without underrun or
timestamp warning after the ten-second seek. The user reports all tests pass for the preferred b639ccc seed 52; this is
the current hardware-accepted baseline.

**Preferred candidate: b639ccc MEDIUM seed 52**, available at
`results/hardware-test-b639ccc/seed52/MediaPlayer_20260914.rbf`.
Four-corner minimum setup/hold slack is +0.645/+0.081 ns for seed 52,
+0.458/+0.048 ns for seed 61, and -0.102/+0.105 ns for seed 87.
Seeds 52 and 61 pass; seed 87 fails setup. Recovery/removal/pulse-width,
183 synchronizer stages, diagnostic-removal and scene-enable checks pass.

Seed 52 uses 35,908 placed ALMs, 512 M10Ks and 59 DSP blocks: savings of
1,136 ALMs, 13 M10Ks and 16 DSPs versus the accepted baseline. Free capacity
is 6,002 ALMs, 41 M10Ks and 53 DSP blocks. Estimated ALMs are 29,843;
use the placed figure when discussing current physical headroom.

The original post-fit audit falsely rejected Quartus `~DUPLICATE` index
registers. The corrected audit requires one shared engine hierarchy and all
six logical index bits, and records every physical copy. It also verifies
eight intermediate M10Ks and three coefficient-staging M10Ks. Missing bits,
extra engines and unrecognized suffixes are rejected. Only timing extraction
was rerun on the original fitted databases; RTL, constraints and RBFs were
unchanged. Build metadata records the audit revision separately from b639ccc.
The build evidence is `results/build-b639ccc-20260914-135047`; the original
failed audit logs remain alongside `timing-rerun.log` in each seed directory.

The separate 7eb5088 HIGH-packing experiment completed: 36,245 placed ALMs
(799 fewer), 31,461 estimated ALMs, 525 M10Ks and 75 DSPs. It fails setup at
-0.021 ns; hold is +0.114 ns. Its RBF is kept separately under
`results/hardware-test-7eb5088-packing-high/seed61` with a timing-failure marker.
The normal MEDIUM setting and accepted RBF remain the baseline.

# Diagnostic removal gate three and compact time bar

**Hardware accepted:** the user reports all tests pass for the preferred
7eb5088 seed 61 handoff. This is the current tested baseline; all three
diagnostic-removal gates are complete. The checks below remain the regression
checklist for future work.

Gate two (100ab07 seed 87) is hardware accepted: the user reports all tests pass.
Retain it as rollback. This candidate removes Audio test and its independent
source, test FIFOs, control/reset state and output adapter. Movie PCM connects
directly to the existing MiSTer audio outputs; old menu status bits 1–3 are
reserved and cannot select a tone or override movie sound.

Elapsed, total and remaining time are black glyphs on the progress bar.
Paused/Seeking labels and their character-selection logic are removed.
The bar and subtitles move down one 14-pixel logical line: at 720×480 the
bar occupies y=466–479, clocks start at y=469, and subtitle lines at y=431/445.
Pause/seek still reveal the bar; seek previews, unknown-time dashes and normal
visibility timeout remain. The pixel pipeline and subtitle styling remain intact.

Repeat Fellow, Groove, Jiggler and Star Wars at 50/59.94 Hz: startup/audio,
pause/resume, short/long/backward/repeated seeks, OSD and audio/video filters,
SRT loading/cue timing, replacement movies and clean EOF including audio tails.
Check the black clocks over empty/full/unknown progress and no bottom clipping.
No Paused/Seeking labels or Audio test menu should remain. Fitted audits require
all test-audio registers absent and movie PCM/FIFO/finished state present, plus
all 183 functional CDC stages. Timing is reported without extra closure builds.

Gate-three regressions pass under results/gate3-*: 12 full-frame player cases
and five subtitle cases (480p/720p/1080p), subtitle transport and lifetime,
reader-error cancellation, pause/seek and EOF controls. Both mixed and seek-EOF
oracles check 423936 reconstruction pixels without mismatches. Audio compares
48384 stereo pairs against FFmpeg within one PCM unit, retains exact pause/seek
sequences, and checks 30 picture timestamps without underrun or timestamp warning.
Gate-three hardware acceptance is complete. All three 7eb5088 builds completed;
seeds 61 and 87 pass all four timing corners. All three pass the 183-stage CDC,
formatter-enable, profiler/reporting-removal and Audio test absence/retained-PCM
audits. No extra timing-fix builds were started.

| Seed | Setup slack | Hold slack | Actual ALMs | Estimated ALMs | M10Ks |
| --- | ---: | ---: | ---: | ---: | ---: |
| 52 | -0.191 ns | +0.114 ns | 37,029 | 31,287 | 525 |
| 61 (preferred) | +0.334 ns | +0.074 ns | 37,044 | 31,325 | 525 |
| 87 | +0.083 ns | +0.115 ns | 36,916 | 31,285 | 525 |

All use 75 DSPs and three PLLs. Seed 61 saves 282 actual ALMs, 495 estimated
ALMs and two M10Ks versus accepted gate-two seed 87, leaving 4,866 ALMs and
28 M10Ks free. Seed 52 is packaged with a timing-failure marker.

Preferred RBF: `results/hardware-test-7eb5088/seed61/MediaPlayer_20260914.rbf`.
SHA-256: `bbd4c36588e5db22343e5e688ef177ed1f54ce24cb4206b8d76332e1d74b84fc`.
Evidence: `results/build-7eb5088-20260914-125028/corner-summary.json`.
Retain accepted `results/hardware-test-100ab07/seed87/MediaPlayer_20260914.rbf`.


# Diagnostic removal gate two

Gate two removes the remaining telemetry mailbox, reporting crossings and
statistics, unused status outputs and legacy LED-success expressions. Seek and
EOF use named functional scheduler outputs with unchanged state logic. Live
reader timeouts/quarantine, fatal decode checks, PCM-finished synchronization,
90 kHz presentation timing and FIFO/DDR ownership remain intact. A dedicated
one-bit mailbox preserves reader-error delivery to seek control, replacing the
old telemetry-bus dependency; all 183 required CDC stages remain audited. Audio test is
still present for gate three. Black Paused/Seeking text and subtitles are unchanged.

The frozen MPEG2FPGA source tree and two unused wrappers are removed from the
repository; they were not part of the compiled design. Git history and the
legacy provenance document retain their origin information.

Test Fellow, Groove, Jiggler and Star Wars: normal startup and audio/video,
pause/resume, every seek size/direction including repeated long/backward seeks,
SRT load and cue timing, OSD/filter operation, replacement movies, paused EOF,
longer audio tails and EOF return to startup at 50 and 59.94 Hz. No telemetry
or LED blink codes should appear. Retain gate-one seed 52 and hardware-accepted
b05b76f seed 87 for comparison/rollback. Gate three waits for user authorization.

Gate-two simulations pass: mixed I/P/B EOF and seek-to-EOF/display ownership
oracles each check 423936 pixels without mismatches; playback/session controls,
reader timeout/malformed-response quarantine, independent reader-error CDC and
seek retirement, raster/refresh, UI/subtitle pixel and cue tests pass. The audio
oracle checks 48384 sample pairs within one PCM unit of FFmpeg, exact pause/seek
sample sequences and 30 picture timestamps with no underrun/timestamp warning.
Evidence is under results/gate2-*. All 100ab07 seeds pass four timing corners,
183 CDC stage checks, the zero-profiler audit and all 17 reporting-removal checks.
Setup slack for seeds 52/61/87 is +0.072/+0.188/+0.344 ns; hold is
+0.116/+0.115/+0.106 ns. Preferred seed 87 uses 37,326 actual ALMs, 527 M10Ks
and 75 DSPs, leaving 4,584 ALMs and 26 M10Ks free. Estimated ALMs are 31,820.
Resources are essentially flat against gate-one seed 52 (37,267 actual/31,787
estimated ALMs); source cleanup does not guarantee additional fitted savings.

Preferred gate-two RBF: `results/hardware-test-100ab07/seed87/MediaPlayer_20260914.rbf`.
SHA-256: `297690c42da92880077be53601e23a7a7fc8c6d4d90fc50105577f0c7f288dba`.
Hardware acceptance is pending. Audio test remains for gate three.

# Diagnostic removal gate one

This candidate removes the on-screen telemetry profiler and its snapshot
hardware. Audio test remains for gate three; reporting-source RTL remains for
gate two. Paused and Seeking are now black glyphs with transparent gaps, at
their existing position on the progress bar. There is no white text background.
The normal progress fill can still be white underneath the text.

Test Fellow, Groove, Jiggler and Star Wars. At each file's startup and EOF,
confirm there is no telemetry pattern. Verify picture/audio continuity, OSD
and filters, pause/resume, short/long forward and backward seeks, replacement
movies and EOF return to startup. Check subtitles and status lettering over
empty/full/unknown progress, at both 50 and 59.94 Hz. Keep hardware-accepted
b05b76f seed 87 as rollback. Gate two waits for your acceptance of this gate.

Simulation evidence is under results/gate1-subtitles, results/gate1-mixed and
results/gate1-controls.json. All three 8e418b3 seeds pass four timing corners,
183 CDC register checks and the zero-profiler-register audit. Preferred seed 52
has setup +0.397 ns and hold +0.114 ns. Seeds 61/87 have setup +0.397/+0.197 ns
and hold +0.099/+0.089 ns. No timing fixes or extra builds were needed.

Preferred RBF: `results/hardware-test-8e418b3/seed52/MediaPlayer_20260914.rbf`.
SHA-256: `78501002b4e4d9669635ffa30e9f744e47103baf0e12740e09594f2a40c625a8`.
Actual placed ALMs are 37267/37169/37350 for seeds 52/61/87; estimated ALMs
are 31787/31731/31708. All retain 527 M10Ks and 75 DSPs. Compared with accepted
b05b76f seed 87, seed 52 reduces estimated ALMs by 964 but physical occupancy
by only 143 because fitter packing differs. Gate-one hardware acceptance is
pending. See
[the three-gate plan](DIAGNOSTIC_REMOVAL_PLAN.md).

# Audio timestamp warning tolerance

Fellow and Groove triggered only the audio timestamp warning at played sample
4609. Exact-byte opening replays reproduce a 15/90000-second (167 us) backward
step in the second audio PES timestamp: frame five says 56477 while the
continuous 48 kHz sample grid reaches 56492. Jiggler and Star Wars say 56492
and do not warn. This is a file timestamp discrepancy, with no missing PCM
samples or underrun in the reproduction.

The next source revision allows up to 90 ticks (1 ms) of lateness in the warning
only. This is a diagnostic tolerance, not a format limit or a change to audio
scheduling. Sample output, PTS handling, seek behavior and underrun detection
are unchanged. Tests must still flag 91-tick and 900-tick lateness, preserve
512-clock sample spacing and every PCM sample, and cover PTS wrap.

Use `python3 tools/replay_audio_startup.py --output results/audio-startup --expect-clean /path/to/fellow.mpg /path/to/Groove.mpg /path/to/Jiggler.mpg /path/to/StarWars.mpg`.
The replay reads at most 1 MiB of each original file without remuxing, stops
after 9216 consumed sample pairs and records timestamps plus prefix hashes.
It uses production clock rates, ideal bounded CDC queues and synthetic video
consumption; it is not a full video or vendor FIFO simulation. On hardware,
reload each file and leave playback running through startup before trying
pause/seek. Verify that the unwanted warning stays absent and audio is clean.
The completed b05b76f EOF builds do not contain this warning adjustment.

# EOF-to-startup qualification

At a clean physical EOF, finish queued video and audio, retain the final image
for one source-frame interval, then return to the startup screen. Clear the
progress/times/status overlay and subtitle association. Do not loop or remember
a resume position. Opening any file, including the same movie, starts fresh.
Main may still display the previously mounted filename until another selection.

Test a short MPG to completion with subtitles visible near the end, then load
another movie and confirm startup playback with no old cue or time. Repeat with
raw M2V, video-only MPG, and a file whose audio lasts longer than its video (such
as Groove). Unknown total/remaining must not prevent EOF completion. Pause near
the end and leave it paused: the frame stays until playback continues. Repeat
short/long forward and backward seeks near the end, including seeking beyond
the endpoint. Once a seek completes and playback is unpaused, EOF returns to
startup; reopening starts from the beginning. Replace the movie just before
its endpoint and confirm the old EOF cannot close the replacement. Keep the OSD
open across completion and verify the menu and filters still work. Check both
50 and 59.94 Hz output. Fatal/truncated streams are not classified as clean EOF.

Simulation: `python3 tools/verify_playback_controls.py --output results/eof-controls.json`
and `python3 tools/verify_decoder_timing.py --output results/eof-mixed --eof-control`.
The controller regression covers all five source frame rates, longer audio,
pause/seek/probe inhibition, CDC generation races, and delayed host/DDR drain.
The mixed raster oracle verifies completion after real I/P/B presentation with
423,936 reconstructed pixels checked.

All b05b76f seeds compiled; 52 and 87 pass all four timing corners, 183 CDC
registers and scene-enable checks. Seed 61 misses setup by 0.009 ns. Preferred
seed 87 has setup +0.358 ns, hold +0.099 ns, 37,410 actual ALMs, 527/553 M10Ks
and 75/112 DSPs. This leaves 4,500 placed ALMs and 26 M10Ks free. Physical
packing varies across seeds; the change in occupancy is not a logic-removal
claim. Seed 52 also passes with setup +0.258 ns and hold +0.115 ns.

Preferred EOF RBF: `results/hardware-test-b05b76f/seed87/MediaPlayer_20260914.rbf`.
SHA-256: `e9ac8007db6a50877ea9ebc7b666b7879f0c30954bf168beefe3569fff08b093`.
It includes the UI layout revision but not the subsequent audio warning tolerance.
Hardware EOF acceptance remains pending.

# Next layout: clocks below the progress bar

The subtitle baseline ec56250 was accepted on hardware. The next revision moves
all three time fields below the progress bar, Paused/Seeking onto the bar, and
subtitles two lines lower. Status has dark text on a light inset. Check the
bottom margin at 480p/720p/1080p, empty/full/unknown progress with status, and
subtitles with the controls shown and hidden. Playback and SRT parsing are
unchanged. All three b5a17cf seeds pass all four timing corners and 171 CDC checks.
Seed 52 is preferred: setup +0.508 ns, hold +0.113 ns, 38,593 actual ALMs,
527 M10Ks and 75 DSPs. Seeds 61/87 have setup +0.436/+0.313 ns and hold
+0.098/+0.076 ns. Hardware layout confirmation remains pending.
The layout-only RBF is `results/hardware-test-b5a17cf/seed52/MediaPlayer_20260914.rbf`
(SHA-256 `399c7ba28c2a3ad74cfb9879e197267bc8ac8ddcbc02e61d968b0a758c86fa55`).
Keep hardware-accepted ec56250 seed 87 as rollback.

# Timing-qualified ec56250 seed 87: manually loaded SRT subtitles

Open a movie, then choose **Load subtitles** and select its SRT. Subtitles
appear above the relocated Paused/Seeking text, independently of controls
visibility. Use **Subtitles: On/Off** to toggle them. New movies clear the
association. Test exact cue boundaries, pause and every seek direction/size,
including paused seeks, replacing SRTs and changing movies during subtitle
reads. Check 480p, 720p and 1080p, OSD access and filters.

Run `python3 tools/make_subtitle_test.py` for a one-hour timing fixture that
works alongside any movie. See [SRT coverage and limits](SUBTITLES.md).
All three seeds pass all four corners, 171 CDC registers and scene-enable
checks. Seed 87 has setup +0.338 ns and hold +0.110 ns; seeds 52/61 have setup
+0.116/+0.136 ns and hold +0.115/+0.108 ns. The user reports everything works perfectly and accepts this subtitle baseline.

Preferred RBF: `results/hardware-test-ec56250/seed87/MediaPlayer_20260914.rbf`.
SHA-256: `765fc4eea7ec7e5a4d2701a3ac470d0f6e4dacadfaef4acd5f771b517bb59752`.
Seed 87 uses 38,773 actual ALMs, 527/553 M10Ks and 75/112 DSPs, leaving 3,137
ALMs and 26 M10Ks. Seed 52 also passes and uses 37,536 actual ALMs, leaving
4,374; its lower physical usage reflects fitter packing, not less functionality.
Estimated ALMs are 33,032/32,933/32,936 for seeds 52/61/87, compared with
31,987 for ffafc79 seed 87. Thus the low placed total of seed 52 is not evidence
that adding subtitles removed logic. All subtitle seeds add seven M10Ks and
six DSPs. Fitter confirms four M10Ks for reader staging and two for line/cue
storage; the overlay hierarchy rises from 15 to 16 M10Ks. Retain ffafc79 seed
87 below as rollback.

# Timing-qualified ffafc79 seed 87: lower progress strip and clocks without labels

The three clocks retain their elapsed / total / remaining order, left to right,
but display only times or unknown dashes. The clocks and bar move down one
outer bar height (14 pixels at 480p, 21 at 720p, approximately 32 at 1080p).
Check centering, the bottom margin and unknown times at all three resolutions,
plus pause, seeking and automatic hiding. All three seeds pass all four timing
corners, 159 CDC registers and the scene-enable audit. Preferred seed 87 has
setup +0.371 ns and hold +0.110 ns; seeds 52/61 have setup +0.196/+0.224 ns
and hold +0.097/+0.103 ns. Seed 87 uses 37,713 actual ALMs, 520 M10Ks and
69 DSPs, leaving 4,197 ALMs and 33 M10Ks. Hardware acceptance is pending.

RBF: `results/hardware-test-ffafc79/seed87/MediaPlayer_20260914.rbf`.
SHA-256: `3d229f28cb7e12b0cde1f2da716754f6c307a80f94678e5668303f9896c93f0d`.

# Sparse-timestamp duration correction — 3d48cc5 seed 87 ready

Preferred RBF: `results/hardware-test-3d48cc5/seed87/MediaPlayer_20260914.rbf`.
SHA-256: `d6f66b6870113e53e46f8d229b11c90b0d0f8870e5c6cb621cc99cf1991a80e7`.
Seed 87 passes all four corners with minimum setup **+0.427 ns** and hold
**+0.107 ns**, plus all 159 CDC registers and the scene-enable audit.
Seed 61 also passes (+0.089 ns setup/hold); seed 52 fails setup (-0.381 ns).
Use seed 87 for hardware validation; it has not been deployed or accepted yet.

Seed 87 uses **37,715 actual ALMs**, **520/553 M10Ks**, 69 DSPs and 47,267
registers, leaving **4,195 ALMs and 33 M10Ks**. Compared with tested b00920a
seed 52, this adds 265 actual ALMs and no M10Ks or DSPs. Estimated ALMs are
31,901, distinct from actual placed usage. The earlier b00920a overlay was
accepted by the user; retain it as rollback. Conversion-induced stutter in
Groove/fellow is separate; see [encoding cadence](ENCODING_CADENCE.md).

Initial `9076405` builds compile but fail setup in scaler/decimal formatter
paths. They are not recommended. The revision uses the existing sequential
divider for decimal digits; pixels and time-field contents are unchanged.

This candidate resolves `Groove.mpg` using MPEG picture-order information
between timestamp anchors. The exact file's bounded-window RTL replay now
reports approximately **01:18:25** total, matching independently decoded video
endpoint timing within one 90 kHz tick. Star Wars LOWER, Pee Strike and fellow
also pass that comparison. Audio-track/container duration may differ from the
video endpoint used by these fields.

Load speed retains the same 64 KiB head / 4 MiB tail read limits. Files without
sufficient bounded evidence still show dashes, as requested; there is no full
file scan. On the timing-qualified candidate, check Groove's Total and Remaining,
then pause, seek and switch to Star Wars LOWER to confirm cached duration and
elapsed position behave correctly. Retain the tested b00920a seed 52 below.

# Timing-qualified player overlay: b00920a seed 52

Preferred RBF: `results/hardware-test-b00920a/seed52/MediaPlayer_20260914.rbf`.
SHA-256: `bf7e9aff272e5f819e16358dba90d2d05e18b9ca78436df6e3cd204e1d520973`.
The user accepted this overlay on hardware; sparse-timestamp duration recovery
is supplied by the newer candidate above.

All three seeds pass all four timing corners, 159 CDC registers and the real
modulo-four scene-enable audit. Seed 52 has minimum setup +0.135 ns and hold
+0.096 ns. Seeds 61 and 87 have setup +0.100/+0.028 ns and hold +0.069/+0.111 ns.
Audit-only correction `9f16364` accounts for Quartus routing copies of the
counter; source RTL, timing constraints and fitted binaries remain `b00920a`.

Seed 52 uses **37,450 actual ALMs (89.4%) and 520/553 M10Ks**, leaving 4,460
ALMs and 33 M10Ks free. The increase over accepted `3ff27c8` seed 52 is 1,676
actual ALMs and 12 M10Ks. DSPs remain 69; registers total 46,904. Estimated
ALMs needed are 31,755 (75.8%), distinct from actual placed ALMs.

Initial `5373dae` fails timing and is not recommended. The intermediate
`287cf6b` correction was cancelled during fitting. Use the RBF above.

This change adds the historical progress strip and three time fields to normal
scaled HDMI, after video filters and before the MiSTer menu. Keep accepted
`3ff27c8` seed 52 below as rollback until hardware validation completes.

On opening an MPG, allow the bounded head/tail timestamp preflight to finish.
It adds startup reads; ordinary seeks reuse the cached result. If sufficient
endpoint evidence is unavailable (including raw M2V), Total and Remaining show
`--:--:--` with a patterned track. Duration never comes from a byte-size ratio.

Check the following on this RBF:

1. Open a complete short MPG and a whole movie, including a file above 4 GiB.
   Compare Total with the encoded stream duration, allowing timestamp rounding;
   confirm Elapsed begins near zero and Remaining counts down.
2. At 480p, 720p and 1080p HDMI output, check the three readable time fields,
   track and fill. Change 4:3/16:9 and video filters: the UI should stay fixed
   and retain its colors. Open the MiSTer OSD over the player UI.
3. Pause with Space. Confirm elapsed position freezes, Paused appears and the
   controls hide after ten seconds even while paused. Resume and confirm the
   controls reappear briefly.
4. Seek both directions with all three jump sizes, including while paused.
   Seeking should remain visible over the existing black picture, then show
   the actual landing time and restart the hide interval. Stress repeated
   seeks and compare playback recovery with the accepted core.
5. Open/reload another file, including raw M2V or one without usable tail
   timestamps. Confirm the previous file's total and progress do not persist.
   Check EOF, remaining clamping and playback at both 50 and 59.94 Hz.

No subtitle files, cue selection, new keyboard shortcuts or HDMI refresh modes
are added. The player overlay targets scaled HDMI; direct-video and analog
paths retain their existing behavior. See `UI_OVERLAY_PLAN.md` for regression
commands, implementation limits and the future provider contract.

# Accepted IDCT intermediate RAM build: 3ff27c8 seed 52

Preferred RBF: `results/hardware-test-3ff27c8/seed52/MediaPlayer_20260914.rbf`.
SHA-256: `236c9817ccfd04b10e23ff0ee052f2c11e5a39d7fcfdb88e3e42b29e969406f1`.
Seed 52 is hardware accepted: the user reports everything works perfectly.

Seeds 52 and 87 pass all four timing corners and the 153-register CDC audit.
Seed 52 has minimum setup +0.133 ns and hold +0.110 ns; seed 87 has +0.067
and +0.074 ns. Seed 61 fails setup at -0.152 ns and is not recommended.

Seed 52 uses 35,774 actually placed ALMs (85.4%), saving 2,016 against
accepted dc1dfc2 seed 52. Quartus estimates 29,791 ALMs needed (71.1%), which
is a different metric. Registers total 43,508. All seeds use 508/553 M10Ks,
69/112 DSPs and three PLLs. The 24 additional M10Ks leave 45 free; each new
bank is verified at a physical M10K site in the fitter report. Requested
RAM type is reported as AUTO despite the RTL attribute, so inspect physical
placement. See the handoff README and per-seed intermediate-ram.json.

Differential IDCT outputs and cycles match dc1dfc2; mixed-picture pixel and
seek tests plus the actual Pee Strike A/V direct restart pass. Expect the
same playback, picture quality and seek speed. Retain dc1dfc2 seed 52 as
rollback and follow the tests below. No new refresh modes are included.

# IDCT intermediate RAM conversion

The current change moves only the intermediate arrays of all three IDCT
instances into eight 8-by-24 M10K banks each. Coefficient storage, signed
arithmetic, rounding and multiplier sharing are unchanged. Synchronous reads
prefetch the next column to preserve the existing transform and sample cycles.
RAM is not cleared on reset: reset cancels the transform, and a full first
pass overwrites every location before the next second pass reads it.

Run the differential test against hardware-accepted dc1dfc2:

```sh
python3 tools/verify_idct_storage.py --baseline dc1dfc2 --output results/idct-storage/equivalence
python3 tools/verify_decoder_timing.py --playback-controls --display-ownership --output results/idct-storage/reconstruction
```

The differential test compares every output on every cycle, including all
64 positive/negative coefficient impulses, dense signed extremes, 512 seeded
sparse random blocks, reset at 133 transform offsets, immediate restart,
simultaneous input controls and invalid overlap. Require identical samples
and handshakes plus the full mixed-picture pixel oracle and seek recovery.
Also replay the captured Pee Strike direct restart through shared DDR and
display ownership using the existing replay tool.

Quartus qualification must confirm all 24 intermediate banks infer M10K,
measure total RAM blocks and actual placed ALMs separately from estimated
ALMs, and pass all four timing corners plus 153 CDC registers. Compilation confirms 24 additional M10Ks (508 total).
Seed 52 from this change is hardware accepted by user report.

On hardware test clean playback at both refresh rates, repeated forward and
backward short/long seeks, pause and paused seeks, reload and EOF. Watch for
block corruption or stale images after seeking. Accepted dc1dfc2 seed 52 below
is the rollback and must remain available.

# Accepted row-buffer RAM conversion

Source **dc1dfc2, seed 52** is the preferred candidate. All three seeds pass
all four timing corners and all 153 CDC checks. Seed 52 has worst setup
+0.437 ns and hold +0.089 ns. Its RBF is
`results/hardware-test-dc1dfc2/seed52/MediaPlayer_20260914.rbf`.
SHA-256: `7eb9a5bebc66423885d5865a40dc55ab24f28d3ff6f4743f05c3ebd394358ce6`.
The user reports playback works perfectly like the previous accepted core.

Seed 52 uses 37,790 actually placed ALMs (90.2%), with Quartus estimating
31,925 ALMs needed (76.2%). These are different metrics. Against accepted
bcddb20 seed 61, actual placement drops by 3,355 ALMs. RAM rises from 482 to
484 of 553 blocks; DSP usage stays at 69. Both row arrays are confirmed M10K.

Current source restores the two 512-byte P/B parser row buffers to M10K RAM,
using the prefetch and rollover handling from historical commit 047f5b2.
The previously accepted bcddb20 seed 61 below remains the rollback; it does
not contain this conversion or the subsequent audio-menu removal.

Run the differential parser comparison against the pre-conversion source:

```sh
python3 tools/verify_row_buffer_equivalence.py --baseline 1349c82 --output results/row-buffer-equivalence
python3 tools/verify_decoder_timing.py --playback-controls --display-ownership --output results/row-buffer-pixels
```

Require identical parser results and reported cycle counts, including chunk
rollover, dense residuals and abort recovery. Two historical dense-stream
fixture/test pairings fail unchanged baseline assertions and are excluded
explicitly. Require current full reconstruction/seek checks for publication
ordering as well; parser equivalence alone does
not model vendor RAM inference or physical timing. In Quartus confirm both
row arrays infer RAM, compare actual placed ALMs separately from the ALMs-needed
estimate, and require all timing corners plus the 153-register CDC audit.
Measured memory cost is two additional M10K blocks. See the candidate figures
above for the current placement result.

On hardware repeat short/long forward and backward seeks, paused seeks/resume,
new-file load and EOF, checking clean pictures and synchronized audio. The
Seek audio bypass diagnostic menu item is removed; normal bypass remains enabled.

# Direct file seeking candidate

Source **bcddb20, seed 61** passes all four timing corners and the 159-register
CDC audit, with worst setup +0.205 ns and hold +0.066 ns. Its test RBF is
`results/hardware-test-bcddb20/seed61/MediaPlayer_20260914.rbf`.
SHA-256: `98a3957e92ffb71112a31d373082854673a45c97fb5c5169c2b48971e75a2f24`.
Hardware acceptance is pending. Seeds 52 and 87 fail setup timing.

This candidate adds timestamp-guided byte-position probing for both directions,
including unseen forward destinations. It retains the a229a01 bank-release fix
and removes the added seek-fault telemetry. The older rollback RBF documented
below does not contain this direct-seek path.

```sh
python3 tools/verify_direct_seek.py --output results/direct-seek-check --input path/to/bounded-prefix.mpg
python3 tools/verify_mp2_seek.py results/mp2-seek-history.json
```

The search uses at most 18 probes, each capped at 4 MiB of reader progress,
and prefers a timestamped I-picture within two seconds before the target.
These are implementation bounds, not MPEG requirements. If no usable point
is found, it reconstructs from the beginning. Original movie PTS origin is
retained across seeks. Raw M2V uses reconstruction fallback in both directions.
Compact playback-health telemetry remains; the separate persistent seek-fault
snapshot is removed from this candidate.

Test 10-second, 30-second and five-minute jumps both ways in Pee Strike and
fellow.mpg, including a first-time jump far ahead and a backward jump late in
the movie. Allow approximate GOP landing initially. Repeat while paused, resume,
open the OSD during a search, and check audio synchronization. Test near zero,
past EOF, and after selecting a different file. The packaged bcddb20 RBF still
provides the historical audio comparison switch; current source removes that
menu option and always uses normal compressed-audio bypass with decoded preroll.
Leave a failed state loaded for inspection; report the file and key combination.

# Seek display-bank ownership fix

The updated source releases the stopped display reader's bank protection during
seeking after pending DDR reads drain. Source **a229a01, seed 87** now passes
all timing corners and the 147-register CDC audit, with worst setup +0.104 ns
and hold +0.077 ns. Its local test RBF is:
`results/hardware-test-a229a01/seed87/MediaPlayer_20260914.rbf`.
Hardware acceptance remains pending. The earlier 6eb49e1 diagnostic RBF does
not contain the bank-release fix.

The regression now models periodic display reads that continue during pause
and stop during seeking. With release disabled, reconstruction fails its
progress check; with release enabled, both retained seeks complete and the
423936-sample pixel oracle passes. A focused test also checks all five frame
regions, queued multi-beat read responses, DDR busy, simultaneous new display
acceptance, pause protection and re-acquisition after seeking.

```sh
iverilog -g2012 -s test_seek_display_ownership -o /tmp/seek-display-test \
  tools/test_seek_display_ownership.sv rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
vvp /tmp/seek-display-test
python3 tools/verify_decoder_timing.py --playback-controls --display-ownership --output results/seek-fixed
# Expected failure control:
python3 tools/verify_decoder_timing.py --playback-controls --display-ownership --disable-display-release --output results/seek-old
```

Repeat the captured Pee Strike seek near 18.45 seconds with the fixed RBF,
then test repeated forward seeks from both moving and paused playback, backward
seeks, resume, and seeking past EOF. The diagnostic audio bypass comparison
is available in that older RBF. The older a229a01 test RBF includes first-fault telemetry;
current source removes that additional overlay to recover placement capacity.

# Historical seek diagnostics and audio comparison

Current source retains compact playback-health telemetry and enables normal
compressed MP2 bypass with decoded preroll during seeking. The diagnostic
**Seek audio bypass** menu item and its configuration mailbox are removed;
previously saved settings for that option no longer affect playback.
The additional persistent seek-fault observer, mailbox and renderer are also
removed from production hardware.

Older RBFs such as bcddb20 have the audio comparison switch. For historical
investigation, compare On and Off using the same file and key, setting the
option before reloading. Current simulation tools retain `--no-audio-bypass`
for regression comparisons. If playback freezes, leave the file loaded and
record the file, position and key command.

The following applies only to historical RBFs with the seek-fault observer
(such as a229a01), and their saved screenshots. The standalone observer test
and screenshot decoder remain available for those records.

The historical snapshot survives pause, later seeks and decoder restart. Reset or a
new file clears it. Error-at-entry means flags were already present when the
observer first saw the seek; it does not establish causality. After entry the
first nonzero error or two seconds without decoder/presentation progress during
seeking captures the record. Audio error flags arrive through their existing
synchronizers, so this is decoder-domain observation order, not exact ordering
between clock domains. A timeout is diagnostic evidence, not proof of deadlock.

Decode an unscaled MiSTer screenshot with:

```sh
python3 tools/streams/decode_hardware_cadence.py screenshot.png --json
```

`seek_diagnostics` contains detailed decoder subcodes, errors, seek state,
current/target quarter-90-kHz timestamps, displayed PTS and picture metadata,
unread video DDR words, compressed-audio RAM bytes, PCM write-domain occupancy,
ingress reservoir minimum, scheduler flags and seek count. RAM counts exclude
pipeline/prefetch registers; the ingress field is a historical minimum, not live
occupancy. The cycle counter saturates after about 71.6 seconds. The snapshot
can decode even while the older cadence snapshot is absent.

The exact-file replay accepts an MPG prefix up to 16 MiB, with unchanged bytes:

```sh
python3 tools/replay_mpg_seek.py opening.mpg results/replay
python3 tools/replay_mpg_seek.py opening.mpg results/replay --reuse --no-audio-bypass
python3 tools/replay_mpg_seek.py opening.mpg results/replay --reuse --seek-delay 137 --host-stall 200000
python3 tools/replay_mpg_seek.py opening.mpg results/replay-shared --shared-ddr --seek-delay 500000 --host-stall 200000
```

It runs the actual mounted reader, PS demux, MP2 decoder/output, bounded queues,
video reconstruction and PTS scheduling. The optional `--shared-ddr` mode routes compressed-video traffic through the
production reconstruction/prediction arbiter; default mode uses separate DDR
service. With `--display-ownership`, periodic display reads claim the current bank,
continue during pause and stop during seeking. This exercises ownership but
not full raster bandwidth. Vendor FIFO CDC remains outside this behavioral model. A prefix may end mid-packet; only explicitly completed pre-EOF seek
boundaries count as success. `--no-skip` provides an ordinary-playback comparison.

# Keyboard playback controls

Use a timing-qualified RBF from the playback-controls build. Hardware validation
of these controls is pending; source and simulation success alone are not acceptance.
Use stock Main with the existing mounted-file menu. For HDMI refresh matching,
retain this per-core override even if the global setting is zero:

```ini
[MediaPlayer]
vsync_adjust=1
```

The menu selects 50/59.94 Hz; this ini setting lets HDMI follow it. At zero,
the configured HDMI timing may require repeat/drop conversion between rates.
No additional ini change is needed specifically for keyboard playback controls.

| Key | Action |
| --- | --- |
| Space | Toggle play/pause |
| Left / Right | Backward / forward 10 seconds |
| Ctrl + Left / Right | Backward / forward 30 seconds |
| Ctrl + Alt + Left / Right | Backward / forward 5 minutes |

Both left/right modifier keys work. Up/Down remain unassigned. Commands operate
with the OSD closed; arrows and Space used in the OSD do not change playback.
Each physical key press produces one command, without typematic repetition.
During a seek, additional seek commands are ignored until completion; Space
can still change whether playback will resume or remain paused.

Pause should freeze the displayed movie frame and silence movie audio, while
the raster and OSD keep running. Resume should continue the retained samples
and frames without a catch-up burst. Leave Audio test Off during movie checks.

MPG seeks in both directions search the file for timestamped sequence headers
and I-pictures, then reconstruct from a nearby restart point. This includes
unseen forward destinations. Files without usable timestamps use the byte-zero
reconstruction fallback. The target uses displayed movie time rather than the
reader's buffered position, and the original movie timestamp origin survives
restarts. Backward jumps clamp at zero; forward jumps beyond EOF land on the
last available frame and then return to startup when playback is unpaused.
Seeking while paused leaves the destination paused.
The screen is blank during seeking and the OSD remains usable. MP2 startup
finds a complete audio header after a partial frame; early frames bypass
synthesis, with decoded preroll restoring history before output resumes.
Leading B-pictures requiring a reference from before the restart are discarded.

1. Play both a numbered M2V and an MPG with audible audio. Pause for 10 seconds,
   open/close the OSD and adjust filters, then resume. Check frame retention,
   silence, sample continuity and A/V alignment. Repeat several times.
2. With a burned-in time/frame counter, compare the shown time before and after
   all three jump sizes in both directions. Allow approximate GOP landing in this initial direct-seek build.
   Use a file longer than six minutes for the five-minute forward jump.
3. Repeat while paused. Verify the requested destination appears and stays still
   until Space resumes. During a seek, toggle Space and check the resulting state.
4. Seek backward near the start, forward near EOF, then reload after clean EOF has returned to startup.
   Reload another file and use Reset during a seek; check clean recovery and
   normal playback, with no old audio or reference-frame corruption.
5. Repeat with 25 fps at 50 Hz and 29.97 fps at 59.94 Hz. Test OSD arrow navigation
   and held keys to ensure they do not accidentally repeat playback commands.

Absence of telemetry while seeking does not prove error-free operation.
Cadence telemetry clears during deliberate pause/seek and measures the subsequent
continuous playback segment. Audio sample telemetry counts played samples,
excluding discarded seek preroll. Report the source/seed, format, source frame
rate, output refresh, starting/landing time, elapsed seek time and any artifacts.

Reproduce focused checks with:
`python3 tools/verify_playback_controls.py --output /tmp/playback-controls.json`
and the actual mixed I/P/B pixel oracle with:
`python3 tools/verify_decoder_timing.py --playback-controls --output /tmp/playback-reconstruction`.

---

# FPGA audio hardware gate

Use stock Main on MiSTer `10.10.0.45`. Keep the accepted `9233f07` seed-52 RBF
as the recovery image. This candidate needs its own hardware acceptance.

1. Load a timing-qualified candidate, leave Audio test **Off**, and play
   `test_av_sync.mpg` generated by `tools/make_mpg_audio_test.sh`. Each white
   flash and short stereo beep should occur together. Listen for both channels,
   gaps, crackles, repeated samples or pitch changes.
2. Play the generated movie excerpt (`test_progressive_mpg.mpg`) and check
   continuous picture, audible movie audio and lip sync through the end.
3. Leave the terminal screen visible for telemetry capture. Require zero error
   flags, `audio_finished`, and played sample pairs equal to decoded MP2 frames
   multiplied by 1,152. Encoder padding can extend audio slightly beyond video.
4. Replay the MPG, load the accepted raw `.m2v` control, then replay MPG again.
   Require clean sound/history reset and unchanged raw picture/completion.
5. After these pass, test a longer converted movie and compare sync near the
   beginning and end. Record the RBF seed, filename and failure time if any.

Audio error bits: 11 compressed MP2 failure, 12 PCM underflow, 13 timestamp
lateness. Bit 10 is Program Stream syntax failure. No error alone is not proof
of audio playback: also check the counters and listen. The screen's video frame
counters still wrap at 256; their derived FPS is unreliable on longer clips.

The first audio profile is 48 kHz stereo MPEG-1 Layer II, unprotected,
112–384 kb/s (192 and 320 kb/s are the main content targets). Other codecs,
sampling rates, mono, CRC-protected audio and interlace are outside
this candidate's acceptance claim. Native 480p output comes later.


## Mounted-file OSD playback validation

For the mounted-file build, select MPG or M2V through **Open MPEG-2 Video**. During playback, open/close the MiSTer OSD repeatedly, enter the video and audio filter pages, change filters, and browse the file selector. Playback should continue while the menu is open. Check video continuity, audible continuity and A/V sync, then select another file, repeat the same file, use Reset, and play through EOF. The previous file must not leak into the next session.

Keyboard pause/seek controls are described above; these mounted-reader checks remain applicable. Record the exact RBF hash and actual Main binary/version: a `main=MiSTer_MediaPlayer` ini override exists on the previously inspected hardware configuration, so stock-Main identity must be verified during acceptance. This build needs no custom Main and does not alter MiSTer.ini.

Run `python3 tools/verify_media_file_reader.py` for host/session regressions and `python3 tools/verify_mpg_audio.py /tmp/mounted-playback.json` for byte/PTS/PCM comparison. Capture post-playback telemetry using the existing workflow; the decoder recognizes schema 9 at (8,280) as well as older captures. Transport status low four bits are error (0 none, 1 timeout, 2 malformed response, 3 size/offset range), bit 4 reader idle and bit 5 session cancellation. Maximum response wait is in 20 MHz system-clock cycles. Reservoir minimum includes normal tail drain and is not by itself an underrun indicator.

## Manual aspect and timing validation

The Aspect ratio menu offers only 4:3 and 16:9. The selected shape does not
follow MPEG sequence metadata. On a 1920x1080 output, expect 1440x1080 centered
for 4:3 and 1920x1080 for 16:9. Switch both ways during playback and confirm
OSD and filter controls remain responsive. Letterboxing already encoded in a
file remains part of the picture.

Run `python3 tools/verify_manual_aspect.py` for the actual core-to-platform
rectangle calculation, `python3 tools/verify_scaler_timing.py` with GHDL for
fraction/blanking equivalence against a0f153a, and
`python3 tools/verify_decoder_timing.py --output /tmp/decoder-timing` for the
mixed I/P/B pixel oracle. These simulations do not replace hardware testing
or fitted timing at every operating corner.

## Color matrix validation

Color matrix offers Auto, BT.601 and BT.709. Auto follows supported sequence
matrix metadata; missing, unspecified or unsupported values use BT.601.
Aspect ratio remains the separate manual 4:3/16:9 choice. Color changes apply
at a raster boundary, and automatic color context follows the displayed picture.

Generate clips with `python3 tools/make_color_matrix_tests.py --output /tmp/color-tests`.
Compare 01_color_601.m2v and 02_color_709.m2v with Auto: both should look nearly
the same. Force BT.601 on the 709 clip to expose the wrong-matrix color shift,
then force BT.709 to restore it. The 03_color_709_untagged.m2v clip requires a
manual BT.709 override. Watch the colored and skin-tone patches; the grayscale
steps should stay essentially unchanged. Keep the same aspect and filters,
check OSD responsiveness, and reload the 601 clip after restoring Auto.

Run `python3 tools/verify_color_matrix.py --output /tmp/color.json` for metadata,
frame ownership, frame-boundary CDC, colored stalled-DDR scanout and exhaustive
matrix arithmetic. Matrix selection adds no gamut or transfer-curve conversion.


## Manual 50 Hz progressive output

Generate checks with `python3 tools/make_refresh_tests.py --output results/refresh-tests`
and follow that directory's README. Use a timing-qualified refresh build; the
hardware-accepted `24d3de0` seed 52 is the recovery baseline. This new mode still
needs hardware acceptance.

**Refresh rate** defaults to **59.94 Hz**; choose **50 Hz** for progressive 25 fps
material. The setting is manual and does not inspect the file's frame rate.
It persists across file reload and the core's Reset command. It changes neither
playback speed nor audio sample rate. Use `[MediaPlayer] vsync_adjust=1` to let
HDMI follow the core refresh, and verify the display's reported signal rate.
The active core raster remains 720x480: at 27 MHz the totals are 858x525 for
59.94 Hz and 864x625 for exact 50 Hz. The latter is an internal scaler raster
with extended blanking, not 576-line playback or a claim of a standard direct
video mode. The configured HDMI resolution remains the scaler's responsibility.

During 25 fps MPG and M2V playback, switch 50/59.94 repeatedly and check continuous
file progression, unchanged audio pitch/speed, and no lasting A/V drift.
Brief display blanking during HDMI relock is possible. Verify even two-refresh
picture spacing at 25 fps/50 Hz, compare the 29.97 fps/59.94 Hz control, exercise
OSD/filter/aspect/color controls, file replacement, Reset and EOF. Record source
SHA, seed and observed display refresh. Simulation covers geometry, exact
cadence and queue ownership; it does not prove HDMI/display relock behavior.


## Compact telemetry profile

Default builds use schema 10: 25 words at overlay origin (8,280), 172x100 pixels.
The capture still appears at settled EOF, fatal error, terminal timeout or no
progress. It retains accepted bytes, elapsed/presentation cycles, picture counts,
source metadata, error flags, snapshot reason, maximum completed display gap,
outlier count, basic terminal state, audio frame/sample/status words and all
transport status fields. Picture counters still wrap at 256, so derived FPS is
not reliable for long clips; this change does not widen those counters.

Detailed stall/hold/DDR totals, two additional ranked gaps, gap context and full
scheduler state are omitted. Use the updated `tools/streams/decode_hardware_cadence.py`
for captures: absent diagnostics are `null`/unavailable, not measured zero.
Schemas 7, 8 and 9 remain readable. Compare retained EOF, error, audio and reader
results with the prior build; verify ordinary playback and 50/59.94 switching,
OSD/filter/aspect/color controls and repeated loads remain unchanged. No custom
Main or MiSTer.ini changes are needed.

For a dedicated diagnostic build, add
`set_global_assignment -name VERILOG_MACRO MMP_DETAILED_TELEMETRY` to its build
copy's QSF. This restores the 49-word schema-9 profiler and its higher resource
cost; qualify that build separately. The normal three-seed builds are compact.
Run `python3 tools/verify_compact_telemetry.py --output /tmp/compact-telemetry`
to compare retained fields against the detailed RTL and round-trip actual compact
overlay pixels through the screenshot decoder, including corruption rejection.
