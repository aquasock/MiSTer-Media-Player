#!/usr/bin/env python3
"""Model one-run-ahead decode using the existing two B scratch banks."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Picture:
    identity: int
    picture_type: int
    temporal_reference: int
    start: int
    ready: int | None = None
    start_hold: int = 0
    ready_hold: int = 0


def read_trace(path: Path) -> tuple[list[Picture], list[int]]:
    pictures: dict[int, Picture] = {}
    decode_order: list[Picture] = []
    displayed: list[int] = []
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            event = row["event"]
            identity = int(row["id"])
            if event == "START":
                picture = Picture(
                    identity=identity,
                    picture_type=int(row["type"]),
                    temporal_reference=int(row["temporal_reference"]),
                    start=int(row["cycle"]),
                    start_hold=int(row["hold_total"]),
                )
                pictures[identity] = picture
                decode_order.append(picture)
            elif event == "READY":
                picture = pictures[identity]
                if picture.ready is not None:
                    raise ValueError(f"duplicate READY: {row}")
                picture.ready = int(row["cycle"])
                picture.ready_hold = int(row["hold_total"])
            elif event == "DISPLAY":
                displayed.append(identity)
            else:
                raise ValueError(f"invalid trace event: {row}")
    if any(picture.ready is None for picture in decode_order):
        raise ValueError("trace contains an incomplete decoded picture")
    return decode_order, displayed


def display_order(pictures: list[Picture]) -> list[int]:
    groups: list[list[Picture]] = []
    group: list[Picture] = []
    for picture in pictures:
        if picture.picture_type == 1 and group:
            groups.append(group)
            group = []
        group.append(picture)
    if group:
        groups.append(group)
    order: list[int] = []
    for pictures_in_gop in groups:
        order.extend(
            picture.identity
            for picture in sorted(
                pictures_in_gop, key=lambda item: item.temporal_reference
            )
        )
    return order


def scaled_work(
    pictures: list[Picture], type_totals: dict[int, int], input_cycles: int
) -> tuple[list[int], list[int]]:
    raw_work: list[int] = []
    raw_gap: list[int] = []
    for index, picture in enumerate(pictures):
        assert picture.ready is not None
        raw_work.append(picture.ready - picture.start)
        if index == 0:
            raw_gap.append(0)
        else:
            prior = pictures[index - 1]
            assert prior.ready is not None
            total_gap = picture.start - prior.ready
            held = picture.start_hold - prior.ready_hold
            raw_gap.append(max(0, total_gap - held))
    combined = [work + gap for work, gap in zip(raw_work, raw_gap)]
    scaled = [0] * len(pictures)
    for picture_type, target in type_totals.items():
        indexes = [
            index
            for index, picture in enumerate(pictures)
            if picture.picture_type == picture_type
        ]
        denominator = sum(combined[index] for index in indexes)
        if denominator <= 0:
            raise ValueError(f"no work for picture type {picture_type}")
        assigned = 0
        for index in indexes[:-1]:
            value = combined[index] * target // denominator
            scaled[index] = value
            assigned += value
        scaled[indexes[-1]] = target - assigned
    if input_cycles:
        denominator = sum(combined)
        assigned = 0
        for index in range(len(pictures) - 1):
            value = combined[index] * input_cycles // denominator
            scaled[index] += value
            assigned += value
        scaled[-1] += input_cycles - assigned
    return scaled, raw_gap


def simulate(
    pictures: list[Picture], work: list[int], cadence: int
) -> tuple[int, int, int]:
    order = display_order(pictures)
    by_id = {picture.identity: picture for picture in pictures}
    ready_time: dict[int, int] = {}
    scratch_bank: dict[int, int] = {}
    occupancy: list[int | None] = [None, None]
    current_scratch: int | None = None
    next_display = 0
    last_display: int | None = None
    first_display_time: int | None = None
    now = 0
    blocked = 0

    def present_one(force: bool, limit: int | None = None) -> bool:
        nonlocal next_display, last_display, first_display_time
        nonlocal current_scratch, now
        if next_display >= len(order):
            return False
        identity = order[next_display]
        if identity not in ready_time:
            return False
        due = ready_time[identity] if last_display is None else last_display + cadence
        event_time = max(due, ready_time[identity])
        if not force and limit is not None and event_time > limit:
            return False
        now = max(now, event_time)
        picture = by_id[identity]
        old_scratch = current_scratch
        current_scratch = scratch_bank.get(identity)
        if old_scratch is not None and old_scratch != current_scratch:
            occupancy[old_scratch] = None
        if picture.picture_type != 3:
            current_scratch = None
        last_display = event_time
        if first_display_time is None:
            first_display_time = event_time
        next_display += 1
        return True

    for index, picture in enumerate(pictures):
        while present_one(False, now):
            pass
        if picture.picture_type == 3:
            while all(item is not None for item in occupancy):
                before = now
                if not present_one(True):
                    raise ValueError("two-bank queue deadlocked before B decode")
                blocked += now - before
            bank = 0 if occupancy[0] is None else 1
            occupancy[bank] = picture.identity
            scratch_bank[picture.identity] = bank
        completion = now + work[index]
        while present_one(False, completion):
            pass
        now = max(now, completion)
        ready_time[picture.identity] = now

    while next_display < len(order):
        if not present_one(True):
            raise ValueError("display order references an undecoded picture")
    assert last_display is not None and first_display_time is not None
    return last_display - first_display_time, blocked, len(order)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--i-cycles", type=int, required=True)
    parser.add_argument("--p-cycles", type=int, required=True)
    parser.add_argument("--b-cycles", type=int, required=True)
    parser.add_argument("--cadence", type=int, default=2_160_000)
    parser.add_argument("--input-cycles", type=int, default=0)
    parser.add_argument("--measured-cadence", type=int)
    args = parser.parse_args()

    pictures, displayed = read_trace(args.trace)
    order = display_order(pictures)
    if displayed and displayed != order[1:]:
        raise ValueError("traced display sequence does not match temporal order")
    work, gaps = scaled_work(
        pictures,
        {1: args.i_cycles, 2: args.p_cycles, 3: args.b_cycles},
        args.input_cycles,
    )
    cadence_cycles, blocked, count = simulate(pictures, work, args.cadence)
    fps = args.cadence * 25.0 * (count - 1) / cadence_cycles
    print(
        f"pictures={count} modeled_cadence={cadence_cycles} "
        f"modeled_fps={fps:.6f} scratch_blocked={blocked} "
        f"decode_work={sum(work)} nonpresentation_gap={sum(gaps)}"
    )
    if args.measured_cadence is not None:
        saved = args.measured_cadence - cadence_cycles
        print(
            f"measured_cadence={args.measured_cadence} saved={saved} "
            f"percent={100.0*saved/args.measured_cadence:.2f}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
