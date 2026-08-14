#!/usr/bin/env python3
"""Generate an I/P-only diagnostic boundary variant of the mixed P regression.

The ordinary mixed regression is first regenerated and fully software-verified.
This diagnostic then removes the trailing I picture and replaces it with a fresh
sequence-header/sequence-extension boundary followed by sequence_end.  The FPGA
therefore sees the same post-P boundary used to release the mixed raster proof,
but no later picture can overwrite the displayed P destination.  If the mixed
P picture is published/presented, the screen must remain on that P frame.

The diagnostic tail is intentionally not a complete decodable MPEG-2 sequence:
its purpose is to present the FPGA with a clean post-P start-code boundary and
then stop before another picture can overwrite the P destination.  Therefore we
validate the authoritative I/P content through the already-verified base stream
and validate this boundary variant structurally instead of asking ffprobe to
decode the deliberately incomplete trailing sequence.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import generate_test_p_motion_residual_mix as base


def main() -> None:
    # Rebuild and fully software-validate the authoritative mixed I/P/I stream.
    # This proves the exact I and P bytes that are copied into the diagnostic.
    base.main()

    src = Path(base.__file__).resolve().parent / 'test_p_motion_residual_mix.m2v'
    out = Path(__file__).resolve().parent / 'test_p_motion_residual_boundary.m2v'

    data = src.read_bytes()
    codes = base.start_codes(data)
    pics = [o for o, c in codes if c == 0x00]
    seqs = [o for o, c in codes if c == 0xB3]
    if len(pics) != 3:
        raise SystemExit(f'expected source I/P/I picture count 3, found {len(pics)}')
    if not seqs or seqs[0] >= pics[0]:
        raise SystemExit('source sequence header not found before first picture')

    # Copy the authoritative stream byte-for-byte through the end of the P
    # picture, stopping immediately before the trailing I picture start code.
    ip_prefix = data[:pics[2]]

    # Reuse the complete original sequence header/extension preamble.  Its B3
    # start code is the post-P boundary observed by the FPGA mixed proof.
    preamble = data[seqs[0]:pics[0]]
    if not preamble.startswith(b'\x00\x00\x01\xb3'):
        raise SystemExit('source preamble does not begin with sequence_header_code')
    if b'\x00\x00\x01\xb5' not in preamble:
        raise SystemExit('source preamble does not contain sequence_extension')

    diag = ip_prefix + preamble + base.SEQ_END
    out.write_bytes(diag)

    # Structural validation only.  The diagnostic tail intentionally starts a
    # new sequence but contains no following picture, so ffprobe is expected to
    # reject the file as an incomplete decodable sequence.  The copied I/P data
    # itself was fully validated by base.main() above.
    if diag[:len(ip_prefix)] != ip_prefix:
        raise SystemExit('diagnostic I/P prefix differs from authoritative mixed stream')
    out_codes = base.start_codes(diag)
    out_pics = [o for o, c in out_codes if c == 0x00]
    if len(out_pics) != 2:
        raise SystemExit(f'diagnostic contains {len(out_pics)} picture start codes, expected 2')
    post_p_sequences = [o for o, c in out_codes if c == 0xB3 and o > out_pics[1]]
    if post_p_sequences != [len(ip_prefix)]:
        raise SystemExit(
            f'unexpected post-P sequence-header boundary offsets {post_p_sequences}; '
            f'expected [{len(ip_prefix)}]'
        )
    if not diag.endswith(base.SEQ_END):
        raise SystemExit('diagnostic lacks sequence_end')

    print(f'generated: {out}')
    print('diagnostic content: authoritative I/P prefix, then sequence-header boundary')
    print('post-P tail is intentionally boundary-only; no trailing picture is present')
    print(f'bytes: {out.stat().st_size}')
    print(f'sha256: {hashlib.sha256(diag).hexdigest()}')
    print('expected hardware display if mixed P publication succeeds: P frame remains visible')


if __name__ == '__main__':
    main()
