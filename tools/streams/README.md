# H.262 diagnostic streams

These streams are **generated test artifacts**, not historical golden-byte files.
Do not compare them to older repository hashes or byte sequences.

Generate them from the repository root with:

```bash
python3 tools/generate_diagnostic_streams.py
```

The generator deletes stale `tools/streams/*.m2v` files first, creates the active
suite, validates the MPEG-2/H.262 structure required by the current decoder
milestone, and asks ffmpeg to decode each result as an independent sanity check.

## Active positive diagnostics for c5b6bc75

| File | Picture sequence | Purpose | Hardware expectation |
|---|---:|---|---|
| `test_flat_gray_i.m2v` | `III` | Minimum-complexity all-I path. First block is intentionally DC-only. | Uniform gray picture; USER should illuminate after the all-I success chain completes. |
| `test_all_i.m2v` | `III` | Intra AC/VLC, inverse quantisation, IDCT, reconstruction and full-frame persistence with deterministic image detail. | Detailed image; USER should illuminate. |
| `test_all_i_q1.m2v` | `III` | Higher-coefficient-density intra stress at quantiser setting 1. | Patterned image; USER should illuminate if the broader intra path succeeds. |
| `test_ip_only.m2v` | `IPI` | Controlled P-picture syntax transition without exercising the narrow explicit-vector/pattern-only residual regressions. The generator verifies that the first P macroblock is intra-coded. | First I frame is reconstructed, P syntax is observed, then the second I frame is reconstructed; USER should illuminate through the P-syntax success path. |

`stream-susi.m2v` and `test_static_ip.m2v` are intentionally not generated.
The current RTL at c5b6bc75 does not provide a general B-picture decoder or a
general arbitrary-P-picture decoder, so those names were producing misleading
results rather than controlled diagnostics.

## Why three I pictures?

The c5b6bc75 top-level all-I USER predicate requires the first and second pictures
to have completed and `picture_count >= 3`. One-picture all-I files therefore
cannot be positive USER regressions for this commit.

## Why an explicit final sequence end?

The streaming FPGA interface does not expose a separate compressed-stream EOF
sideband to the picture parser. Each generated file therefore ends with
`sequence_end_code` so the final `picture_data()` region reaches a non-slice
start-code boundary and can retire deterministically.
