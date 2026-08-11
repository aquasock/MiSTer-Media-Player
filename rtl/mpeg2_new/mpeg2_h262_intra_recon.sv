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
//     and macroblock_address_increment gives the difference to the first
//     macroblock.  Therefore the first macroblock column in a slice is
//     macroblock_address_increment - 1.
//   - 6.1.3 / Figure 6-10: in 4:2:0, luminance block 0 is the upper-left 8x8
//     block of the 16x16 macroblock.
//   - 7.6: intra-coded macroblocks form no prediction, so p[y][x] = 0.
//   - 7.6.8: d[y][x] = f[y][x] + p[y][x], saturated to [0,255].
//
// Phase 1F capability boundary:
//   The upstream Phase-1 parser currently supplies only luminance block 0 of
//   the first macroblock in the first captured slice.  This module therefore
//   reconstructs that one 8x8 block, with exact H.262 picture coordinates.
//   It does not infer coordinates from display timing or legacy MPEG2FPGA tags.
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

    input  wire               sample_valid,
    input  wire [5:0]         sample_index,
    input  wire signed [15:0] sample_value,
    input  wire               idct_block_complete,

    output reg                pixel_valid,
    output reg [11:0]         pixel_x,
    output reg [11:0]         pixel_y,
    output reg [7:0]          pixel_luma,
    output reg                block_start,
    output reg                block_complete,
    output reg                recon_error,

    output reg [11:0]         block_origin_x,
    output reg [11:0]         block_origin_y
);

// H.262 6.3.3.  The temporary width is one bit wider so +15 cannot overflow.
wire [14:0] horizontal_size_rounded = {1'b0, horizontal_size} + 15'd15;
wire [10:0] mb_width = horizontal_size_rounded[14:4];

// H.262 6.3.16.  For ordinary SD pictures the extension is absent and the
// first term is zero.  Keeping it here prevents a hidden SD-only coordinate
// rule in this reconstruction block.
wire [10:0] mb_row =
    (vertical_size > 14'd2800) ?
        ({8'd0, slice_vertical_position_extension} << 7) +
         {3'd0, slice_vertical_position} - 11'd1 :
        {3'd0, slice_vertical_position} - 11'd1;

// At slice start previous_macroblock_address is row_base-1, so for the first
// macroblock in the slice its column is increment-1.  This is directly
// equivalent to the normative macroblock-address equations in 6.3.17.
wire [11:0] mb_column = macroblock_address_increment - 12'd1;

wire [15:0] origin_x_calc = {4'd0, mb_column} << 4;
wire [15:0] origin_y_calc = {5'd0, mb_row} << 4;

wire coordinate_state_valid =
    (horizontal_size != 14'd0) &&
    (vertical_size != 14'd0) &&
    (slice_vertical_position != 8'd0) &&
    (macroblock_address_increment != 12'd0) &&
    (mb_width != 11'd0) &&
    (mb_column < mb_width) &&
    (origin_x_calc < 16'd4096) &&
    (origin_y_calc < 16'd4096);

function automatic [7:0] saturate_pel;
    input signed [15:0] value;
    begin
        // H.262 7.6/7.6.8: p[y][x] is zero for intra-coded macroblocks, so
        // d[y][x] is the IDCT result saturated to the decoded-pel range.
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
        pixel_valid           <= 1'b0;
        pixel_x               <= 12'd0;
        pixel_y               <= 12'd0;
        pixel_luma            <= 8'd0;
        block_start           <= 1'b0;
        block_complete        <= 1'b0;
        recon_error           <= 1'b0;
        block_origin_x        <= 12'd0;
        block_origin_y        <= 12'd0;
        capture_active        <= 1'b0;
        expected_sample_index <= 6'd0;
        idct_block_complete_d  <= 1'b0;
    end
    else begin
        pixel_valid   <= 1'b0;
        block_start   <= 1'b0;
        idct_block_complete_d <= idct_block_complete;

        if (sample_valid) begin
            if (!capture_active) begin
                // The IDCT stream is defined to begin at row-major index 0.
                if ((sample_index != 6'd0) || !coordinate_state_valid) begin
                    recon_error <= 1'b1;
                end
                else begin
                    capture_active        <= 1'b1;
                    expected_sample_index <= 6'd1;
                    block_complete        <= 1'b0;
                    block_origin_x        <= origin_x_calc[11:0];
                    block_origin_y        <= origin_y_calc[11:0];

                    pixel_valid <= 1'b1;
                    block_start <= 1'b1;
                    pixel_x     <= origin_x_calc[11:0];
                    pixel_y     <= origin_y_calc[11:0];
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
                    end
                    else begin
                        expected_sample_index <= expected_sample_index + 1'b1;
                    end
                end
            end
        end

        // block_complete from the IDCT and the row-major sample-63 event are
        // expected together.  Treat a completion with no active final sample
        // as an internal pipeline/protocol error, not an H.262 syntax error.
        if (idct_block_complete && !idct_block_complete_d &&
            !(sample_valid && (sample_index == 6'd63))) begin
            recon_error <= 1'b1;
        end
    end
end

endmodule
