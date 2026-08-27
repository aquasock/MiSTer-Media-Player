# DVD-ceiling timing investigation

Production remains `a4f2769`; diagnostic checkout `39f0875`. No MiSTer action or production change was made.

## Finding

The decoder's normal writer-capacity handoff adds **two clocks per block**, or **16,200 clocks / 0.27 ms per 720×480 picture**. With that cost included, this exact clip requires **33.529155 ms per picture on average**, against **33.366667 ms available**, even before physical memory delays. That is a sustained shortfall of about 0.49%; extra buffering alone cannot hide it indefinitely.

The actual production pipeline, writer and scheduler were exercised with always-available input and always-ready DDR:

| Diagnostic | Late intervals | Picture ordinals |
|---|---:|---|
| weave_ideal_ddr | 2 | 181, 348 |
| bob_ideal_ddr | 2 | 181, 348 |
| weave_direct_recon_ack | 0 | None |

All three runs complete 449 ordered picture identities, 448 swaps, 29,095,200 DDR words and 3,636,900 stored blocks without asserted errors. Pixel counts are checked; there is no new pixel-value oracle.

The direct-reconstruction-ack run changes only the testbench's parser-release connection. The writer still runs. **This is not a deployable patch:** it bypasses the capacity protection required when both capture banks are full.

## Hardware agreement

For the two saved Weave misses and Bob picture 167, the following sum exactly matches the measured previous-reference-to-candidate-ready interval:

`isolated decoder interval + 16,200 writer clocks + 37 next-header clocks + reported capacity-blocked clocks`

Bob picture 346 differs by 26 clocks (0.433 microseconds). The hardware counters have slightly different interval starting boundaries, so this is supporting cost accounting, not a reconstructed physical stall trace.

The ideal-memory misses occur at different ordinals from physical 167/346. The model omits real transport, queues, DDR arbitration/read contention, scaler and startup/video CDC; it uses raster phase and startup admission derived from saved hardware timestamps. It does not independently reproduce the physical startup or each hardware stall.

## Recommended next change

Retiming the writer's capacity grant is the smallest measured candidate. Remove both normal handoff clocks only when the alternate capture bank is free; preserve exactly one delayed grant under full-bank pressure. Preserve `block_stored`, all DDR payload/address/order behavior, ownership and reset/error protection.

Extend the existing writer-overlap regression to cover immediate/delayed grants, duplicates, premature grants, random backpressure, reset and all output bytes. Then qualify supported reconstruction and presentation/P/B clients, Quartus timing, the exact ceiling clip in both hardware modes, and a longer sustained run. Keep the clock, cadence, startup, queue sizes and transport guards unchanged.

The existing unmodified writer-overlap regression passes. No hardware fix or full DVD compatibility is claimed by this investigation.
