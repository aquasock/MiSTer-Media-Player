// kate - Decoupled MPEG2 luma framebuffer.
//
// Port A: MPEG2 resampler writes at 54 MHz.
// Port B: independent SVGA raster reads at 40 MHz.
//
// Explicit altsyncram is used because Quartus 17 will otherwise implement
// this mixed-clock framebuffer as registers instead of M10K RAM.

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

// MPEG2FPGA position codes.
localparam [2:0]
	ROW_0_COL_0    = 3'b000,
	ROW_1_COL_0    = 3'b001,
	ROW_X_COL_0    = 3'b010;

// -------------------------------------------------------------------------
// Write-side address generation.
// -------------------------------------------------------------------------

reg [18:0] wr_address;
reg [18:0] wr_line_base;
reg [8:0]  wr_line;

reg [18:0] ram_wr_address;
reg [7:0]  ram_wr_data;
reg        ram_wr_en;

always @(posedge wr_clk) begin
	if (reset) begin
		wr_address     <= 19'd0;
		wr_line_base   <= 19'd0;
		wr_line        <= 9'd0;

		ram_wr_address <= 19'd0;
		ram_wr_data    <= 8'd0;
		ram_wr_en      <= 1'b0;
	end
	else begin
		ram_wr_en <= 1'b0;

		if (wr_en) begin
			case (wr_position)

				ROW_0_COL_0: begin
					ram_wr_address <= 19'd0;
					ram_wr_data    <= wr_y;
					ram_wr_en      <= 1'b1;

					wr_address     <= 19'd1;
					wr_line_base   <= 19'd0;
					wr_line        <= 9'd0;
				end

				ROW_1_COL_0: begin
					ram_wr_address <= 19'd720;
					ram_wr_data    <= wr_y;
					ram_wr_en      <= 1'b1;

					wr_address     <= 19'd721;
					wr_line_base   <= 19'd720;
					wr_line        <= 9'd1;
				end

				ROW_X_COL_0: begin
					if (wr_line < SRC_HEIGHT-1) begin
						ram_wr_address <= wr_line_base + 19'd720;
						ram_wr_data    <= wr_y;
						ram_wr_en      <= 1'b1;

						wr_line_base   <= wr_line_base + 19'd720;
						wr_address     <= wr_line_base + 19'd721;
						wr_line        <= wr_line + 1'b1;
					end
				end

				default: begin
					if ((wr_line < SRC_HEIGHT) &&
					    (wr_address < FB_SIZE)) begin

						ram_wr_address <= wr_address;
						ram_wr_data    <= wr_y;
						ram_wr_en      <= 1'b1;

						wr_address <= wr_address + 1'b1;
					end
				end

			endcase
		end
	end
end

// -------------------------------------------------------------------------
// Read-side address generation.
//
// 720x480 centered in 800x600:
// X = 40..759
// Y = 60..539
// -------------------------------------------------------------------------

wire source_window =
	pixel_en &&
	(h_pos >= 12'd40)  && (h_pos < 12'd760) &&
	(v_pos >= 12'd60)  && (v_pos < 12'd540);

wire [18:0] ram_rd_address =
	((v_pos - 12'd60) * 19'd720) +
	 (h_pos - 12'd40);

wire [7:0] ram_rd_data;

// -------------------------------------------------------------------------
// True dual-clock framebuffer.
//
// Explicit M10K-backed RAM prevents Quartus from attempting to synthesize
// 345600 x 8 bits as logic/registers.
// -------------------------------------------------------------------------

altsyncram #(
	.operation_mode                 ("DUAL_PORT"),
	.width_a                        (8),
	.widthad_a                      (19),
	.numwords_a                     (FB_SIZE),

	.width_b                        (8),
	.widthad_b                      (19),
	.numwords_b                     (FB_SIZE),

	.outdata_reg_b                  ("UNREGISTERED"),
	.address_reg_b                  ("CLOCK1"),

	.read_during_write_mode_mixed_ports ("OLD_DATA"),

	.ram_block_type                 ("M10K"),
	.intended_device_family         ("Cyclone V")
) framebuffer_ram (
	.clock0         (wr_clk),
	.clock1         (rd_clk),

	.address_a      (ram_wr_address),
	.data_a         (ram_wr_data),
	.wren_a         (ram_wr_en),

	.address_b      (ram_rd_address),
	.q_b            (ram_rd_data),

	.aclr0          (1'b0),
	.aclr1          (1'b0),

	.addressstall_a (1'b0),
	.addressstall_b (1'b0),

	.byteena_a      (1'b1),
	.byteena_b      (1'b1),


	.data_b         (8'd0),
	.wren_b         (1'b0),

	.q_a            ()
);

// -------------------------------------------------------------------------
// altsyncram read address is registered, so delay raster control one clock
// to keep the returned pixel aligned.
// -------------------------------------------------------------------------

reg source_window_d;

always @(posedge rd_clk) begin
	if (reset) begin
		source_window_d <= 1'b0;
		video_y         <= 8'd0;
		video_de        <= 1'b0;
		video_hs        <= 1'b0;
		video_vs        <= 1'b0;
	end
	else begin
		source_window_d <= source_window;

		video_de <= pixel_en;
		video_hs <= h_sync;
		video_vs <= v_sync;

		if (source_window_d)
			video_y <= ram_rd_data;
		else
			video_y <= 8'd0;
	end
end

endmodule
