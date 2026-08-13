#!/usr/bin/env python3
"""Generate the fresh controlled P 4:2:0 reconstruction diagnostic.

This test is defined by c5b6bc75's semantic P-path predicates. Historical .m2v
bytes and hashes are intentionally not inputs.
"""
from __future__ import annotations

import tempfile
from pathlib import Path

import generate_diagnostic_streams as common


def validate_controlled_p420(path: Path) -> None:
    data = path.read_bytes()
    codes = common.start_codes(data)

    p_picture_idx = next(
        idx
        for idx, (_, code) in enumerate(codes)
        if code == 0x00
        and common.picture_type(common.payload_between(data, codes, idx)) == 2
    )
    slice_idx = next(
        idx
        for idx in range(p_picture_idx + 1, len(codes))
        if 1 <= codes[idx][1] <= 0xAF
    )
    bits = common.BitView(common.payload_between(data, codes, slice_idx))

    observed = {
        "qscale": bits.get(5),
        "slice_extension_flag": bits.get(1),
        "mba": bits.get(1),
        "mbtype": bits.get(2),
        "cbp": bits.get(6),
        "first_coeff": bits.get(10),
        "first_sign": bits.get(1),
    }
    expected = {
        "qscale": 1,
        "slice_extension_flag": 0,
        "mba": 1,
        "mbtype": 0b01,
        "cbp": 0b001100,
        "first_coeff": 0b0000001010,
        "first_sign": 0,
    }
    if observed != expected:
        raise ValueError(
            f"{path.name}: controlled P prefix {observed}, expected {expected}"
        )


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="mmp-h262-p420-") as tempdir:
        temp = Path(tempdir)

        def base(x: int, y: int) -> tuple[int, int, int]:
            return (
                48 + ((x * 17 + y * 11) & 127),
                56 + ((x * 7 + y * 19) & 127),
                64 + ((x * 13 + y * 5) & 127),
            )

        def changed(x: int, y: int) -> tuple[int, int, int]:
            r, g, b = base(x, y)
            if x < 16 and y < 16:
                return r - 20, g + 10, b + 18
            return r, g, b

        common.ppm(temp / "p42000.ppm", base)
        common.ppm(temp / "p42001.ppm", changed)
        common.ppm(temp / "p42002.ppm", base)

        output = common.OUT / "test_p420_recon.m2v"
        common.encode(
            [
                "-framerate", common.FPS,
                "-start_number", "0",
                "-i", str(temp / "p420%02d.ppm"),
            ],
            3,
            12,
            1,
            output,
            "expr:eq(n,0)+eq(n,2)",
        )
        common.validate(output, [1, 2, 1], "pattern")
        validate_controlled_p420(output)

    print(
        "Generated and validated test_p420_recon.m2v: "
        "pictures=IPI, first P macroblock=pattern, CBP=63, first Y0 level=+7"
    )


if __name__ == "__main__":
    main()
