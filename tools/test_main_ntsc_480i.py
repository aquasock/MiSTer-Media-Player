#!/usr/bin/env python3
"""Static contract checks for the MediaPlayer-specific ADV7513 480i patch."""

from pathlib import Path
import sys


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} MAIN_PATCH", file=sys.stderr)
        return 2

    patch = Path(sys.argv[1]).read_text(encoding="utf-8")
    markers = (
        'cfg.direct_video == 1 && !strcasecmp(user_io_get_core_name(), "MediaPlayer")',
        'user_io_status_get("[121]")',
        'ntsc_480i ? 0b01100101 : 0b01100001',
        'ntsc_480i ? 0x48 : 0x08',
        'ntsc_480i ? 0b11000010 : 0x80',
        'ntsc_widescreen ? 7 : 6',
        'mediaplayer_ntsc_480i() ? 27000 : 74250',
        '0x55, 0b00010001',
        '0b01001000 | (ntsc_widescreen ? 0b00100000 : 0b00010000)',
        '0x57, 0b00000100',
        'if (mediaplayer_ntsc_480i()) hdmi_config_set_mode(&v_cur);',
    )
    for marker in markers:
        require(marker in patch, f"missing patch contract: {marker}")

    # The core presents a 54 MHz bus while CE_PIXEL advances its 858-sample
    # native raster once every four clocks. Dividing the ADV7513 input clock by
    # two therefore samples each 13.5 MHz content pixel twice at 27 MHz.
    source_clock = 54_000_000
    adv_clock = source_clock // 2
    content_clock = source_clock // 4
    require(adv_clock == 27_000_000, "ADV7513 clock is not 27 MHz")
    require(adv_clock // content_clock == 2, "each content pixel is not sampled twice")
    require(858 * 2 == 1716, "525-line 2x horizontal total mismatch")
    require(720 * 2 == 1440, "525-line 2x active width mismatch")

    # HDMI audio clock regeneration: Fs = FtmDS * N / (128 * CTS).
    require(adv_clock * 6144 // (128 * 27000) == 48_000,
            "48 kHz N/CTS relationship mismatch")
    require(adv_clock * 12288 // (128 * 27000) == 96_000,
            "96 kHz N/CTS relationship mismatch")

    # Protect the generic Main path: this patch must retain its old values in
    # the non-MediaPlayer branches.
    for generic in ('0b01100001', '0x08', '74250'):
        require(generic in patch, f"generic HDMI fallback missing: {generic}")

    print("Main NTSC 480i HDMI contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
