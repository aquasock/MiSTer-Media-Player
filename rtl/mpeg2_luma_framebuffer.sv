// kate - Decoupled MPEG2 luma framebuffer.
//
// Phase 1I stores all four luminance blocks of the first 4:2:0 intra
// macroblock.  The decoder writes explicit picture X/Y coordinates at 54 MHz,
// while the independent fixed SVGA raster reads at 40 MHz.
//
// To keep the proof unambiguous, RAM is exposed only after all four 8x8 Y
// blocks have completed.  The rest of the 720x480 source window remains the
// fixed diagnostic background so uninitialised RAM cannot look like decoded
// picture data.
//
// Explicit altsyncram is retained because Quartus 17 otherwise implements this
// mixed-clock framebuffer poorly or attempts to use registers.

module mpeg2_luma_framebuffer
(
    input  wire        reset,

    // New H.262 reconstruction side - 54 MHz.
    input  wire        wr_clk,
    input  wire [7:0]  wr_y,
    input  wire [11:0] wr_x_pos,
    input  wire [11:0] wr_y_pos,
    input  wire        wr_en,
    input  wire        wr_macroblock_start,
    input  wire        wr_block_start,
    input  wire        wr_block_complete,

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

// -------------------------------------------------------------------------
// Write-side address generation and first-macroblock publication.
// -------------------------------------------------------------------------

reg [18:0] ram_wr_address;
reg [7:0]  ram_wr_data;
reg        ram_wr_en;

wire [18:0] wr_linear_address =
    (wr_y_pos * 19'd720) + wr_x_pos;

// kate - Phase 1I publication descriptor.  macroblock_origin_* are captured
// from block 0's first reconstructed sample.  The descriptor is not published
// until the fourth block-complete pulse, so the read side never exposes a
// partially reconstructed 16x16 macroblock.
reg [11:0] macroblock_origin_x_wr;
reg [11:0] macroblock_origin_y_wr;
reg [2:0]  completed_luma_blocks_wr;
reg        macroblock_present_wr;
reg        macroblock_active_wr;

always @(posedge wr_clk) begin
    if (reset) begin
        ram_wr_address          <= 19'd0;
        ram_wr_data             <= 8'd0;
        ram_wr_en               <= 1'b0;
        macroblock_origin_x_wr  <= 12'd0;
        macroblock_origin_y_wr  <= 12'd0;
        completed_luma_blocks_wr<= 3'd0;
        macroblock_present_wr   <= 1'b0;
        macroblock_active_wr    <= 1'b0;
    end
    else begin
        ram_wr_en <= 1'b0;

        if (wr_macroblock_start) begin
            completed_luma_blocks_wr <= 3'd0;
            macroblock_present_wr    <= 1'b0;
            macroblock_active_wr     <= 1'b1;
        end

        if (wr_block_start && macroblock_active_wr &&
            (completed_luma_blocks_wr == 3'd0)) begin
            // Block 0 is the upper-left 8x8 block; its first pixel therefore
            // carries the 16x16 macroblock's picture-space origin.
            macroblock_origin_x_wr <= wr_x_pos;
            macroblock_origin_y_wr <= wr_y_pos;
        end

        if (wr_block_complete && macroblock_active_wr) begin
            if (completed_luma_blocks_wr == 3'd3) begin
                completed_luma_blocks_wr <= 3'd4;
                macroblock_present_wr    <= 1'b1;
                macroblock_active_wr     <= 1'b0;
            end
            else begin
                completed_luma_blocks_wr <= completed_luma_blocks_wr + 3'd1;
            end
        end

        if (wr_en &&
            (wr_x_pos < SRC_WIDTH) &&
            (wr_y_pos < SRC_HEIGHT)) begin
            ram_wr_address <= wr_linear_address;
            ram_wr_data    <= wr_y;
            ram_wr_en      <= 1'b1;
        end
    end
end

// -------------------------------------------------------------------------
// Read-side synchronization of the completed-macroblock descriptor.
// -------------------------------------------------------------------------

reg        macroblock_present_rd_1;
reg        macroblock_present_rd_2;
reg [11:0] macroblock_origin_x_rd_1;
reg [11:0] macroblock_origin_x_rd_2;
reg [11:0] macroblock_origin_y_rd_1;
reg [11:0] macroblock_origin_y_rd_2;

always @(posedge rd_clk) begin
    if (reset) begin
        macroblock_present_rd_1 <= 1'b0;
        macroblock_present_rd_2 <= 1'b0;
        macroblock_origin_x_rd_1 <= 12'd0;
        macroblock_origin_x_rd_2 <= 12'd0;
        macroblock_origin_y_rd_1 <= 12'd0;
        macroblock_origin_y_rd_2 <= 12'd0;
    end
    else begin
        macroblock_present_rd_1 <= macroblock_present_wr;
        macroblock_present_rd_2 <= macroblock_present_rd_1;
        macroblock_origin_x_rd_1 <= macroblock_origin_x_wr;
        macroblock_origin_x_rd_2 <= macroblock_origin_x_rd_1;
        macroblock_origin_y_rd_1 <= macroblock_origin_y_wr;
        macroblock_origin_y_rd_2 <= macroblock_origin_y_rd_1;
    end
end

// -------------------------------------------------------------------------
// Read-side address generation.
//
// The 720x480 diagnostic presentation remains centered in 800x600.  This is a
// presentation/debug choice, not an H.262 decoding rule.
// -------------------------------------------------------------------------

wire source_window =
    pixel_en &&
    (h_pos >= 12'd40)  && (h_pos < 12'd760) &&
    (v_pos >= 12'd60)  && (v_pos < 12'd540);

wire [11:0] source_x = h_pos - 12'd40;
wire [11:0] source_y = v_pos - 12'd60;

wire decoded_macroblock_window =
    source_window &&
    macroblock_present_rd_2 &&
    (source_x >= macroblock_origin_x_rd_2) &&
    (source_x <  macroblock_origin_x_rd_2 + 12'd16) &&
    (source_y >= macroblock_origin_y_rd_2) &&
    (source_y <  macroblock_origin_y_rd_2 + 12'd16);

wire [18:0] ram_rd_address =
    ((v_pos - 12'd60) * 19'd720) +
     (h_pos - 12'd40);

wire [7:0] ram_rd_data;

// -------------------------------------------------------------------------
// True dual-clock framebuffer.
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
// altsyncram read address is registered, so delay the region controls one
// clock to keep them aligned with q_b.
// -------------------------------------------------------------------------

reg source_window_d;
reg decoded_macroblock_window_d;

always @(posedge rd_clk) begin
    if (reset) begin
        source_window_d             <= 1'b0;
        decoded_macroblock_window_d <= 1'b0;
        video_y                     <= 8'd0;
        video_de                    <= 1'b0;
        video_hs                    <= 1'b0;
        video_vs                    <= 1'b0;
    end
    else begin
        source_window_d             <= source_window;
        decoded_macroblock_window_d <= decoded_macroblock_window;

        video_de <= pixel_en;
        video_hs <= h_sync;
        video_vs <= v_sync;

        if (decoded_macroblock_window_d)
            video_y <= ram_rd_data;
        else if (source_window_d)
            video_y <= 8'd24;
        else
            video_y <= 8'd0;
    end
end

endmodule
