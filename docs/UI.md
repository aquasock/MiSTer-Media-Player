# Transport UI overlay

The on-screen time/progress-bar overlay, composited on top of the scaled
video ahead of subtitles (see the visualizers document for where this sits
relative to `ascal` and the audio visualizer stage, and the subtitles
document for the format this shares its renderer with).

## Menu structure

The OSD is a flat list of top-level entries plus two conditionally-shown
submenus:

- **Load media** — mount a file (movie or music/album; see the FLAC and
  MPEG documents for what's accepted). Covered below.
- **Subtitles** submenu — load an `.srt`, toggle visibility, and set
  offset/speed. Covered in full in the subtitles document.
- **Visualizers** submenu (Type: Waveforms/FFT/O-Scope) — shown only during
  music playback, hidden entirely for movie playback since it has no effect
  there. See the visualizers document for what each mode does.
- **Aspect ratio**, **Refresh rate**, **Color matrix** — video-output
  settings, detailed in the MPEG document. Refresh rate and color matrix are
  the mirror image of the Visualizers submenu: hidden during music playback,
  shown only for movie playback, since both are meaningless without a
  decoded picture. Aspect ratio has no such restriction and stays visible in
  both modes, since it also affects how the visualizer viewport is framed.
- **Reset** / **Reset and close OSD** — two menu entries bound to the same
  underlying action; the second additionally closes the menu afterward.
  Covered below alongside Load media, since they trigger the same
  restart mechanism.

The music/movie-mode split for the Visualizers/Refresh-rate/Color-matrix
entries is driven by a single flag threaded into the menu system, the same
one that selects the music vs. movie audio decode path elsewhere in the
design (see the architecture document) — so "is a menu item visible" and
"is the decoder in music mode" are answering the same underlying question,
not two independently-maintained pieces of state.

## Loading and resetting

Both **Load media** (mounting a new file) and **Reset**/**Reset and close
OSD** funnel into the same restart signal, alongside the physical reset
button and a natural end-of-file close — there's no separate "reset" code
path distinct from "loading a file." The practical difference is just what
gets loaded afterward: mounting a file starts a session against that file;
Reset restarts a session against whatever's *currently* mounted, re-reading
it from the start. Either one increments the same session counter this
document's state bus carries (see "Where state comes from" above) and drains
outstanding readers/DDR clients through the session controller's generation
counter (see the architecture document) before the restart actually begins
— so a Reset during active seeking or playback is a clean stop-then-restart,
never a restart racing in-flight work from the previous session.

## Where state comes from

A single state module derives one coherent 91-bit state bus from playback
signals — elapsed/duration/target, paused/seeking flags, and a parallel
music-mode elapsed/duration/track-origin set for track-relative time. That
bus carries a 16-bit session counter (incremented on a new file or the start
of a seek) that later stages use as a tamper/staleness check — content built
against an old session number is never displayed as if it were current. This
state crosses from the control clock domain to the video clock domain
through one coherent multi-bit synchronizer, so the renderer always sees a
single consistent snapshot, never a torn mix of old and new fields.

## Visibility timing

The overlay isn't always on screen — it's shown for a bounded window and
then hides itself:

- **Manual activity** (pause toggled, a seek engaged, or the seek target
  moving) shows the overlay and resets its hide countdown to 3 seconds,
  every time it happens — holding a seek key down keeps extending the
  window rather than letting it expire mid-seek.
- **Loading a file**, or **a natural track change during music playback**,
  also shows the overlay, but for **6 seconds in music mode** (3 seconds
  elsewhere), split into two consecutive 3-second phases.
- Those two music-mode phases show *different* information: for the first
  3 seconds it shows **track**-relative elapsed/duration, then
  automatically switches to **album**-relative elapsed/duration for the
  remaining 3 seconds, then hides. A seek during music playback is handled
  differently from a natural track change — it always shows track-relative
  time for its own (separate) 3-second window, never the album view, since a
  seek isn't considered "arriving at a new track" for this purpose.
- A landed seek during an active album/track transition doesn't get
  double-counted as a second natural track change — that transition is
  explicitly suppressed until the track state actually confirms it settled.

## Scene assembly

A dedicated scene-assembler state machine, running in the video clock
domain but only advancing on every fourth pixel clock (a deliberate
multicycle timing budget — the rest of the render pipeline still runs at
full pixel rate), turns that state bus into up to 8 text regions and 4
rectangles:

- **Font scale** is chosen from output height: the largest of three integer
  glyph sizes at 1080p-class output, a middle size around 720p, the
  smallest below that — never a fractional/interpolated scale.
- **Time math** — HH:MM:SS for up to three fields (position, duration, and
  remaining time) — runs through one shared restoring integer divider,
  reused serially for every division the scene needs (percentage/pixel math
  included), rather than dedicated per-field arithmetic. All of the
  project's internal time values share one fixed-point tick unit (360,000
  units per second), so this is a single consistent conversion regardless of
  which timestamp is being formatted.
- **Progress bar fill** is a real proportional computation — current
  position multiplied by the bar's pixel width, divided by duration through
  that same shared divider — not a coarse or stepped indicator. Layout
  (bar position, track width, fill inset) is itself computed from the
  current output resolution every time a scene is built, not hardcoded to
  one resolution.
- **Subtitle content merges in as part of the same scene.** A separate
  subtitle bridge hands over subtitle text/geometry (see the subtitles
  document) through dedicated inputs on this same assembler, occupying the
  remaining two of the eight text slots plus their own background
  rectangles. The merge only proceeds once the subtitle side has finished
  writing and isn't mid-edit, and the whole assembled scene is only
  committed if *both* the playback state and the subtitle content are still
  exactly the snapshot the build started from — any change mid-build
  discards the in-progress scene and restarts from scratch rather than
  committing a torn combination of old and new content.

## Independent visibility groups

Every object (text or rectangle) carries a 1-bit group tag, and a commit
carries a 2-bit group-visibility mask alongside it — one bit for "UI
elements visible," one for "subtitle elements visible." This means the
transport UI and subtitles fade in/out **completely independently** within
the same rendered scene: the time/progress-bar overlay can finish its
3-second hide countdown and disappear while a subtitle stays on screen (or
the reverse) — they're not tied to the same visibility timer just because
they share a renderer.

## Rendering

The shared renderer (also used for subtitles) double-buffers a 12-object
scene (8 text + 4 rectangle slots, matching the assembler's output) and
only swaps to newly-committed content at a frame boundary, so nothing ever
changes mid-frame. Each pixel is resolved through a deep, fully-pipelined
per-pixel stage: parallel axis-range hit-testing against all 12 objects,
priority selection (first matching text region wins; a rectangle can be
flagged "hatched," alternating between two colors on odd/even pixel columns
rather than a single solid fill), a glyph coordinate/font ROM lookup
supporting the three integer scales, and a fixed-palette color resolve —
one color is alpha-blended (a translucent darkening of the video beneath it,
via precomputed blend ROMs rather than a runtime multiply) and the other
three are solid: opaque black text, a fixed gray, and a fixed near-white.
Every commit is additionally tagged with the same session-derived epoch
number used elsewhere in the system; a scene whose epoch doesn't match is
never displayed, which is what makes a seek or file change reliably clear
stale on-screen content instead of racing a late in-flight update.
