//============================================================================
// MiSTer Media Player - new H.262 decoder inverse quantiser
//
// This diagnostic engine receives the complete QFS[] coefficient set for the
// first intra luminance block, performs the H.262 inverse scan and inverse
// quantisation, saturates the reconstructed coefficients, and applies MPEG-2
// mismatch control.  It remains passive; the legacy MPEG2FPGA path still owns
// displayed video during the current bootstrap phases.
//
// Normative standards basis:
//   ITU-T H.262 (02/2000) / ISO/IEC 13818-2:2000
//   - 6.3.11 default quantisation matrices
//   - 7.3 inverse scan / Figures 7-2 and 7-3
//   - 7.4.1 intra DC inverse quantisation / Table 7-4
//   - 7.4.2 weighting matrix and quantiser scale / Tables 7-5 and 7-6
//   - 7.4.3 saturation
//   - 7.4.4 mismatch control
//
// Phase 1D capability boundary:
//   The normative default intra matrix is implemented.  Downloaded custom
//   matrices are valid H.262, but are reported as unsupported until matrix
//   download storage is implemented in a later phase.
//============================================================================
module mpeg2_h262_inverse_quant
(
    input  wire               clk,
    input  wire               reset,

    input  wire               block_start,
    input  wire               coeff_write_en,
    input  wire [5:0]         coeff_write_index,
    input  wire signed [12:0] coeff_write_value,
    input  wire               block_end,

    input  wire               intra_quant_matrix_default,
    input  wire [1:0]         intra_dc_precision,
    input  wire [4:0]         quantiser_scale_code,
    input  wire               q_scale_type,
    input  wire               alternate_scan,

    output reg                block_complete,
    output reg                iq_error,
    output reg                unsupported_matrix,
    output reg signed [11:0]  first_luma_f00,
    output reg signed [11:0]  first_luma_f77,

    // kate - Phase 1E streams the final, mismatch-corrected F[v][u]
    // coefficients in physical row-major order to the IDCT.
    output reg                coeff_out_block_start,
    output reg                coeff_out_valid,
    output reg [5:0]          coeff_out_index,
    output reg signed [11:0]  coeff_out_value,
    output reg                coeff_out_block_end
);

// QFS[] is the one-dimensional coefficient array produced by H.262 7.2.
// kate - This small register array is deliberate for the first-block proof.
// A streaming/block RAM implementation can replace it when the full decoder
// begins processing every block continuously.
reg signed [12:0] qfs [0:63];
reg signed [11:0] reconstructed [0:63];
integer i;

reg       busy;
reg [5:0] physical_index;
reg       parity_lsb;
reg       emit_active;
reg [5:0] emit_index;

reg [1:0] latched_intra_dc_precision;
reg [4:0] latched_quantiser_scale_code;
reg       latched_q_scale_type;
reg       latched_alternate_scan;

// H.262 7.3 Figures 7-2 and 7-3 define scan[alternate_scan][v][u].
// physical_index is v*8+u; the function returns n such that
// QF[v][u] = QFS[n].
function automatic [5:0] scan_index;
    input       alternate;
    input [5:0] linear;
    begin
        if (!alternate) begin
            case (linear)
                 0: scan_index =  0;  1: scan_index =  1;
                 2: scan_index =  5;  3: scan_index =  6;
                 4: scan_index = 14;  5: scan_index = 15;
                 6: scan_index = 27;  7: scan_index = 28;
                 8: scan_index =  2;  9: scan_index =  4;
                10: scan_index =  7; 11: scan_index = 13;
                12: scan_index = 16; 13: scan_index = 26;
                14: scan_index = 29; 15: scan_index = 42;
                16: scan_index =  3; 17: scan_index =  8;
                18: scan_index = 12; 19: scan_index = 17;
                20: scan_index = 25; 21: scan_index = 30;
                22: scan_index = 41; 23: scan_index = 43;
                24: scan_index =  9; 25: scan_index = 11;
                26: scan_index = 18; 27: scan_index = 24;
                28: scan_index = 31; 29: scan_index = 40;
                30: scan_index = 44; 31: scan_index = 53;
                32: scan_index = 10; 33: scan_index = 19;
                34: scan_index = 23; 35: scan_index = 32;
                36: scan_index = 39; 37: scan_index = 45;
                38: scan_index = 52; 39: scan_index = 54;
                40: scan_index = 20; 41: scan_index = 22;
                42: scan_index = 33; 43: scan_index = 38;
                44: scan_index = 46; 45: scan_index = 51;
                46: scan_index = 55; 47: scan_index = 60;
                48: scan_index = 21; 49: scan_index = 34;
                50: scan_index = 37; 51: scan_index = 47;
                52: scan_index = 50; 53: scan_index = 56;
                54: scan_index = 59; 55: scan_index = 61;
                56: scan_index = 35; 57: scan_index = 36;
                58: scan_index = 48; 59: scan_index = 49;
                60: scan_index = 57; 61: scan_index = 58;
                62: scan_index = 62; 63: scan_index = 63;
                default: scan_index = 6'd0;
            endcase
        end
        else begin
            case (linear)
                 0: scan_index =  0;  1: scan_index =  4;
                 2: scan_index =  6;  3: scan_index = 20;
                 4: scan_index = 22;  5: scan_index = 36;
                 6: scan_index = 38;  7: scan_index = 52;
                 8: scan_index =  1;  9: scan_index =  5;
                10: scan_index =  7; 11: scan_index = 21;
                12: scan_index = 23; 13: scan_index = 37;
                14: scan_index = 39; 15: scan_index = 53;
                16: scan_index =  2; 17: scan_index =  8;
                18: scan_index = 19; 19: scan_index = 24;
                20: scan_index = 34; 21: scan_index = 40;
                22: scan_index = 50; 23: scan_index = 54;
                24: scan_index =  3; 25: scan_index =  9;
                26: scan_index = 18; 27: scan_index = 25;
                28: scan_index = 35; 29: scan_index = 41;
                30: scan_index = 51; 31: scan_index = 55;
                32: scan_index = 10; 33: scan_index = 17;
                34: scan_index = 26; 35: scan_index = 30;
                36: scan_index = 42; 37: scan_index = 46;
                38: scan_index = 56; 39: scan_index = 60;
                40: scan_index = 11; 41: scan_index = 16;
                42: scan_index = 27; 43: scan_index = 31;
                44: scan_index = 43; 45: scan_index = 47;
                46: scan_index = 57; 47: scan_index = 61;
                48: scan_index = 12; 49: scan_index = 15;
                50: scan_index = 28; 51: scan_index = 32;
                52: scan_index = 44; 53: scan_index = 48;
                54: scan_index = 58; 55: scan_index = 62;
                56: scan_index = 13; 57: scan_index = 14;
                58: scan_index = 29; 59: scan_index = 33;
                60: scan_index = 45; 61: scan_index = 49;
                62: scan_index = 59; 63: scan_index = 63;
                default: scan_index = 6'd0;
            endcase
        end
    end
endfunction

// H.262 6.3.11 normative default intra quantisation matrix.  For 4:2:0,
// Table 7-5 selects this same intra matrix for luminance and chrominance.
function automatic [7:0] default_intra_weight;
    input [5:0] linear;
    begin
        case (linear)
             0: default_intra_weight =  8;  1: default_intra_weight = 16;
             2: default_intra_weight = 19;  3: default_intra_weight = 22;
             4: default_intra_weight = 26;  5: default_intra_weight = 27;
             6: default_intra_weight = 29;  7: default_intra_weight = 34;
             8: default_intra_weight = 16;  9: default_intra_weight = 16;
            10: default_intra_weight = 22; 11: default_intra_weight = 24;
            12: default_intra_weight = 27; 13: default_intra_weight = 29;
            14: default_intra_weight = 34; 15: default_intra_weight = 37;
            16: default_intra_weight = 19; 17: default_intra_weight = 22;
            18: default_intra_weight = 26; 19: default_intra_weight = 27;
            20: default_intra_weight = 29; 21: default_intra_weight = 34;
            22: default_intra_weight = 34; 23: default_intra_weight = 38;
            24: default_intra_weight = 22; 25: default_intra_weight = 22;
            26: default_intra_weight = 26; 27: default_intra_weight = 27;
            28: default_intra_weight = 29; 29: default_intra_weight = 34;
            30: default_intra_weight = 37; 31: default_intra_weight = 40;
            32: default_intra_weight = 22; 33: default_intra_weight = 26;
            34: default_intra_weight = 27; 35: default_intra_weight = 29;
            36: default_intra_weight = 32; 37: default_intra_weight = 35;
            38: default_intra_weight = 40; 39: default_intra_weight = 48;
            40: default_intra_weight = 26; 41: default_intra_weight = 27;
            42: default_intra_weight = 29; 43: default_intra_weight = 32;
            44: default_intra_weight = 35; 45: default_intra_weight = 40;
            46: default_intra_weight = 48; 47: default_intra_weight = 58;
            48: default_intra_weight = 26; 49: default_intra_weight = 27;
            50: default_intra_weight = 29; 51: default_intra_weight = 34;
            52: default_intra_weight = 38; 53: default_intra_weight = 46;
            54: default_intra_weight = 56; 55: default_intra_weight = 69;
            56: default_intra_weight = 27; 57: default_intra_weight = 29;
            58: default_intra_weight = 35; 59: default_intra_weight = 38;
            60: default_intra_weight = 46; 61: default_intra_weight = 56;
            62: default_intra_weight = 69; 63: default_intra_weight = 83;
            default: default_intra_weight = 8'd16;
        endcase
    end
endfunction

// H.262 Table 7-6 quantiser_scale mapping.
function automatic [7:0] quantiser_scale_value;
    input       nonlinear;
    input [4:0] code;
    begin
        if (!nonlinear) begin
            quantiser_scale_value = {code, 1'b0};
        end
        else begin
            case (code)
                 1: quantiser_scale_value =   1;
                 2: quantiser_scale_value =   2;
                 3: quantiser_scale_value =   3;
                 4: quantiser_scale_value =   4;
                 5: quantiser_scale_value =   5;
                 6: quantiser_scale_value =   6;
                 7: quantiser_scale_value =   7;
                 8: quantiser_scale_value =   8;
                 9: quantiser_scale_value =  10;
                10: quantiser_scale_value =  12;
                11: quantiser_scale_value =  14;
                12: quantiser_scale_value =  16;
                13: quantiser_scale_value =  18;
                14: quantiser_scale_value =  20;
                15: quantiser_scale_value =  22;
                16: quantiser_scale_value =  24;
                17: quantiser_scale_value =  28;
                18: quantiser_scale_value =  32;
                19: quantiser_scale_value =  36;
                20: quantiser_scale_value =  40;
                21: quantiser_scale_value =  44;
                22: quantiser_scale_value =  48;
                23: quantiser_scale_value =  52;
                24: quantiser_scale_value =  56;
                25: quantiser_scale_value =  64;
                26: quantiser_scale_value =  72;
                27: quantiser_scale_value =  80;
                28: quantiser_scale_value =  88;
                29: quantiser_scale_value =  96;
                30: quantiser_scale_value = 104;
                31: quantiser_scale_value = 112;
                default: quantiser_scale_value = 8'd0;
            endcase
        end
    end
endfunction

wire [5:0] qfs_read_index =
    scan_index(latched_alternate_scan, physical_index);
wire signed [12:0] qfs_current = qfs[qfs_read_index];
wire [7:0] weight_current = default_intra_weight(physical_index);
wire [7:0] quantiser_scale_current =
    quantiser_scale_value(latched_q_scale_type,
                          latched_quantiser_scale_code);

reg signed [31:0] qfs_ext;
reg signed [31:0] weight_ext;
reg signed [31:0] qscale_ext;
reg signed [31:0] dc_mult_ext;
reg signed [31:0] product_qw;
reg signed [31:0] product_qws;
reg signed [31:0] dequant_numerator;
reg signed [31:0] dequant_unclipped;
reg signed [11:0] dequant_saturated;

always @* begin
    qfs_ext    = {{19{qfs_current[12]}}, qfs_current};
    weight_ext = {24'd0, weight_current};
    qscale_ext = {24'd0, quantiser_scale_current};

    case (latched_intra_dc_precision)
        2'd0: dc_mult_ext = 32'sd8;
        2'd1: dc_mult_ext = 32'sd4;
        2'd2: dc_mult_ext = 32'sd2;
        default: dc_mult_ext = 32'sd1;
    endcase

    product_qw       = 32'sd0;
    product_qws      = 32'sd0;
    dequant_numerator= 32'sd0;
    dequant_unclipped= 32'sd0;

    if (physical_index == 6'd0) begin
        // H.262 7.4.1: intra DC is independent of weighting matrix and qscale.
        dequant_unclipped = qfs_ext * dc_mult_ext;
    end
    else begin
        // H.262 7.4.2.3 for an intra block:
        // F'' = (QF * W * quantiser_scale * 2) / 32.
        // H.262 4.1 defines '/' as integer division truncated toward zero;
        // SystemVerilog signed division has the same truncation direction.
        product_qw        = qfs_ext * weight_ext;
        product_qws       = product_qw * qscale_ext;
        dequant_numerator = product_qws * 32'sd2;
        dequant_unclipped = dequant_numerator / 32'sd32;
    end

    // H.262 7.4.3 saturation range.
    if (dequant_unclipped > 32'sd2047)
        dequant_saturated = 12'sd2047;
    else if (dequant_unclipped < -32'sd2048)
        dequant_saturated = 12'sh800;
    else
        dequant_saturated = dequant_unclipped[11:0];
end

wire total_parity_with_current = parity_lsb ^ dequant_saturated[0];
wire signed [11:0] mismatch_corrected_last =
    total_parity_with_current ?
        dequant_saturated :
        {dequant_saturated[11:1], ~dequant_saturated[0]};

always @(posedge clk) begin
    if (reset) begin
        busy                         <= 1'b0;
        physical_index               <= 6'd0;
        parity_lsb                   <= 1'b0;
        latched_intra_dc_precision   <= 2'd0;
        latched_quantiser_scale_code <= 5'd0;
        latched_q_scale_type         <= 1'b0;
        latched_alternate_scan       <= 1'b0;
        block_complete               <= 1'b0;
        iq_error                     <= 1'b0;
        unsupported_matrix           <= 1'b0;
        first_luma_f00               <= 12'sd0;
        first_luma_f77               <= 12'sd0;
        emit_active                    <= 1'b0;
        emit_index                     <= 6'd0;
        coeff_out_block_start          <= 1'b0;
        coeff_out_valid                <= 1'b0;
        coeff_out_index                <= 6'd0;
        coeff_out_value                <= 12'sd0;
        coeff_out_block_end            <= 1'b0;
        for (i = 0; i < 64; i = i + 1) begin
            qfs[i]          <= 13'sd0;
            reconstructed[i] <= 12'sd0;
        end
    end
    else begin
        // kate - coefficient handoff controls are one-cycle pulses.
        coeff_out_block_start <= 1'b0;
        coeff_out_valid       <= 1'b0;
        coeff_out_block_end   <= 1'b0;

        if (block_start) begin
            if (busy || emit_active) begin
                iq_error <= 1'b1;
            end
            else begin
                block_complete     <= 1'b0;
                unsupported_matrix <= 1'b0;
                first_luma_f00     <= 12'sd0;
                first_luma_f77     <= 12'sd0;
                for (i = 0; i < 64; i = i + 1) begin
                    qfs[i]           <= 13'sd0;
                    reconstructed[i] <= 12'sd0;
                end
            end
        end

        if (coeff_write_en) begin
            if (busy || emit_active)
                iq_error <= 1'b1;
            else
                qfs[coeff_write_index] <= coeff_write_value;
        end

        if (block_end) begin
            if (busy || emit_active || (quantiser_scale_code == 5'd0)) begin
                iq_error <= 1'b1;
            end
            else if (!intra_quant_matrix_default) begin
                // Valid H.262, but outside the current implementation subset.
                unsupported_matrix <= 1'b1;
            end
            else begin
                latched_intra_dc_precision   <= intra_dc_precision;
                latched_quantiser_scale_code <= quantiser_scale_code;
                latched_q_scale_type         <= q_scale_type;
                latched_alternate_scan       <= alternate_scan;
                physical_index               <= 6'd0;
                parity_lsb                   <= 1'b0;
                busy                         <= 1'b1;
            end
        end

        if (busy) begin
            if (physical_index == 6'd63) begin
                // H.262 7.4.4: if the sum of saturated coefficients is even,
                // toggle the LSB of F[7][7].  The standard notes that parity
                // alone is sufficient to determine this condition.
                reconstructed[63] <= mismatch_corrected_last;
                first_luma_f77     <= mismatch_corrected_last;
                busy               <= 1'b0;
                block_complete     <= 1'b1;
                emit_active        <= 1'b1;
                emit_index         <= 6'd0;
            end
            else begin
                reconstructed[physical_index] <= dequant_saturated;
                parity_lsb <= parity_lsb ^ dequant_saturated[0];
                if (physical_index == 6'd0)
                    first_luma_f00 <= dequant_saturated;
                physical_index <= physical_index + 1'b1;
            end
        end

        // kate - Emit the completed 8x8 transform-domain block only after
        // mismatch control has finalized F[7][7].  The explicit stream keeps
        // the IDCT independent of the inverse-quantiser's internal storage.
        if (emit_active) begin
            coeff_out_valid <= 1'b1;
            coeff_out_index <= emit_index;
            coeff_out_value <= reconstructed[emit_index];

            if (emit_index == 6'd0)
                coeff_out_block_start <= 1'b1;

            if (emit_index == 6'd63) begin
                coeff_out_block_end <= 1'b1;
                emit_active         <= 1'b0;
            end
            else begin
                emit_index <= emit_index + 1'b1;
            end
        end
    end
end

endmodule
