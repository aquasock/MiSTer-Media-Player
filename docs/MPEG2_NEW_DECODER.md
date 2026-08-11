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

### Phase 2 — chroma

Decode 4:2:0 Cb/Cr and add the independent presentation conversion path.

### Phase 3 — P pictures

Add reference-frame ownership, motion-vector decoding and forward motion
compensation.

### Phase 4 — B pictures

Add second reference frame, bidirectional prediction and coded/display ordering.

### Phase 5 — complete Main-Profile/Main-Level relevant H.262 behaviour

Add interlaced frame/field pictures and remaining standard tools required by the
target media.  Scope is determined from H.262 profile/level rules, not guessed.

### Phase 6 — MPEG-2 Systems

Implement the required H.222.0 Program Stream/PES/timestamp layer separately
from the video decoder.

### Phase 7 — DVD-Video application layer

Add filesystem/navigation/subpicture/audio/disc integration from authoritative
DVD-Video specifications available to the project.  Copy protection/decryption
is not part of the H.262 decoder and remains a separate input-layer concern.
