//============================================================================
// MiSTer Media Player - native-output timing isolation pattern
//
// Static field-invariant vertical bars retain the established native timing
// isolation view. The moving mode adds a pair-identical narrow bar which holds
// for thirty complete frames, jumps ninety-six pixels and wraps after seven
// positions. Both modes exercise native clock/sync generation and MiSTer's
// processed-HDMI path while bypassing all framebuffer, cache and DDRAM pixels.
//============================================================================
module mpeg2_native_timing_pattern
(
    input  wire        clk,
    input  wire        reset,
    input  wire        moving,
    input  wire        frame_window,
    input  wire [11:0] h_pos,
    input  wire [11:0] v_pos,
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

localparam [11:0] MOVING_FIRST_X = 12'd48;
localparam [11:0] MOVING_LAST_X  = 12'd624;
localparam [11:0] MOVING_STEP_X  = 12'd96;
localparam [11:0] MOVING_WIDTH   = 12'd16;

reg        frame_window_d;
reg [4:0]  moving_hold_frames;
reg [11:0] moving_bar_x;

wire [7:0] moving_field_row = v_pos[8:1];
wire moving_reference_line =
    (moving_field_row == 8'd60) || (moving_field_row == 8'd180);
wire moving_bar_pixel =
    (h_pos >= moving_bar_x) &&
    (h_pos < (moving_bar_x + MOVING_WIDTH));

always @(posedge clk) begin
    if (reset || !moving) begin
        frame_window_d    <= 1'b0;
        moving_hold_frames <= 5'd0;
        moving_bar_x      <= MOVING_FIRST_X;
    end
    else begin
        frame_window_d <= frame_window;
        if (frame_window && !frame_window_d) begin
            if (moving_hold_frames == 5'd29) begin
                moving_hold_frames <= 5'd0;
                if (moving_bar_x == MOVING_LAST_X)
                    moving_bar_x <= MOVING_FIRST_X;
                else
                    moving_bar_x <= moving_bar_x + MOVING_STEP_X;
            end
            else begin
                moving_hold_frames <= moving_hold_frames + 5'd1;
            end
        end
    end
end

always @* begin
    video_r = 8'h00;
    video_g = 8'h00;
    video_b = 8'h00;
    if (pixel_en) begin
        if (moving) begin
            video_r = 8'h10;
            video_g = 8'h10;
            video_b = 8'h10;
            if (moving_reference_line) begin
                video_r = 8'h50;
                video_g = 8'h50;
                video_b = 8'h50;
            end
            if (moving_bar_pixel) begin
                video_r = 8'hbf;
                video_g = 8'hbf;
                video_b = 8'hbf;
            end
        end else if (h_pos < 12'd90) begin
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
