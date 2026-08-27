// UNVALIDATED: see run_interlaced_p_pixels.sh.  The progressive control
// through this same path mismatches on 64.7% of samples, so the oracle format
// is wrong and no result here is meaningful yet.
//
// Entry 550: pixel-accurate reconstruction of an interlaced 480i stream that
// contains P pictures.  The interlaced regression is intra-only and the
// progressive pixel regression is 128x96, so this combination -- the one an
// ordinary 480i programme stream actually uses -- had no vehicle before now.
`timescale 1ns/1ps

module tb_h262_interlaced_p_pixels #(
    parameter integer MEMORY_READ_LATENCY=1,
    parameter integer SWAP_WINDOW_CYCLES=10000,
    parameter integer STALL_TRACE_CYCLES=0
);
    tb_h262_live_raster_soak #(
        .MIXED_PIXEL_MODE(1),
        .PIXEL_WIDTH(720),
        .PIXEL_HEIGHT(480),
        .PIXEL_PICTURES(8),
        .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY),
        .SWAP_WINDOW_CYCLES(SWAP_WINDOW_CYCLES),
        .STALL_TRACE_CYCLES(STALL_TRACE_CYCLES)
    ) regression();
endmodule
