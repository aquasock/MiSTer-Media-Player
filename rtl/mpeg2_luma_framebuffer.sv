// kate - Decoupled MPEG2 4:2:0 picture framebuffer.
//
// Phase 1N M10K packing fix.
//
// The historical module/file name is retained to avoid gratuitous top-level
// churn.  The decoder stores all three reconstructed component planes for the
// first supported H.262 picture:
//   Y  : up to 720x480
//   Cb : up to 360x240
//   Cr : up to 360x240
//
// The original Phase 1N proof stored one 8-bit pel per RAM word.  Cyclone V
// M10K blocks are substantially more efficient in their 256x40 configuration,
// so this revision packs five 8-bit pels into each 40-bit word and uses the
// M10K byte-enable lanes for single-pel writes.  This reduces the three picture
// planes from about 508 M10Ks to about 406 M10Ks without changing decoded
// precision or picture dimensions.
//
// The decoder writes explicit component-plane X/Y coordinates at 54 MHz while
// the independent fixed SVGA raster reads at 40 MHz.  The complete picture is
// published atomically only after parser/reconstruction completion.
//
// kate - Phase 1N presentation uses nearest-neighbour 4:2:0 chroma expansion:
// each stored Cb/Cr pel supplies a 2x2 luma-pel area.  This is intentionally a
// simple first-colour-picture presentation choice, not an H.262 sampling rule.
// A later quality phase can add siting-aware interpolation without changing the
// decoded component planes.

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

localparam integer SRC_WIDTH          = 720;
localparam integer SRC_HEIGHT         = 480;
localparam integer CHROMA_WIDTH       = SRC_WIDTH / 2;
localparam integer CHROMA_HEIGHT      = SRC_HEIGHT / 2;
localparam integer PELS_PER_RAM_WORD  = 5;
localparam integer Y_WORDS_PER_ROW    = SRC_WIDTH / PELS_PER_RAM_WORD;       // 144
localparam integer C_WORDS_PER_ROW    = CHROMA_WIDTH / PELS_PER_RAM_WORD;    // 72
localparam integer Y_FB_WORDS         = Y_WORDS_PER_ROW * SRC_HEIGHT;         // 69120
localparam integer C_FB_WORDS         = C_WORDS_PER_ROW * CHROMA_HEIGHT;      // 17280

localparam [1:0] COMPONENT_Y  = 2'd0;
localparam [1:0] COMPONENT_CB = 2'd1;
localparam [1:0] COMPONENT_CR = 2'd2;

// -------------------------------------------------------------------------
// Small constant /5 helpers.
//
// Coordinates are bounded to 0..719 (Y) or 0..359 (Cb/Cr), and these constant
// operations synthesize to small combinational networks.  Keeping division to
// X only also preserves the row-aligned packed RAM organization.
// -------------------------------------------------------------------------

wire [11:0] wr_x_group = wr_x_pos / 12'd5;
wire [2:0]  wr_x_lane  = wr_x_pos % 12'd5;

wire [4:0] wr_lane_enable =
    (wr_x_lane == 3'd0) ? 5'b00001 :
    (wr_x_lane == 3'd1) ? 5'b00010 :
    (wr_x_lane == 3'd2) ? 5'b00100 :
    (wr_x_lane == 3'd3) ? 5'b01000 :
                           5'b10000;

// Replicate the pel across every byte lane.  byteena_a selects the one lane
// that is actually changed, so no read/modify/write cycle is required.
wire [39:0] wr_data_40 = {5{wr_value}};

// -------------------------------------------------------------------------
// Write-side three-plane picture store and publication descriptor.
// -------------------------------------------------------------------------

reg [16:0] y_wr_address;
reg [39:0] y_wr_data;
reg [4:0]  y_wr_byteena;
reg        y_wr_en;

reg [14:0] cb_wr_address;
reg [39:0] cb_wr_data;
reg [4:0]  cb_wr_byteena;
reg        cb_wr_en;

reg [14:0] cr_wr_address;
reg [39:0] cr_wr_data;
reg [4:0]  cr_wr_byteena;
reg        cr_wr_en;

wire [16:0] y_wr_word_address =
    ({5'd0, wr_y_pos} * 17'd144) + {9'd0, wr_x_group[7:0]};
wire [14:0] c_wr_word_address =
    ({3'd0, wr_y_pos} * 15'd72) + {8'd0, wr_x_group[6:0]};

reg        picture_present_wr;
reg [11:0] picture_width_wr;
reg [11:0] picture_height_wr;

always @(posedge wr_clk) begin
    if (reset) begin
        y_wr_address       <= 17'd0;
        y_wr_data          <= 40'd0;
        y_wr_byteena       <= 5'b00000;
        y_wr_en            <= 1'b0;
        cb_wr_address      <= 15'd0;
        cb_wr_data         <= {5{8'd128}};
        cb_wr_byteena      <= 5'b00000;
        cb_wr_en           <= 1'b0;
        cr_wr_address      <= 15'd0;
        cr_wr_data         <= {5{8'd128}};
        cr_wr_byteena      <= 5'b00000;
        cr_wr_en           <= 1'b0;
        picture_present_wr <= 1'b0;
        picture_width_wr   <= 12'd0;
        picture_height_wr  <= 12'd0;
    end
    else begin
        y_wr_en       <= 1'b0;
        cb_wr_en      <= 1'b0;
        cr_wr_en      <= 1'b0;
        y_wr_byteena  <= 5'b00000;
        cb_wr_byteena <= 5'b00000;
        cr_wr_byteena <= 5'b00000;

        if (wr_en) begin
            case (wr_component)
                COMPONENT_Y: begin
                    if ((wr_x_pos < SRC_WIDTH) &&
                        (wr_y_pos < SRC_HEIGHT)) begin
                        y_wr_address  <= y_wr_word_address;
                        y_wr_data     <= wr_data_40;
                        y_wr_byteena  <= wr_lane_enable;
                        y_wr_en       <= 1'b1;
                    end
                end

                COMPONENT_CB: begin
                    if ((wr_x_pos < CHROMA_WIDTH) &&
                        (wr_y_pos < CHROMA_HEIGHT)) begin
                        cb_wr_address <= c_wr_word_address;
                        cb_wr_data    <= wr_data_40;
                        cb_wr_byteena <= wr_lane_enable;
                        cb_wr_en      <= 1'b1;
                    end
                end

                COMPONENT_CR: begin
                    if ((wr_x_pos < CHROMA_WIDTH) &&
                        (wr_y_pos < CHROMA_HEIGHT)) begin
                        cr_wr_address <= c_wr_word_address;
                        cr_wr_data    <= wr_data_40;
                        cr_wr_byteena <= wr_lane_enable;
                        cr_wr_en      <= 1'b1;
                    end
                end

                default: begin end
            endcase
        end

        // The parser can assert this only after the final macroblock's Cr block
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

wire [11:0] y_rd_group = source_x / 12'd5;
wire [2:0]  y_rd_lane  = source_x % 12'd5;
wire [16:0] y_rd_address = source_window ?
    (({5'd0, source_y} * 17'd144) + {9'd0, y_rd_group[7:0]}) : 17'd0;

// kate - Phase 1N nearest-neighbour 4:2:0 expansion.  One chroma pel is read
// for every 2x2 luma-pel group by dropping the low X/Y bits before RAM packing.
wire [10:0] chroma_source_x = source_x[11:1];
wire [10:0] chroma_source_y = source_y[11:1];
wire [10:0] c_rd_group = chroma_source_x / 11'd5;
wire [2:0]  c_rd_lane  = chroma_source_x % 11'd5;
wire [14:0] c_rd_address = source_window ?
    (({4'd0, chroma_source_y} * 15'd72) + {8'd0, c_rd_group[6:0]}) : 15'd0;

wire [39:0] y_rd_word;
wire [39:0] cb_rd_word;
wire [39:0] cr_rd_word;

// altsyncram registers the read address.  Carry the byte-lane selector through
// the same one-cycle latency so the selected pel stays aligned with q_b.
reg [2:0] y_rd_lane_d;
reg [2:0] c_rd_lane_d;

always @(posedge rd_clk) begin
    if (reset) begin
        y_rd_lane_d <= 3'd0;
        c_rd_lane_d <= 3'd0;
    end
    else begin
        y_rd_lane_d <= y_rd_lane;
        c_rd_lane_d <= c_rd_lane;
    end
end

reg [7:0] y_rd_data;
reg [7:0] cb_rd_data;
reg [7:0] cr_rd_data;

always @* begin
    case (y_rd_lane_d)
        3'd0: y_rd_data = y_rd_word[7:0];
        3'd1: y_rd_data = y_rd_word[15:8];
        3'd2: y_rd_data = y_rd_word[23:16];
        3'd3: y_rd_data = y_rd_word[31:24];
        default: y_rd_data = y_rd_word[39:32];
    endcase

    case (c_rd_lane_d)
        3'd0: begin
            cb_rd_data = cb_rd_word[7:0];
            cr_rd_data = cr_rd_word[7:0];
        end
        3'd1: begin
            cb_rd_data = cb_rd_word[15:8];
            cr_rd_data = cr_rd_word[15:8];
        end
        3'd2: begin
            cb_rd_data = cb_rd_word[23:16];
            cr_rd_data = cr_rd_word[23:16];
        end
        3'd3: begin
            cb_rd_data = cb_rd_word[31:24];
            cr_rd_data = cr_rd_word[31:24];
        end
        default: begin
            cb_rd_data = cb_rd_word[39:32];
            cr_rd_data = cr_rd_word[39:32];
        end
    endcase
end

// -------------------------------------------------------------------------
// True dual-clock component framebuffers.
//
// Cyclone V M10K dual-port mode supports 256x40 organization.  Five byte
// enables select the individual 8-bit pel lanes.  DONT_CARE is used for
// mixed-port read-during-write because the design never publishes a picture
// until all decoder writes are complete; no presentation pixel depends on the
// collision value.
// -------------------------------------------------------------------------

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (40),
    .widthad_a                      (17),
    .numwords_a                     (Y_FB_WORDS),
    .width_b                        (40),
    .widthad_b                      (17),
    .numwords_b                     (Y_FB_WORDS),
    .byte_size                      (8),
    .width_byteena_a                (5),
    .width_byteena_b                (5),
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
    .q_b            (y_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (y_wr_byteena),
    .byteena_b      (5'b11111),
    .data_b         (40'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (40),
    .widthad_a                      (15),
    .numwords_a                     (C_FB_WORDS),
    .width_b                        (40),
    .widthad_b                      (15),
    .numwords_b                     (C_FB_WORDS),
    .byte_size                      (8),
    .width_byteena_a                (5),
    .width_byteena_b                (5),
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
    .q_b            (cb_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (cb_wr_byteena),
    .byteena_b      (5'b11111),
    .data_b         (40'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (40),
    .widthad_a                      (15),
    .numwords_a                     (C_FB_WORDS),
    .width_b                        (40),
    .widthad_b                      (15),
    .numwords_b                     (C_FB_WORDS),
    .byte_size                      (8),
    .width_byteena_a                (5),
    .width_byteena_b                (5),
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
    .q_b            (cr_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (cr_wr_byteena),
    .byteena_b      (5'b11111),
    .data_b         (40'd0),
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
