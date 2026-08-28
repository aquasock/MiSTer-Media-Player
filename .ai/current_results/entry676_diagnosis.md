# DVD cadence qualification: drain overlap and terminal cut

## Proven scheduling miss

At source `18d9189` (production `d70b18f`), the ideal and contended native runs both finish with 289 distinct pictures in display order, correct descriptors and all 25 timestamps. Their reconstructed-pixel CSVs equal the prior accepted numerical baseline. The contended case nevertheless publishes coded B116 two fields late after B115.

The original B116 readiness edge is cycle 290,202,808; the missed selection boundary is cycle 290,197,963. The 4,845-clock miss is 80.75 microseconds at the modeled 60 MHz decoder clock. B115 and B116 incur no scheduler presentation hold. Earlier P112 is held 2,699,879 clocks while a completed B generation still presents its scratch and future pictures.

Production `e9041b2`, tested with `e876bf3`, permits the second ordinary successor into the existing third region only after old B prediction has finished and the destination differs from every retained or actually displayed ordinary frame. Its completion retains the existing secondary identity. Following I/P payloads wait at full capacity; a B header waits for old-generation retirement before binding that secondary reference. The focused I/P/B/end matrix, metadata tests, broad scheduler, native timing integration and mixed-raster control pass. The complete contended trace places B116 readiness at cycle 290,096,234, 101,729 clocks (1.695 milliseconds) before its boundary. Both complete native runs finish with all 289 pictures once in order, correct complete metadata, all 25 timestamps, clear cache/phase/overlap flags and zero interior cadence mismatches. Their only strict-gate failure is the terminal cut described below. Paired reconstruction passes with identical CSVs and unchanged source fingerprints; no hardware acceptance is claimed.

## Independent terminal fixture discontinuity

Both completed `18d9189` traces hold P285 for four fields before I288, although P285 has an authored duration of three. I288 was already ready; this is not a decode deadline miss.

`terminal_source_check.json` verifies that the tested elementary video, excluding its final sequence-end marker, is an exact 10,334,164-byte prefix of a 13-second stream-copy extraction from `/home/vash/mister-builds/entry622/VTS_01_1.VOB`. The final I288 starts an open GOP and has temporal reference 2. Its following coded B289 and B290 have temporal references 0 and 1, so they precede I288 in display order. The 12-second cut omits both.

| Picture | Present in cut | First field | Authored fields |
| --- | --- | --- | --- |
| P285 | Yes | Bottom | 3 |
| B289 | No | Top | 2 |
| B290 | No | Top | 3 |
| I288 | Yes | Bottom | 2 |

The source sequence preserves alternating field parity. Omitting the two B pictures removes five fields and creates the only adjacent field-order discontinuity in the 289-picture fixture. With continuous physical field timing, the retained final I picture must wait one additional field to begin on its authored bottom field.

H.262 (02/2000), clause 6.3.10 (printed pages 49–50), defines first-field order and the two/three-field progressive-frame output. Clause 7.12 (printed page 106) requires alternating top/bottom fields in a conforming interlaced bitstream and distinguishes decoding output from the display process. [Official controlled text](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-H.262-200002-S!!PDF-E&lang=e&type=items). The added display hold is a recovery choice for this cut, not a general standard allowance or proof that the edited fixture is conformant.

## Current gate and deployment boundary

The strict analyzer remains unchanged and rejects both completed comparison runs. No terminal exception has been enabled. User approval has been requested to recognize only this verified final one-field adjustment while continuing to require every picture once, exact metadata, timestamps, zero other cadence mismatches and unchanged pixel bounds. No FPGA build or MiSTer write has occurred. FTP access to `10.10.0.30` has twice failed with “No route to host.”
