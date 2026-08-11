// kate - Decoupled MPEG2 luma framebuffer.
//
// Phase 1F changes framebuffer ownership: the legacy MPEG2FPGA resampler no
// longer writes this RAM.  The standards-driven H.262 decoder writes decoded
// luminance samples with explicit picture X/Y coordinates at 54 MHz, while the
// independent SVGA raster reads at 40 MHz.
//
// The current decoder only reconstructs the first 8x8 luminance block.  To
// make that proof unambiguous, the display returns a fixed diagnostic
// background outside the completed block rather than showing uninitialised RAM.
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
// Write-side address generation.
// -------------------------------------------------------------------------

reg [18:0] ram_wr_address;
reg [7:0]  ram_wr_data;
reg        ram_wr_en;

wire [18:0] wr_linear_address =
    (wr_y_pos * 19'd720) + wr_x_pos;

// The first completed block's origin and publication flag are stable until a
// later block starts or reset occurs.  This makes the multi-bit coordinates
// safe to transfer with the synchronized publication flag on the read side.
reg [11:0] block_origin_x_wr;
reg [11:0] block_origin_y_wr;
reg        block_present_wr;
reg        wr_block_complete_d;

always @(posedge wr_clk) begin
    if (reset) begin
        ram_wr_address       <= 19'd0;
        ram_wr_data          <= 8'd0;
        ram_wr_en            <= 1'b0;
        block_origin_x_wr    <= 12'd0;
        block_origin_y_wr    <= 12'd0;
        block_present_wr     <= 1'b0;
        wr_block_complete_d  <= 1'b0;
    end
    else begin
        ram_wr_en           <= 1'b0;
        wr_block_complete_d <= wr_block_complete;

        if (wr_block_start) begin
            // kate - The reconstruction engine supplies the H.262 picture
            // coordinate of sample [0][0] for this 8x8 block.
            block_origin_x_wr <= wr_x_pos;
            block_origin_y_wr <= wr_y_pos;
            block_present_wr  <= 1'b0;
        end
        else if (wr_block_complete && !wr_block_complete_d) begin
            // Publish on the completion edge.  The two-clock read-domain
            // synchronizer leaves more than one writer clock for the final
            // registered Port-A write to commit before the block is exposed.
            block_present_wr <= 1'b1;
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
// Read-side synchronization of the completed-block descriptor.
//
// The coordinates are captured before block_present_wr can become one and do
// not change while it remains one.  Two read-clock stages are therefore used
// for both the descriptor and its publication flag.
// -------------------------------------------------------------------------

reg        block_present_rd_1;
reg        block_present_rd_2;
reg [11:0] block_origin_x_rd_1;
reg [11:0] block_origin_x_rd_2;
reg [11:0] block_origin_y_rd_1;
reg [11:0] block_origin_y_rd_2;

always @(posedge rd_clk) begin
    if (reset) begin
        block_present_rd_1 <= 1'b0;
        block_present_rd_2 <= 1'b0;
        block_origin_x_rd_1 <= 12'd0;
        block_origin_x_rd_2 <= 12'd0;
        block_origin_y_rd_1 <= 12'd0;
        block_origin_y_rd_2 <= 12'd0;
    end
    else begin
        block_present_rd_1 <= block_present_wr;
        block_present_rd_2 <= block_present_rd_1;
        block_origin_x_rd_1 <= block_origin_x_wr;
        block_origin_x_rd_2 <= block_origin_x_rd_1;
        block_origin_y_rd_1 <= block_origin_y_wr;
        block_origin_y_rd_2 <= block_origin_y_rd_1;
    end
end

// -------------------------------------------------------------------------
// Read-side address generation.
//
// Phase 1F keeps the existing 720x480 diagnostic presentation centered in
// 800x600.  This is a presentation choice, not an H.262 decoding rule.
// -------------------------------------------------------------------------

wire source_window =
    pixel_en &&
    (h_pos >= 12'd40)  && (h_pos < 12'd760) &&
    (v_pos >= 12'd60)  && (v_pos < 12'd540);

wire [11:0] source_x = h_pos - 12'd40;
wire [11:0] source_y = v_pos - 12'd60;

wire decoded_block_window =
    source_window &&
    block_present_rd_2 &&
    (source_x >= block_origin_x_rd_2) &&
    (source_x <  block_origin_x_rd_2 + 12'd8) &&
    (source_y >= block_origin_y_rd_2) &&
    (source_y <  block_origin_y_rd_2 + 12'd8);

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
reg decoded_block_window_d;

always @(posedge rd_clk) begin
    if (reset) begin
        source_window_d        <= 1'b0;
        decoded_block_window_d <= 1'b0;
        video_y                <= 8'd0;
        video_de               <= 1'b0;
        video_hs               <= 1'b0;
        video_vs               <= 1'b0;
    end
    else begin
        source_window_d        <= source_window;
        decoded_block_window_d <= decoded_block_window;

        video_de <= pixel_en;
        video_hs <= h_sync;
        video_vs <= v_sync;

        if (decoded_block_window_d)
            video_y <= ram_rd_data;
        else if (source_window_d)
            // kate - Diagnostic background only.  It makes the 8x8 decoded
            // block visible while ensuring uninitialised RAM cannot masquerade
            // as decoder output.
            video_y <= 8'd24;
        else
            video_y <= 8'd0;
    end
end

endmodule
