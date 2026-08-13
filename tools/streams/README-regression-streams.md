# MPEG-2 diagnostic regression streams

## Baseline reset — 2026-08-13

The integrity/provenance of the earlier ad-hoc regression `.m2v` files is considered **questioned**. The six files in this directory are a **new diagnostic baseline generated from scratch**. Historical hashes, byte offsets, and exact macroblock/VLC assumptions from the superseded files must not be used as evidence about these new files.

`regenerate_test_streams.py` is the generation authority for this set. It generates raw YUV420p source frames itself, then invokes FFmpeg's native `mpeg2video` encoder at 25 fps with no B-frames and explicit picture forcing. Each output is explicitly terminated with `sequence_end_code` (`00 00 01 B7`).

## Diagnostic intent

| File | Geometry | Pictures | Intended diagnostic role |
|---|---:|---|---|
| `test_all_i.m2v` | 352×288 | I I I I | Baseline intra decode/store/display and repeated reference publication. Four frames carry a changing top-left marker. |
| `test_ipii.m2v` | 352×288 | I P I I | P-picture transition/control baseline. The P source frame repeats the preceding I source; following forced I frames have visible markers. |
| `test_ip_motion_end.m2v` | 352×288 | I P I | Motion-oriented P source. The P source is the reference pattern translated left by 2 luma pixels (and 1 chroma sample). Intended to encourage a +2-pixel horizontal prediction. |
| `test_ip_motion_nores_end.m2v` | 352×288 | I P I | Static P source. The P source exactly repeats the preceding I source, intended to encourage zero-vector/no-residual prediction. |
| `test_ip_halfpel_end.m2v` | 352×288 | I P I | Half-pel-oriented P source. P luma is constructed as rounded horizontal interpolation of reference luma at x+1/x+2; chroma is unchanged. |
| `test_ip_two_mb_static.m2v` | 32×16 | I P I | Two-adjacent-macroblock placement/persistence proof. The two macroblocks have distinct luma values. The generator verifies the controlled `12 79 c0` first-P-slice prefix used by the Phase 1T-r recognizer. |

## Conformance / diagnostic caution

The picture sequence, geometry, pixel format, termination, and the two-MB controlled slice prefix are verified by the generator. **Do not infer exact first-macroblock motion vectors, coded-block-pattern values, residual VLCs, or coefficient values for the other P streams merely from source-frame intent.** Those properties must be freshly decoded/observed and then recorded before FPGA probes rely on them.

This reset intentionally invalidates historical byte-level expectations for the first five files. Hardware results from the old binaries remain historical evidence for the old binaries only. Phase 1T-r and later testing must establish a fresh regression baseline against the files currently committed in Git.
