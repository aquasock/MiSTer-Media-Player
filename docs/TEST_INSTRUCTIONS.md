# Direct file seeking candidate

The next build adds timestamp-guided byte-position probing for both directions,
including unseen forward destinations. It retains the a229a01 bank-release fix.
The older RBF documented below does not contain this direct-seek path.

```sh
python3 tools/verify_direct_seek.py --output results/direct-seek-check --input path/to/bounded-prefix.mpg
python3 tools/verify_mp2_seek.py results/mp2-seek-history.json
```

The search uses at most 18 probes, each capped at 4 MiB of reader progress,
and prefers a timestamped I-picture within two seconds before the target.
These are implementation bounds, not MPEG requirements. If no usable point
is found, it reconstructs from the beginning. Original movie PTS origin is
retained across seeks. Raw M2V uses reconstruction fallback in both directions.
The first-fault stall observer monitors decoder reconstruction, excluding the
header-only probe phase.

Test 10-second, 30-second and five-minute jumps both ways in Pee Strike and
fellow.mpg, including a first-time jump far ahead and a backward jump late in
the movie. Allow approximate GOP landing initially. Repeat while paused, resume,
open the OSD during a search, and check audio synchronization. Test near zero,
past EOF, and after selecting a different file. Compare audio-bypass On and Off.
Leave a failed state loaded for telemetry; report the file and key combination.

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
remains available. The older a229a01 test RBF includes first-fault telemetry;
current source removes that additional overlay to recover placement capacity.

# Seek audio comparison and historical diagnostics

Current source retains the audio-bypass comparison and compact playback-health
telemetry. The additional persistent seek-fault observer, mailbox and renderer
are removed from production hardware. Playback and seek controls are unchanged.
Use the same file, refresh setting and seek key for both runs:

1. Set **Seek audio bypass** to **On**, reload `01 - Pee Strike.mpg`, and
   press Right once a few seconds into playback. Repeat with `fellow.mpg`.
2. If it freezes, leave the file loaded and record the file, playback position
   and key command. Current source does not generate the seek-fault block.
3. Set **Seek audio bypass** to **Off**, reload the same file and repeat.
   This disables only compressed MP2 frame bypass; file-position searching,
   PCM draining, target calculation and video reconstruction remain enabled.
   Set the option before reloading and do not change it during a seek.

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
restarts. Backward jumps clamp at zero; forward jumps beyond EOF finish on the
last available frame. Seeking while paused leaves the destination paused.
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
4. Seek backward near the start, forward near EOF, then backward after EOF.
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
