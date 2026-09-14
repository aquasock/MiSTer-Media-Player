`timescale 1ns/1ps

module tb_h262_mixed_raster_pixels #(
    parameter integer SHARED_IDCT_MODE=0,
    parameter integer IDCT_INTRA_MODE=0,
    parameter integer REFRESH_50_MODE=0,
    parameter integer EOF_CONTROL_MODE=0,
    parameter integer MEMORY_READ_LATENCY=1,
    parameter integer PLAYBACK_CONTROL_MODE=0,
    parameter integer DISPLAY_OWNERSHIP_MODE=0,
    parameter integer SEEK_DISPLAY_RELEASE=1,
    parameter integer SWAP_WINDOW_CYCLES=10000,
    parameter integer STALL_TRACE_CYCLES=0
);
    tb_h262_live_raster_soak #(
        .SHARED_IDCT_MODE(SHARED_IDCT_MODE),
        .IDCT_INTRA_MODE(IDCT_INTRA_MODE),
        .REFRESH_50_MODE(REFRESH_50_MODE),
        .MIXED_PIXEL_MODE(1),
        .EOF_CONTROL_MODE(EOF_CONTROL_MODE),
        .PLAYBACK_CONTROL_MODE(PLAYBACK_CONTROL_MODE),
        .DISPLAY_OWNERSHIP_MODE(DISPLAY_OWNERSHIP_MODE),
        .SEEK_DISPLAY_RELEASE(SEEK_DISPLAY_RELEASE),
        .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY),
        .SWAP_WINDOW_CYCLES(SWAP_WINDOW_CYCLES),
        .STALL_TRACE_CYCLES(STALL_TRACE_CYCLES)
    ) regression();
endmodule
