// Entry 695: pixel-accurate reconstruction of a 480i B picture that predicts
// every macroblock with field motion in both directions.  Each destination
// field averages a forward and a backward field prediction, so one macroblock
// draws on four independently selected reference fields -- the case that makes
// the B engine's field walk a different problem from the P engine's.
//
// The oracle comes from the fixture generator, which computes the expected
// frame with h262common's bidirectional field reference model and proves it
// byte-identical to FFmpeg's decode of the same bitstream before writing it.
`timescale 1ns/1ps

module tb_h262_b_field_motion_pixels #(
    parameter integer MEMORY_READ_LATENCY=1,
    parameter integer SWAP_WINDOW_CYCLES=10000,
    parameter integer STALL_TRACE_CYCLES=0
);
    tb_h262_live_raster_soak #(
        .MIXED_PIXEL_MODE(1),
        .PIXEL_WIDTH(720),
        .PIXEL_HEIGHT(480),
        .PIXEL_PICTURES(3),
        .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY),
        .SWAP_WINDOW_CYCLES(SWAP_WINDOW_CYCLES),
        .STALL_TRACE_CYCLES(STALL_TRACE_CYCLES)
    ) regression();
endmodule
