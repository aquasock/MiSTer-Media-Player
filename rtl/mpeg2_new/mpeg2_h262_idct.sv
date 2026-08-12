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
// kate - Phase 1P timing closure:
//   The original behavioral accumulator loops caused Quartus 17 to map each
//   8-term dot product as a long serial DSP/MAC chain.  TimeQuest measured the
//   worst pass-1 transform_index -> temp path at 35.453 ns.
//
//   The arithmetic is now explicitly associated as a balanced tree:
//
//       p0 + p1   p2 + p3   p4 + p5   p6 + p7
//          \       /           \       /
//           sum01               sum23
//                \             /
//                    result
//
//   Both passes still evaluate the exact same integer sum before the unchanged
//   rounding operation.  Only the hardware association is different.
//
// kate - Phase 1P same-clock closure:
//   After the inverse-quant pipeline removed the next major bottleneck,
//   explicit 54->54 MHz reports showed a remaining -1.544 ns pass-1 path from
//   transform_index to temp[].  The routed path still crossed a DSP cascade
//   before the balanced adder/rounding logic.  Both IDCT passes now register
//   the eight parallel multiplier results before the balanced adder tree.
//   This adds one pipeline clock to each pass but preserves one dot-product
//   issue per clock after pipeline fill and does not change the arithmetic.
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

reg       capture_active;
reg       pass1_active;
reg       pass2_active;
reg [5:0] transform_index;

// kate - One registered multiplier stage per separable IDCT pass.  The active
// flag issues one transform result per clock; pipe_valid marks the result whose
// eight products were captured on the previous clock.
reg       pass1_pipe_valid;
reg [5:0] pass1_pipe_index;
reg       pass2_pipe_valid;
reg [5:0] pass2_pipe_index;

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

// -------------------------------------------------------------------------
// Phase 1P balanced pass-1 dot product.
//
// 12-bit coefficient x 15-bit Q14 basis = exact signed 27-bit product.
// Sign-extend to the existing 32-bit accumulator width before adding.  The
// legal coefficient/basis range cannot overflow 32 bits, so re-association is
// bit-exact with the former serial accumulator.
// -------------------------------------------------------------------------

reg signed [26:0] pass1_product0;
reg signed [26:0] pass1_product1;
reg signed [26:0] pass1_product2;
reg signed [26:0] pass1_product3;
reg signed [26:0] pass1_product4;
reg signed [26:0] pass1_product5;
reg signed [26:0] pass1_product6;
reg signed [26:0] pass1_product7;

reg signed [26:0] pass1_product0_r;
reg signed [26:0] pass1_product1_r;
reg signed [26:0] pass1_product2_r;
reg signed [26:0] pass1_product3_r;
reg signed [26:0] pass1_product4_r;
reg signed [26:0] pass1_product5_r;
reg signed [26:0] pass1_product6_r;
reg signed [26:0] pass1_product7_r;

reg signed [31:0] pass1_pair0;
reg signed [31:0] pass1_pair1;
reg signed [31:0] pass1_pair2;
reg signed [31:0] pass1_pair3;
reg signed [31:0] pass1_quad0;
reg signed [31:0] pass1_quad1;
reg signed [31:0] pass1_sum;

wire [5:0] pass1_row_base = {transform_index[5:3], 3'b000};

always @* begin
    pass1_product0 =
        $signed(coeff[pass1_row_base + 6'd0]) *
        $signed(basis_q14(transform_index[2:0], 3'd0));
    pass1_product1 =
        $signed(coeff[pass1_row_base + 6'd1]) *
        $signed(basis_q14(transform_index[2:0], 3'd1));
    pass1_product2 =
        $signed(coeff[pass1_row_base + 6'd2]) *
        $signed(basis_q14(transform_index[2:0], 3'd2));
    pass1_product3 =
        $signed(coeff[pass1_row_base + 6'd3]) *
        $signed(basis_q14(transform_index[2:0], 3'd3));
    pass1_product4 =
        $signed(coeff[pass1_row_base + 6'd4]) *
        $signed(basis_q14(transform_index[2:0], 3'd4));
    pass1_product5 =
        $signed(coeff[pass1_row_base + 6'd5]) *
        $signed(basis_q14(transform_index[2:0], 3'd5));
    pass1_product6 =
        $signed(coeff[pass1_row_base + 6'd6]) *
        $signed(basis_q14(transform_index[2:0], 3'd6));
    pass1_product7 =
        $signed(coeff[pass1_row_base + 6'd7]) *
        $signed(basis_q14(transform_index[2:0], 3'd7));

    pass1_pair0 =
        {{5{pass1_product0_r[26]}}, pass1_product0_r} +
        {{5{pass1_product1_r[26]}}, pass1_product1_r};
    pass1_pair1 =
        {{5{pass1_product2_r[26]}}, pass1_product2_r} +
        {{5{pass1_product3_r[26]}}, pass1_product3_r};
    pass1_pair2 =
        {{5{pass1_product4_r[26]}}, pass1_product4_r} +
        {{5{pass1_product5_r[26]}}, pass1_product5_r};
    pass1_pair3 =
        {{5{pass1_product6_r[26]}}, pass1_product6_r} +
        {{5{pass1_product7_r[26]}}, pass1_product7_r};

    pass1_quad0 = pass1_pair0 + pass1_pair1;
    pass1_quad1 = pass1_pair2 + pass1_pair3;
    pass1_sum   = pass1_quad0 + pass1_quad1;
end

// -------------------------------------------------------------------------
// Phase 1P balanced pass-2 dot product.
//
// 24-bit Q10 intermediate x 15-bit Q14 basis = exact signed 39-bit product.
// Sign-extend to the existing 48-bit accumulator width and use the same
// balanced three-level addition tree.
// -------------------------------------------------------------------------

reg signed [38:0] pass2_product0;
reg signed [38:0] pass2_product1;
reg signed [38:0] pass2_product2;
reg signed [38:0] pass2_product3;
reg signed [38:0] pass2_product4;
reg signed [38:0] pass2_product5;
reg signed [38:0] pass2_product6;
reg signed [38:0] pass2_product7;

reg signed [38:0] pass2_product0_r;
reg signed [38:0] pass2_product1_r;
reg signed [38:0] pass2_product2_r;
reg signed [38:0] pass2_product3_r;
reg signed [38:0] pass2_product4_r;
reg signed [38:0] pass2_product5_r;
reg signed [38:0] pass2_product6_r;
reg signed [38:0] pass2_product7_r;

reg signed [47:0] pass2_pair0;
reg signed [47:0] pass2_pair1;
reg signed [47:0] pass2_pair2;
reg signed [47:0] pass2_pair3;
reg signed [47:0] pass2_quad0;
reg signed [47:0] pass2_quad1;
reg signed [47:0] pass2_sum;
reg signed [31:0] pass2_integer;

always @* begin
    pass2_product0 =
        $signed(temp[{3'd0, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd0));
    pass2_product1 =
        $signed(temp[{3'd1, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd1));
    pass2_product2 =
        $signed(temp[{3'd2, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd2));
    pass2_product3 =
        $signed(temp[{3'd3, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd3));
    pass2_product4 =
        $signed(temp[{3'd4, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd4));
    pass2_product5 =
        $signed(temp[{3'd5, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd5));
    pass2_product6 =
        $signed(temp[{3'd6, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd6));
    pass2_product7 =
        $signed(temp[{3'd7, transform_index[2:0]}]) *
        $signed(basis_q14(transform_index[5:3], 3'd7));

    pass2_pair0 =
        {{9{pass2_product0_r[38]}}, pass2_product0_r} +
        {{9{pass2_product1_r[38]}}, pass2_product1_r};
    pass2_pair1 =
        {{9{pass2_product2_r[38]}}, pass2_product2_r} +
        {{9{pass2_product3_r[38]}}, pass2_product3_r};
    pass2_pair2 =
        {{9{pass2_product4_r[38]}}, pass2_product4_r} +
        {{9{pass2_product5_r[38]}}, pass2_product5_r};
    pass2_pair3 =
        {{9{pass2_product6_r[38]}}, pass2_product6_r} +
        {{9{pass2_product7_r[38]}}, pass2_product7_r};

    pass2_quad0 = pass2_pair0 + pass2_pair1;
    pass2_quad1 = pass2_pair2 + pass2_pair3;
    pass2_sum   = pass2_quad0 + pass2_quad1;

    pass2_integer = round_q24_to_integer(pass2_sum);
end

always @(posedge clk) begin
    if (reset) begin
        capture_active       <= 1'b0;
        pass1_active         <= 1'b0;
        pass2_active         <= 1'b0;
        transform_index      <= 6'd0;
        pass1_pipe_valid     <= 1'b0;
        pass1_pipe_index     <= 6'd0;
        pass2_pipe_valid     <= 1'b0;
        pass2_pipe_index     <= 6'd0;
        block_complete       <= 1'b0;
        idct_error           <= 1'b0;
        sample_valid         <= 1'b0;
        sample_index         <= 6'd0;
        sample_value         <= 16'sd0;
        first_luma_sample00  <= 16'sd0;
        first_luma_sample77  <= 16'sd0;

        pass1_product0_r <= 27'sd0;
        pass1_product1_r <= 27'sd0;
        pass1_product2_r <= 27'sd0;
        pass1_product3_r <= 27'sd0;
        pass1_product4_r <= 27'sd0;
        pass1_product5_r <= 27'sd0;
        pass1_product6_r <= 27'sd0;
        pass1_product7_r <= 27'sd0;

        pass2_product0_r <= 39'sd0;
        pass2_product1_r <= 39'sd0;
        pass2_product2_r <= 39'sd0;
        pass2_product3_r <= 39'sd0;
        pass2_product4_r <= 39'sd0;
        pass2_product5_r <= 39'sd0;
        pass2_product6_r <= 39'sd0;
        pass2_product7_r <= 39'sd0;

        for (i = 0; i < 64; i = i + 1) begin
            coeff[i] <= 12'sd0;
            temp[i]  <= 24'sd0;
        end
    end
    else begin
        sample_valid <= 1'b0;

        // kate - The pipeline valid for each pass follows that pass's issue
        // enable.  On the cycle after index 63 is issued, the active flag is
        // already low but pipe_valid remains high long enough to retire index
        // 63 before the next pass/block begins.
        pass1_pipe_valid <= pass1_active;
        pass2_pipe_valid <= pass2_active;

        if (coeff_block_start) begin
            if (capture_active ||
                pass1_active || pass1_pipe_valid ||
                pass2_active || pass2_pipe_valid) begin
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
            if ((!capture_active && !coeff_block_start) ||
                pass1_active || pass1_pipe_valid ||
                pass2_active || pass2_pipe_valid) begin
                idct_error <= 1'b1;
            end
            else begin
                capture_active  <= 1'b0;
                pass1_active    <= 1'b1;
                transform_index <= 6'd0;
            end
        end

        // Pass 1 issue stage: capture all eight Q14 products for one horizontal
        // 1-D transform.  One transform_index is still issued every clock.
        if (pass1_active) begin
            pass1_pipe_index <= transform_index;
            pass1_product0_r <= pass1_product0;
            pass1_product1_r <= pass1_product1;
            pass1_product2_r <= pass1_product2;
            pass1_product3_r <= pass1_product3;
            pass1_product4_r <= pass1_product4;
            pass1_product5_r <= pass1_product5;
            pass1_product6_r <= pass1_product6;
            pass1_product7_r <= pass1_product7;

            if (transform_index == 6'd63) begin
                pass1_active <= 1'b0;
            end
            else begin
                transform_index <= transform_index + 1'b1;
            end
        end

        // Pass 1 retire stage: balanced tree and unchanged Q14->Q10 rounding
        // operate only on registered multiplier outputs.
        if (pass1_pipe_valid) begin
            temp[pass1_pipe_index] <= round_q14_to_q10(pass1_sum);

            if (pass1_pipe_index == 6'd63) begin
                pass2_active    <= 1'b1;
                transform_index <= 6'd0;
            end
        end

        // Pass 2 issue stage: capture all eight Q24 products for one vertical
        // 1-D transform.  This mirrors pass 1 so pass 2 cannot become the next
        // multiplier-to-adder critical path after pass-1 timing is fixed.
        if (pass2_active) begin
            pass2_pipe_index <= transform_index;
            pass2_product0_r <= pass2_product0;
            pass2_product1_r <= pass2_product1;
            pass2_product2_r <= pass2_product2;
            pass2_product3_r <= pass2_product3;
            pass2_product4_r <= pass2_product4;
            pass2_product5_r <= pass2_product5;
            pass2_product6_r <= pass2_product6;
            pass2_product7_r <= pass2_product7;

            if (transform_index == 6'd63) begin
                pass2_active <= 1'b0;
            end
            else begin
                transform_index <= transform_index + 1'b1;
            end
        end

        // Pass 2 retire stage.  Output order and rounding are unchanged; only
        // the multiplier results arrive from the new pipeline register.
        if (pass2_pipe_valid) begin
            // kate - Do not clamp f[y][x] here.  H.262 7.6.8 performs the
            // decoded-pel saturation after prediction is added (p=0 for intra).
            sample_valid <= 1'b1;
            sample_index <= pass2_pipe_index;
            sample_value <= pass2_integer[15:0];

            if (pass2_pipe_index == 6'd0)
                first_luma_sample00 <= pass2_integer[15:0];
            if (pass2_pipe_index == 6'd63)
                first_luma_sample77 <= pass2_integer[15:0];

            if (pass2_pipe_index == 6'd63) begin
                block_complete <= 1'b1;
            end
        end
    end
end

endmodule
