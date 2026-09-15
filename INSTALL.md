# Installing

This covers getting a built core onto real MiSTer hardware and playing
something with it. For building the core itself, see the build document —
this assumes you already have a finished `.rbf` in hand.

## Requirements

- A MiSTer system on the target hardware this core is built for (Cyclone V
  `5CSEBA6U23I7`, QMTech DE10-Nano-compatible), already running a normal
  MiSTer Linux setup on its SD card.
- The built core file (an `.rbf`, named after the core and a build date,
  following standard MiSTer core-naming convention).
- Media to play: an MPEG-2 Program Stream (`.mpg`) with MP2 audio, and/or a
  `.flac` file (standalone or an embedded-CUESHEET album), and optionally a
  matching `.srt` subtitle file for video.

## Installing the core

Copy the `.rbf` onto the MiSTer's SD card (or a USB drive MiSTer is
configured to read from) the same way you'd install any other MiSTer core —
at the SD card root, alongside `menu.rbf`. MiSTer's main menu will list it
by the core name embedded in the file once it's present; select it there to
load it, the same as any other core.

There's no separate installer step and nothing to configure before first
use — the core boots straight to its own menu with nothing mounted.

## Loading media

From the core's own menu (open it with the usual MiSTer OSD key), select
**Load media** and browse to a file. Accepted types are MPEG Program
Stream video and FLAC audio (standalone or album) — see the MPEG and FLAC
documents for exactly what's supported within each format. Mounting a file
starts playback of that file's own session; mounting a different file while
one is already loaded cleanly restarts into the new file rather than
requiring a manual stop first.

To load subtitles for a video file, open the **Subtitles** submenu and use
its own **Load** entry to select a matching `.srt`. Subtitles are loaded
independently of the video file itself, so you can load a video first and
attach (or swap) subtitles afterward, or vice versa.

## Adjusting playback

Everything else — subtitle visibility/offset/speed, aspect ratio, refresh
rate, color matrix, the audio visualizer mode, and what Reset actually
does — lives in the same OSD menu. The full menu structure, what each entry
does, and which entries are conditionally hidden depending on whether
you're playing a movie or music, is covered in the UI document.

## Updating

Replacing the core is the same as installing it: copy a newer `.rbf` over
the old one (or alongside it, if you want to keep both — MiSTer distinguishes
them by their embedded build date) and select it from the main menu again.

## Removing

Delete the `.rbf` from the SD card. Nothing else on the card is modified by
this core outside of whatever media files you chose to load.
