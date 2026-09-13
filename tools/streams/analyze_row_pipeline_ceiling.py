#!/usr/bin/env python3
"""Replay serial P/B row events through a two-bank producer/consumer model."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class PictureRows:
    engine: str
    temporal_reference: int
    ready: list[int] = field(default_factory=list)
    retire: list[int] = field(default_factory=list)


def read_pictures(path: Path) -> list[PictureRows]:
    pictures: list[PictureRows] = []
    active: dict[str, PictureRows | None] = {"P": None, "B": None}
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            engine = row["engine"]
            event = row["event"]
            cycle = int(row["cycle"])
            temporal_reference = int(row["temporal_reference"])
            if engine not in active or event not in {"READY", "RETIRE"}:
                raise ValueError(f"invalid row event: {row}")
            picture = active[engine]
            if event == "READY":
                if picture is None or (
                    picture.temporal_reference != temporal_reference
                    and len(picture.ready) == len(picture.retire)
                ):
                    picture = PictureRows(engine, temporal_reference)
                    pictures.append(picture)
                    active[engine] = picture
                if len(picture.ready) != len(picture.retire):
                    raise ValueError(f"READY before prior RETIRE: {row}")
                picture.ready.append(cycle)
            else:
                if picture is None or len(picture.ready) != len(picture.retire) + 1:
                    raise ValueError(f"RETIRE without READY: {row}")
                if picture.temporal_reference != temporal_reference:
                    raise ValueError(f"temporal reference changed inside row: {row}")
                picture.retire.append(cycle)
    for picture in pictures:
        if len(picture.ready) != len(picture.retire) or not picture.ready:
            raise ValueError(f"incomplete picture trace: {picture}")
    return pictures


def replay(picture: PictureRows) -> tuple[int, int]:
    service = [b - a for a, b in zip(picture.ready, picture.retire)]
    parse = [
        picture.ready[index] - picture.retire[index - 1]
        for index in range(1, len(picture.ready))
    ]
    if min(service) < 0 or (parse and min(parse) < 0):
        raise ValueError(f"negative interval: {picture}")

    serial = picture.retire[-1] - picture.ready[0]
    parse_end = [0]
    service_end = [service[0]]
    for index in range(1, len(service)):
        bank_release = service_end[index - 2] if index >= 2 else 0
        parser_start = max(parse_end[index - 1], bank_release)
        parse_end.append(parser_start + parse[index - 1])
        service_start = max(parse_end[index], service_end[index - 1])
        service_end.append(service_start + service[index])
    return serial, service_end[-1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    totals = {engine: [0, 0, 0] for engine in ("P", "B")}
    for picture in read_pictures(args.trace):
        serial, overlapped = replay(picture)
        values = totals[picture.engine]
        values[0] += 1
        values[1] += serial
        values[2] += overlapped

    for engine, (pictures, serial, overlapped) in totals.items():
        saved = serial - overlapped
        percent = 100.0 * saved / serial if serial else 0.0
        print(
            f"{engine} pictures={pictures} serial={serial} "
            f"two_bank={overlapped} saved={saved} percent={percent:.2f}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
