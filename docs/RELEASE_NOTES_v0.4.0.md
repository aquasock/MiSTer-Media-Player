# MiSTer Media Player v0.4.0 release notes

v0.4.0 is the Phase 1U milestone release candidate. It preserves the hardware-proven continuous progressive 4:2:0 all-I path and advances P-picture reconstruction from the deliberately narrow v0.3.0 diagnostic subsets to a substantially generalized syntax-derived progressive 4:2:0 P decoder within the current implementation envelope.

## Highlights

- Unified generalized P execution around syntax-derived per-macroblock motion vectors and residual block plans.
- Added signed horizontal and vertical forward motion-vector reconstruction with predictor reuse/reset and H.262 wrap behavior for the supported f_code=3 path.
- Added integer, horizontal half-sample, vertical half-sample, and bilinear prediction, including 4:2:0 chroma-vector scaling.
- Added complete supported 4:2:0 coded-block-pattern selection across Y0/Y1/Y2/Y3/Cb/Cr.
- Generalized non-intra residual coefficient handling beyond the earlier fixed +7 proof, including ordinary run/level VLCs, non-zero runs, signs, EOB, and Escape syntax.
- Added q_scale_type, alternate_scan, slice and macroblock quantiser-scale changes, and modified-first-coefficient handling on the generalized P path.
- Preserved skip handling, macroblock-address progression/escape, prediction-plus-residual reconstruction, DDR persistence, and P-picture publication/reference promotion.
- Preserved consecutive P reference consumption so a reconstructed P picture can become the forward reference for the following P picture.
- Registered the generalized DDR request path to restore positive timing margin and eliminate the hardware crash seen in the rejected first generalized candidate.
- Removed an obsolete legacy transform diagnostic assertion from generalized mode while retaining the historical controlled proof unchanged.

## Current supported development subset

- Raw MPEG-2 Video elementary-stream input (`.m2v`).
- Progressive frame pictures on the hardware-proven paths.
- 4:2:0 chroma.
- Continuous supported I-picture playback up to the established 720x480 diagnostic geometry.
- Generalized P-picture regression path at the current 128x96 / 8x6-macroblock geometry with forward f_code=(3,3).
- Full 8-bit Y/Cb/Cr reconstruction into two planar MiSTer DDR3 frame banks.
- Fixed 800x600 diagnostic video output.
- Synthetic 33-bit / 90 kHz elementary-stream presentation timing metadata.

The generalized P implementation still has explicit engineering limits: the current diagnostic path caps one P picture at 16 coded residual blocks and 64 non-zero coefficient events. Those are implementation limits, not H.262 limits.

## Known limitations

The following remain outside v0.4.0:

- B pictures.
- Interlaced frame/field-picture support and broader H.262 picture structures.
- Chroma formats other than 4:2:0.
- General MPEG-2 Program Stream (`.mpg` / `.mpeg`) demux and PES-derived timestamps.
- Audio.
- DVD/VOB navigation and optical-disc playback.
- Removal of the current generalized-P diagnostic geometry/f_code/resource caps.

## Release validation

The exact release-candidate commit must pass a clean/from-scratch Quartus Prime 17.0 build, the standard Phase 1P timing reports with zero setup TNS, and the milestone MiSTer hardware regression set before tag `v0.4.0` or a GitHub Release is created.

The user-built release binary will retain MiSTer's date-coded naming convention (`MediaPlayer_YYYYMMDD.rbf`).
