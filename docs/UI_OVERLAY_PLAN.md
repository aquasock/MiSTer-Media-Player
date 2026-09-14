# Unified playback overlay

Implementation baseline: hardware-accepted `3ff27c8` seed 52. The shared
renderer and duration preflight now implement this design in RTL; hardware
candidate `b00920a` seed 52 passes four-corner timing and resource qualification;
user hardware validation is pending. See `TEST_INSTRUCTIONS.md`. The [interactive preview](ui/overlay-preview.html)
remains a design aid; deterministic RTL renderings are produced by the tests.
The [font character sheet](ui/font-sheet.html) shows the actual ROM glyphs.

## Implemented interface and bounds

`media_ui_state` produces a coherent 91-bit presentation snapshot in the
20 MHz core system domain. `player_ui_config` transfers it to HDMI with the
existing coalescing request/acknowledge mailbox. `media_ui_scene` assembles an
inactive scene there, using a sequential divider (including decimal digit conversion) and one serialized multiplier for all
layout and progress arithmetic. Both advance only every fourth HDMI clock;
timing exceptions apply exclusively between registers sharing that enable.
Mailbox inputs, provider writes, pixel logic and compositor-facing outputs
retain single-cycle timing. A pending latch captures short publication acks. The compositor starts publication at the next VS
rising edge, copies twelve descriptors from staging RAM during blanking, then
acknowledges the complete scene. Incomplete copies never draw. Session/seek epochs reject stale scenes without blocking playback.
The actual pixel pipeline delays RGB, HS, VS and DE together by ten registers. Axis comparisons, qualification, priority selection and coordinate subtraction
have separate stages. Fixed-palette alpha blending also uses byte lookup RAM,
with red and green sharing a dual-read table.
Pixel glyph-coordinate conversion uses a small synchronous lookup ROM instead
of cascaded divisions. `tools/make_overlay_roms.py --check` verifies the glyph, coordinate and blend ROMs.

The scene holds eight text objects (64 eight-bit glyph IDs each) and four
rectangles. Slots 0–3 carry controls; slots 4–7 are reserved for a retained
auxiliary provider. Its text/object writes precede `aux_commit`; publication
waits for a complete provider transaction. Epoch mismatch suppresses an old
provider, and controls visibility never clears its retained content. Production
ties this interface inactive, so synthesis may remove unused provider storage.
Synthetic-provider tests exercise the interface without implementing subtitles.

The palette and 5×7 glyphs follow the historical reference. Font scale uses
quarter-pixel units (4, 6 and 9 at 480, 720 and 1080 lines), equally on both
axes; object positions follow active-output proportions. Other output heights
use the nearest lower supported scale tier. The unknown-duration hatch selects
the dark alpha palette over the video in the one composition pass.

Duration preflight reads at most 64 KiB from the head and 4 MiB from the tail.
It first finds a pack prefix and then reuses a separate, strictly checked
instance of the existing PES parser; it does not duplicate the reader RAM.
The first validated head video PTS is the movie origin; malformed head
evidence and a different selected video-stream ID in the tail are rejected. The tail requires sequence/rate
metadata, timestamped pictures, slice evidence and a complete packet boundary.
The sparse-timestamp correction reconstructs picture presentation times from
PTS anchors, temporal references and the supported progressive frame period.
Reference pictures unwrap the modulo-1024 temporal reference; B-pictures use
their position before the following reference. A late B-picture anchor can
therefore establish the endpoint of an earlier-coded future reference. Group
boundaries carry the previous group's endpoint into the next group, including
when that group has no new PTS. A serialized multiplier performs both picture
and maximum-group offsets without adding DSPs. Up to one 90 kHz tick of anchor
quantization is accepted; conflicting anchors make the duration unknown.

This follows the temporal-reference semantics in the project's controlled
[H.262 (02/2000), clause 6.3.9](https://www.itu.int/rec/T-REC-H.262-200002-S/en).
It remains header-based qualification of the video endpoint, not full decoding
or proof of arbitrary concatenated-file continuity. Unanchored windows, mixed
frame rates, repeat-field/extended-rate cases, ambiguous half-wrap timestamp
spans, invalid picture order, malformed headers and insufficient final slice
or packet evidence remain unknown. The temporal-index implementation is bounded
to 20 bits per group inside the fixed-size probe window. No whole-file scan or
file-size duration estimate is used. A presented position beyond the qualified
endpoint still invalidates it.
The 25-second preflight watchdog stops work; an outstanding storage request
still has to retire before playback can safely take ownership.

The current reader's existing 2 TiB implementation limit remains unchanged.
The probe cache survives ordinary seeks, and a new mount/reload invalidates it.
Normal codec delivery remains blocked by the session gate throughout preflight.
No extra seek probe or duration byte-ratio estimate is introduced.

Regression commands:

```sh
python3 tools/verify_ui_duration.py --media path/to/a/complete/test.mpg
python3 tools/verify_player_overlay.py
python3 tools/make_overlay_roms.py --check
python3 tools/verify_overlay_timing.py --output results/ui-overlay/pixel-timing
python3 tools/verify_media_file_reader.py
python3 tools/verify_decoder_timing.py --playback-controls --display-ownership --output results/ui-overlay/reconstruction
```

`verify_ui_duration.py` checks synthetic endpoint cases and actual shared-reader
retirement, including offsets above 4 GiB. The optional complete MPEG check
decodes only the bounded tail with ffprobe and compares reconstructed display
timestamps plus the exact frame period. Repeat `--media` to check multiple files.
`verify_player_overlay.py` checks every pixel at three HDMI sizes, time fields,
unknown/hidden states, pause/seek, progress endpoints, timing alignment and
retained-provider/epoch behavior. The isolated compositor fit checks internal
register paths at 148.5 MHz; its virtual I/O exceptions are confined to that
test and do not apply to full-core qualification. The synthesis CDC audit now expects 159
preserved synchronizer registers, including the new six-stage mailbox.


## Scope

Combine playback position/duration, brief pause/seek feedback and the future
subtitle renderer into one player overlay. Implement the progress bar and
three time fields first. Provide shared drawing, publication and lifetime
interfaces for subtitles; do not implement subtitle loading, parsing, cue
selection, file formats or a subtitle menu in this boundary.

Keep stock Main, progressive decoding, the existing play/pause and seek keys,
and the existing output modes. This work must not change HDMI timing or add
refresh modes. Future output-mode work must use standard HDMI timings and
frequencies, including blanking, sync and pixel clock.

## Visual reference recovered from history

Reference commit: `af7f570`, `host/arm/audio_ui.c:draw_progress_strip()` and
`host/arm/media_player_helper.c:video_overlay_descriptor()`. `08db78e` introduced
this strip over video using the older DVD overlay transport.

The reference canvas is 720×480:

| Element | Reference geometry / appearance |
|---|---|
| Elapsed field | `Elapsed: HH:MM:SS`, centered in x=32…249, y=422 |
| Total field | `Total: HH:MM:SS`, centered in x=250…469, y=422 |
| Remaining field | `Remaining: HH:MM:SS`, centered in x=470…687, y=422 |
| Track | x=32, y=438, width=656, height=14 |
| Fill | x=34, y=441, maximum width=652, height=8 |
| Glyph style | 5×7 pixel glyphs, six-pixel character advance |

Use the actual video-overlay palette: transparent; dark `#181b20` with alpha
160/255; muted blue-gray `#687d89`; pale `#eef2f4`. The progress track uses
blue-gray and its fill and text use pale white. The blue-green YCbCr fill
constants in the standalone audio UI are not the final video-overlay colors:
the old packing stage replaced them with palette entries.

Preserve this layout, relative margins, colors and pixel-font character.
Make the mixed-case labels readable: the recovered font table lacks lowercase
glyphs even though the later label strings contain lowercase. Do not reproduce
missing letters. The preview adds the needed lowercase glyphs.

Anchor positions to the active HDMI output rectangle. Scale glyphs uniformly
with output height, and position the three fields proportionally across the
output width. Changing the movie's 4:3/16:9 aspect must not stretch the glyphs
or move the overlay. Reserve a lower-screen text region above the controls for
future subtitles; the preview's dotted guide is not a rendered subtitle.

## Composition point

```text
decoded picture → existing scaler / video filters / shadow mask
                → shared player overlay → existing MiSTer menu → HDMI
```

In `sys/sys_top.v`, insert the compositor between `HDMI_shadowmask` outputs
(`hdmi_data_mask`, HS, VS and DE) and the `hdmi_osd` inputs. Work in RGB in the
HDMI clock domain. This keeps UI text independent of movie aspect selection,
color conversion, scaler filters and shadow-mask settings. The MiSTer menu
retains priority and its existing input handling.

This boundary targets normal scaled HDMI output. Direct-video / analog paths
must remain functional but are not silently claimed to have the same overlay.
The compositor must delay RGB, DE, HS and VS together by its fixed pipeline
latency. It must never modify active dimensions, porches, sync widths, clock
selection or refresh frequency. During video seek blanking the player overlay
can continue rendering over the existing black picture.

## One rendering interface, separate content lifetimes

Use a small text-and-rectangle scene rather than a decoded-video framebuffer
or another full-resolution RGBA framebuffer. A full 720×480 two-bit plane is
86,400 bytes; even one exceeds the 56.25 KiB of currently free M10K capacity.
The old full-plane DDR upload, DVD record channel and even/odd line caches are
not part of this implementation.

Proposed modules and responsibilities:

| Module | Responsibility |
|---|---|
| `media_duration_probe` | Bounded file-read transaction and validated duration result |
| `media_ui_state` | Position, validity, activity, pause/seek and hide timer |
| `media_ui_scene` | Format fields and assemble the complete scene from content providers |
| `media_overlay_store` | Small text/glyph memories, staging state and atomic publication |
| `media_overlay_compositor` | Shared glyph/rectangle lookup and RGB composition |

Text objects carry position, glyph IDs, size, palette selection and group ID.
Rectangle objects carry bounds, palette selection and group ID. The compositor
does not know whether a text object is a clock, status label or future subtitle.
Represent text using glyph IDs, rather than tying the compositor to an SRT
parser or assuming that subtitle character encoding is ASCII.

Start with bounded object counts, such as eight text objects and four
rectangles, sufficient for the three fields, status and future basic subtitle
lines. Final capacities and memory organization require synthesis. Use
synchronous block memory for text/glyph storage and pipeline pixel lookup;
avoid replicated large register muxes or arithmetic division on the pixel path.
Calculate formatted time and progress width in the slower control domain.

Scene transaction contract:

1. Begin a staging scene with a file-session ID and scene generation.
2. Write bounded text/rectangle objects and their text data to inactive storage.
3. Commit the completed scene through a request/acknowledge handshake.
4. Publish only at a video-frame boundary; active storage remains immutable.
5. Acknowledge ownership release before the producer reuses storage.

Carry metadata as one coherent snapshot. Synchronizing individual bits of a
time value or sharing a mutable text buffer across clocks is insufficient.
Video timing and playback must never wait for a scene update. Coalesce repeated
UI refresh requests, reject invalid staging transactions and retain the last
complete scene. A file change clears the old scene using its session ID.

The playback-controls group and future subtitle group have independent
visibility. Hiding the progress strip must not clear subtitles. A future cue
producer supplies its objects to the same scene assembler; it does not gain a
second pixel compositor, separate overlay plane or private display-bank owner.
The assembler regenerates a complete scene from retained provider state so one
provider cannot erase the other during an update.

Future subtitle timing follows the movie presentation timeline. Pausing keeps
the current cue. Seeking invalidates the old cue and requires selection at the
actual landing position. The controls' hide timer is unrelated to cue timing.
Providing these contracts does not solve subtitle-file access through stock
Main; that transport and format decision remains future work.

## Duration: probe timestamps, never infer from file size

The user selected a bounded timestamp probe and unknown values when unavailable.
The old byte-position/file-size duration estimate must not return.

Perform a preflight probe on a new file before enabling normal reader delivery
to the decoder. Reuse the mounted-file reader and staging RAM with an explicit
single-owner request multiplexer; do not instantiate another full response
buffer merely for this UI. During the probe, codec FIFOs stay reset and probe
bytes cannot enter them.

Start with a bounded head window (64 KiB) and tail window (up to 4 MiB), clamped
to file size. Resynchronize and validate program-stream packet headers; examine
video timestamps and enough video-header metadata to qualify the endpoint.
Retain the largest valid presentation timestamp in the tail, because decode
order can differ from presentation order. Relate duration to the same movie
origin used by playback, and include the final picture's display duration when
it can be established. A bare last-PES timestamp is not automatically a proven
end time when subsequent pictures lack timestamps.

Expose `duration_valid` separately from the duration value. Unsupported raw
streams, insufficient endpoint metadata, malformed headers, inconsistent
timeline evidence or exhausted probe limits produce unknown duration. Support
the current continuous-timeline MPG scope; do not infer reliable duration for
arbitrary concatenated timelines from two endpoint windows. Invalidate a
previous result if playback later establishes a timeline discontinuity.

Use 64-bit byte offsets and overflow-safe window arithmetic, including files
larger than 4 GiB. Normalize 33-bit PTS values consistently and reject ambiguous
wrap/discontinuity cases. Cache the result per mounted file, retaining it across
ordinary seeks and pause, and invalidate it on a new file or explicit reload.

Bound bytes, requests and wall time. On cancellation/error, stop issuing
requests and drain any accepted response before restoring playback-reader
ownership. A late response must never be interpreted as bytes from a different
file or transaction. A nonresponsive outstanding storage request cannot be
reassigned merely because a UI timeout expires; retain the existing reader's
safe retirement behavior.

## Display behavior

- Elapsed follows the existing presented playback position, not the file-reader
  byte offset or decoder look-ahead. Freeze it during pause.
- During seeking, keep a coherent seek preview/target with a brief `Seeking`
  label; after completion replace it with the actual landing position.
- Derive remaining as `max(total − position, 0)`. Use the reference's floor for
  elapsed seconds and ceiling for total/remaining seconds.
- Unknown total and remaining display `--:--:--`. Use a patterned track without
  a percentage fill so unknown duration does not resemble zero progress.
- Show controls on first playback, play/pause and seek activity. Keep them
  visible while a seek is pending, then restart a ten-second hide interval on
  landing. Use a wall-clock counter for hiding, including while paused.
- Preserve Space and all existing arrow/modifier bindings. Menu navigation must
  not trigger playback actions. Add no new keyboard binding in this boundary.
- Keep menu priority. UI visibility or publication must not enter the pause
  handshake, decoder reset, audio path, display-bank protection or seek logic.

## Resource and verification boundary

Baseline: 35,774 actual placed ALMs and 508/553 M10Ks. Free capacity is 6,136
ALMs and 45 M10Ks. Set an initial design budget of at most 2,000 additional
actual placed ALMs and 12 M10Ks for the first UI/probe implementation. This is
a budget, not a savings prediction or a measured fit. Reserve subtitle object
interfaces now; do not preallocate a full subtitle cue database or bitmap plane.

Before a source build:

- Render deterministic reference images with known/unknown durations, all three
  fields and progress endpoints; compare pixel positions, palette and text.
- Exercise scaled 480p/720p/1080p timing, 4:3 and 16:9 picture changes, hidden UI
  passthrough, and identical HS/VS/DE delay. Confirm filters affect video only.
- Test asynchronous scene publication during active video, reset/cancellation,
  rapid seeks and file changes. Reject stale generations and partial scenes.
- Test independent group visibility with synthetic text objects only; do not
  introduce a subtitle loader or claim actual subtitle support.
- Test duration probes with VBR files, B-frame reordering, missing/truncated
  timestamps, no duration, file sizes above 4 GiB, PTS wrap, bounded read failure,
  late acknowledgement and a new mount during the probe.
- Require current decoder/pixel and exact-file seek regressions to remain clean.

Commit and push the tested implementation before the standard three-seed build.
Audit updated CDC endpoints and every timing corner; compare actual placed ALMs
separately from Quartus's estimate. Package the preferred passing RBF for testing
against accepted `3ff27c8` seed 52. No subtitle or new HDMI-mode implementation
belongs in that build.

## Current compact clock layout

The next revision retains the three horizontal field centers and displays only
`HH:MM:SS` (or unknown `--:--:--`), without Elapsed/Total/Remaining prefixes.
On the 720x480 reference canvas, clocks move from y=422 to y=436, the track
from [438,452) to [452,466), and its fill from [441,449) to [455,463).
The 14-pixel displacement is one outer bar height and scales with HDMI height.
The separate Paused/Seeking status stays at y=403. This supersedes the labeled
clock geometry above; the retained future subtitle provider is unchanged.

## Player feature scope update

Audio-track selection is excluded by user decision. Do not add a soundtrack
selector or reserve implementation resources for track switching. The original
feature list now comprises playback position/total duration, brief pause/seek
feedback, resume from last position, predictable EOF behavior, clear playback
errors and subtitle support. The first two are implemented; subtitle playback
remains deferred, with only its shared overlay framework in place.

## Current next-release target

The current scope is predictable end-of-file behavior and manually loaded SRT
subtitles. Resume from the last position has been dropped. Opening another
movie forgets the previous session, and a completed movie returns to startup.

Keep stock Main. Manual SRT loading replaces automatic filename discovery;
playlists, N/P playlist navigation and audio-track selection remain excluded.
The ec56250 subtitle implementation is hardware accepted. The b5a17cf layout
revision passes all three seeds; its hardware confirmation remains pending.

EOF closure uses physical input EOF and decoder/presentation/audio drain,
followed by one source-frame interval. A reset-generation-tagged mailbox
requests the existing safe file-change reset. Logical file size, subtitle
association, duration, controls and playback message suppression are cleared.
The mounted file may remain named in Main, but the core issues no replay reads
and waits for a fresh file selection. Pause and seeking inhibit closure;
malformed or fatal streams retain the existing diagnostic behavior. Duration
estimates, including unknown duration, do not control completion.

## Manual SRT implementation boundary

Feature three is now authorized and implemented for qualification. See
[SUBTITLES.md](SUBTITLES.md) for the streaming second-slot loader, parser limits,
cue lifecycle, atomic shared-overlay transfer and verification. This supersedes
older notes deferring all subtitle loading. The user's accompanying layout
change moves Paused/Seeking down one line to y=417 at 480p, with the bottom
subtitle line at y=403 and an additional line at y=389. Bar/clocks stay put.

## Post-acceptance layout revision

The user accepts the ec56250 subtitle build and requests clocks below the bar,
Paused/Seeking on the bar, and subtitles two lines lower. The new 480p reference
layout is clocks y=469, status y=455, subtitle lines y=417/431 and the unchanged
track [452,466). These positions supersede earlier layouts in this document.
Status uses opaque dark text on a light inset so it remains readable over any
progress fill. Subtitle backdrops retain their alpha blend.
