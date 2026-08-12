// kate - Decoupled MPEG2 luma framebuffer.
//
// Phase 1M stores reconstructed luminance for every slice of the first H.262
// picture.  The decoder writes explicit picture X/Y coordinates at 54 MHz while
// the independent fixed SVGA raster reads at 40 MHz.
//
// kate - Unlike the Phase 1L first-slice proof, no partial slice is published.
// RAM remains hidden until the parser reports that picture_data() has reached
// the next non-slice start code.  At that point the complete decoded luma
// picture becomes visible atomically from the presentation side.
//
// The current on-chip framebuffer is deliberately 720x480.  Smaller pictures
// are shown at the upper-left of that diagnostic source window.  Pictures larger
// than this local Phase 1M store are not published.
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

    input  wire        wr_picture_complete,
    input  wire [13:0] wr_horizontal_size,
    input  wire [13:0] wr_vertical_size,

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
// Write-side picture store and publication descriptor.
// -------------------------------------------------------------------------

reg [18:0] ram_wr_address;
reg [7:0]  ram_wr_data;
reg        ram_wr_en;

wire [18:0] wr_linear_address =
    (wr_y_pos * 19'd720) + wr_x_pos;

reg        picture_present_wr;
reg [11:0] picture_width_wr;
reg [11:0] picture_height_wr;

always @(posedge wr_clk) begin
    if (reset) begin
        ram_wr_address     <= 19'd0;
        ram_wr_data        <= 8'd0;
        ram_wr_en          <= 1'b0;
        picture_present_wr <= 1'b0;
        picture_width_wr   <= 12'd0;
        picture_height_wr  <= 12'd0;
    end
    else begin
        ram_wr_en <= 1'b0;

        if (wr_en &&
            (wr_x_pos < SRC_WIDTH) &&
            (wr_y_pos < SRC_HEIGHT)) begin
            ram_wr_address <= wr_linear_address;
            ram_wr_data    <= wr_y;
            ram_wr_en      <= 1'b1;
        end

        // The parser reaches this point only after the final slice's final Y
        // block has traversed reconstruction and the following non-slice start
        // code has been recognized.  The descriptor therefore publishes a
        // stable completed picture rather than an in-progress decode.
        if (wr_picture_complete && !picture_present_wr) begin
            if ((wr_horizontal_size != 14'd0) &&
                (wr_vertical_size   != 14'd0) &&
                (wr_horizontal_size <= SRC_WIDTH) &&
                (wr_vertical_size   <= SRC_HEIGHT)) begin
                picture_width_wr   <= wr_horizontal_size[11:0];
                picture_height_wr  <= wr_vertical_size[11:0];
                picture_present_wr <= 1'b1;
            end
        end
    end
end

// -------------------------------------------------------------------------
// Read-side synchronization of the completed-picture descriptor.
// -------------------------------------------------------------------------

reg        picture_present_rd_1;
reg        picture_present_rd_2;
reg [11:0] picture_width_rd_1;
reg [11:0] picture_width_rd_2;
reg [11:0] picture_height_rd_1;
reg [11:0] picture_height_rd_2;

always @(posedge rd_clk) begin
    if (reset) begin
        picture_present_rd_1 <= 1'b0;
        picture_present_rd_2 <= 1'b0;
        picture_width_rd_1   <= 12'd0;
        picture_width_rd_2   <= 12'd0;
        picture_height_rd_1  <= 12'd0;
        picture_height_rd_2  <= 12'd0;
    end
    else begin
        picture_present_rd_1 <= picture_present_wr;
        picture_present_rd_2 <= picture_present_rd_1;
        picture_width_rd_1   <= picture_width_wr;
        picture_width_rd_2   <= picture_width_rd_1;
        picture_height_rd_1  <= picture_height_wr;
        picture_height_rd_2  <= picture_height_rd_1;
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

wire decoded_picture_window =
    source_window &&
    picture_present_rd_2 &&
    (source_x < picture_width_rd_2) &&
    (source_y < picture_height_rd_2);

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
// altsyncram read address is registered, so delay region controls one clock to
// keep them aligned with q_b.
// -------------------------------------------------------------------------

reg source_window_d;
reg decoded_picture_window_d;

always @(posedge rd_clk) begin
    if (reset) begin
        source_window_d          <= 1'b0;
        decoded_picture_window_d <= 1'b0;
        video_y                  <= 8'd0;
        video_de                 <= 1'b0;
        video_hs                 <= 1'b0;
        video_vs                 <= 1'b0;
    end
    else begin
        source_window_d          <= source_window;
        decoded_picture_window_d <= decoded_picture_window;

        video_de <= pixel_en;
        video_hs <= h_sync;
        video_vs <= v_sync;

        if (decoded_picture_window_d)
            video_y <= ram_rd_data;
        else if (source_window_d)
            video_y <= 8'd24;
        else
            video_y <= 8'd0;
    end
end

endmodule
