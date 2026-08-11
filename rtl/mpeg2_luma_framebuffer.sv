// kate - Decoupled MPEG2 luma framebuffer.
//
// Phase 1J diagnostic 3 publication build.
//
// The decoder still targets the first four 4:2:0 intra macroblocks' luminance:
// sixteen 8x8 Y blocks forming one 64x16 horizontal strip.  The decoder writes
// explicit picture X/Y coordinates at 54 MHz while the independent fixed SVGA
// raster reads at 40 MHz.
//
// kate - This diagnostic version keeps the earlier progressive macroblock
// publication and first row of five MB3-luma markers.  A second row of six
// markers reports MB3 Cb/Cr decode milestones, normal Phase-1J completion, and
// probe_error.  The markers observe state only; decode decisions are unchanged.
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

    // kate - Phase 1J diagnostic-3 sticky parser milestones, all generated in
    // the same 54 MHz domain as the framebuffer write port.
    input  wire        wr_diag_mb3_cb_dc_seen,
    input  wire        wr_diag_mb3_cb_eob_seen,
    input  wire        wr_diag_mb3_cr_dc_seen,
    input  wire        wr_diag_mb3_cr_eob_seen,
    input  wire        wr_diag_phase1j_complete,
    input  wire        wr_diag_probe_error,

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
// Write-side address generation and diagnostic macroblock publication.
// -------------------------------------------------------------------------

reg [18:0] ram_wr_address;
reg [7:0]  ram_wr_data;
reg        ram_wr_en;

wire [18:0] wr_linear_address =
    (wr_y_pos * 19'd720) + wr_x_pos;

reg [11:0] strip_origin_x_wr;
reg [11:0] strip_origin_y_wr;
reg [4:0]  completed_luma_blocks_wr;
reg [2:0]  macroblocks_started_wr;
reg        strip_active_wr;

// kate - Thermometer publication bits are monotonic.  Each bit crosses the
// 54->40 MHz boundary independently through two flip-flops, avoiding a binary
// count CDC where a multi-bit transition could momentarily decode incorrectly.
// bit 0 = MB0 Y complete, bit 1 = MB1 Y complete, ... bit 3 = MB3 Y complete.
reg [3:0] published_macroblocks_wr;

// kate - Phase 1J diagnostic-2 progress state for the fourth macroblock.
// mb3_started_wr goes high on the fourth luma_macroblock_start pulse, which is
// emitted only after the parser has accepted MB3's macroblock type.
// mb3_luma_blocks_done_wr is a thermometer for MB3 Y0..Y3 reconstruction.
reg       mb3_started_wr;
reg [3:0] mb3_luma_blocks_done_wr;

always @(posedge wr_clk) begin
    if (reset) begin
        ram_wr_address             <= 19'd0;
        ram_wr_data                <= 8'd0;
        ram_wr_en                  <= 1'b0;
        strip_origin_x_wr          <= 12'd0;
        strip_origin_y_wr          <= 12'd0;
        completed_luma_blocks_wr   <= 5'd0;
        macroblocks_started_wr     <= 3'd0;
        strip_active_wr            <= 1'b0;
        published_macroblocks_wr   <= 4'b0000;
        mb3_started_wr              <= 1'b0;
        mb3_luma_blocks_done_wr     <= 4'b0000;
    end
    else begin
        ram_wr_en <= 1'b0;

        if (wr_macroblock_start) begin
            if (!strip_active_wr && (published_macroblocks_wr == 4'b0000)) begin
                completed_luma_blocks_wr <= 5'd0;
                macroblocks_started_wr   <= 3'd1;
                strip_active_wr          <= 1'b1;
            end
            else if (strip_active_wr && (macroblocks_started_wr < 3'd4)) begin
                // Before the fourth start pulse the counter is 3.
                if (macroblocks_started_wr == 3'd3)
                    mb3_started_wr <= 1'b1;
                macroblocks_started_wr <= macroblocks_started_wr + 3'd1;
            end
        end

        if (wr_block_start && strip_active_wr &&
            (completed_luma_blocks_wr == 5'd0)) begin
            strip_origin_x_wr <= wr_x_pos;
            strip_origin_y_wr <= wr_y_pos;
        end

        if (wr_block_complete && strip_active_wr) begin
            case (completed_luma_blocks_wr)
                5'd3: begin
                    // Four Y blocks = macroblock 0 complete.
                    published_macroblocks_wr[0] <= 1'b1;
                    completed_luma_blocks_wr    <= 5'd4;
                end
                5'd7: begin
                    published_macroblocks_wr[1] <= 1'b1;
                    completed_luma_blocks_wr    <= 5'd8;
                end
                5'd11: begin
                    published_macroblocks_wr[2] <= 1'b1;
                    completed_luma_blocks_wr    <= 5'd12;
                end
                5'd12: begin
                    // MB3 Y block 0 completed.
                    mb3_luma_blocks_done_wr[0] <= 1'b1;
                    completed_luma_blocks_wr   <= 5'd13;
                end
                5'd13: begin
                    // MB3 Y block 1 completed.
                    mb3_luma_blocks_done_wr[1] <= 1'b1;
                    completed_luma_blocks_wr   <= 5'd14;
                end
                5'd14: begin
                    // MB3 Y block 2 completed.
                    mb3_luma_blocks_done_wr[2] <= 1'b1;
                    completed_luma_blocks_wr   <= 5'd15;
                end
                5'd15: begin
                    // MB3 Y block 3 completed; the full fourth macroblock is visible.
                    mb3_luma_blocks_done_wr[3] <= 1'b1;
                    published_macroblocks_wr[3] <= 1'b1;
                    completed_luma_blocks_wr    <= 5'd16;
                    strip_active_wr             <= 1'b0;
                end
                default: begin
                    completed_luma_blocks_wr <= completed_luma_blocks_wr + 5'd1;
                end
            endcase
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
// Read-side synchronization of the strip origin and publication thermometer.
// -------------------------------------------------------------------------

reg [3:0]  published_macroblocks_rd_1;
reg [3:0]  published_macroblocks_rd_2;
reg [11:0] strip_origin_x_rd_1;
reg [11:0] strip_origin_x_rd_2;
reg [11:0] strip_origin_y_rd_1;
reg [11:0] strip_origin_y_rd_2;
reg        mb3_started_rd_1;
reg        mb3_started_rd_2;
reg [3:0]  mb3_luma_blocks_done_rd_1;
reg [3:0]  mb3_luma_blocks_done_rd_2;
reg [5:0]  chroma_status_rd_1;
reg [5:0]  chroma_status_rd_2;

always @(posedge rd_clk) begin
    if (reset) begin
        published_macroblocks_rd_1 <= 4'b0000;
        published_macroblocks_rd_2 <= 4'b0000;
        strip_origin_x_rd_1        <= 12'd0;
        strip_origin_x_rd_2        <= 12'd0;
        strip_origin_y_rd_1        <= 12'd0;
        strip_origin_y_rd_2        <= 12'd0;
        mb3_started_rd_1             <= 1'b0;
        mb3_started_rd_2             <= 1'b0;
        mb3_luma_blocks_done_rd_1    <= 4'b0000;
        mb3_luma_blocks_done_rd_2    <= 4'b0000;
        chroma_status_rd_1            <= 6'b000000;
        chroma_status_rd_2            <= 6'b000000;
    end
    else begin
        published_macroblocks_rd_1 <= published_macroblocks_wr;
        published_macroblocks_rd_2 <= published_macroblocks_rd_1;
        strip_origin_x_rd_1        <= strip_origin_x_wr;
        strip_origin_x_rd_2        <= strip_origin_x_rd_1;
        strip_origin_y_rd_1        <= strip_origin_y_wr;
        strip_origin_y_rd_2        <= strip_origin_y_rd_1;
        mb3_started_rd_1             <= mb3_started_wr;
        mb3_started_rd_2             <= mb3_started_rd_1;
        mb3_luma_blocks_done_rd_1    <= mb3_luma_blocks_done_wr;
        mb3_luma_blocks_done_rd_2    <= mb3_luma_blocks_done_rd_1;
        chroma_status_rd_1 <= {
            wr_diag_probe_error,
            wr_diag_phase1j_complete,
            wr_diag_mb3_cr_eob_seen,
            wr_diag_mb3_cr_dc_seen,
            wr_diag_mb3_cb_eob_seen,
            wr_diag_mb3_cb_dc_seen
        };
        chroma_status_rd_2 <= chroma_status_rd_1;
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

wire [11:0] published_width =
    published_macroblocks_rd_2[3] ? 12'd64 :
    published_macroblocks_rd_2[2] ? 12'd48 :
    published_macroblocks_rd_2[1] ? 12'd32 :
    published_macroblocks_rd_2[0] ? 12'd16 : 12'd0;

wire decoded_strip_window =
    source_window &&
    (published_width != 12'd0) &&
    (source_x >= strip_origin_x_rd_2) &&
    (source_x <  strip_origin_x_rd_2 + published_width) &&
    (source_y >= strip_origin_y_rd_2) &&
    (source_y <  strip_origin_y_rd_2 + 12'd16);

// kate - Five 8x8 status cells at picture coordinates y=24..31.
//   cell 0: MB3 macroblock type accepted / reconstruction context started
//   cell 1: MB3 Y0 reconstructed
//   cell 2: MB3 Y1 reconstructed
//   cell 3: MB3 Y2 reconstructed
//   cell 4: MB3 Y3 reconstructed
// Reached cells are bright (220); unreached cells are dim (48).  They are
// intentionally outside the decoded 64x16 strip and are diagnostic UI only.
wire diagnostic_status_row =
    source_window && (source_y >= 12'd24) && (source_y < 12'd32);

wire status_cell0 = diagnostic_status_row && (source_x < 12'd8);
wire status_cell1 = diagnostic_status_row && (source_x >= 12'd10) && (source_x < 12'd18);
wire status_cell2 = diagnostic_status_row && (source_x >= 12'd20) && (source_x < 12'd28);
wire status_cell3 = diagnostic_status_row && (source_x >= 12'd30) && (source_x < 12'd38);
wire status_cell4 = diagnostic_status_row && (source_x >= 12'd40) && (source_x < 12'd48);
wire diagnostic_status_window = status_cell0 || status_cell1 || status_cell2 ||
                                status_cell3 || status_cell4;
wire diagnostic_status_on =
    (status_cell0 && mb3_started_rd_2) ||
    (status_cell1 && mb3_luma_blocks_done_rd_2[0]) ||
    (status_cell2 && mb3_luma_blocks_done_rd_2[1]) ||
    (status_cell3 && mb3_luma_blocks_done_rd_2[2]) ||
    (status_cell4 && mb3_luma_blocks_done_rd_2[3]);

// kate - Phase 1J diagnostic-3 second row at picture y=36..43.
//   cell 0: MB3 Cb DC decoded
//   cell 1: MB3 Cb EOB decoded
//   cell 2: MB3 Cr DC decoded
//   cell 3: MB3 Cr EOB decoded
//   cell 4: normal Phase-1J final completion flag
//   cell 5: probe_error (bright means an error was actually raised)
wire diagnostic_chroma_row =
    source_window && (source_y >= 12'd36) && (source_y < 12'd44);

wire chroma_cell0 = diagnostic_chroma_row && (source_x < 12'd8);
wire chroma_cell1 = diagnostic_chroma_row && (source_x >= 12'd10) && (source_x < 12'd18);
wire chroma_cell2 = diagnostic_chroma_row && (source_x >= 12'd20) && (source_x < 12'd28);
wire chroma_cell3 = diagnostic_chroma_row && (source_x >= 12'd30) && (source_x < 12'd38);
wire chroma_cell4 = diagnostic_chroma_row && (source_x >= 12'd40) && (source_x < 12'd48);
wire chroma_cell5 = diagnostic_chroma_row && (source_x >= 12'd50) && (source_x < 12'd58);
wire diagnostic_chroma_window = chroma_cell0 || chroma_cell1 || chroma_cell2 ||
                                chroma_cell3 || chroma_cell4 || chroma_cell5;
wire diagnostic_chroma_on =
    (chroma_cell0 && chroma_status_rd_2[0]) ||
    (chroma_cell1 && chroma_status_rd_2[1]) ||
    (chroma_cell2 && chroma_status_rd_2[2]) ||
    (chroma_cell3 && chroma_status_rd_2[3]) ||
    (chroma_cell4 && chroma_status_rd_2[4]) ||
    (chroma_cell5 && chroma_status_rd_2[5]);

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
reg decoded_strip_window_d;
reg diagnostic_status_window_d;
reg diagnostic_status_on_d;
reg diagnostic_chroma_window_d;
reg diagnostic_chroma_on_d;

always @(posedge rd_clk) begin
    if (reset) begin
        source_window_d        <= 1'b0;
        decoded_strip_window_d     <= 1'b0;
        diagnostic_status_window_d <= 1'b0;
        diagnostic_status_on_d     <= 1'b0;
        diagnostic_chroma_window_d <= 1'b0;
        diagnostic_chroma_on_d     <= 1'b0;
        video_y                     <= 8'd0;
        video_de               <= 1'b0;
        video_hs               <= 1'b0;
        video_vs               <= 1'b0;
    end
    else begin
        source_window_d            <= source_window;
        decoded_strip_window_d     <= decoded_strip_window;
        diagnostic_status_window_d <= diagnostic_status_window;
        diagnostic_status_on_d     <= diagnostic_status_on;
        diagnostic_chroma_window_d <= diagnostic_chroma_window;
        diagnostic_chroma_on_d     <= diagnostic_chroma_on;

        video_de <= pixel_en;
        video_hs <= h_sync;
        video_vs <= v_sync;

        if (decoded_strip_window_d)
            video_y <= ram_rd_data;
        else if (diagnostic_status_window_d)
            video_y <= diagnostic_status_on_d ? 8'd220 : 8'd48;
        else if (diagnostic_chroma_window_d)
            video_y <= diagnostic_chroma_on_d ? 8'd220 : 8'd48;
        else if (source_window_d)
            video_y <= 8'd24;
        else
            video_y <= 8'd0;
    end
end

endmodule
