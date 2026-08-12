//============================================================================
// MiSTer Media Player - standards-driven H.262 intra reconstruction
//
// Normative standards basis:
//   ITU-T H.262 consolidated text (02/2012):
//   - 6.3.3: mb_width = (horizontal_size + 15) / 16.
//   - 6.3.16: slice_vertical_position identifies the macroblock row; for
//     vertical_size > 2800 the 3-bit slice_vertical_position_extension extends
//     that row number.
//   - 6.3.17: at the start of a slice,
//       previous_macroblock_address = (mb_row * mb_width) - 1,
//     then each macroblock_address_increment advances macroblock_address.
//   - 6.1.3 / Figure 6-10: in 4:2:0, luminance blocks 0..3 occupy the 16x16
//     macroblock as 0/1 on the upper row and 2/3 on the lower row.
//   - 7.6: intra-coded macroblocks form no prediction, so p[y][x] = 0.
//   - 7.6.8: d[y][x] = f[y][x] + p[y][x], saturated to [0,255].
//
// Phase 1L capability boundary:
//   The upstream streaming probe supplies luminance blocks 0..3 for every
//   macroblock in the first slice.  This module accumulates the normative
//   macroblock_address_increment sequence until the row boundary; each 16x16
//   macroblock is therefore placed at its actual picture X coordinate.
//   Chroma remains deferred.
//============================================================================

module mpeg2_h262_intra_recon
(
    input  wire               clk,
    input  wire               reset,

    input  wire [13:0]        horizontal_size,
    input  wire [13:0]        vertical_size,
    input  wire [7:0]         slice_vertical_position,
    input  wire [2:0]         slice_vertical_position_extension,
    input  wire [11:0]        macroblock_address_increment,

    // kate - Pulses once for each accepted Phase-1L intra macroblock header.
    input  wire               macroblock_start,

    input  wire               sample_valid,
    input  wire [5:0]         sample_index,
    input  wire signed [15:0] sample_value,
    input  wire               idct_block_complete,

    output reg                pixel_valid,
    output reg [11:0]         pixel_x,
    output reg [11:0]         pixel_y,
    output reg [7:0]          pixel_luma,
    output reg                block_start,
    // One-cycle completion pulse used as the upstream pipeline-ready handshake.
    output reg                block_complete,
    // Sticky proof that at least one complete macroblock's four Y blocks have
    // traversed reconstruction.  First-slice completion is owned by the parser.
    output reg                macroblock_luma_complete,
    output reg                recon_error,

    output reg [11:0]         block_origin_x,
    output reg [11:0]         block_origin_y
);

// H.262 6.3.3.  The temporary width is one bit wider so +15 cannot overflow.
wire [14:0] horizontal_size_rounded = {1'b0, horizontal_size} + 15'd15;
wire [10:0] mb_width = horizontal_size_rounded[14:4];

// H.262 6.3.16.
wire [10:0] mb_row =
    (vertical_size > 14'd2800) ?
        ({8'd0, slice_vertical_position_extension} << 7) +
         {3'd0, slice_vertical_position} - 11'd1 :
        {3'd0, slice_vertical_position} - 11'd1;

// kate - Phase 1L keeps the accumulated macroblock column explicitly.  For the
// first macroblock in a slice column = increment-1; after that each increment
// is relative to the previously decoded macroblock address (H.262 6.3.17).
// There is deliberately no fixed macroblock-count limit here; the parser owns
// first-slice termination and this stage only enforces the encoded row width.
reg        macroblock_sequence_started;
reg [11:0] current_mb_column;

wire [12:0] first_mb_column_calc =
    {1'b0, macroblock_address_increment} - 13'd1;
wire [12:0] next_mb_column_calc =
    {1'b0, current_mb_column} + {1'b0, macroblock_address_increment};

wire [15:0] macroblock_origin_x_calc = {4'd0, current_mb_column} << 4;
wire [15:0] macroblock_origin_y_calc = {5'd0, mb_row} << 4;

wire coordinate_state_valid =
    macroblock_sequence_started &&
    (horizontal_size != 14'd0) &&
    (vertical_size != 14'd0) &&
    (slice_vertical_position != 8'd0) &&
    (mb_width != 11'd0) &&
    (current_mb_column < mb_width) &&
    (macroblock_origin_x_calc < 16'd4096) &&
    (macroblock_origin_y_calc < 16'd4096);

// H.262 6.1.3 / Figure 6-10, 4:2:0 frame macroblock luminance layout:
//       0 1
//       2 3
reg [1:0] luma_block_index;
wire [3:0] luma_block_x_offset = luma_block_index[0] ? 4'd8 : 4'd0;
wire [3:0] luma_block_y_offset = luma_block_index[1] ? 4'd8 : 4'd0;

wire [15:0] block_origin_x_calc =
    macroblock_origin_x_calc + {12'd0, luma_block_x_offset};
wire [15:0] block_origin_y_calc =
    macroblock_origin_y_calc + {12'd0, luma_block_y_offset};

function automatic [7:0] saturate_pel;
    input signed [15:0] value;
    begin
        // H.262 7.6/7.6.8: p[y][x] is zero for intra-coded macroblocks.
        if (value < 16'sd0)
            saturate_pel = 8'd0;
        else if (value > 16'sd255)
            saturate_pel = 8'd255;
        else
            saturate_pel = value[7:0];
    end
endfunction

reg       capture_active;
reg [5:0] expected_sample_index;
reg       idct_block_complete_d;

always @(posedge clk) begin
    if (reset) begin
        pixel_valid                 <= 1'b0;
        pixel_x                     <= 12'd0;
        pixel_y                     <= 12'd0;
        pixel_luma                  <= 8'd0;
        block_start                 <= 1'b0;
        block_complete              <= 1'b0;
        macroblock_luma_complete    <= 1'b0;
        recon_error                 <= 1'b0;
        block_origin_x              <= 12'd0;
        block_origin_y              <= 12'd0;
        luma_block_index            <= 2'd0;
        macroblock_sequence_started <= 1'b0;
        current_mb_column           <= 12'd0;
        capture_active              <= 1'b0;
        expected_sample_index       <= 6'd0;
        idct_block_complete_d       <= 1'b0;
    end
    else begin
        pixel_valid    <= 1'b0;
        block_start    <= 1'b0;
        block_complete <= 1'b0;
        idct_block_complete_d <= idct_block_complete;

        if (macroblock_start) begin
            if (capture_active || (macroblock_address_increment == 12'd0)) begin
                recon_error <= 1'b1;
            end
            else if (!macroblock_sequence_started) begin
                if (first_mb_column_calc >= {2'd0, mb_width}) begin
                    recon_error <= 1'b1;
                end
                else begin
                    current_mb_column           <= first_mb_column_calc[11:0];
                    macroblock_sequence_started <= 1'b1;
                    luma_block_index            <= 2'd0;
                end
            end
            else begin
                // H.262 6.3.17 advances macroblock_address by the decoded
                // increment.  Phase 1L permits every legal column in this row
                // rather than imposing Phase 1J's four-macroblock test limit.
                if (next_mb_column_calc >= {2'd0, mb_width}) begin
                    recon_error <= 1'b1;
                end
                else begin
                    current_mb_column <= next_mb_column_calc[11:0];
                    luma_block_index  <= 2'd0;
                end
            end
        end

        if (sample_valid) begin
            if (!capture_active) begin
                if ((sample_index != 6'd0) || !coordinate_state_valid) begin
                    recon_error <= 1'b1;
                end
                else begin
                    capture_active        <= 1'b1;
                    expected_sample_index <= 6'd1;
                    block_origin_x        <= block_origin_x_calc[11:0];
                    block_origin_y        <= block_origin_y_calc[11:0];

                    pixel_valid <= 1'b1;
                    block_start <= 1'b1;
                    pixel_x     <= block_origin_x_calc[11:0];
                    pixel_y     <= block_origin_y_calc[11:0];
                    pixel_luma  <= saturate_pel(sample_value);
                end
            end
            else begin
                if (sample_index != expected_sample_index) begin
                    recon_error <= 1'b1;
                end
                else begin
                    pixel_valid <= 1'b1;
                    pixel_x     <= block_origin_x + {9'd0, sample_index[2:0]};
                    pixel_y     <= block_origin_y + {9'd0, sample_index[5:3]};
                    pixel_luma  <= saturate_pel(sample_value);

                    if (sample_index == 6'd63) begin
                        capture_active        <= 1'b0;
                        expected_sample_index <= 6'd0;
                        block_complete        <= 1'b1;

                        if (luma_block_index == 2'd3) begin
                            macroblock_luma_complete <= 1'b1;
                        end
                        else begin
                            luma_block_index <= luma_block_index + 2'd1;
                        end
                    end
                    else begin
                        expected_sample_index <= expected_sample_index + 6'd1;
                    end
                end
            end
        end

        // Each IDCT completion must coincide with the final row-major sample.
        if (idct_block_complete && !idct_block_complete_d &&
            !(sample_valid && (sample_index == 6'd63))) begin
            recon_error <= 1'b1;
        end
    end
end

endmodule
