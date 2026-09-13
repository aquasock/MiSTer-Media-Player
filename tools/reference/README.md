# MP2 arithmetic reference

`pl_mpeg.h` is an unmodified engineering reference from Dominic Szablewski's
MIT-licensed PL_MPEG project, retrieved 2026-09-13 from:
https://raw.githubusercontent.com/phoboslab/pl_mpeg/master/pl_mpeg.h

SHA-256: `3a8cb30c83c2a1147719c30fe0c8b93da2987aa43140077c575b39aaa75fc2c9`.

The upstream file retains its author and SPDX-License-Identifier: MIT notice.
`generate_mp2_tables.py` derives only the 512 synthesis-window values from it;
cosine and requantization ROMs are generated mathematically. This header is not
compiled into the FPGA or a runtime helper. The serial RTL is an independent
implementation tested against FFmpeg, not a formal ISO conformance claim.

The upstream repository describes its MIT licensing in README.md; it does not
ship a separate license file. The MIT terms are reproduced in LICENSE.pl_mpeg
for distribution with the derived window ROM.
