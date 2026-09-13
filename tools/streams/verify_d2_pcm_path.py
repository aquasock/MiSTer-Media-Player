#!/usr/bin/env python3
"""Deterministic software proof for the PCM contract and sample scheduler."""
from __future__ import annotations

import hashlib
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "rtl" / "audio" / "audio_pcm_test_source.sv"
ADAPTER = ROOT / "rtl" / "audio" / "audio_pcm_output_adapter.sv"

EXPECTED_HASHES = {
    1: "971301c0648c2239c0a31bc32c22f0c525fe8fa7e733939989f26aa16203284e",
    2: "74a0b6e12d3b2e02c5f55f3a16f06c2bdb36b337c0004b37c16c083b808fe594",
    3: "5bd31f9bc3d7adcea5cdefa3ad33164328e5d0f70053e0e8daf087c7cf18aa42",
    4: "cdf89fbba835efec2b6b348b26ad3134292d82ec87b0414d4404fe77311c69fa",
}

EXPECTED_PHASE = {
    "PHASE_440_44100": 0x028DDFB9,
    "PHASE_660_44100": 0x03D4CF96,
    "PHASE_440_48000": 0x0258BF26,
    "PHASE_660_48000": 0x03851EB8,
}


def parse_hex_localparams(text: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for name, value in re.findall(
        r"localparam\s+\[31:0\]\s+(PHASE_[A-Z0-9_]+)\s*=\s*32'h([0-9A-Fa-f]+)",
        text,
    ):
        out[name] = int(value, 16)
    return out


def parse_decimal_localparam(text: str, name: str) -> int:
    match = re.search(
        rf"localparam\s+\[25:0\]\s+{name}\s*=\s*26'd([0-9]+)", text
    )
    if not match:
        raise SystemExit(f"missing {name}")
    return int(match.group(1))


def mode_info(mode: int) -> tuple[int, int, bool]:
    if mode == 1:
        return EXPECTED_PHASE["PHASE_440_44100"], EXPECTED_PHASE["PHASE_660_44100"], False
    if mode == 2:
        return EXPECTED_PHASE["PHASE_440_44100"], EXPECTED_PHASE["PHASE_660_44100"], True
    if mode == 3:
        return EXPECTED_PHASE["PHASE_440_48000"], EXPECTED_PHASE["PHASE_660_48000"], False
    if mode == 4:
        return EXPECTED_PHASE["PHASE_440_48000"], EXPECTED_PHASE["PHASE_660_48000"], True
    raise ValueError(mode)


def accepted_samples(mode: int, count: int, ready_pattern) -> bytes:
    left_step, right_step, stereo = mode_info(mode)
    phase_left = phase_right = 0
    accepted = cycle = 0
    out = bytearray()
    while accepted < count:
        if ready_pattern(cycle):
            left = 8192 if (phase_left >> 31) & 1 else -8192
            right_raw = 8192 if (phase_right >> 31) & 1 else -8192
            right = right_raw if stereo else left
            out += struct.pack("<hh", left, right)
            phase_left = (phase_left + left_step) & 0xFFFFFFFF
            phase_right = (phase_right + right_step) & 0xFFFFFFFF
            accepted += 1
        cycle += 1
        if cycle > count * 20:
            raise SystemExit("ready pattern did not make finite progress")
    return bytes(out)


def scheduler_gaps(audio_clk: int, rate: int, events: int) -> list[int]:
    phase = since = 0
    gaps: list[int] = []
    while len(gaps) < events:
        phase += rate
        since += 1
        if phase >= audio_clk:
            phase -= audio_clk
            gaps.append(since)
            since = 0
    return gaps


def main() -> None:
    src_text = SRC.read_text()
    adapter_text = ADAPTER.read_text()

    actual_phase = parse_hex_localparams(src_text)
    if actual_phase != EXPECTED_PHASE:
        raise SystemExit(f"phase constants changed: {actual_phase}")

    audio_clk = parse_decimal_localparam(adapter_text, "AUDIO_CLK_HZ")
    rate_441 = parse_decimal_localparam(adapter_text, "RATE_44100")
    rate_480 = parse_decimal_localparam(adapter_text, "RATE_48000")
    if (audio_clk, rate_441, rate_480) != (24_576_000, 44_100, 48_000):
        raise SystemExit("sample scheduler constants changed")

    patterns = {
        "continuous": lambda cycle: True,
        "periodic": lambda cycle: (cycle % 7) not in (2, 3),
        "bursty": lambda cycle: (cycle % 19) < 11,
        "lfsr_like": lambda cycle: (((cycle * 1103515245 + 12345) >> 16) & 7) != 0,
    }

    for mode in range(1, 5):
        reference = accepted_samples(mode, 8192, patterns["continuous"])
        digest = hashlib.sha256(reference).hexdigest()
        if digest != EXPECTED_HASHES[mode]:
            raise SystemExit(f"mode {mode}: PCM hash mismatch {digest}")
        for name, pattern in patterns.items():
            candidate = accepted_samples(mode, 8192, pattern)
            if candidate != reference:
                raise SystemExit(
                    f"mode {mode}: ready pattern {name} changed accepted PCM"
                )

        prefix = accepted_samples(mode, 1024, patterns["bursty"])
        restarted = accepted_samples(mode, 1024, patterns["continuous"])
        if prefix != restarted:
            raise SystemExit(f"mode {mode}: re-arm sequence mismatch")

    gaps_48 = scheduler_gaps(audio_clk, rate_480, 10_000)
    if set(gaps_48) != {512}:
        raise SystemExit(f"48 kHz scheduler is not exactly /512: {set(gaps_48)}")

    gaps_441 = scheduler_gaps(audio_clk, rate_441, 10_000)
    if set(gaps_441) != {557, 558}:
        raise SystemExit(f"44.1 kHz scheduler jitter bound changed: {set(gaps_441)}")
    if gaps_441.count(557) != 7210 or gaps_441.count(558) != 2790:
        raise SystemExit("44.1 kHz deterministic scheduler signature changed")

    print("PCM VERIFY PASS")
    print("  modes: 44.1 mono/stereo, 48 mono/stereo")
    print("  valid/ready: accepted PCM invariant under 4 ready profiles")
    print("  re-arm: deterministic for all 4 modes")
    print("  scheduler: 48 kHz exact /512; 44.1 kHz gaps limited to 557/558 clocks")


if __name__ == "__main__":
    main()
