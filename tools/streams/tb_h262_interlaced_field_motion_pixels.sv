// Entry 695: pixel-accurate reconstruction of a 480i P picture that predicts
// every macroblock with field motion.  The entry 549 interlaced P fixture is
// frame-motion frame-DCT, so it exercises the signalling and none of the field
// prediction mathematics; this vehicle is the other half.
//
// The oracle comes from the fixture generator itself, which computes the
// expected frame with h262common's field reference model and proves it
// byte-identical to FFmpeg's decode of the same bitstream before writing it.
// That is the same arrangement run_mixed_raster_pixels.sh uses, rather than
// the entry 550 interlaced harness, whose progressive control does not pass.
`timescale 1ns/1ps

module tb_h262_interlaced_field_motion_pixels #(
    parameter integer MEMORY_READ_LATENCY=1,
    parameter integer SWAP_WINDOW_CYCLES=10000,
    parameter integer STALL_TRACE_CYCLES=0
);
    tb_h262_live_raster_soak #(
        .MIXED_PIXEL_MODE(1),
        .PIXEL_WIDTH(720),
        .PIXEL_HEIGHT(480),
        .PIXEL_PICTURES(2),
        .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY),
        .SWAP_WINDOW_CYCLES(SWAP_WINDOW_CYCLES),
        .STALL_TRACE_CYCLES(STALL_TRACE_CYCLES)
    ) regression();
endmodule
