// kate - Decoupled MPEG2 4:2:0 picture framebuffer.
//
// Phase 1N M10K fit diagnostic.
//
// IMPORTANT:
// - The H.262 parser, inverse quantizer, IDCT and reconstruction path remain
//   full precision.
// - Luma is stored at the full reconstructed 8-bit precision.
// - Cb and Cr are temporarily stored as their upper 4 bits only so the first
//   complete colour-picture path can be tested without exhausting the DE10-Nano
//   Cyclone V M10K block count.
// - This chroma reduction is a diagnostic presentation/storage choice.  It is
//   NOT an H.262 requirement and is not intended to be the final framebuffer.
// - Once the colour path is proven, full-precision picture/reference storage
//   will move to external DDR3.
//
// The historical module/file name is retained to avoid unnecessary top-level
// churn.  The picture planes represented here are:
//   Y  : up to 720x480, 8 bits/pel
//   Cb : up to 360x240, upper 4 bits/pel (diagnostic only)
//   Cr : up to 360x240, upper 4 bits/pel (diagnostic only)
//
// The decoder writes explicit component-plane X/Y coordinates at 54 MHz while
// the independent fixed SVGA raster reads at 40 MHz.  The complete picture is
// published atomically only after parser/reconstruction completion.
//
// kate - Phase 1N presentation uses nearest-neighbour 4:2:0 chroma expansion:
// each stored Cb/Cr pel supplies a 2x2 luma-pel area.  This is intentionally a
// simple first-colour-picture presentation choice, not an H.262 sampling rule.

module mpeg2_luma_framebuffer
(
    input  wire        reset,

    // H.262 reconstruction side - 54 MHz.
    input  wire        wr_clk,
    input  wire [7:0]  wr_value,
    // 0 = Y, 1 = Cb, 2 = Cr.
    input  wire [1:0]  wr_component,
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

    output reg  [7:0]  video_r,
    output reg  [7:0]  video_g,
    output reg  [7:0]  video_b,
    output reg         video_de,
    output reg         video_hs,
    output reg         video_vs
);

localparam integer SRC_WIDTH        = 720;
localparam integer SRC_HEIGHT       = 480;
localparam integer Y_FB_SIZE        = SRC_WIDTH * SRC_HEIGHT;
localparam integer CHROMA_WIDTH     = SRC_WIDTH / 2;
localparam integer CHROMA_HEIGHT    = SRC_HEIGHT / 2;
localparam integer CHROMA_FB_SIZE   = CHROMA_WIDTH * CHROMA_HEIGHT;

localparam [1:0] COMPONENT_Y  = 2'd0;
localparam [1:0] COMPONENT_CB = 2'd1;
localparam [1:0] COMPONENT_CR = 2'd2;

// -------------------------------------------------------------------------
// Write-side three-plane picture store and publication descriptor.
// -------------------------------------------------------------------------

reg [18:0] y_wr_address;
reg [7:0]  y_wr_data;
reg        y_wr_en;

reg [16:0] cb_wr_address;
reg [3:0]  cb_wr_data;
reg        cb_wr_en;

reg [16:0] cr_wr_address;
reg [3:0]  cr_wr_data;
reg        cr_wr_en;

wire [18:0] y_wr_linear_address =
    ({7'd0, wr_y_pos} * 19'd720) + {7'd0, wr_x_pos};

wire [16:0] c_wr_linear_address =
    ({5'd0, wr_y_pos} * 17'd360) + {5'd0, wr_x_pos};

reg        picture_present_wr;
reg [11:0] picture_width_wr;
reg [11:0] picture_height_wr;

always @(posedge wr_clk) begin
    if (reset) begin
        y_wr_address       <= 19'd0;
        y_wr_data          <= 8'd0;
        y_wr_en            <= 1'b0;
        cb_wr_address      <= 17'd0;
        cb_wr_data         <= 4'd8;
        cb_wr_en           <= 1'b0;
        cr_wr_address      <= 17'd0;
        cr_wr_data         <= 4'd8;
        cr_wr_en           <= 1'b0;
        picture_present_wr <= 1'b0;
        picture_width_wr   <= 12'd0;
        picture_height_wr  <= 12'd0;
    end
    else begin
        y_wr_en  <= 1'b0;
        cb_wr_en <= 1'b0;
        cr_wr_en <= 1'b0;

        if (wr_en) begin
            case (wr_component)
                COMPONENT_Y: begin
                    if ((wr_x_pos < SRC_WIDTH) &&
                        (wr_y_pos < SRC_HEIGHT)) begin
                        y_wr_address <= y_wr_linear_address;
                        y_wr_data    <= wr_value;
                        y_wr_en      <= 1'b1;
                    end
                end

                COMPONENT_CB: begin
                    if ((wr_x_pos < CHROMA_WIDTH) &&
                        (wr_y_pos < CHROMA_HEIGHT)) begin
                        cb_wr_address <= c_wr_linear_address;
                        cb_wr_data    <= wr_value[7:4];
                        cb_wr_en      <= 1'b1;
                    end
                end

                COMPONENT_CR: begin
                    if ((wr_x_pos < CHROMA_WIDTH) &&
                        (wr_y_pos < CHROMA_HEIGHT)) begin
                        cr_wr_address <= c_wr_linear_address;
                        cr_wr_data    <= wr_value[7:4];
                        cr_wr_en      <= 1'b1;
                    end
                end

                default: begin end
            endcase
        end

        // The parser asserts this only after the final macroblock's Cr block
        // has completed the same IQ -> IDCT -> reconstruction path as Y/Cb.
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

wire [18:0] y_rd_address = source_window ?
    (({7'd0, source_y} * 19'd720) + {7'd0, source_x}) : 19'd0;

// kate - Phase 1N nearest-neighbour 4:2:0 expansion.  One chroma pel is read
// for every 2x2 luma-pel group by dropping the low X/Y bits.
wire [10:0] chroma_source_x = source_x[11:1];
wire [10:0] chroma_source_y = source_y[11:1];

wire [16:0] c_rd_address = source_window ?
    (({6'd0, chroma_source_y} * 17'd360) +
     {6'd0, chroma_source_x}) : 17'd0;

wire [7:0] y_rd_data;
wire [3:0] cb_rd_data_4;
wire [3:0] cr_rd_data_4;

// Expand the diagnostic 4-bit chroma back to 8 bits by restoring the stored
// high nibble and clearing the discarded low nibble.  This deliberately keeps
// neutral chroma exactly at 8'h80 rather than shifting it toward a colour cast.
wire [7:0] cb_rd_data = {cb_rd_data_4, 4'b0000};
wire [7:0] cr_rd_data = {cr_rd_data_4, 4'b0000};

// -------------------------------------------------------------------------
// True dual-clock component framebuffers.
//
// DONT_CARE is used for mixed-port read-during-write because the picture is not
// published to the read side until reconstruction has completed.
// -------------------------------------------------------------------------

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (8),
    .widthad_a                      (19),
    .numwords_a                     (Y_FB_SIZE),
    .width_b                        (8),
    .widthad_b                      (19),
    .numwords_b                     (Y_FB_SIZE),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) y_framebuffer_ram (
    .clock0         (wr_clk),
    .clock1         (rd_clk),
    .address_a      (y_wr_address),
    .data_a         (y_wr_data),
    .wren_a         (y_wr_en),
    .address_b      (y_rd_address),
    .q_b            (y_rd_data),
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

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (4),
    .widthad_a                      (17),
    .numwords_a                     (CHROMA_FB_SIZE),
    .width_b                        (4),
    .widthad_b                      (17),
    .numwords_b                     (CHROMA_FB_SIZE),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) cb_framebuffer_ram (
    .clock0         (wr_clk),
    .clock1         (rd_clk),
    .address_a      (cb_wr_address),
    .data_a         (cb_wr_data),
    .wren_a         (cb_wr_en),
    .address_b      (c_rd_address),
    .q_b            (cb_rd_data_4),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (1'b1),
    .byteena_b      (1'b1),
    .data_b         (4'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (4),
    .widthad_a                      (17),
    .numwords_a                     (CHROMA_FB_SIZE),
    .width_b                        (4),
    .widthad_b                      (17),
    .numwords_b                     (CHROMA_FB_SIZE),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) cr_framebuffer_ram (
    .clock0         (wr_clk),
    .clock1         (rd_clk),
    .address_a      (cr_wr_address),
    .data_a         (cr_wr_data),
    .wren_a         (cr_wr_en),
    .address_b      (c_rd_address),
    .q_b            (cr_rd_data_4),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (1'b1),
    .byteena_b      (1'b1),
    .data_b         (4'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

// -------------------------------------------------------------------------
// Phase 1N colour presentation.
// -------------------------------------------------------------------------

wire [7:0] rgb_r;
wire [7:0] rgb_g;
wire [7:0] rgb_b;

mpeg2_ycbcr_to_rgb_bt601 mpeg2_ycbcr_to_rgb_bt601
(
    .y  (y_rd_data),
    .cb (cb_rd_data),
    .cr (cr_rd_data),
    .r  (rgb_r),
    .g  (rgb_g),
    .b  (rgb_b)
);

// altsyncram read addresses are registered, so delay the region controls one
// clock to keep them aligned with all three q_b outputs.
reg source_window_d;
reg decoded_picture_window_d;

always @(posedge rd_clk) begin
    if (reset) begin
        source_window_d          <= 1'b0;
        decoded_picture_window_d <= 1'b0;
        video_r                  <= 8'd0;
        video_g                  <= 8'd0;
        video_b                  <= 8'd0;
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

        if (decoded_picture_window_d) begin
            video_r <= rgb_r;
            video_g <= rgb_g;
            video_b <= rgb_b;
        end
        else if (source_window_d) begin
            video_r <= 8'd24;
            video_g <= 8'd24;
            video_b <= 8'd24;
        end
        else begin
            video_r <= 8'd0;
            video_g <= 8'd0;
            video_b <= 8'd0;
        end
    end
end

endmodule
