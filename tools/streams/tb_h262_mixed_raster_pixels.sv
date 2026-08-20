`timescale 1ns/1ps

module tb_h262_mixed_raster_pixels #(
    parameter integer MEMORY_READ_LATENCY=1
);
    tb_h262_live_raster_soak #(
        .MIXED_PIXEL_MODE(1),
        .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY)
    ) regression();
endmodule
