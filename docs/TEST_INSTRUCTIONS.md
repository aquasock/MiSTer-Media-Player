# Hardware playback test

The stability target is straightforward: play the first 15 minutes of ordinary
DVD/VOB material from many discs. DVD menus, MiSTer menu integration and full
movie completion are outside this gate.

Before testing, build and install the current core:

```bash
tools/build.sh install
```

For each disc:

1. Start a movie file and let it play for 15 minutes.
2. Watch for corruption, stalls, audio loss, sync drift or a wedged core.
3. Record the filename and whether it passed.
4. Before starting another file, collect the helper log and a scaled screenshot:

```bash
tools/mister.sh log disc-name.log
tools/mister.sh screenshot disc-name.png
```

For periodic visual samples during playback, run:

```bash
tools/mister.sh screenshot-stream 900 disc-name-frames
```

The stream command stores MiSTer's native scaled 1440x1080 PNG output without
resizing or recompression. Press Ctrl+C to stop an unlimited capture started
without a duration.

The core is considered stable when failures require hunting for unusual discs,
rather than when only one known movie works.
