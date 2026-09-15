# MiSTer-Phosphor architecture

This describes the design as it exists in the current source (validated against
the `68f32c7` seed61 build: 85% ALMs, 99% RAM blocks, 75 DSPs, all four STA
corners passing). It replaces an earlier version of this document that
described a pre-decoder-rewrite, MP2-only baseline; almost everything below is
new since then.

Several companion documents cover their subsystems in more depth than fits
here: MPEG (video decode), FLAC (music/album audio), subtitles, the
transport UI overlay, and audio visualizers, plus a separate document for
building the project in Quartus. This document is the map; those are the
detail.

## Top-level structure

The platform entity Quartus actually builds is `sys_top`
(`TOP_LEVEL_ENTITY sys_top`). It instantiates two project-specific blocks
plus the stock MiSTer scaler/OSD chain between them:

```
sys_top
 ├─ emu                       (this project's core: decode, demux, audio, session/seek)
 ├─ ascal                     (stock MiSTer HDMI scaler, unmodified boilerplate)
 ├─ media_audio_viewport      (bounds the visualizer region within the scaled frame)
 ├─ media_audio_visualizers   (Waveforms / FFT / O-Scope, PCM-driven)
 ├─ media_player_overlay      (subtitle/UI overlay compositor)
 └─ osd                       (stock MiSTer on-screen menu, drawn last)
```

`emu`'s body is assembled from nine topic-split source files joined by
`` `include `` concatenation (covering: ports, music, session, clocks,
container, decoder, prediction, framebuffer, output) — pure text
substitution with no synthesis effect. The project's build file list only
references the single top-level entry point, never the fragments
individually, so the split is invisible to Quartus.

`emu` exposes raw decoded video and player state to `sys_top` through a
`PLAYER_*` port group (`PLAYER_UI_CLOCK`, `PLAYER_UI_STATE`,
`PLAYER_SUBTITLE_COMMAND/ACK`, `PLAYER_VISUALIZER`, `PLAYER_MUSIC*`,
`PLAYER_PCM_*`). `sys_top` scales `emu`'s raw VGA output through `ascal`,
composites subtitles/UI on top via `media_player_overlay`, then hands off to
the stock `osd` module for the MiSTer menu overlay.

A stock `Template_MiSTer` boilerplate module (module name `media_player`, a
bare test-pattern generator) is left over from the original devkit import.
It is not instantiated anywhere in `sys_top` or `emu` — dead code, harmless
but unused, in the same category as other unused leftover files from that
same original devkit import.

## Container demux and audio duality

`mpeg2_program_stream_ingress` reads the accepted byte stream and splits it
into a video byte stream (with in-band PTS) and an audio byte stream. Audio
decoding forks on `media_music_mode`, set once per session and held until the
decoder/DDR clients have drained:

- **Movie audio** — `mp2_decoder` decodes MPEG-1 Layer II from the demuxed
  audio byte stream.
- **Music/album audio** — `flac_ddr_decoder` decodes FLAC directly from the
  *video*-labeled byte path when a bare `.flac`/album file is loaded (no
  container demux involved); `flac_album_control` drives cue-sheet track
  indexing and seek targeting for embedded-cue albums.

Both paths converge on the same downstream PCM plumbing (`media_music_time`,
`flac_pcm_landing` → `PLAYER_PCM_DATA/VALID/READY`), and both share the DDR
arbiter's `stream` client — never concurrently, since only one mode is active
per session.

## H.262 decode pipeline

The H.262 pipeline stages from the prior version of this document remain the
right mental model, now implemented as separate modules rather than one
monolith:

`mpeg2_h262_frontend` (sequence/picture header parsing) →
`mpeg2_h262_two_picture_probe` (per-macroblock slice/DCT syntax, drives IQ/IDCT) →
`mpeg2_h262_inverse_quant` → `mpeg2_h262_shared_idct` (one shared IDCT engine
serving I/P/B reconstruction — enforced by an audit in the project's timing
analysis tooling, not just convention) → `mpeg2_h262_intra_recon` →
`mpeg2_h262_ddram_store_420p` (writes reconstructed pixels).

P-picture prediction is a separate path: `mpeg2_h262_reference_read_probe`
reconstructs inter macroblocks from reference-frame DDR reads plus residual
samples, feeding the same DDR store client the intra path uses
(`p_store_select` muxes between them).

B-picture handling is the most involved piece: `mpeg2_h262_b_presentation_scheduler`
owns display-order reordering, decode/display scratch-bank allocation, and
the full B-picture presentation state machine, gated by a 2-vblank
publish/present handshake. A separate P-ownership state machine at the top
level (outside the scheduler module) prevents a following P picture's input
from overtaking a still-displayed reference bank — hand-rolled combinational
+ sequential logic, not part of the scheduler itself.

`mpeg2_h262_picture_timestamp` and `mpeg2_h262_pts_presentation_timeline`
bind PTS to picture banks and drive the 90 kHz presentation clock; picture
color matrix (BT.601/BT.709) is resolved per-frame in `mpeg2_h262_picture_color`
and applied in `media_color_control` ahead of the framebuffer.

## DDR arbitration

`mpeg2_h262_ddram_arbiter` has four clients: `writer` (picture reconstruction
store), `reader` (luma framebuffer scanout, bank-offset by
`mpeg2_new_display_frame_offset`), `prediction` (P/B reference reads), and
`stream` (compressed byte ring / FLAC PCM, muxed by `media_music_mode` before
reaching this arbiter). Its output feeds `emu`'s `DDRAM_*` ports, which
`sys_top` arbitrates again at the platform level against `ascal`'s framebuffer
and the HPS bridge — two arbitration layers, not one.

The compressed-video ingress ring still matches the original design: an
8 MiB ring at physical DDR `0x30400000`–`0x30bfffff` (`BASE=29'h06080000`,
`ADDRESS_BITS=20`, 64-bit words), sitting above the framebuffer regions at
`0x30000000`–`0x3027ffff`. Each word carries one compressed byte plus an
optional PTS tag and EOF flag.

## Session, seek, and subtitles

`media_session_control` drains readers/DDR clients through a generation
counter before honoring a restart; `media_file_reader` serves both normal
playback and `media_duration_probe`'s preflight duration scan from the same
SD/host arbiter (`media_sd_owner`). `media_seek_search` and
`media_seek_point` implement probe-based seeking against MPEG-2 sequence/GOP
boundaries; `media_keyboard_control` and `media_playback_control` own
pause/seek intent and elapsed-time tracking respectively, separately for
movie-elapsed and track-relative (music) time.

Subtitles (`media_subtitles`, `media_srt_parser`, `media_subtitle_select`,
`media_subtitle_time`) run independently of the decode pipeline, reading a
mounted `.srt` over the same SD arbiter, and merge into the same on-screen
scene the transport UI builds in `sys_top` — see the UI and subtitles
documents — rather than being mixed into the H.262 framebuffer.

## UI overlay

`media_ui_state` derives a single `PLAYER_UI_STATE` scene-state bus from
playback/seek/track state and duration validity, consumed in `sys_top` to
build the on-screen transport/track UI — merged with subtitle content into
one committed scene before rendering, not layered on top of it afterward.
See the UI document for the full assembly, visibility-timing, and rendering
mechanics.

## Audio visualizers

`media_audio_visualizers` (three modes: Waveforms, FFT, and O-Scope — the
last being the 256×256 phosphor-decay XY vectorscope) is instantiated
directly in `sys_top` (instance `visualizer`), not inside `emu` or
`media_player_overlay` — confirmed both from source and from Quartus's own
synthesized hierarchy report (`sys_top|media_audio_visualizers:visualizer|...`,
including its phosphor RAM and FFT twiddle/window ROMs as real `altsyncram`
instances). It sits between `ascal` and the overlay compositor in the video
chain. Note: the FFT mode's rendering module is still named
`media_fire_renderer` (instance `fire`), a leftover from before it was
renamed from "Fire" (a continuous flame gradient) to "FFT" (quantized
spectrum blocks) — see the visualizers document for the full per-mode
breakdown and that naming history.

```
ascal → media_audio_viewport → media_audio_visualizers → media_player_overlay → osd
```

`media_audio_viewport` first masks the visualizer to a bounded region of the
scaled frame (driven by the scaler's `hmin/hmax/vmin/vmax`, enabled by
`music_request`); `media_audio_visualizers` then selects a mode from `emu`'s
`PLAYER_VISUALIZER` (via `select_visualizer`) and renders from live PCM taps
(`sample_left/right`, `audio_active`, `sample_tick`) before its output
(`visual_rgb`/`hs`/`vs`/`de`) feeds `media_player_overlay` for subtitle/UI
compositing. This is live, working hardware, verified on the QMTech MiSTer
target — not just simulation-tested source.

## Build/device target

Cyclone V `5CSEBA6U23I7` (QMTech DE10-Nano-compatible MiSTer), Quartus Prime
17.0.2 Lite. Current validated full-core fit (seed61, `HIGH` ALM packing):
35,817/41,910 ALMs (85%), 546/553 M10K blocks (99%, the tightest margin in the
design), 75/112 DSPs (67%), 4/6 PLLs. All four STA corners (slow/fast ×
setup/hold/recovery/removal/MPW) pass, worst case +0.045 ns (hold, corner 3).
M10K usage (already including the visualizer stage's phosphor/FFT RAM) is the
binding constraint for any future feature that adds block RAM.
