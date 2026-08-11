// kate - Decoupled MPEG2 display framebuffer proof-of-concept.
// Captures 720x480 luminance at decoder speed and reads it independently
// from the 800x600 MiSTer video raster.

module mpeg2_luma_framebuffer
(
	input  wire        reset,

	// MPEG2 resampler side - 54 MHz.
	input  wire        wr_clk,
	input  wire [7:0]  wr_y,
	input  wire [2:0]  wr_position,
	input  wire        wr_en,

	// Independent video side - 40 MHz.
	input  wire        rd_clk,
	input  wire [11:0] h_pos,
	input  wire [11:0] v_pos,
	input  wire        pixel_en,
	input  wire        h_sync,
	input  wire        v_sync,

	output reg  [7:0]  video_y,
	output reg         video_de,
	output reg         video_hs,
	output reg         video_vs
);

localparam integer SRC_WIDTH  = 720;
localparam integer SRC_HEIGHT = 480;
localparam integer FB_SIZE    = SRC_WIDTH * SRC_HEIGHT;

// Same codes used by MPEG2FPGA resample/mixer.
localparam [2:0]
	ROW_0_COL_0    = 3'b000,
	ROW_1_COL_0    = 3'b001,
	ROW_X_COL_0    = 3'b010,
	ROW_X_COL_X    = 3'b011,
	ROW_X_COL_LAST = 3'b100;

// 720 x 480 x 8 = 2,764,800 bits.
(* ramstyle = "M10K" *) reg [7:0] framebuffer [0:FB_SIZE-1];

reg [18:0] wr_addr;
reg [18:0] wr_line_base;
reg [8:0]  wr_line;

// -------------------------------------------------------------------------
// Write side.
//
// MPEG2FPGA provides explicit first-pixel-of-line position markers.
// Pauses between pixels don't matter here: we advance only on wr_en.
// -------------------------------------------------------------------------

always @(posedge wr_clk) begin
	if (reset) begin
		wr_addr      <= 19'd0;
		wr_line_base <= 19'd0;
		wr_line      <= 9'd0;
	end
	else if (wr_en) begin
		case (wr_position)

			ROW_0_COL_0: begin
				framebuffer[0] <= wr_y;
				wr_addr        <= 19'd1;
				wr_line_base   <= 19'd0;
				wr_line        <= 9'd0;
			end

			ROW_1_COL_0: begin
				framebuffer[19'd720] <= wr_y;
				wr_addr              <= 19'd721;
				wr_line_base         <= 19'd720;
				wr_line              <= 9'd1;
			end

			ROW_X_COL_0: begin
				if (wr_line < SRC_HEIGHT-1) begin
					framebuffer[wr_line_base + 19'd720] <= wr_y;
					wr_line_base <= wr_line_base + 19'd720;
					wr_addr      <= wr_line_base + 19'd721;
					wr_line      <= wr_line + 1'b1;
				end
			end

			default: begin
				if ((wr_line < SRC_HEIGHT) && (wr_addr < FB_SIZE)) begin
					framebuffer[wr_addr] <= wr_y;
					wr_addr <= wr_addr + 1'b1;
				end
			end

		endcase
	end
end

// -------------------------------------------------------------------------
// Read side.
//
// Center 720x480 inside the stable 800x600 SVGA raster:
//
//       X = 40..759
//       Y = 60..539
//
// This side never waits for MPEG2. It simply scans the most recently
// captured contents of framebuffer at the video clock.
// -------------------------------------------------------------------------

wire source_window =
	pixel_en &&
	(h_pos >= 12'd40)  && (h_pos < 12'd760) &&
	(v_pos >= 12'd60)  && (v_pos < 12'd540);

wire [18:0] source_addr =
	((v_pos - 12'd60) * SRC_WIDTH) +
	 (h_pos - 12'd40);

always @(posedge rd_clk) begin
	if (reset) begin
		video_y  <= 8'd0;
		video_de <= 1'b0;
		video_hs <= 1'b0;
		video_vs <= 1'b0;
	end
	else begin
		video_de <= pixel_en;
		video_hs <= h_sync;
		video_vs <= v_sync;

		if (source_window)
			video_y <= framebuffer[source_addr];
		else
			video_y <= 8'd0;
	end
end

endmodule
