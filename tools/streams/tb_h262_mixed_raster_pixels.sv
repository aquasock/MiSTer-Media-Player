`timescale 1ns/1ps

module tb_h262_mixed_raster_pixels;
    tb_h262_live_raster_soak #(.MIXED_PIXEL_MODE(1)) regression();
endmodule
