# New MPEG-2 / H.262 decoder

This directory tracks the clean-room MiSTer-oriented decoder being developed in
parallel with the existing MPEG2FPGA integration.

## Normative standards hierarchy

Decoder behaviour is to be derived from authoritative standards, not memory or
assumption.

1. **ITU-T H.262 (02/2000) / ISO/IEC 13818-2:2000** — MPEG-2 Video coded
   representation and decoding process.
2. **ITU-T H.222.0 / ISO/IEC 13818-1** — MPEG-2 Systems (PES, Program Stream,
   Transport Stream, timing and synchronization) when container/system support
   is added.
3. **DVD-Video application specification** — required later for complete
   commercial DVD navigation/application behaviour.  This is a separate layer
   from H.262/H.222.0 and must not be inferred from those standards.

The implementation should cite the relevant standard clause/table in RTL where
syntax constants or normative behaviour are encoded.

## Architecture

Compressed bytes cross from the MiSTer HPS domain into one decoder clock domain
through the existing asynchronous stream FIFO.  The new decoder will reconstruct
frames into explicit Y/Cb/Cr frame stores.  Display scans a completed frame
independently; decoded pixel cadence is never used as the video raster clock.

Planned ownership boundary:

    HPS / file or disc source
             |
             v
       async byte FIFO
             |
             v
       H.262 front end
      start codes / bits
             |
             v
      slice + macroblock
             |
             v
       VLC coefficients
             |
             v
      inverse quantizer
             |
             v
            IDCT
             |
             v
      reconstruction +
      motion compensation
             |
             v
       Y/Cb/Cr frame DDR
             |
      completed-buffer handoff
             |
             v
       independent MiSTer
       presentation pipeline

## Milestones

### Phase 0 — H.262 header front end

Passive parser runs beside MPEG2FPGA and validates:

- byte-aligned start codes;
- sequence header;
- sequence extension;
- picture header;
- picture coding extension;
- slice arrival;
- fundamental marker/reserved/forbidden checks used by those headers.

No video path changes in this phase.

### Phase 1 — progressive 4:2:0 I-picture luma

Take ownership of the compressed stream and implement enough of clauses 6 and 7
to decode the existing progressive all-I tests into an explicit luma frame.

#### Phase 1A — slice and first macroblock probe

Still passive beside MPEG2FPGA.  Capture a bounded prefix of the first slice and
prove bit alignment against the normative H.262 syntax before coefficient
decoding is introduced:

- H.262 (02/2000) 6.2.4 `slice()`, including `quantiser_scale_code` and
  the `slice_extension_flag` / `intra_slice` / `slice_picture_id_enable` /
  `slice_picture_id` syntax introduced into the consolidated 2000 edition;
- H.262 6.2.5 `macroblock()` entry;
- Annex B Table B.1 `macroblock_address_increment`, including
  `macroblock_escape`;
- Annex B Table B.2 non-scalable I-picture `macroblock_type`.

The bootstrap decoder explicitly rejects scalable-sequence syntax as unsupported
rather than applying the non-scalable slice grammar to it.  This is an
implementation capability boundary, not a claim that scalable H.262 is invalid.

For this diagnostic build USER illuminates only after a valid first I-picture
macroblock type has been decoded and neither the Phase 0 front end nor Phase 1A
probe has reported an error.

#### Phase 1B — first luminance intra DC coefficient

Still passive beside MPEG2FPGA.  Continue from the proven first I macroblock into
`block(0)` and implement the normative DC path only:

- H.262 6.2.3.1 / 6.3.10 `intra_dc_precision`, `frame_pred_frame_dct`, and
  `concealment_motion_vectors`;
- H.262 6.2.5 optional macroblock-level `quantiser_scale_code`;
- H.262 6.2.6 `block()` entry for luminance block 0;
- H.262 Annex B Table B.12 `dct_dc_size_luminance`;
- H.262 7.2.1 differential reconstruction and Table 7-2 DC predictor reset.

The Phase 1 bootstrap currently marks intra concealment motion vectors as an
unsupported capability (not a syntax error), so the first block follows the
macroblock type and optional macroblock quantiser scale directly.

The probe stops immediately after reconstructing the first luminance `QFS[0]`;
AC run/level VLC decoding is intentionally deferred to Phase 1C.  USER now
illuminates only after this first DC coefficient has been reconstructed within
the H.262-required range and neither parser has reported an error.

For the local ffmpeg-generated 720x480 flat-gray all-I reference stream used to
sanely check the RTL parser, the first slice independently parses as
`intra_dc_precision = 0`, luminance `dct_dc_size = 2`, differential `-2`, and
therefore `QFS[0] = 126` from the Table 7-2 reset predictor of 128.  These are
reference-stream observations, not values assumed by the decoder.

#### Phase 1C — complete first luminance block coefficient decode

Still passive beside MPEG2FPGA.  Continue from the Phase 1B intra DC result and
consume every remaining coefficient of luminance `block(0)` through End of Block.

Normative behaviour implemented in this diagnostic:

- H.262 7.2.2 and Table 7-3 select Annex B Table B.14 when
  `intra_vlc_format = 0` and Table B.15 when `intra_vlc_format = 1` for an
  intra block;
- normal VLC entries produce `run` and positive `level`, followed by the
  separate sign bit specified by 7.2.2;
- End of Block terminates coefficient decoding and makes the remaining `QFS[n]`
  values zero as described by 7.2.2.4;
- Escape uses the Table B.14/B.15 escape VLC followed by the six-bit `run` and
  twelve-bit two's-complement `signed_level` defined by 7.2.2.3 and Table B.16;
- escape `signed_level = 0` is forbidden and `0x800` (-2048) is reserved;
- coefficient run placement is checked so no coefficient is produced beyond
  `QFS[63]`.

The separate `mpeg2_h262_dct_vlc` module contains the complete Table B.14 and
Table B.15 VLC mappings needed for intra AC decoding.  Table B.14's special
first-coefficient `1 s` form is deliberately not used here: H.262 7.2.2.2
states that an intra block codes its DC coefficient by 7.2.1, so the first
Table B.14 coefficient in this path is a subsequent coefficient.

The passive probe capture was expanded from 16 to 64 bytes to give ordinary
test blocks more room.  That 64-byte bound is only a temporary diagnostic
implementation detail and is **not** treated as an H.262 bitstream limit.  The
production decoder will replace this capture/parser arrangement with a
streaming bitreader.

USER illuminates only after a legal End of Block has completed the first
luminance block and neither the H.262 front end nor coefficient probe reports
an error.

For the local ffmpeg-generated flat-gray all-I reference stream, the first
luminance block is DC-only after its DC differential: with
`intra_vlc_format = 0`, the next two bits are the Table B.14 End-of-Block code
`10`.  This is a reference-stream observation, not a value assumed by the RTL.

#### Phase 1D — inverse scan and inverse quantisation

Still passive beside MPEG2FPGA.  The complete first-luminance `QFS[0..63]`
coefficient set from Phase 1C is materialized and reconstructed according to the
normative MPEG-2 inverse-quantisation process:

- H.262 7.3 and Figures 7-2/7-3 map the one-dimensional `QFS[n]` sequence to
  two-dimensional `QF[v][u]` using `alternate_scan`;
- H.262 7.4.1 and Table 7-4 apply the special intra-DC multiplier selected by
  `intra_dc_precision`;
- H.262 6.3.11 supplies the normative default intra quantisation matrix;
- H.262 7.4.2.1 and Table 7-5 select the intra matrix for 4:2:0 luminance;
- H.262 7.4.2.2 and Table 7-6 map `quantiser_scale_code` through `q_scale_type`;
- H.262 7.4.2.3 performs the intra AC reconstruction arithmetic;
- H.262 7.4.3 saturates every reconstructed coefficient to `[-2048,+2047]`;
- H.262 7.4.4 applies MPEG-2 mismatch control by correcting only `F[7][7]`
  when the sum of saturated coefficients is even.

The `/` operation in the inverse-quantisation arithmetic follows H.262 4.1:
integer division is truncated toward zero.  The RTL therefore uses signed
integer division rather than an arithmetic right shift, which would round
negative values differently.

This milestone implements the **default intra quantisation matrix only**.
H.262 permits matrices to be downloaded in a sequence header or quant matrix
extension.  Such streams remain valid H.262; the Phase 1D front end records
that a custom matrix is in use and the inverse quantiser reports the feature as
unsupported instead of treating the bitstream as malformed.  Full matrix
loading/storage is a later decoder capability.

The first-block coefficient probe now emits a one-cycle block-start pulse,
non-zero `QFS[]` writes, and a block-end pulse at legal EOB.  Zero coefficients
created by run values and by EOB are implicit because block-start clears the
64-entry diagnostic coefficient store.

USER illuminates only after the first luma block has completed inverse scan,
inverse quantisation, saturation and mismatch control with no syntax,
coefficient-probe, inverse-quantiser, or unsupported-matrix condition.
Displayed video is still generated by the legacy MPEG2FPGA path in this phase.

For the local ffmpeg-generated flat-gray all-I reference stream, the first block
has `QFS[0] = 126`, no AC coefficients, `intra_dc_precision = 0`, and therefore
reconstructs to `F[0][0] = 1008`.  The saturated coefficient sum is even, so
7.4.4 mismatch control changes `F[7][7]` from 0 to 1.  These values are
reference-stream observations used to sanity-check the implementation; they are
not hardcoded into the RTL.

The local detailed all-I reference stream exercises the non-zero AC path as
well.  Its independently parsed first block uses `quantiser_scale_code = 2`,
`q_scale_type = 0` (`quantiser_scale = 4`), and reconstructs `F[0][0] = 456`;
mismatch control again leaves the final `F[7][7] = 1`.


#### Phase 1E — 8x8 inverse discrete cosine transform

Still passive beside MPEG2FPGA.  After each Phase 1D coefficient reaches its
final saturated value, the inverse quantiser emits the physical `F[v][u]`
coefficient in row-major order into `mpeg2_h262_idct.sv`.  The final coefficient
is emitted only after MPEG-2 mismatch control has finalized `F[7][7]`.

The normative basis is the consolidated ITU-T H.262 text (02/2012):

- clause 7.5 requires a conforming inverse DCT after reconstruction of `F[v][u]`;
- Annex A defines the N=8 mathematical real-number IDCT;
- Annex A defines the mathematical integer result by nearest-integer rounding,
  with exact half-integers rounded away from zero;
- Annex A requires decoder IDCT accuracy to conform to ISO/IEC 23002-1 and its
  Annexes A and B.

The RTL uses a separable two-pass fixed-point implementation.  Its one-
dimensional normalized basis is represented in Q14, the first pass is retained
as Q10, and the second pass is rounded to integer.  This is an implementation
choice, not an H.262 requirement.  Eight products are evaluated per clock, so
each 8x8 transform consumes 64 clocks per pass (128 transform clocks/block).
At the present 60 MHz MPEG clock, the transform itself has theoretical block-
rate headroom over 720x576 4:2:0 at 30 frames/s.  Finalized inverse-quantized
coefficients stream directly into the idle IDCT capture bank; eliminating the
former 64-clock completed-block replay saves 518,400 clocks for each 720x480
4:2:0 picture without changing normative arithmetic or transform results.

The current consolidated H.262 Annex A does **not** define the IDCT by clipping
its mathematical integer result to an 8-bit signed range.  Therefore Phase 1E
keeps a signed 16-bit `f[y][x]` stream.  H.262 7.6.8 separately requires adding
prediction and transform data and then saturating the final decoded sample to
`[0,255]`; for intra macroblocks the prediction is zero.  That decoded-pel
saturation will be added when the first spatial blocks are written to our frame
buffer.

Engineering verification of the selected fixed-point representation was run
against the Annex-A mathematical IDCT when this phase was generated.  All 4096
legacy H.262 Annex-A DC/mismatch vectors had observed peak error no greater than
1, and 10,000 random sparse legal coefficient blocks also had observed peak
error no greater than 1.  This is useful implementation validation but is **not
a claim of formal ISO/IEC 23002-1 conformance**; the formal accuracy test suite
will be run before the IDCT is declared standards-conformant.

For the flat-gray reference first block (`F[0][0]=1008`, `F[7][7]=1` after
mismatch control), both the mathematical reference and this fixed-point model
produce 126 for all 64 spatial-domain values.  This is a test-stream observation
and is not hardcoded in the RTL.

USER illuminates only after the new IDCT has emitted all 64 spatial-domain
values for the first luma block and no syntax, coefficient-probe, inverse-
quantiser, unsupported-matrix, or IDCT protocol error has occurred.  Displayed
video is still generated by the legacy MPEG2FPGA path in this phase.


#### Phase 1F — first decoded luminance block to the MiSTer framebuffer

This is the first phase in which pixel data from the standards-driven decoder
owns the visible framebuffer.  The legacy MPEG2FPGA resampler is disconnected
from the framebuffer write port.  MPEG2FPGA remains instantiated only so that
this diagnostic can reuse the already-proven 40 MHz SVGA timing generator while
our decoder/presentation boundary is brought up incrementally.

Normative H.262 behaviour implemented here comes from the consolidated ITU-T
H.262 text (02/2012):

- 6.3.3 defines `mb_width = (horizontal_size + 15) / 16`;
- 6.3.16 defines `slice_vertical_position`, and for pictures taller than 2800
  lines its `slice_vertical_position_extension`, as the macroblock-row position;
- 6.3.17 resets `previous_macroblock_address` to
  `(mb_row * mb_width) - 1` at slice start and defines
  `macroblock_address_increment` as the difference to the current macroblock;
  therefore the first macroblock column in a slice is
  `macroblock_address_increment - 1`;
- 6.1.3 / Figure 6-10 defines luminance block 0 of a 4:2:0 macroblock as the
  upper-left 8x8 block of the 16x16 luminance macroblock;
- 7.6 states that no prediction is formed for an intra-coded macroblock, so
  `p[y][x] = 0`;
- 7.6.8 adds `f[y][x]` and `p[y][x]` and saturates the final decoded sample to
  `[0,255]`.

`mpeg2_h262_intra_recon.sv` implements those rules for the one block currently
available from the Phase-1 probe.  It checks that the IDCT sample stream is
row-major 0 through 63, applies the normative intra decoded-pel saturation, and
emits explicit picture `(x,y)` coordinates with each luminance sample.

The slice probe now exposes its already-decoded three-bit
`slice_vertical_position_extension`; this avoids embedding a hidden assumption
that the H.262 picture is always shorter than 2800 lines even though the present
MiSTer framebuffer diagnostic is intentionally standard-definition sized.

The existing 720x480 M10K framebuffer is reused rather than allocating a second
full frame.  Only the completed 8x8 block is exposed from RAM.  The rest of the
720x480 source window is replaced by a fixed dark diagnostic background so
uninitialised RAM cannot be mistaken for decoder output.  The 720x480 centering
inside the 800x600 raster and the background value are presentation/debug
choices, not H.262 requirements.

For the current 720x480 ffmpeg test streams, the first slice begins at
`slice_vertical_position = 1` and its first
`macroblock_address_increment = 1`, so the first decoded block is expected at
picture coordinate `(0,0)`, displayed at the upper-left of the centered source
window.  These are observations of the test streams, not values hardcoded in
the decoder.

USER illuminates only after the reconstruction engine has accepted all 64 IDCT
samples and no earlier syntax, coefficient, inverse-quantisation, IDCT, or
reconstruction protocol error has occurred.

Phase 1F is still intentionally only a first-block proof.  The next decoder
milestone will extend block parsing/reconstruction through all four luminance
blocks of the first 4:2:0 macroblock before expanding across macroblocks and
slices.

### Phase 2 — chroma

Decode 4:2:0 Cb/Cr and add the independent presentation conversion path.

### Phase 3 — P pictures

Add reference-frame ownership, motion-vector decoding and forward motion
compensation.

### Phase 4 — B pictures

Add second reference frame, bidirectional prediction and coded/display ordering.

### Phase 5 — complete Main-Profile/Main-Level relevant H.262 behaviour

The first bounded interlaced path accepts 720x480 4:2:0 all-I frame pictures
using frame DCT, preserves authored field order, and presents native 480i.
Future work adds field pictures, interlaced prediction and the remaining tools
required by target media. Scope is determined from H.262 profile/level rules,
not guessed.

### Phase 6 — MPEG-2 Systems

Implement the required H.222.0 Program Stream/PES/timestamp layer separately
from the video decoder.

### Phase 7 — DVD-Video application layer

Add filesystem/navigation/subpicture/audio/disc integration from authoritative
DVD-Video specifications available to the project.  Copy protection/decryption
is not part of the H.262 decoder and remains a separate input-layer concern.
