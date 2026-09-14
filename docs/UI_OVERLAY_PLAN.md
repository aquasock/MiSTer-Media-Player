# Unified playback overlay

Design baseline: hardware-accepted `3ff27c8` seed 52. This document and the
[interactive preview](ui/overlay-preview.html) describe the proposed runtime
change. They do not add an overlay to the current RBF.

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
