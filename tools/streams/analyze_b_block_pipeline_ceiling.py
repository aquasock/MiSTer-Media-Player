#!/usr/bin/env python3
"""Replay serial B block fetch/retire events through two logical banks."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Block:
    temporal_reference: int
    mbi: int
    blk: int
    direction: int
    start: int
    fetched: int | None = None
    retire: int | None = None


@dataclass
class Picture:
    temporal_reference: int
    blocks: list[Block] = field(default_factory=list)


def read_pictures(path: Path) -> list[Picture]:
    pictures: list[Picture] = []
    picture: Picture | None = None
    active: Block | None = None
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            event = row["event"]
            cycle = int(row["cycle"])
            temporal_reference = int(row["temporal_reference"])
            mbi = int(row["mbi"])
            blk = int(row["blk"])
            direction = int(row["direction"])
            identity = (temporal_reference, mbi, blk, direction)
            if event == "START":
                if active is not None:
                    raise ValueError(f"START before prior RETIRE: {row}")
                if picture is None or (mbi == 0 and blk == 0):
                    picture = Picture(temporal_reference)
                    pictures.append(picture)
                elif picture.temporal_reference != temporal_reference:
                    raise ValueError(f"picture changed away from block zero: {row}")
                active = Block(*identity, start=cycle)
                picture.blocks.append(active)
            elif event == "FETCHED":
                if active is None or identity != (
                    active.temporal_reference,
                    active.mbi,
                    active.blk,
                    active.direction,
                ):
                    raise ValueError(f"FETCHED identity mismatch: {row}")
                if active.fetched is not None:
                    raise ValueError(f"duplicate FETCHED: {row}")
                active.fetched = cycle
            elif event == "RETIRE":
                if active is None or identity != (
                    active.temporal_reference,
                    active.mbi,
                    active.blk,
                    active.direction,
                ):
                    raise ValueError(f"RETIRE identity mismatch: {row}")
                if active.fetched is None or active.retire is not None:
                    raise ValueError(f"RETIRE before FETCHED or duplicate: {row}")
                active.retire = cycle
                active = None
            else:
                raise ValueError(f"invalid event: {row}")
    if active is not None:
        raise ValueError(f"incomplete final block: {active}")
    if not pictures:
        raise ValueError("trace contains no B blocks")
    return pictures


def replay(picture: Picture) -> tuple[int, int, int, int, int]:
    if not picture.blocks:
        raise ValueError(f"picture has no predicted blocks: {picture}")
    producer: list[int] = []
    consumer: list[int] = []
    gaps = 0
    for index, block in enumerate(picture.blocks):
        assert block.fetched is not None and block.retire is not None
        prior_retire = (
            picture.blocks[index - 1].retire if index else block.start
        )
        assert prior_retire is not None
        gap = block.start - prior_retire
        fetch = block.fetched - block.start
        consume_remainder = block.retire - block.fetched
        if min(gap, fetch, consume_remainder) < 0:
            raise ValueError(f"negative block interval: {block}")
        gaps += gap
        producer.append(gap + fetch)
        consumer.append(consume_remainder)

    producer_end = [producer[0]]
    consumer_end = [producer_end[0] + consumer[0]]
    for index in range(1, len(producer)):
        bank_release = consumer_end[index - 2] if index >= 2 else 0
        producer_start = max(producer_end[index - 1], bank_release)
        producer_end.append(producer_start + producer[index])
        consumer_start = max(producer_end[index], consumer_end[index - 1])
        consumer_end.append(consumer_start + consumer[index])

    first = picture.blocks[0].start
    last = picture.blocks[-1].retire
    assert last is not None
    serial = last - first
    return serial, consumer_end[-1], sum(producer), sum(consumer), gaps


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--total-cycles", type=int)
    args = parser.parse_args()

    totals = [0, 0, 0, 0, 0, 0, 0]
    for picture in read_pictures(args.trace):
        serial, overlapped, producer, consumer, gaps = replay(picture)
        totals[0] += 1
        totals[1] += len(picture.blocks)
        totals[2] += serial
        totals[3] += overlapped
        totals[4] += producer
        totals[5] += consumer
        totals[6] += gaps
    pictures, blocks, serial, overlapped, producer, consumer, gaps = totals
    saved = serial - overlapped
    percent = 100.0 * saved / serial if serial else 0.0
    message = (
        f"B pictures={pictures} blocks={blocks} serial={serial} "
        f"two_bank_upper={overlapped} saved={saved} percent={percent:.2f} "
        f"fetch={producer-gaps} setup_gaps={gaps} "
        f"consumer_remainder={consumer}"
    )
    if args.total_cycles is not None:
        whole_percent = 100.0 * saved / args.total_cycles
        message += (
            f" total_cycles={args.total_cycles} "
            f"whole_trace_upper_percent={whole_percent:.2f}"
        )
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
