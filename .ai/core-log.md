## 59 COMMIT Unreleased ??? 2026-09-14T04:48:02-07:00

#### Coming From:

Unreleased dc1dfc2

#### Purpose:

Move IDCT intermediate storage into banked M10K memory while preserving transform arithmetic and cycle behavior.

#### Outcome:

The user approved the first proposed IDCT storage optimization. Start with the intermediate arrays only in all three IDCT instances, budgeting eight 8-by-24 banks per instance and 24 additional M10Ks overall. Keep coefficients and all arithmetic unchanged. Prefetch the next column synchronously, including the pass transition, so the existing multiplier issue and sample cycles remain unchanged. Do not reset the RAM contents; every complete first pass overwrites all entries before consumption, and reset cancels the transform. No RTL change or build has yet been performed.

#### Next Steps:

Implement banked intermediate storage and differential tests against dc1dfc2 covering sparse and dense blocks, signed extremes, repeated blocks and reset interruption. Require identical output values and cycles, run the mixed-picture pixel oracle with paused seeks and display ownership plus exact-file A/V replay, commit and push tested source, then compile seeds 52, 61 and 87. Confirm M10K inference, actual placed ALMs and all timing corners before packaging the best candidate for hardware acceptance.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv
- tools/test_idct_storage.sv
- tools/verify_idct_storage.py
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 58 COMMIT Unreleased dc1dfc2 2026-09-14T04:41:39-07:00

#### Coming From:

Unreleased dc1dfc2

#### Purpose:

Record hardware acceptance and investigate optimization techniques in the original upstream decoder.

#### Outcome:

The user reports everything works perfectly like before with the delivered dc1dfc2 seed 52 row-buffer candidate. Passed records that reported playback acceptance; detailed file/key/EOF coverage was not enumerated. Its build-info now records hardware acceptance. The user requested comparison with mrchrisster/MiSTer_MPEG2; upstream main was pinned to 11d1aa2d11649d0c4048d1b33fb1d2abc84771ef and inspected from a read-only clone. Active local files.qip selects mpeg2_new, while upstream idct.v is byte-identical to the dormant local mpeg2fpga IDCT. Useful adaptation candidates are upstream's RAM-backed transpose storage and shared streamed transform pipeline. Current three active IDCT instances total 4196 combinational ALUTs, 7971 registers and 24 DSP blocks with no block memory; this is total module cost, not forecast savings. Their eight parallel reads mean RAM banking or prefetch needs design work, and upstream's two-RAM count cannot be copied as a local budget. The current intra inverse quantizer also holds qfs/reconstructed arrays in registers and totals 1073 combinational ALUTs, 1776 registers and six DSP blocks; a RAM-backed or streamed adaptation is another candidate. A shared IDCT would require overlap/throughput and seek-ownership proof. Upstream VLC tables are combinational too, so no ready-made ROM saving was found. Different transform widths, rounding and output clipping prevent claiming a drop-in replacement; current audio, PTS and seek behavior must remain. Findings and source references are saved in results/upstream-optimization-audit/findings.md. No source optimization, build or deployment was performed.

#### Next Steps:

Present the bounded opportunities and select an approved optimization boundary before implementation. Prefer retaining current transform arithmetic while redesigning storage, or first converting the simpler inverse-quantizer buffers; require numerical equivalence, pixel-oracle and seek recovery tests, then measured RAM/ALM and timing qualification. Retain accepted dc1dfc2 seed 52 as baseline.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 57 COMMIT Unreleased dc1dfc2 2026-09-14T04:33:57-07:00

#### Coming From:

Unreleased dc1dfc2

#### Purpose:

Qualify the row-buffer RAM builds and deliver the preferred seed 52 candidate.

#### Outcome:

All three clean dc1dfc2 seeds pass all four timing corners and the 153-register CDC audit, with both 512-by-8 row arrays confirmed as M10K in each synthesis report. Seeds 52, 61 and 87 have minimum setup +0.437, +0.322 and +0.303 ns and hold +0.089, +0.086 and +0.091 ns respectively; recovery, removal and pulse width also pass. Their actual placed ALMs are 37790, 37813 and 37878, while ALMs-needed estimates are 31925, 31938 and 31904; do not conflate these metrics. All use 484 RAM blocks, 69 DSP blocks and three PLLs. Preferred seed 52 uses 48362 registers and reduces actual placed ALMs by 3355 against accepted bcddb20 seed 61, at a cost of two additional M10K blocks; the intervening audio-menu removal is included. Estimated utilization is 76.2 percent while actual placement is 90.2 percent. Total compile/audit durations are 901.1, 905.0 and 889.6 seconds. Hash-verified handoffs and instructions are under results/hardware-test-dc1dfc2; preferred seed52/MediaPlayer_20260914.rbf has SHA-256 7eb9a5bebc66423885d5865a40dc55ab24f28d3ff6f4743f05c3ebd394358ce6. Documentation commit 29a54d3 identifies the candidate; runtime source remains dc1dfc2. No hardware acceptance, deployment or further build was performed.

#### Next Steps:

Have the user test seed 52 for normal playback, repeated short/long seeks both directions, paused seeks/resume, reload and EOF, confirming clean video, synchronized audio and removal of the diagnostic audio menu. Preserve accepted bcddb20 seed 61 as rollback and leave additional RAM conversions unstarted until requested.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 56 COMMIT Unreleased dc1dfc2 2026-09-14T04:11:41-07:00

#### Coming From:

Unreleased 1349c82

#### Purpose:

Restore the P and B parser row-buffer block-memory conversion to recover logic capacity.

#### Outcome:

Source dc1dfc2 restores the seven-file historical 047f5b2 conversion to current progressive RTL. Both 512-byte row arrays use synchronous M10K reads, one-byte-ahead prefetch and shadow head/tail bytes so the two-byte rollover needs no extra RAM write port or combinational read. Five supported differential parser/transport cases pass against baseline 1349c82 with identical RESULT lines and reported cycle counts: P/B intra, B residual streaming, eight P and eight B window refills, and abort recovery. A new strict runner rejects failed baselines and isolates legacy generator output; two historical dense-stream fixture/test pairings were found to fail unchanged baseline count assertions and are explicitly excluded rather than counting matching failures as success. Current full I/P/B reconstruction with display ownership and repeated paused seeks passes 423936 pixel comparisons with zero mismatches; actual Pee Strike direct restart at the ten-second target resumes audio and video with shared DDR and no reported errors. These models use ideal bounded queues and do not prove vendor RAM inference or physical timing. Evidence is under results/row-buffer. The source was committed and pushed before clean seeds 52, 61 and 87 started at 2026-09-14T04:17:03-07:00 with six workers each under results/build-dc1dfc2-20260914-041703. Packing remains MEDIUM and menu-ROM storage is unchanged. The result checker requires 153 CDC registers and separately reports actual placed ALMs. No RBF is ready yet, no current savings are claimed and the MiSTer was not changed.

#### Next Steps:

Finish the three builds, confirm both row arrays infer M10K, compare actual placed ALMs and RAM usage with bcddb20 while noting the included audio-menu removal, and audit every timing corner plus 153 CDC registers. Package the best candidate for user validation of playback and repeated forward/backward seeks, keeping the hardware-accepted bcddb20 seed 61 as rollback.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/verify_row_buffer_equivalence.py
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 55 COMMIT Unreleased 1349c82 2026-09-14T04:07:41-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Remove the diagnostic seek-audio menu switch while retaining normal compressed-audio bypass.

#### Outcome:

The user authorized removing the Seek audio bypass menu entry during a read-only historical RAM optimization audit. Source 1349c82 removes the option and its one-bit CDC mailbox, connects MP2 seeking directly to media_seeking and removes the obsolete mailbox from the timing audit, reducing required synchronizer checks from 159 to 153. The existing bypass algorithm and full-frame synthesis preroll are preserved; saved status bit seven no longer affects behavior. MP2 quantizer and joint-stereo tests pass exact resumed PCM comparisons across two reset sessions, normal and wrapped timestamps, and one-byte, 582-byte and false-header 1604-byte startup prefixes. Evidence is under results/menu-removal. No builds or hardware changes were made. Separately, Git history confirms that progressive restoration 9233f07 lost the 047f5b2 parser row-buffer BRAM conversion and 6e44472 configuration-ROM BRAM enable. Current P and B row_bytes arrays are each 512 by 8 with combinational reads, and CONF_STR_BRAM defaults to zero. Historical entry 420 records 7082 fewer estimated ALMs and two additional RAM blocks for the row-buffer conversion, followed by hardware acceptance in entry 422; those historical savings are not a current-build prediction. Large residual plans and shared residual storage already use M10K. The attempted 19-to-20-bit coefficient padding in 5fb7d5d saved nothing because synthesis removed the unused bit and was reverted by 3e89189. No RAM conversion is authorized or implemented in this menu-removal boundary.

#### Next Steps:

Menu removal is ready for the next build; adapt future build summaries to 153 CDC checks. Recommend porting the historical row-buffer conversion with differential parser and current seeking tests, followed by the smaller configuration-ROM change, as the next resource-recovery work.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_av.svh
- tools/phase1p_timing.tcl
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 54 COMMIT Unreleased bcddb20 2026-09-14T03:59:43-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Record the completed seed 61 maximum-packing comparison.

#### Outcome:

The single HIGH-packing bcddb20 seed 61 experiment compiled and passes all four timing corners and the 159-register CDC audit. Minimum setup is +0.028 ns, hold +0.111 ns, recovery +2.751 ns, removal +0.112 ns and pulse width +0.925 ns. It places 41230 ALMs versus 41145 in the original MEDIUM seed 61, an increase of 85; ALMs-needed estimates are 41329 versus 41223. Registers are 56346 versus 56345, with 482 RAM blocks, 69 DSPs and three PLLs unchanged. HIGH therefore offers no area benefit and less setup margin than the original +0.205 ns candidate. Compile took 1145 seconds and compile plus audit 1226.7 seconds versus 1424.1 seconds for the original; HIGH ran alone while the original ran alongside two seeds, so elapsed time does not isolate packing effort. The separate experimental RBF at results/hardware-test-bcddb20-packing-high/seed61/MediaPlayer_20260914.rbf is hash verified as 4cd4eadd5ee8a3eef1ed11158d8d3157d2002cc47389d5e47e43971681f0fa82. Comparison JSON, exact settings diff and timing evidence are retained under results/build-bcddb20-packing-high-20260914-033800. No source settings, baseline RBF or MiSTer state were changed, and no additional builds were started. Built refers to the successful HIGH experiment; Passed remains unchecked because hardware acceptance applies only to the original MEDIUM candidate.

#### Next Steps:

Retain the user's hardware-accepted MEDIUM seed 61 as preferred and leave production packing effort unchanged. Any further area reduction should be separately planned from resource evidence rather than assuming HIGH packing reduces occupied logic.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 53 COMMIT Unreleased bcddb20 2026-09-14T03:41:24-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Record hardware acceptance of the direct-seek seed 61 candidate.

#### Outcome:

The user reports that the core works well and seeking is rock solid and decently fast with the delivered bcddb20 seed 61 candidate. Passed records this reported playback/seek acceptance, not an independently enumerated matrix of files, keys or EOF cases. Its local build-info now records that scope. The separate maximum-packing experiment remains independent and is not accepted by this feedback. The user also asked what lies behind the black seek display: media_seeking holds the framebuffer reader/cache in reset, which forces RGB black while raster timing continues. Probe passes scan container/video headers without codec reconstruction; after selecting a restart point, the decoder reconstructs the short lead-in and reuses released frame banks. There is no intact live picture under an overlay; removing reset/blanking alone would expose invalid or changing data and can interfere with the display-bank release that fixed seeking. No playback source or hardware state was changed.

##