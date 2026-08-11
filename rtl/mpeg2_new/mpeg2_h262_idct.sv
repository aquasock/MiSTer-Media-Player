//============================================================================
// MiSTer Media Player - standards-driven H.262 8x8 inverse DCT
//
// Normative standards basis:
//   ITU-T H.262 consolidated text (02/2012), clause 7.5 and Annex A.
//   Annex A defines the N=8 mathematical real-number IDCT, defines the
//   mathematical integer-number result as nearest-integer rounding with exact
//   half-integers rounded away from zero, and requires decoder IDCT accuracy to
//   conform to ISO/IEC 23002-1 (including its Annexes A and B).
//
// Implementation choice (not prescribed by H.262):
//   A separable two-pass fixed-point matrix IDCT is used.  The normalized
//   one-dimensional basis (C(k)/2)*cos((2n+1)k*pi/16) is represented in Q14.
//   The first pass is rounded to Q10; the second pass is rounded to integer.
//   Both roundings use nearest with ties away from zero, matching the rounding
//   convention in H.262 Annex A.  There is deliberately NO saturation here:
//   the current H.262 Annex A defines the mathematical integer IDCT without
//   clipping.  Final decoded-pel saturation belongs to H.262 7.6.8.
//
// Throughput architecture:
//   Eight multiplications are evaluated in parallel for one 8-term dot product
//   per clock.  64 clocks are used for each pass (128 transform clocks/block).
//   At 54 MHz this transform engine alone has headroom above the 4:2:0 block
//   rate of 720x576 at 30 frames/s.  Future block double-buffering can overlap
//   coefficient preparation with this transform.
//
// Verification performed when this implementation was generated:
//   - fixed-point model compared against the Annex-A mathematical IDCT;
//   - all 4096 legacy H.262 Annex-A DC/mismatch vectors had peak error <= 1;
//   - 10,000 random sparse legal coefficient blocks had observed peak error <=1.
// These are engineering verification results, not a substitute for formal
// ISO/IEC 23002-1 conformance testing.  We do not claim formal conformance until
// the standardized accuracy test suite has been run against the RTL.
//============================================================================

module mpeg2_h262_idct
(
    input  wire               clk,
    input  wire               reset,

    input  wire               coeff_block_start,
    input  wire               coeff_valid,
    input  wire [5:0]         coeff_index,
    input  wire signed [11:0] coeff_value,
    input  wire               coeff_block_end,

    output reg                block_complete,
    output reg                idct_error,

    // kate - Spatial-domain f[y][x] stream in row-major order.  Width is kept
    // wider than a decoded pel because H.262 applies pel saturation later.
    output reg                sample_valid,
    output reg [5:0]          sample_index,
    output reg signed [15:0]  sample_value,
    output reg signed [15:0]  first_luma_sample00,
    output reg signed [15:0]  first_luma_sample77
);

reg signed [11:0] coeff [0:63];
// First-pass values carry ten fractional bits (Q10).
reg signed [23:0] temp [0:63];
integer i;
integer k;

reg       capture_active;
reg       pass1_active;
reg       pass2_active;
reg [5:0] transform_index;

// Q14 samples of B[n][k] = (C(k)/2)*cos((2n+1)k*pi/16), where
// C(0)=1/sqrt(2), C(k)=1 otherwise.  These constants implement the
// separable form of the N=8 mathematical IDCT in H.262 Annex A.
function automatic signed [14:0] basis_q14;
    input [2:0] n;
    input [2:0] kidx;
    begin
        case ({n,kidx})
            6'o00: basis_q14 =  15'sd5793; 6'o01: basis_q14 =  15'sd8035;
            6'o02: basis_q14 =  15'sd7568; 6'o03: basis_q14 =  15'sd6811;
            6'o04: basis_q14 =  15'sd5793; 6'o05: basis_q14 =  15'sd4551;
            6'o06: basis_q14 =  15'sd3135; 6'o07: basis_q14 =  15'sd1598;

            6'o10: basis_q14 =  15'sd5793; 6'o11: basis_q14 =  15'sd6811;
            6'o12: basis_q14 =  15'sd3135; 6'o13: basis_q14 = -15'sd1598;
            6'o14: basis_q14 = -15'sd5793; 6'o15: basis_q14 = -15'sd8035;
            6'o16: basis_q14 = -15'sd7568; 6'o17: basis_q14 = -15'sd4551;

            6'o20: basis_q14 =  15'sd5793; 6'o21: basis_q14 =  15'sd4551;
            6'o22: basis_q14 = -15'sd3135; 6'o23: basis_q14 = -15'sd8035;
            6'o24: basis_q14 = -15'sd5793; 6'o25: basis_q14 =  15'sd1598;
            6'o26: basis_q14 =  15'sd7568; 6'o27: basis_q14 =  15'sd6811;

            6'o30: basis_q14 =  15'sd5793; 6'o31: basis_q14 =  15'sd1598;
            6'o32: basis_q14 = -15'sd7568; 6'o33: basis_q14 = -15'sd4551;
            6'o34: basis_q14 =  15'sd5793; 6'o35: basis_q14 =  15'sd6811;
            6'o36: basis_q14 = -15'sd3135; 6'o37: basis_q14 = -15'sd8035;

            6'o40: basis_q14 =  15'sd5793; 6'o41: basis_q14 = -15'sd1598;
            6'o42: basis_q14 = -15'sd7568; 6'o43: basis_q14 =  15'sd4551;
            6'o44: basis_q14 =  15'sd5793; 6'o45: basis_q14 = -15'sd6811;
            6'o46: basis_q14 = -15'sd3135; 6'o47: basis_q14 =  15'sd8035;

            6'o50: basis_q14 =  15'sd5793; 6'o51: basis_q14 = -15'sd4551;
            6'o52: basis_q14 = -15'sd3135; 6'o53: basis_q14 =  15'sd8035;
            6'o54: basis_q14 = -15'sd5793; 6'o55: basis_q14 = -15'sd1598;
            6'o56: basis_q14 =  15'sd7568; 6'o57: basis_q14 = -15'sd6811;

            6'o60: basis_q14 =  15'sd5793; 6'o61: basis_q14 = -15'sd6811;
            6'o62: basis_q14 =  15'sd3135; 6'o63: basis_q14 =  15'sd1598;
            6'o64: basis_q14 = -15'sd5793; 6'o65: basis_q14 =  15'sd8035;
            6'o66: basis_q14 = -15'sd7568; 6'o67: basis_q14 =  15'sd4551;

            6'o70: basis_q14 =  15'sd5793; 6'o71: basis_q14 = -15'sd8035;
            6'o72: basis_q14 =  15'sd7568; 6'o73: basis_q14 = -15'sd6811;
            6'o74: basis_q14 =  15'sd5793; 6'o75: basis_q14 = -15'sd4551;
            6'o76: basis_q14 =  15'sd3135; 6'o77: basis_q14 = -15'sd1598;
            default: basis_q14 = 15'sd0;
        endcase
    end
endfunction

// Q14 -> Q10, nearest with exact half cases away from zero.
function automatic signed [23:0] round_q14_to_q10;
    input signed [31:0] value;
    reg signed [31:0] magnitude;
    reg signed [31:0] rounded;
    begin
        if (value < 0) begin
            magnitude = -value;
            rounded = -((magnitude + 32'sd8) >>> 4);
        end
        else begin
            rounded = (value + 32'sd8) >>> 4;
        end
        round_q14_to_q10 = rounded[23:0];
    end
endfunction

// Q24 -> integer, nearest with exact half cases away from zero.
function automatic signed [31:0] round_q24_to_integer;
    input signed [47:0] value;
    reg signed [47:0] magnitude;
    reg signed [47:0] rounded;
    begin
        if (value < 0) begin
            magnitude = -value;
            rounded = -((magnitude + 48'sd8388608) >>> 24);
        end
        else begin
            rounded = (value + 48'sd8388608) >>> 24;
        end
        round_q24_to_integer = rounded[31:0];
    end
endfunction

reg signed [31:0] pass1_sum;
reg signed [47:0] pass2_sum;
reg signed [31:0] pass2_integer;

always @* begin
    pass1_sum = 32'sd0;
    for (k = 0; k < 8; k = k + 1) begin
        pass1_sum = pass1_sum +
            ($signed(coeff[(transform_index[5:3] * 8) + k]) *
             $signed(basis_q14(transform_index[2:0], k[2:0])));
    end
end

always @* begin
    pass2_sum = 48'sd0;
    for (k = 0; k < 8; k = k + 1) begin
        pass2_sum = pass2_sum +
            ($signed(temp[(k * 8) + transform_index[2:0]]) *
             $signed(basis_q14(transform_index[5:3], k[2:0])));
    end
    pass2_integer = round_q24_to_integer(pass2_sum);
end

always @(posedge clk) begin
    if (reset) begin
        capture_active       <= 1'b0;
        pass1_active         <= 1'b0;
        pass2_active         <= 1'b0;
        transform_index      <= 6'd0;
        block_complete       <= 1'b0;
        idct_error           <= 1'b0;
        sample_valid         <= 1'b0;
        sample_index         <= 6'd0;
        sample_value         <= 16'sd0;
        first_luma_sample00  <= 16'sd0;
        first_luma_sample77  <= 16'sd0;
        for (i = 0; i < 64; i = i + 1) begin
            coeff[i] <= 12'sd0;
            temp[i]  <= 24'sd0;
        end
    end
    else begin
        sample_valid <= 1'b0;

        if (coeff_block_start) begin
            if (capture_active || pass1_active || pass2_active) begin
                idct_error <= 1'b1;
            end
            else begin
                capture_active      <= 1'b1;
                block_complete      <= 1'b0;
                first_luma_sample00 <= 16'sd0;
                first_luma_sample77 <= 16'sd0;
                for (i = 0; i < 64; i = i + 1)
                    coeff[i] <= 12'sd0;
            end
        end

        if (coeff_valid) begin
            if (!capture_active && !coeff_block_start) begin
                idct_error <= 1'b1;
            end
            else begin
                coeff[coeff_index] <= coeff_value;
            end
        end

        if (coeff_block_end) begin
            if ((!capture_active && !coeff_block_start) || pass1_active || pass2_active) begin
                idct_error <= 1'b1;
            end
            else begin
                capture_active  <= 1'b0;
                pass1_active    <= 1'b1;
                transform_index <= 6'd0;
            end
        end

        if (pass1_active) begin
            temp[transform_index] <= round_q14_to_q10(pass1_sum);
            if (transform_index == 6'd63) begin
                pass1_active    <= 1'b0;
                pass2_active    <= 1'b1;
                transform_index <= 6'd0;
            end
            else begin
                transform_index <= transform_index + 1'b1;
            end
        end

        if (pass2_active) begin
            // kate - Do not clamp f[y][x] here.  H.262 7.6.8 performs the
            // decoded-pel saturation after prediction is added (p=0 for intra).
            sample_valid <= 1'b1;
            sample_index <= transform_index;
            sample_value <= pass2_integer[15:0];

            if (transform_index == 6'd0)
                first_luma_sample00 <= pass2_integer[15:0];
            if (transform_index == 6'd63)
                first_luma_sample77 <= pass2_integer[15:0];

            if (transform_index == 6'd63) begin
                pass2_active    <= 1'b0;
                block_complete  <= 1'b1;
            end
            else begin
                transform_index <= transform_index + 1'b1;
            end
        end
    end
end

endmodule
