#!/usr/bin/env python3
"""Calculate strict hardware ceilings for destination-decoupling policies."""

from __future__ import annotations

import argparse
from dataclasses import dataclass


@dataclass(frozen=True)
class Ceiling:
    name: str
    removable_cycles: int
    best_cycles: int
    target_shortfall: int


def ceiling(name: str, measured: int, removable: int, target: int) -> Ceiling:
    best = measured - removable
    return Ceiling(name, removable, best, max(0, best - target))


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Bound destination-safe predecode and fifth-frame gains without "
            "assuming unobserved overlap."
        )
    )
    parser.add_argument("--pictures", type=int, required=True)
    parser.add_argument("--measured-cadence", type=int, required=True)
    parser.add_argument("--target-cadence", type=int, required=True)
    parser.add_argument("--presentation-wait", type=int, required=True)
    parser.add_argument("--destination-wait", type=int, required=True)
    parser.add_argument("--decoder-wait", type=int, required=True)
    parser.add_argument("--additional-decoder-reduction", type=int, default=0)
    parser.add_argument("--target-fps", type=float, default=25.0)
    args = parser.parse_args()

    values = (
        args.pictures,
        args.measured_cadence,
        args.target_cadence,
        args.presentation_wait,
        args.destination_wait,
        args.decoder_wait,
        args.additional_decoder_reduction,
    )
    if any(value < 0 for value in values) or args.pictures < 2:
        parser.error("cycle counts must be nonnegative and pictures at least two")
    if args.measured_cadence < args.target_cadence:
        parser.error("measured cadence is already below the supplied target")
    if args.presentation_wait + args.destination_wait > args.measured_cadence:
        parser.error("wait counters exceed measured cadence")

    # A two-row producer cannot remove more than every destination-hold cycle,
    # even if parsing and transform are free and both rows always cover the
    # complete wait.  This deliberately overstates the bounded architecture.
    two_row = ceiling(
        "two-row-absolute",
        args.measured_cadence,
        args.destination_wait,
        args.target_cadence,
    )

    # Give an ideal fifth frame an even stronger, physically impossible
    # standalone bound: remove every destination and presentation wait cycle
    # at zero cost.  Any remainder cannot be closed by ownership alone.
    fifth = ceiling(
        "fifth-frame-absolute",
        args.measured_cadence,
        args.destination_wait + args.presentation_wait,
        args.target_cadence,
    )

    current_fps = (
        args.target_fps * args.target_cadence / args.measured_cadence
    )
    print(
        f"pictures={args.pictures} measured={args.measured_cadence} "
        f"target={args.target_cadence} measured_fps={current_fps:.6f} "
        f"gap={args.measured_cadence-args.target_cadence}"
    )
    for result in (two_row, fifth):
        best_fps = args.target_fps * args.target_cadence / result.best_cycles
        closes = result.target_shortfall == 0
        print(
            f"policy={result.name} removable={result.removable_cycles} "
            f"best={result.best_cycles} best_fps={best_fps:.6f} "
            f"shortfall={result.target_shortfall} closes={int(closes)}"
        )
    required_decoder = fifth.target_shortfall
    decoder_percent = (
        100.0 * required_decoder / args.decoder_wait if args.decoder_wait else 0.0
    )
    print(
        f"minimum_additional_decoder_reduction={required_decoder} "
        f"decoder_wait_percent={decoder_percent:.2f}"
    )
    combined_best = fifth.best_cycles - args.additional_decoder_reduction
    combined_shortfall = max(0, combined_best - args.target_cadence)
    combined_fps = args.target_fps * args.target_cadence / combined_best
    print(
        f"policy=fifth-plus-decoder reduction="
        f"{args.additional_decoder_reduction} best={combined_best} "
        f"best_fps={combined_fps:.6f} shortfall={combined_shortfall} "
        f"closes={int(combined_shortfall == 0)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
