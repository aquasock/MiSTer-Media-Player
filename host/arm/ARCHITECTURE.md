# ARM Media Helper Architecture

The helper is the source, container and codec boundary for MediaPlayer. MiSTer
Main remains a transport broker and the FPGA remains responsible for H.262
decode, presentation timing and final audio/video output.

## Stable launch contract

Protocol version one uses:

```text
MediaPlayer_Helper --protocol 1 --source file:/absolute/path/movie.mpg
```

`--capabilities` prints the implemented and reserved source types. Bare paths
remain accepted for transition and local verification, but Main uses the
versioned form.

The helper writes only annotated H.262 bytes to standard output. Diagnostics go
to standard error. Decoded signed 16-bit stereo PCM goes to the installed ALSA
path through `aplay`; Main never handles PCM and the helper never owns FPGA SPI.
Main's isolated broker exposes a source-string launch function; its current
file-selector wrapper constructs `file:` while a later disc-menu action can pass
`dvd:` without changing process, pipe or FPGA-transfer ownership.

## Source boundary

`media_source` is a pull interface with read, character-read, rewind, error and
close operations. The current backend implements `file:`. `dvd:` is recognized
as a reserved source and deliberately returns unsupported without opening,
mounting or reading the device.

A future DVD backend may turn title and program-chain navigation into a logical
byte stream without changing Program Stream parsing. It will own optical-device
discovery, ISO9660/UDF access, VIDEO_TS and IFO interpretation, VOB program-chain
assembly and any CSS policy. Those responsibilities do not belong in Main or
the FPGA.

## Pipeline boundaries

The current implementation contains these logical stages even where they still
share a compilation unit:

1. Source: `file:` now; `dvd:` and `iso:` later.
2. Container: raw M2V pass-through or MPEG Program Stream/PES demultiplexing.
3. Timeline: PTS extraction and FPGA in-band timestamp records, with future
   discontinuity events for title, cell and seek transitions.
4. Audio codec: MPEG Layer II now; AC-3 and DVD LPCM later behind codec
   selection rather than source-specific decode paths.
5. Outputs: annotated H.262 to Main and 48 kHz signed stereo PCM to ALSA.

Future play, pause, seek, title, chapter, angle, audio-track and subtitle-track
commands require a versioned control channel. They are intentionally not
implemented in protocol one; adding that channel must not change the source,
container, codec or output ownership above.

## Deferred DVD scope

Recognizing `dvd:` in protocol one is an architectural reservation, not DVD
support. Mounting the connected disc, navigating titles, handling encryption,
decoding AC-3 or LPCM, rendering subpictures and supporting interlaced content
remain separate approved development phases after embedded file audio works.
