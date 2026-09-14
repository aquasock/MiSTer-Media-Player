# Production diagnostic removal plan

Status: gate two authorized and implemented for qualification; gate three remains pending. The user accepts b05b76f seed 87's EOF and
layout behavior. Preserve that RBF as the hardware rollback baseline:
37,410 placed ALMs, 527/553 M10Ks, 75/112 DSPs, setup +0.358 ns, hold +0.099 ns.
The later 6688db2 audio warning tolerance is simulation-tested only.

## Boundary

Remove diagnostic reporting and test hardware from the production core while
retaining everything needed to decode, synchronize, seek, drain, or reject bad
input safely. Keep simulation assertions, exact-file replay tools, pixel/PCM
oracles and archived Git source available for engineering. No new diagnostic
menu or alternate diagnostic RBF is needed. Do not delete modules by name:
several modules named `probe` and `diagnostic` contain production decoding.

## Three hardware acceptance gates

The user supersedes the original two-commit/one-build plan with three separate
build-and-test gates. Do not begin the next gate until they accept the current
candidate on Fellow, Groove, Jiggler and Star Wars. Run simulations and three
clean seeds at each gate, then provide the best timing-qualified RBF. Each
accepted gate becomes the next rollback baseline.

### Gate one: remove the telemetry screen and profiler

Remove the cadence profiler instance, frozen snapshots, trigger timers,
serializer, telemetry coordinates and RGB overlay. Route framebuffer RGB
directly to video outputs with unchanged sync/DE and no extra pipeline delay.
Remove the profiler from files.qip and its obsolete snapshot CDC constraints.
Keep the independent player/subtitle overlay. The user's accompanying UI
request makes Paused/Seeking opaque black glyphs with transparent gaps, at the
existing y=455 reference position, without the previous white text inset.

Preserve existing functional scheduler debug bits 26/0 used by seek/EOF.
Leave reporting-source RTL, the telemetry mailbox and Audio test for later
gates. Synthesis may naturally prune unobserved reporting hardware now; do not
add preservation attributes to force it to remain. The telemetry-only mailbox
may disappear entirely; if it remains, all six control synchronizer stages
must pass their existing checks. Every functional CDC remains mandatory.
Require zero cadence-profiler registers in the fitted timing netlist.

Hardware checks: no telemetry pattern at startup or EOF, clean picture/audio,
pause/seek/EOF/file replacement, subtitles and black status glyphs over empty,
filled and unknown progress at both output rates.

### Gate two: remove reporting sources and legacy diagnostic wiring

The gate-two implementation replaces consumed scheduler debug bits with named functional outputs before
removing debug buses. Preserve the exact pending-frame and reorder-active
logic. Trace consumers before removing counters, error details and warnings.
Remove the 256-bit reporting mailbox, minimum-reservoir tracking, historical
request/completion/max-wait statistics, audio sample-count crossing and
profiler-only seconds counter. Keep live timeout state, byte position,
generation, FIFO flow control, 90 kHz presentation ticks and PCM finished CDC.
Retire dead success/LED expressions; prune observation-only leaf ports while
retaining simulation visibility where useful. Keep fatal decode/transport
checks that gate reads or prevent malformed input being classified as clean
EOF. Do not delete production decoder modules named probe or diagnostic.
Update CDC counts/constraints only for endpoints actually removed.

The user also authorizes deleting the frozen `rtl/mpeg2fpga/` reference copy
in gate two. Check and remove unused legacy integration wrappers and update
references, preserving attribution required by any retained code. Git history
keeps the old implementation; this cleanup does not save FPGA resources.

Hardware checks: repeat all four files, including long/backward seeks,
replacement movies and clean EOF. Retain gate one's accepted RBF.

### Gate three: remove Audio test hardware

Remove its menu, tone source, test-only FIFOs/control mailboxes/output adapter
and output mux; connect movie PCM directly to the existing MiSTer audio ports.
Keep old status bits reserved so saved aspect/color/refresh/subtitle settings
are not renumbered. Verify old Audio test settings cannot override movie PCM.

Hardware checks: startup audio, continuity, pause/resume, seeking, filters and
longer audio tails, plus the common four-file playback checks. Retain gate
two's accepted RBF.

## Validation gates

Before a hardware build, require unchanged mixed I/P/B reconstruction pixels,
PCM sample sequence and cadence, actual-file openings, pause and all seek
sizes/directions, EOF drain/new-file races, duration and subtitle lifecycle,
and full-frame player overlay checks. Cover invalid input and host/DDR stalls
so removal does not bypass cancellation, quarantine, reset or ownership rules.
Use simulation-only observers for evidence; screen telemetry is no longer a
verification mechanism. Verify old Audio test status bits cannot override PCM.

Build clean seeds 52/61/87 at each gate after its tests pass. Audit all four timing
corners, remaining CDC stages and fitted resources. Confirm each gate's removal targets are absent from the hardware.
Report actual placed ALMs, estimated ALMs, M10Ks and DSPs separately against
b05b76f; report measured savings, not a promised percentage. Some dead source
logic is already optimized away, and placement varies between seeds.

Hardware acceptance: use Fellow, Groove, Jiggler and Star Wars; check startup,
OSD and filters, aspect/color/refresh, pause/short/long/reverse seeks, SRT load
and cue timing, replacement movies and clean EOF at 50/59.94 Hz. Verify no
telemetry pattern or test-tone menu remains and no audio/video/UI behavior has
changed. Preserve b05b76f seed 87 until this candidate is accepted.

Gate-two implementation disconnects reporting-only leaf outputs instead of
deleting their standalone simulation ports. The fitter audit requires zero
registers for the telemetry mailbox, reporting crossings, reader statistics,
PCM warnings/sample count, MP2 decoded-frame count and whole-second counter.
The functional PCM-finished crossing and 90 kHz tick remain connected. No
additional timing-fix batches are planned without user direction.

The old reporting bus also carried the reader-error bit used to terminate a
failed seek. Gate two replaces that payload with a dedicated one-bit
`reader_error_config` mailbox, retaining all six audited synchronizer stages.
The required CDC total stays 183 while the 256-bit statistics payload disappears.

Gate two is hardware accepted by the user. Gate three also includes the user's
compact UI request: black clocks on the bar, removal of Paused/Seeking glyph
selection and status payload bits, and bar/subtitles lowered one 14-pixel line.
Activity detection remains functional for bar visibility and seek preview.
Standalone Audio test modules remain available to offline tests but are excluded
from files.qip; fitted audits prove no test hardware remains in the core.
