// kate - Decoupled MPEG2 luma framebuffer.
//
// Phase 1L stores the complete first H.262 slice's reconstructed luminance.
// The decoder writes explicit picture X/Y coordinates at 54 MHz while the
// independent fixed SVGA raster reads at 40 MHz.
//
// H.262 permits a slice to contain an arbitrary number of consecutive
// macroblocks within one macroblock row.  Accordingly this framebuffer no
// longer assumes a four-macroblock/64-pixel strip.  It records the actual
// reconstructed X span and publishes that 16-line slice only after the parser
// reports the normative slice terminator.
//
// The rest of the 720x480 source window remains the fixed diagnostic background
// so uninitialised RAM cannot look like decoded picture data.
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
    input  wire        wr_slice_complete,

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
// Write-side address generation and complete-first-slice publication.
// -------------------------------------------------------------------------

reg [18:0] ram_wr_address;
reg [7:0]  ram_wr_data;
reg        ram_wr_en;

wire [18:0] wr_linear_address =
    (wr_y_pos * 19'd720) + wr_x_pos;

// kate - The first reconstructed block supplies the slice's upper-left
// picture-space origin.  strip_end_x_wr is exclusive and grows from actual
// reconstructed pixels, so a legal short slice is displayed at its real width.
// These descriptor fields settle in the write clock domain before
// strip_present_wr is asserted and remain stable thereafter.
reg [11:0] strip_origin_x_wr;
reg [11:0] strip_origin_y_wr;
reg [11:0] strip_end_x_wr;
reg        strip_origin_valid_wr;
reg        strip_present_wr;
reg        strip_active_wr;

// wr_block_complete is intentionally retained at the interface because it is
// the decoder's natural block-level publication event and will be useful when
// this framebuffer grows beyond the first-slice proof.  Phase 1L publication
// itself is governed by wr_slice_complete.

always @(posedge wr_clk) begin
    if (reset) begin
        ram_wr_address        <= 19'd0;
        ram_wr_data           <= 8'd0;
        ram_wr_en             <= 1'b0;
        strip_origin_x_wr     <= 12'd0;
        strip_origin_y_wr     <= 12'd0;
        strip_end_x_wr        <= 12'd0;
        strip_origin_valid_wr <= 1'b0;
        strip_present_wr      <= 1'b0;
        strip_active_wr       <= 1'b0;
    end
    else begin
        ram_wr_en <= 1'b0;

        // The first accepted macroblock starts the one-slice capture.  Later
        // macroblock_start pulses belong to the same slice and require no
        // framebuffer-side bookkeeping because writes carry explicit X/Y.
        if (wr_macroblock_start && !strip_active_wr && !strip_present_wr) begin
            strip_origin_x_wr     <= 12'd0;
            strip_origin_y_wr     <= 12'd0;
            strip_end_x_wr        <= 12'd0;
            strip_origin_valid_wr <= 1'b0;
            strip_present_wr      <= 1'b0;
            strip_active_wr       <= 1'b1;
        end

        if (wr_block_start && strip_active_wr && !strip_origin_valid_wr) begin
            strip_origin_x_wr     <= wr_x_pos;
            strip_origin_y_wr     <= wr_y_pos;
            strip_origin_valid_wr <= 1'b1;
        end

        if (wr_en &&
            (wr_x_pos < SRC_WIDTH) &&
            (wr_y_pos < SRC_HEIGHT)) begin
            ram_wr_address <= wr_linear_address;
            ram_wr_data    <= wr_y;
            ram_wr_en      <= 1'b1;

            if (strip_active_wr &&
                ((wr_x_pos + 12'd1) > strip_end_x_wr))
                strip_end_x_wr <= wr_x_pos + 12'd1;
        end

        // The parser can reach slice completion only after the final luma block
        // has traversed IQ/IDCT/reconstruction and its Cb/Cr syntax has been
        // consumed.  Publication therefore never exposes a partial slice.
        if (wr_slice_complete && strip_active_wr) begin
            if (strip_origin_valid_wr &&
                (strip_end_x_wr > strip_origin_x_wr)) begin
                strip_present_wr <= 1'b1;
                strip_active_wr  <= 1'b0;
            end
        end
    end
end

// -------------------------------------------------------------------------
// Read-side synchronization of the completed-slice descriptor.
// -------------------------------------------------------------------------

reg        strip_present_rd_1;
reg        strip_present_rd_2;
reg [11:0] strip_origin_x_rd_1;
reg [11:0] strip_origin_x_rd_2;
reg [11:0] strip_origin_y_rd_1;
reg [11:0] strip_origin_y_rd_2;
reg [11:0] strip_end_x_rd_1;
reg [11:0] strip_end_x_rd_2;

always @(posedge rd_clk) begin
    if (reset) begin
        strip_present_rd_1  <= 1'b0;
        strip_present_rd_2  <= 1'b0;
        strip_origin_x_rd_1 <= 12'd0;
        strip_origin_x_rd_2 <= 12'd0;
        strip_origin_y_rd_1 <= 12'd0;
        strip_origin_y_rd_2 <= 12'd0;
        strip_end_x_rd_1    <= 12'd0;
        strip_end_x_rd_2    <= 12'd0;
    end
    else begin
        strip_present_rd_1  <= strip_present_wr;
        strip_present_rd_2  <= strip_present_rd_1;
        strip_origin_x_rd_1 <= strip_origin_x_wr;
        strip_origin_x_rd_2 <= strip_origin_x_rd_1;
        strip_origin_y_rd_1 <= strip_origin_y_wr;
        strip_origin_y_rd_2 <= strip_origin_y_rd_1;
        strip_end_x_rd_1    <= strip_end_x_wr;
        strip_end_x_rd_2    <= strip_end_x_rd_1;
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

wire decoded_slice_window =
    source_window &&
    strip_present_rd_2 &&
    (source_x >= strip_origin_x_rd_2) &&
    (source_x <  strip_end_x_rd_2) &&
    (source_y >= strip_origin_y_rd_2) &&
    (source_y <  strip_origin_y_rd_2 + 12'd16);

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
reg decoded_slice_window_d;

always @(posedge rd_clk) begin
    if (reset) begin
        source_window_d        <= 1'b0;
        decoded_slice_window_d <= 1'b0;
        video_y                <= 8'd0;
        video_de               <= 1'b0;
        video_hs               <= 1'b0;
        video_vs               <= 1'b0;
    end
    else begin
        source_window_d        <= source_window;
        decoded_slice_window_d <= decoded_slice_window;

        video_de <= pixel_en;
        video_hs <= h_sync;
        video_vs <= v_sync;

        if (decoded_slice_window_d)
            video_y <= ram_rd_data;
        else if (source_window_d)
            video_y <= 8'd24;
        else
            video_y <= 8'd0;
    end
end

endmodule
