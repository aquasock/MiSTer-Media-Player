// kate - Fixed presentation raster for MiSTer-Media-Player Phase 1G.
//
// This module deliberately has no MPEG inputs.  The compressed stream can
// therefore change framebuffer contents, but it cannot change display timing.
//
// Entry 280: the 40 MHz dot clock and the 800x600 active area are unchanged,
// but blanking is retimed to 1000x800 total so the refresh is exactly 50.000 Hz
// instead of 60.3165 Hz.  This makes every 25 fps presentation slot a uniform
// two-refresh 40.000 ms window rather than the alternating 33.158/49.738 ms
// windows the 60 Hz grid produced.  The 88-pixel back porch is deliberately
// preserved because it is the framebuffer line-fetch window; the reduction is
// taken from the front porch and sync width.  CADENCE_STEP_25FPS in the
// presentation scheduler is the refresh period and must track this geometry.
//
// Timing is the 800x600, 40 MHz-pixel-clock geometry:
//   horizontal: 800 active + 16 front +  96 sync + 88 back = 1000
//   vertical:   600 active +  1 front +   4 sync + 195 back =  800
// Both sync pulses are positive polarity for this mode.

module mpeg2_video_svga_800x600
(
	input  wire        clk,
	input  wire        reset,

	output wire [11:0] h_pos,
	output wire [11:0] v_pos,
	output wire        pixel_en,
	output wire        h_sync,
	output wire        v_sync
);

localparam integer H_ACTIVE = 800;
localparam integer H_FRONT  = 16;
localparam integer H_SYNC   = 96;
localparam integer H_BACK   = 88;
localparam integer H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

localparam integer V_ACTIVE = 600;
localparam integer V_FRONT  = 1;
localparam integer V_SYNC   = 4;
localparam integer V_BACK   = 195;
localparam integer V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

reg [11:0] h_count;
reg [11:0] v_count;

always @(posedge clk) begin
	if (reset) begin
		h_count <= 12'd0;
		v_count <= 12'd0;
	end
	else if (h_count == H_TOTAL-1) begin
		h_count <= 12'd0;

		if (v_count == V_TOTAL-1)
			v_count <= 12'd0;
		else
			v_count <= v_count + 12'd1;
	end
	else begin
		h_count <= h_count + 12'd1;
	end
end

assign h_pos = h_count;
assign v_pos = v_count;

assign pixel_en =
	(h_count < H_ACTIVE) &&
	(v_count < V_ACTIVE);

assign h_sync =
	(h_count >= H_ACTIVE + H_FRONT) &&
	(h_count <  H_ACTIVE + H_FRONT + H_SYNC);

assign v_sync =
	(v_count >= V_ACTIVE + V_FRONT) &&
	(v_count <  V_ACTIVE + V_FRONT + V_SYNC);

endmodule
