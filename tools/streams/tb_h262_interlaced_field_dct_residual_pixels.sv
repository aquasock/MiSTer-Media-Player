// Entry 707: pixel-accurate P and B field-DCT residual reconstruction in
// interlaced frame pictures.  Motion remains frame based so this fixture
// isolates dct_type parsing, metadata transport and coded-luma placement.
`timescale 1ns/1ps

module tb_h262_interlaced_field_dct_residual_pixels #(
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
