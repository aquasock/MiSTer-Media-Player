//============================================================================
// MiSTer Media Player - native-output timing isolation pattern
//
// Field-invariant vertical bars contain no one-line vertical detail.  They
// therefore exercise native 480i clock/sync generation while bypassing all
// framebuffer and DDRAM pixel delivery.
//============================================================================
module mpeg2_native_timing_pattern
(
    input  wire [11:0] h_pos,
    input  wire        pixel_en,
    input  wire        h_sync,
    input  wire        v_sync,
    output reg  [7:0]  video_r,
    output reg  [7:0]  video_g,
    output reg  [7:0]  video_b,
    output wire        video_de,
    output wire        video_hs,
    output wire        video_vs
);

assign video_de = pixel_en;
assign video_hs = h_sync;
assign video_vs = v_sync;

always @* begin
    video_r = 8'h00;
    video_g = 8'h00;
    video_b = 8'h00;
    if (pixel_en) begin
        if (h_pos < 12'd90) begin
            video_r = 8'hbf; video_g = 8'hbf; video_b = 8'hbf;
        end else if (h_pos < 12'd180) begin
            video_r = 8'hbf; video_g = 8'hbf; video_b = 8'h00;
        end else if (h_pos < 12'd270) begin
            video_r = 8'h00; video_g = 8'hbf; video_b = 8'hbf;
        end else if (h_pos < 12'd360) begin
            video_r = 8'h00; video_g = 8'hbf; video_b = 8'h00;
        end else if (h_pos < 12'd450) begin
            video_r = 8'hbf; video_g = 8'h00; video_b = 8'hbf;
        end else if (h_pos < 12'd540) begin
            video_r = 8'hbf; video_g = 8'h00; video_b = 8'h00;
        end else if (h_pos < 12'd630) begin
            video_r = 8'h00; video_g = 8'h00; video_b = 8'hbf;
        end else begin
            video_r = 8'h10; video_g = 8'h10; video_b = 8'h10;
        end
    end
end

endmodule
