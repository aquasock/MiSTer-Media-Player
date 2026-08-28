# Original DVD stutter: reproduced in the video path

Both complete native simulations decode all **289 pictures**, but publish only
**278 unique pictures**: eleven are skipped and pictures 71 and 95 are each
published twice. The resulting **280 publications / 279 bank swaps** match the
hardware counter. These identity counts come from simulation; the hardware
barcode itself cannot identify individual pictures.

| Ranked selection gap | Hardware cycles | Simulation cycles | Picture ordinal |
| --- | ---: | ---: | ---: |
| 116.815 ms | 7,008,906 | 7,008,907 | 57 |
| 100.100 ms | 6,006,000 | 6,006,000 | 71 |
| 83.448 ms | 5,006,906 | 5,006,906 | 89 |

The one-cycle difference is 16.7 ns. Both the low-latency model and the model
with 16-cycle reads plus 16 busy cycles per 256-cycle period reproduce this
signature. No audio or host-delivery model is present.

## Confirmed failures

1. **Reference over-admission during B drain.** A following P payload is allowed
   to proceed while the sole pending reference slot is occupied. The full trace
   loses decoded references; the reduced `OVERLAP_REFERENCE_ADMISSION` test
   fails with `hold=0`, an occupied pending slot, and scratch-derived capacity.
2. **Early-header retirement race.** A B header arriving one clock before its
   I-reference completion can bind an older P. The metadata owner also changes
   picture type before retiring the I descriptor. `EARLY_B_REFERENCE` reproduces
   both failures: old bank 1 selected, actual reference bank 2, no bank-2 descriptor.

The full runs expose seventeen published I-pictures with stale TFF/RFF flags
and one lost first-picture PTS-valid flag. The 25 helper timestamps follow the
authored cadence within 2.5 ticks; they do not prescribe the long pauses.

## Checks retained

The complete paired numerical qualification passes all 149,817,600 samples per
run. Its isolated and real-reference CSVs match entry 665 byte for byte. Both
native runs also produce that same real-reference CSV: maximum difference 5,
102 samples above the old fixed-two bound, zero measured propagation-bound
violations. The compact reconstruction and default film tests pass. The two
new opt-in regression failures are intentional evidence, not passing tests.

Production RTL, Main, helper and timing constraints remain unchanged from
`6c1b621`. Native trace binaries were compiled at `e029f4f`; the numerical
controls ran at `94b60b2`; reduced tests ran at `5548e4e`; final analysis is
`c8bd628`. No Quartus build or MiSTer modification was made.

## Proposed next boundary

Correct reference admission and the completion/header handoff in the scheduler
and metadata owner. Require every picture to publish once in order with its
own field flags and PTS, correct film cadence, and unchanged pixel bounds.
Then perform a clean timing-audited build and retest original audio playback.
This production fix and FPGA build still require approval.
