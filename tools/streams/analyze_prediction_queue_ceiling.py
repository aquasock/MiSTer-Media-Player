#!/usr/bin/env python3
"""Replay an H.262 prediction trace through block-scoped ordered read queues.

The trace comes from tb_h262_live_raster_soak +PRED_TRACE=<path>.  Production
RTL remains unchanged.  Each block's baseline physical misses are treated as
addresses available to a dedicated producer at block start, issued in first-
demand order, and retained for the life of the block.  The default-latency
trace is the conservative compute floor; queue stalls are added only when a
modeled response would arrive after its recorded first demand.
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from pathlib import Path


EXPECTED_HITS = 499_551
EXPECTED_MISSES = 71_329
EXPECTED_BLOCKS = 6_624
SERIALIZED_TEN_CYCLE_BASELINE = 2_919_996
MIXED_HARDWARE_BASELINE_FPS = 14.983129
Y_BASE = 0x06000000
CB_BASE = 0x0600A8C0
CR_BASE = 0x0600D2F0
BANK_OFFSET = 0x00010000


@dataclass
class Block:
    start: int
    engine: int
    temporal_reference: int
    mbi: int
    blk: int
    end: int | None = None
    demands: list[int] = field(default_factory=list)
    misses: list[tuple[int, int]] = field(default_factory=list)


@dataclass
class Trace:
    blocks: list[Block]
    hits: int
    misses: int
    total_cycles: int


def parse_int(value: str) -> int:
    return int(value, 10)


def parse_trace(path: Path) -> Trace:
    blocks: list[Block] = []
    active: Block | None = None
    hits = 0
    misses = 0
    total_cycles = 0

    with path.open(newline="", encoding="ascii") as stream:
        rows = csv.DictReader(stream)
        expected_fields = [
            "cycle",
            "event",
            "engine",
            "temporal_reference",
            "mbi",
            "blk",
            "ei",
            "tap",
            "direction",
            "address",
        ]
        if rows.fieldnames != expected_fields:
            raise ValueError(f"unexpected trace columns: {rows.fieldnames}")

        for row in rows:
            cycle = parse_int(row["cycle"])
            event = row["event"].strip()
            if event == "S":
                if active is not None:
                    raise ValueError(
                        f"nested block at cycle {cycle}; prior block began "
                        f"at {active.start}"
                    )
                active = Block(
                    start=cycle,
                    engine=parse_int(row["engine"]),
                    temporal_reference=parse_int(row["temporal_reference"]),
                    mbi=parse_int(row["mbi"]),
                    blk=parse_int(row["blk"]),
                )
                blocks.append(active)
            elif event == "E":
                if active is None:
                    raise ValueError(f"block end without start at cycle {cycle}")
                active.end = cycle
                active = None
            elif event == "H":
                hits += 1
                if active is None:
                    raise ValueError(f"hit outside a block at cycle {cycle}")
                active.demands.append(int(row["address"], 16))
            elif event == "M":
                misses += 1
                if active is None:
                    raise ValueError(f"miss outside a block at cycle {cycle}")
                address = int(row["address"], 16)
                active.demands.append(address)
                active.misses.append((cycle, address))
            elif event == "Z":
                total_cycles = cycle
            else:
                raise ValueError(f"unknown event {event!r} at cycle {cycle}")

    if active is not None:
        raise ValueError(f"unterminated block beginning at cycle {active.start}")
    if total_cycles == 0:
        raise ValueError("trace has no final Z record")
    return Trace(blocks, hits, misses, total_cycles)


def ordered_completions(count: int, depth: int, latency: int) -> list[int]:
    """Return completion offsets for one-command-per-cycle ordered service."""
    completions: list[int] = []
    previous_accept = -1
    for index in range(count):
        accept = previous_accept + 1
        if index >= depth:
            accept = max(accept, completions[index - depth])
        completion = accept + latency
        completions.append(completion)
        previous_accept = accept
    return completions


def unique_first_misses(block: Block) -> list[tuple[int, int]]:
    seen: set[int] = set()
    result: list[tuple[int, int]] = []
    for cycle, address in block.misses:
        if address not in seen:
            seen.add(address)
            result.append((cycle, address))
    return result


def replay_block(block: Block, depth: int, latency: int) -> tuple[int, int]:
    unique = unique_first_misses(block)
    completions = ordered_completions(len(unique), depth, latency)
    accumulated_stall = 0
    peak_buffer = 0

    for index, (demand_cycle, _address) in enumerate(unique):
        demand_offset = demand_cycle - block.start + accumulated_stall
        if completions[index] > demand_offset:
            accumulated_stall += completions[index] - demand_offset

        resident = 0
        for later in range(index + 1, len(unique)):
            if completions[later] <= demand_offset:
                resident += 1
        peak_buffer = max(peak_buffer, resident)

    return accumulated_stall, peak_buffer


def percentile(values: list[int], numerator: int, denominator: int) -> int:
    if not values:
        return 0
    ordered = sorted(values)
    index = ((len(ordered) - 1) * numerator) // denominator
    return ordered[index]


def validate_block_rectangles(blocks: list[Block]) -> tuple[int, int, int]:
    empty = 0
    single = 0
    dual = 0
    for block in blocks:
        addresses = set(block.demands)
        if not addresses:
            empty += 1
            continue
        stride = 90 if block.blk < 4 else 45
        base = Y_BASE if block.blk < 4 else CB_BASE if block.blk == 4 else CR_BASE
        rectangles: dict[int, set[tuple[int, int]]] = {}
        for address in addresses:
            bank = int(address >= base + BANK_OFFSET)
            offset = address - base - bank * BANK_OFFSET
            row, column = divmod(offset, stride)
            rectangles.setdefault(bank, set()).add((row, column))
        if len(rectangles) == 1:
            single += 1
        elif len(rectangles) == 2:
            dual += 1
        else:
            raise ValueError(
                f"block has {len(rectangles)} reference rectangles: "
                f"engine={block.engine} tr={block.temporal_reference} "
                f"mbi={block.mbi} blk={block.blk}"
            )
        for points in rectangles.values():
            rows = [point[0] for point in points]
            columns = [point[1] for point in points]
            height = max(rows) - min(rows) + 1
            width = max(columns) - min(columns) + 1
            if width > 2 or height > 9 or len(points) != width * height:
                raise ValueError(
                    f"non-rectangular block footprint width={width} "
                    f"height={height} words={len(points)}"
                )
    return empty, single, dual


def analyze(trace: Trace, depths: list[int], latencies: list[int],
            serialized_cycles: int, baseline_fps: float,
            expected_hits: int, expected_misses: int,
            expected_blocks: int) -> None:
    if trace.hits != expected_hits or trace.misses != expected_misses:
        raise ValueError(
            f"trace accounting mismatch hits={trace.hits} misses={trace.misses}"
        )
    if len(trace.blocks) != expected_blocks:
        raise ValueError(f"trace block mismatch blocks={len(trace.blocks)}")
    if any(block.end is None for block in trace.blocks):
        raise ValueError("trace contains an incomplete block")

    empty_rectangles, single_rectangles, dual_rectangles = \
        validate_block_rectangles(trace.blocks)

    unique_miss_counts = [
        len(unique_first_misses(block)) for block in trace.blocks
    ]
    unique_demand_counts = [
        len(set(block.demands)) for block in trace.blocks
    ]
    duplicate_misses = trace.misses - sum(unique_miss_counts)
    print(
        "PREDICTION_QUEUE_TRACE "
        f"cycles={trace.total_cycles} blocks={len(trace.blocks)} "
        f"hits={trace.hits} misses={trace.misses} "
        f"unique_block_miss_words={sum(unique_miss_counts)} "
        f"duplicate_block_misses={duplicate_misses}"
    )
    print(
        "PREDICTION_QUEUE_MISS_CAPACITY "
        f"average={sum(unique_miss_counts) / len(unique_miss_counts):.3f} "
        f"p50={percentile(unique_miss_counts, 50, 100)} "
        f"p95={percentile(unique_miss_counts, 95, 100)} "
        f"p99={percentile(unique_miss_counts, 99, 100)} "
        f"maximum={max(unique_miss_counts)}"
    )
    print(
        "PREDICTION_QUEUE_BLOCK_WORD_CAPACITY "
        f"average={sum(unique_demand_counts) / len(unique_demand_counts):.3f} "
        f"p50={percentile(unique_demand_counts, 50, 100)} "
        f"p95={percentile(unique_demand_counts, 95, 100)} "
        f"p99={percentile(unique_demand_counts, 99, 100)} "
        f"maximum={max(unique_demand_counts)}"
    )
    print(
        "PREDICTION_QUEUE_RECTANGLES "
        f"intra={empty_rectangles} single={single_rectangles} "
        f"dual={dual_rectangles} maximum_width=2 maximum_height=9 "
        "maximum_words=36"
    )

    for latency in latencies:
        for depth in depths:
            stalls = 0
            peak_buffer = 0
            for block in trace.blocks:
                block_stalls, block_peak = replay_block(block, depth, latency)
                stalls += block_stalls
                peak_buffer = max(peak_buffer, block_peak)
            predicted_cycles = trace.total_cycles + stalls
            speedup = serialized_cycles / predicted_cycles
            predicted_fps = baseline_fps * speedup
            reduction = 100.0 * (serialized_cycles - predicted_cycles) / serialized_cycles
            print(
                "PREDICTION_QUEUE_RESULT "
                f"latency={latency} depth={depth} stalls={stalls} "
                f"predicted_cycles={predicted_cycles} "
                f"reduction_percent={reduction:.4f} speedup={speedup:.6f} "
                f"scaled_fps={predicted_fps:.6f} peak_return_buffer={peak_buffer}"
            )

    absolute_speedup = serialized_cycles / trace.total_cycles
    absolute_fps = baseline_fps * absolute_speedup
    print(
        "PREDICTION_QUEUE_ABSOLUTE_CEILING "
        f"cycles={trace.total_cycles} speedup={absolute_speedup:.6f} "
        f"scaled_fps={absolute_fps:.6f}"
    )


def comma_ints(value: str) -> list[int]:
    result = [int(item) for item in value.split(",") if item]
    if not result or any(item <= 0 for item in result):
        raise argparse.ArgumentTypeError("expected positive comma-separated integers")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--depths", type=comma_ints, default=[2, 4, 8, 16])
    parser.add_argument("--latencies", type=comma_ints, default=[1, 10])
    parser.add_argument(
        "--serialized-cycles",
        type=int,
        default=SERIALIZED_TEN_CYCLE_BASELINE,
    )
    parser.add_argument(
        "--baseline-fps",
        type=float,
        default=MIXED_HARDWARE_BASELINE_FPS,
    )
    parser.add_argument("--expected-hits", type=int, default=EXPECTED_HITS)
    parser.add_argument("--expected-misses", type=int, default=EXPECTED_MISSES)
    parser.add_argument("--expected-blocks", type=int, default=EXPECTED_BLOCKS)
    args = parser.parse_args()
    analyze(
        parse_trace(args.trace),
        args.depths,
        args.latencies,
        args.serialized_cycles,
        args.baseline_fps,
        args.expected_hits,
        args.expected_misses,
        args.expected_blocks,
    )


if __name__ == "__main__":
    main()
