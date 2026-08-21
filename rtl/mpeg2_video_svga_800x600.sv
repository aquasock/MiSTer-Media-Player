// kate - Fixed presentation raster for MiSTer-Media-Player Phase 1G.
//
// This module deliberately has no MPEG inputs.  The compressed stream can
// therefore change framebuffer contents, but it cannot change display timing.
//
// Timing is the standard 800x600, 40 MHz-pixel-clock geometry:
//   horizontal: 800 active + 40 front + 128 sync + 88 back = 1056
//   vertical:   600 active +  1 front +   4 sync + 23 back =  628
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
localparam integer H_FRONT  = 40;
localparam integer H_SYNC   = 128;
localparam integer H_BACK   = 88;
localparam integer H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

localparam integer V_ACTIVE = 600;
localparam integer V_FRONT  = 1;
localparam integer V_SYNC   = 4;
localparam integer V_BACK   = 23;
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
