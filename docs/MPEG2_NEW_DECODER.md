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
