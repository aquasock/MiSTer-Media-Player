#!/usr/bin/env python3
"""Change matrices between I/P/B pictures, then reset with a new sequence."""
from pathlib import Path
import h262common as h
from analyze_h262_compatibility import start_codes
from generate_test_b_quantized import main as generate_base


def extension(intra, non_intra):
    bits = "0011"
    for weights in (intra, non_intra):
        bits += "1" + "".join(f"{w:08b}" for w in weights)
    return bytes.fromhex("000001b5") + h.bits_to_bytes(bits + "00")


def main():
    generate_base()
    directory = Path(__file__).resolve().parent
    base = (directory/"test_b_quantized.m2v").read_bytes()
    tables = [([8]+[17]*63, [8]*64), ([8]+[23]*63, [11]*64),
              ([8]+[13]*63, [5]*64)]
    codes = start_codes(base)
    picture = -1
    inserted = set()
    data = bytearray()
    last = 0
    for offset, code in codes:
        if code == 0:
            picture += 1
        if 1 <= code <= 0xaf and picture not in inserted:
            data += base[last:offset] + extension(*tables[picture])
            last = offset
            inserted.add(picture)
    data += base[last:]
    # The second independently decodable sequence restores default matrices.
    (directory/"test_matrix_transitions.m2v").write_bytes(bytes(data) + base)
    print("MATRIX_TRANSITIONS_READY sequences=2 picture_updates=3 default_reset=1")


if __name__ == "__main__":
    main()
