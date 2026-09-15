# FLAC support

FLAC is the **music/album** playback path, entirely separate from movie
playback — movie audio is MP2, decoded from a demuxed Program Stream (module
`mp2_decoder`, covered in the MPEG document); FLAC is only used when a
standalone `.flac` file (or an embedded-cue album FLAC) is loaded directly,
selected via `media_music_mode`. The two never run concurrently. Everything
below is implemented natively — no software decode, no FFmpeg/reference-decoder
dependency at runtime (those are host-side test tools only, per the
architecture document).

## Accepted stream profile

The decoder is intentionally narrow, not a general FLAC decoder: it only
accepts **44.1 kHz, 16-bit, 2-channel (stereo)** FLAC, and checks this twice
— once from `STREAMINFO` (the stream decoder's `META_NEXT` state) and again
per-frame from the frame header (`FORMAT`/`RATE_CHECK` states). Any file
encoded at a different sample rate, bit depth, or channel count (including
mono) is rejected outright rather than resampled or downmixed. There is no
Ogg-FLAC container support — the decoder starts by matching the literal
`fLaC` magic and walks native metadata blocks directly; APEv2/ID3 tags
aren't parsed (irrelevant, since nothing outside the `fLaC` stream is read).

## Format coverage (RFC 9639)

Within that fixed profile, the actual FLAC syntax coverage is complete
against the spec's subframe/residual model, verified directly against the
subframe decoder and its shared prediction engine:

- **Subframe types**: CONSTANT, VERBATIM, FIXED (predictor orders 0–4, exact
  RFC 9639 coefficients), and LPC (orders 1–32, coefficient precision up to
  15 bits, arbitrary quantization shift). All four types share one serial
  MAC engine rather than separate FIXED/LPC datapaths.
- **Residual coding**: both 4-bit and 5-bit Rice partition orders, including
  the escape code (raw/unencoded residuals at an explicit bit width) in
  each.
- **Wasted bits-per-sample**: the unary-coded wasted-bits mechanism is
  implemented, not skipped.
- **Stereo decorrelation**: all four 2-channel modes — independent (code 1),
  left/side (8), right/side (9), and mid/side (10). Any other
  channel-assignment code is rejected at the frame header.
- **Block sizes**: every standard FLAC block-size encoding (fixed 192,
  576×2^n, 256×2^n, and both 8-bit/16-bit "read from footer" forms), subject
  to the file's `STREAMINFO` min/max block bounds and to matching the
  established fixed size once a stream commits to constant blocking.
- **Both CRC checks are enforced, not just logged**: CRC-8 over each frame
  header and CRC-16 over the whole frame must both pass before a frame is
  even offered to the frame store — a frame that fails either is never
  committed to playback.

Samples are provisional until the *outer* frame CRC passes — the subframe
decoder can emit samples mid-frame, but the frame store only exposes them as
PCM after a commit follows a clean frame CRC, so a corrupt frame never
reaches the audio output even partially.

## Frame storage and DDR sharing

The frame store holds two full decoded frames in external DDR (ping-pong
banked, so frame N+1 can decode while frame N drains to PCM), one 64-bit word
per coded stereo sample pair (two signed 17-bit coded channels in separate
32-bit lanes), reserving 131,072 words for music. It defaults to the exact
same DDR base address (`BASE=29'h06080000`) as the movie path's compressed
video ring — safe only because movie and music modes are mutually exclusive
per session, never concurrent. Stereo decorrelation happens on the *read*
side, converting stored coded channels back to left/right only as each
sample is handed off as a PCM token.

## Album / embedded-CUESHEET navigation

The album control module adds optional single-file CD-style navigation on
top of the plain decoder, for an album FLAC with an embedded `CUESHEET`
metadata block (availability requires exactly one well-formed `CUESHEET`
block, a non-empty audio track table, and a known total sample count):

- Parses the track index table directly from the CUESHEET block (up to 128
  tracks) and the optional `SEEKTABLE` block (up to 512 seek points) if
  present, both into on-chip RAM.
- Next/previous-track keyboard seeking walks the track table to find target
  boundaries; a direct time-based seek converts a requested elapsed time to
  a sample position (a fixed-point divider module) and then picks the best
  available seek-table entry at or before that sample, falling back to the
  stream start if no seek table exists.
- Reports current-track identity/bounds and a track-changed pulse
  independently of playback, by continuously scanning the track table
  against the live playback position — this is what drives the "track
  elapsed / track duration" UI distinct from whole-album elapsed/duration.
- A seek discards decoded output up to the target sample without ever
  putting that discarded audio on the audio clock (a dedicated landing
  module); a resume mechanism lets the stream decoder rejoin mid-file at a
  known frame number/position instead of re-parsing from the start.

A plain (non-album) `.flac` file plays back the same way, just without any of
the CUESHEET-driven track table — album availability simply stays false and
next/prev-track seeking has nothing to act on.

## What's explicitly rejected

- Anything not 44.1 kHz / 16-bit / stereo, including mono files.
- Ogg-FLAC (`OggS` framing) — the decoder never gets past magic detection.
- More than one `CUESHEET` block, or a malformed one (bad track/index
  ordering, non-audio-only leadout, overlapping track boundaries) — album
  navigation simply reports unavailable; this does not block plain playback
  of the same file's audio.
- A frame whose header or frame CRC doesn't check out — no partial/best-effort
  playback of a damaged frame.
- LPC precision code 15 (reserved/invalid per spec) and any FIXED order
  above 4 or LPC order above 32.
