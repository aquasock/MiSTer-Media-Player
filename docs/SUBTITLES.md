# Manual SRT subtitles

Open the movie first, then use **Load subtitles** to select its separate SRT.
The filenames need not match. **Subtitles: On/Off** hides or restores the loaded
track. Loading a different movie or resetting clears the association; select
its SRT again. There is no automatic discovery, playlist loader or custom Main.

Subtitles appear one text line above Paused/Seeking and remain visible when
playback controls hide. Pausing retains the current cue. Seeking hides it and
rescans the SRT from its beginning after landing; larger SRT files can therefore
have a brief subtitle recovery delay. Movie playback does not wait for the
subtitle scan. Cue intervals include their start and exclude their end.

## Initial format coverage and limits

- Normal `HH:MM:SS,mmm --> HH:MM:SS,mmm` timing lines, CRLF or LF endings,
  numeric cue labels and an optional UTF-8 BOM on the first numeric label.
- The last text line/cue can end at EOF without a trailing blank line.
- Printable ASCII, including all lowercase letters and punctuation. UTF-8
  characters outside that set display `?` once per codepoint; this is not full
  Unicode font support. Tabs become spaces. Use UTF-8 or ASCII, not UTF-16.
- Two text lines, at most 63 displayed characters per line. Additional lines
  and characters are discarded. Long lines are not automatically word-wrapped.
  Angle-bracket tags are removed; italic/bold/color styling is not rendered.
- A 256-byte input-line buffer; oversized timing lines are rejected. Ordinary
  cue bodies are streamed with bounded storage. Malformed headers are skipped.
- Cues should be in chronological order and nonoverlapping. One cue is retained
  at a time; overlapping or out-of-order cues are not combined.
- Text and a small translucent dark backdrop use the existing scaled-HDMI
  compositor. Analog/direct-video subtitle output is not added.

These are implementation limits, not limits of the SRT format. Predictable
movie EOF/idle behavior and session resume remain separate release tasks.

## Implementation and verification

`S1` is a second stock Main mounted-file slot. A serialized request owner tags
all response writes, including the delayed final words, before routing them to
the movie or subtitle reader. Movie slot `S0` remains its existing byte stream. New subtitle reads wait
during duration probing/seeking or when the active movie reader has less than
8 KiB buffered, giving movie delivery priority.
Subtitle storage is a 4-KiB reader staging buffer, a 256-byte line buffer and a
128-byte cue buffer; actual physical RAM and logic are established by fitting.
No whole-file cue database is allocated. Seeking cancels and drains outstanding
subtitle reads before restarting. A new movie also invalidates association.

The system-clock parser/publisher sends acknowledged text/commit commands
through two audited configuration mailboxes. The HDMI provider commits complete
text with the current player epoch. Scene assembly and frame publication keep
text changes atomic; old seek/file epochs cannot become visible. Subtitle and
controls visibility groups are independent.

On the 480p reference layout, Paused/Seeking is now y=417. The subtitle bottom
line is y=403; a two-line cue begins at y=389. Clock fields remain y=436 and the
progress track remains [452,466). Coordinates scale with the HDMI output.
The font has 94 visible printable ASCII glyphs plus space in its existing ROM.

Run `python3 tools/verify_subtitles.py`. It checks parser bounds and syntax,
actual hps_io two-drive isolation, cue timing and cancellation through unrelated
clocks, existing overlay regressions and full subtitle pixel comparisons at
480p, 720p and 1080p, including controls hidden and stale epochs.

Generate test subtitles with `python3 tools/make_subtitle_test.py`; load the
result beside any movie. Each five-second interval has four seconds of text
and one second without text. Test pause, all seek sizes/directions, Off/On,
OSD/filter access, replacement SRTs and movie changes. The generator refuses to
overwrite an existing file. FPGA timing/resource qualification and user hardware
acceptance must be recorded separately from simulation results.
