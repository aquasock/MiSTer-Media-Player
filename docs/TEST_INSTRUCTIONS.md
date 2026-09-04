# Hardware playback test

Use a matched RBF, core-specific patched Main, ARM helper and visualizer pack.
Keep the official `/media/fat/MiSTer`, install the patched executable as
`/media/fat/MiSTer_MediaPlayer`, and merge the `[MediaPlayer]` section from
`assets/MiSTer_MediaPlayer.ini.fragment` at the end of `/media/fat/MiSTer.ini`.
Make both custom executables executable and reboot. For direct optical testing,
confirm the drive is present as readable `/dev/sr0`. Patched Main launches both
disc types directly from the `Load Physical Disc` submenu; no marker file or
filesystem mount is required.

Run normal playback first with `Telemetry` Off. Turn it On only for a fresh
diagnostic run; the next playback creates `/tmp/MediaPlayer_ARM.log`, and later
playback replaces it.

## Idle visualizer lifecycle

1. Load the MediaPlayer core without selecting media. With
   `MediaPlayer_Visualizer.mmpvis` installed, require the visualizer background
   to begin and continue at stable cadence without audible PCM.
2. Open the OSD and browse without selecting media. The background must remain
   active behind the OSD.
3. Start a Video DVD or MPEG-2 file. Require one clean decoder transition and
   normal video takeover with no visualizer frames mixed into playback.
4. Stop playback or let a finite source end. Require the idle background to
   return automatically. Repeat with an audio file and Audio CD; each must show
   the player overlay immediately, clear it after ten seconds, and continue the
   audio-reactive visualizer.
5. Temporarily omit the pack and reload the core. Main must attempt idle startup
   only once rather than repeatedly launching the helper; ordinary audio must
   still use its full-frame fallback interface.

## MPEG Program Stream

1. Open a recommended-recipe `.mpg` containing MPEG-2 I/P/B video and MP2
   audio. Require clean native 480p video, audible synchronized audio and
   responsive OSD access.
2. Use Alt+Left/Right, Ctrl+Left/Right and Ctrl+Alt+Left/Right. Require clean
   10-second, 1-minute and 5-minute jumps without old frames or audio crossing
   the restart.
3. Let the file end. The final frame may remain visible, but playback must be
   paused and replay-ready. Press Space or player-one Start and require the file
   to restart from the beginning.
4. Spot-check an existing `.mpeg`, `.vob` and raw `.m2v`. Fixed seeking and
   replay-ready EOF apply to Program Streams, not raw `.m2v`.

## Standalone audio

1. Play representative MP3, WAV, FLAC and Ogg Vorbis files. Require clean audio
   and a stable player interface with centered elapsed, total and remaining
   times plus a moving duration-relative progress bar.
2. With `MediaPlayer_Visualizer.mmpvis` installed, require the translucent
   interface over the moving visualizer for the first ten playback seconds.
   After ten seconds without input the overlay must clear and reveal the full
   visualizer. Its color/brightness should change smoothly with loudness.
3. Press Space to pause and resume, then exercise any fixed seek. User activity
   must restore the interface immediately and restart the ten-second interval;
   visualizer cadence must remain constant while playing and paused.
4. Let one track reach EOF. The last valid presentation may remain visible, but
   the player must enter its paused replay-ready state. Press Space or
   player-one Start and require a restart from the beginning.
5. Temporarily omit the visualizer pack and confirm audio still plays using the
   ordinary full-frame interface.

## Audio CD

1. Insert a standard Audio CD, choose `Load Physical Disc`, then `Audio CD`.
   Require the audio UI and clean 44.1 kHz stereo playback from the first audio
   track.
2. Test a mixed-mode disc where available. Data tracks must be skipped and must
   never be emitted as noise.
3. Press P/N or player-one Left/Right to move between audio tracks. Previous
   restarts the current track after three seconds or selects the preceding
   audio track near its start; Next selects the following audio track.
4. Exercise the fixed-time keyboard seeks, pause/resume and visualizer overlay.
   Require the same clean READY/GO reset behavior as file-backed audio.
5. Let the disc reach the end, press Play to restart it, and confirm that a DVD
   inserted afterward still opens through `Load Physical Disc` then `Video DVD`.

## DVD ISO and direct optical playback

Use multiple authored commercial DVDs where legally permitted, including discs
with scene-selection pages, finite or indefinite still menus, picture-bearing
menu transitions and different supported audio layouts.

For both one `.iso` selected through `Load Disc Image` then `Video DVD` and the
physical `Video DVD` menu action:

1. Start from a clean core launch and require first-play/title startup without
   a helper exit, decoder latch or indefinite black screen.
2. Press M or player-one Select to enter the root menu. Move in every direction,
   activate a normal button and exercise an authored automatic action.
3. Enter Scene Selection, change pages in both directions, launch a scene,
   return to the menu, resume the saved title position, reopen Scene Selection
   and change pages again.
4. During title playback, use P/N or player-one Left/Right for previous/next
   chapters, including several rapid changes. Require each hop to resume on a
   clean picture with working audio and controls.
5. Pause and resume with Space or player-one Start, then return to the root menu
   after several minutes of playback.
6. If a menu uses unsupported DVD LPCM, silence is expected there; navigation
   must remain responsive and supported title audio must begin afterward.
7. Repeat the navigation loop several times. A long optical read may delay a
   transition, but it must not deadlock Main/helper transport.

## Telemetry capture

After reproducing a failure, leave that state visible and collect all three
artifacts before starting another file:

```bash
tools/mister.sh log disc-name.log
tools/mister.sh screenshot disc-name.png
tools/mister.sh screenshot-stream 60 disc-name-frames
```

The stream command stores MiSTer's scaled 1440x1080 PNG output without resizing
or recompression. Press Ctrl+C to stop an unlimited stream started without a
duration. Also retain the decoded telemetry sidecar when the screenshot helper
produces one.

Record the exact source commit and installed SHA-256 values with every result.
The project owner completed this matrix on the accepted v0.9.0 runtime set.
Future changes to any runtime component require another relevant pass before a
new release package is accepted.
