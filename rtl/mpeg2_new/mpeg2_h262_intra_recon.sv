//============================================================================
// MiSTer Media Player - standards-driven H.262 intra 4:2:0 reconstruction
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:
//   - 6.3.3: mb_width = (horizontal_size + 15) / 16.
//   - 6.3.16: slice_vertical_position identifies the macroblock row; for
//     vertical_size > 2800 the 3-bit slice_vertical_position_extension extends
//     that row number.
//   - 6.3.17: at the start of a slice,
//       previous_macroblock_address = (mb_row * mb_width) - 1,
//     then each macroblock_address_increment advances macroblock_address.
//   - 6.1.3 / Figure 6-10: 4:2:0 macroblock block order is
//       Y0, Y1, Y2, Y3, Cb, Cr.
//   - 7.6: intra-coded macroblocks form no prediction, so p[y][x] = 0.
//   - 7.6.8: d[y][x] = f[y][x] + p[y][x], saturated to [0,255].
//
// Phase 1N capability boundary:
//   The upstream streaming parser now submits all six 4:2:0 intra blocks for
//   every macroblock of the first picture.  Y samples are emitted in full-size
//   picture coordinates; Cb and Cr samples are emitted in their 1/2-width,
//   1/2-height component-plane coordinates.  Chroma upsampling and YCbCr->RGB
//   presentation are deliberately downstream concerns.
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

    // kate - Pulses once for every accepted slice_start_code.  H.262 6.3.17
    // restarts previous_macroblock_address at each slice.
    input  wire               slice_start,

    // Pulses once for each accepted Phase-1N intra macroblock header.
    input  wire               macroblock_start,

    // Legacy parser module exposes the current H.262 4:2:0 block number.
    // It remains stable from qfs_block_start through this block_complete.
    input  wire [2:0]         block_index,

    input  wire               sample_valid,
    input  wire [5:0]         sample_index,
    input  wire signed [15:0] sample_value,
    input  wire               idct_block_complete,

    output reg                pixel_valid,
    // 0 = Y, 1 = Cb, 2 = Cr.
    output reg [1:0]          pixel_component,
    output reg [11:0]         pixel_x,
    output reg [11:0]         pixel_y,
    output reg [7:0]          pixel_value,
    output reg                block_start,
    // One-cycle completion pulse used as the upstream pipeline-ready handshake.
    output reg                block_complete,
    // Sticky proof that at least one complete six-block 4:2:0 macroblock has
    // traversed reconstruction.  First-picture completion is owned by parser.
    output reg                macroblock_420_complete,
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

// H.262 6.3.17 macroblock-address progression within one slice.
reg        macroblock_sequence_started;
reg [11:0] current_mb_column;

wire [12:0] first_mb_column_calc =
    {1'b0, macroblock_address_increment} - 13'd1;
wire [12:0] next_mb_column_calc =
    {1'b0, current_mb_column} + {1'b0, macroblock_address_increment};

wire [15:0] luma_macroblock_origin_x = {4'd0, current_mb_column} << 4;
wire [15:0] luma_macroblock_origin_y = {5'd0, mb_row} << 4;
wire [15:0] chroma_macroblock_origin_x = {4'd0, current_mb_column} << 3;
wire [15:0] chroma_macroblock_origin_y = {5'd0, mb_row} << 3;

wire coordinate_state_valid =
    macroblock_sequence_started &&
    (horizontal_size != 14'd0) &&
    (vertical_size != 14'd0) &&
    (slice_vertical_position != 8'd0) &&
    (mb_width != 11'd0) &&
    (current_mb_column < mb_width) &&
    (block_index <= 3'd5);

// H.262 4:2:0 block layout:
//       Y0 Y1       Cb and Cr each contain one 8x8 block
//       Y2 Y3       for the same 16x16 luma macroblock.
wire [3:0] luma_block_x_offset = block_index[0] ? 4'd8 : 4'd0;
wire [3:0] luma_block_y_offset = block_index[1] ? 4'd8 : 4'd0;
wire       current_block_is_luma = (block_index < 3'd4);
wire [1:0] current_component = current_block_is_luma ? 2'd0 :
                               (block_index == 3'd4) ? 2'd1 : 2'd2;

wire [15:0] block_origin_x_calc = current_block_is_luma ?
    (luma_macroblock_origin_x + {12'd0, luma_block_x_offset}) :
     chroma_macroblock_origin_x;
wire [15:0] block_origin_y_calc = current_block_is_luma ?
    (luma_macroblock_origin_y + {12'd0, luma_block_y_offset}) :
     chroma_macroblock_origin_y;

function automatic [7:0] saturate_pel;
    input signed [15:0] value;
    begin
        // H.262 7.6/7.6.8: p[y][x] is zero for an intra-coded macroblock.
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
reg [2:0] active_block_index;
reg [1:0] active_component;

always @(posedge clk) begin
    if (reset) begin
        pixel_valid                 <= 1'b0;
        pixel_component             <= 2'd0;
        pixel_x                     <= 12'd0;
        pixel_y                     <= 12'd0;
        pixel_value                 <= 8'd0;
        block_start                 <= 1'b0;
        block_complete              <= 1'b0;
        macroblock_420_complete     <= 1'b0;
        recon_error                 <= 1'b0;
        block_origin_x              <= 12'd0;
        block_origin_y              <= 12'd0;
        macroblock_sequence_started <= 1'b0;
        current_mb_column           <= 12'd0;
        capture_active              <= 1'b0;
        expected_sample_index       <= 6'd0;
        idct_block_complete_d       <= 1'b0;
        active_block_index          <= 3'd0;
        active_component            <= 2'd0;
    end
    else begin
        pixel_valid    <= 1'b0;
        block_start    <= 1'b0;
        block_complete <= 1'b0;
        idct_block_complete_d <= idct_block_complete;

        if (slice_start) begin
            // The parser emits this only after the previous slice's final Cr
            // block has completed, so downstream sample capture must be idle.
            if (capture_active) begin
                recon_error <= 1'b1;
            end
            else begin
                macroblock_sequence_started <= 1'b0;
                current_mb_column           <= 12'd0;
            end
        end

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
                end
            end
            else begin
                if (next_mb_column_calc >= {2'd0, mb_width}) begin
                    recon_error <= 1'b1;
                end
                else begin
                    current_mb_column <= next_mb_column_calc[11:0];
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
                    active_block_index    <= block_index;
                    active_component      <= current_component;
                    block_origin_x        <= block_origin_x_calc[11:0];
                    block_origin_y        <= block_origin_y_calc[11:0];

                    pixel_valid     <= 1'b1;
                    block_start     <= 1'b1;
                    pixel_component <= current_component;
                    pixel_x         <= block_origin_x_calc[11:0];
                    pixel_y         <= block_origin_y_calc[11:0];
                    pixel_value     <= saturate_pel(sample_value);
                end
            end
            else begin
                if (sample_index != expected_sample_index) begin
                    recon_error <= 1'b1;
                end
                else begin
                    pixel_valid     <= 1'b1;
                    pixel_component <= active_component;
                    pixel_x         <= block_origin_x + {9'd0, sample_index[2:0]};
                    pixel_y         <= block_origin_y + {9'd0, sample_index[5:3]};
                    pixel_value     <= saturate_pel(sample_value);

                    if (sample_index == 6'd63) begin
                        capture_active        <= 1'b0;
                        expected_sample_index <= 6'd0;
                        block_complete        <= 1'b1;

                        if (active_block_index == 3'd5)
                            macroblock_420_complete <= 1'b1;
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
