//============================================================================
// MiSTer Media Player - standards-driven H.262 8x8 inverse DCT
//
// Commit 149 resource consolidation.
//
// Normative basis remains ITU-T H.262 / ISO/IEC 13818-2 clause 7.5 and
// Annex A.  Arithmetic, Q14 basis constants, two-pass separable ordering,
// nearest/ties-away rounding, sample order, and external handshake are
// preserved from the accepted implementation.
//
// Resource change: pass 1 and pass 2 are sequential and can never execute at
// the same time, so they now share one registered bank of eight 24x15 signed
// multipliers and one 48-bit balanced adder tree instead of synthesizing two
// parallel multiplier/adder banks.  No transform precision is reduced.
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

    output reg                sample_valid,
    output reg [5:0]          sample_index,
    output reg signed [15:0]  sample_value,
    output reg signed [15:0]  first_luma_sample00,
    output reg signed [15:0]  first_luma_sample77
);

reg signed [11:0] coeff [0:63];
reg signed [23:0] temp [0:63];
integer i;

reg       capture_active;
reg       pass1_active;
reg       pass2_active;
reg [5:0] transform_index;

// One multiplier pipeline is shared by both transform passes.
reg       pipe_valid;
reg       pipe_pass2;
reg [5:0] pipe_index;

function automatic signed [14:0] basis_q14;
    input [2:0] n;
    input [2:0] kidx;
    begin
        case ({n,kidx})
            6'o00: basis_q14 =  15'sd5793;
            6'o01: basis_q14 =  15'sd8035;
            6'o02: basis_q14 =  15'sd7568;
            6'o03: basis_q14 =  15'sd6811;
            6'o04: basis_q14 =  15'sd5793;
            6'o05: basis_q14 =  15'sd4551;
            6'o06: basis_q14 =  15'sd3135;
            6'o07: basis_q14 =  15'sd1598;
            6'o10: basis_q14 =  15'sd5793;
            6'o11: basis_q14 =  15'sd6811;
            6'o12: basis_q14 =  15'sd3135;
            6'o13: basis_q14 = -15'sd1598;
            6'o14: basis_q14 = -15'sd5793;
            6'o15: basis_q14 = -15'sd8035;
            6'o16: basis_q14 = -15'sd7568;
            6'o17: basis_q14 = -15'sd4551;
            6'o20: basis_q14 =  15'sd5793;
            6'o21: basis_q14 =  15'sd4551;
            6'o22: basis_q14 = -15'sd3135;
            6'o23: basis_q14 = -15'sd8035;
            6'o24: basis_q14 = -15'sd5793;
            6'o25: basis_q14 =  15'sd1598;
            6'o26: basis_q14 =  15'sd7568;
            6'o27: basis_q14 =  15'sd6811;
            6'o30: basis_q14 =  15'sd5793;
            6'o31: basis_q14 =  15'sd1598;
            6'o32: basis_q14 = -15'sd7568;
            6'o33: basis_q14 = -15'sd4551;
            6'o34: basis_q14 =  15'sd5793;
            6'o35: basis_q14 =  15'sd6811;
            6'o36: basis_q14 = -15'sd3135;
            6'o37: basis_q14 = -15'sd8035;
            6'o40: basis_q14 =  15'sd5793;
            6'o41: basis_q14 = -15'sd1598;
            6'o42: basis_q14 = -15'sd7568;
            6'o43: basis_q14 =  15'sd4551;
            6'o44: basis_q14 =  15'sd5793;
            6'o45: basis_q14 = -15'sd6811;
            6'o46: basis_q14 = -15'sd3135;
            6'o47: basis_q14 =  15'sd8035;
            6'o50: basis_q14 =  15'sd5793;
            6'o51: basis_q14 = -15'sd4551;
            6'o52: basis_q14 = -15'sd3135;
            6'o53: basis_q14 =  15'sd8035;
            6'o54: basis_q14 = -15'sd5793;
            6'o55: basis_q14 = -15'sd1598;
            6'o56: basis_q14 =  15'sd7568;
            6'o57: basis_q14 = -15'sd6811;
            6'o60: basis_q14 =  15'sd5793;
            6'o61: basis_q14 = -15'sd6811;
            6'o62: basis_q14 =  15'sd3135;
            6'o63: basis_q14 =  15'sd1598;
            6'o64: basis_q14 = -15'sd5793;
            6'o65: basis_q14 =  15'sd8035;
            6'o66: basis_q14 = -15'sd7568;
            6'o67: basis_q14 =  15'sd4551;
            6'o70: basis_q14 =  15'sd5793;
            6'o71: basis_q14 = -15'sd8035;
            6'o72: basis_q14 =  15'sd7568;
            6'o73: basis_q14 = -15'sd6811;
            6'o74: basis_q14 =  15'sd5793;
            6'o75: basis_q14 = -15'sd4551;
            6'o76: basis_q14 =  15'sd3135;
            6'o77: basis_q14 = -15'sd1598;
            default: basis_q14 = 15'sd0;
        endcase
    end
endfunction

// Q14 -> Q10, nearest with exact half cases away from zero.
function automatic signed [23:0] round_q14_to_q10;
    input signed [47:0] value;
    reg signed [47:0] magnitude;
    reg signed [47:0] rounded;
    begin
        if (value < 0) begin
            magnitude = -value;
            rounded = -((magnitude + 48'sd8) >>> 4);
        end
        else begin
            rounded = (value + 48'sd8) >>> 4;
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

wire issue_active = pass1_active || pass2_active;
wire issue_pass2 = pass2_active;
wire [5:0] pass1_row_base = {transform_index[5:3], 3'b000};

reg signed [23:0] operand0;
reg signed [23:0] operand1;
reg signed [23:0] operand2;
reg signed [23:0] operand3;
reg signed [23:0] operand4;
reg signed [23:0] operand5;
reg signed [23:0] operand6;
reg signed [23:0] operand7;

reg signed [14:0] basis0;
reg signed [14:0] basis1;
reg signed [14:0] basis2;
reg signed [14:0] basis3;
reg signed [14:0] basis4;
reg signed [14:0] basis5;
reg signed [14:0] basis6;
reg signed [14:0] basis7;

always @* begin
    if (issue_pass2) begin
        operand0 = temp[{3'd0, transform_index[2:0]}];
        operand1 = temp[{3'd1, transform_index[2:0]}];
        operand2 = temp[{3'd2, transform_index[2:0]}];
        operand3 = temp[{3'd3, transform_index[2:0]}];
        operand4 = temp[{3'd4, transform_index[2:0]}];
        operand5 = temp[{3'd5, transform_index[2:0]}];
        operand6 = temp[{3'd6, transform_index[2:0]}];
        operand7 = temp[{3'd7, transform_index[2:0]}];

        basis0 = basis_q14(transform_index[5:3], 3'd0);
        basis1 = basis_q14(transform_index[5:3], 3'd1);
        basis2 = basis_q14(transform_index[5:3], 3'd2);
        basis3 = basis_q14(transform_index[5:3], 3'd3);
        basis4 = basis_q14(transform_index[5:3], 3'd4);
        basis5 = basis_q14(transform_index[5:3], 3'd5);
        basis6 = basis_q14(transform_index[5:3], 3'd6);
        basis7 = basis_q14(transform_index[5:3], 3'd7);
    end
    else begin
        operand0 = {{12{coeff[pass1_row_base + 6'd0][11]}}, coeff[pass1_row_base + 6'd0]};
        operand1 = {{12{coeff[pass1_row_base + 6'd1][11]}}, coeff[pass1_row_base + 6'd1]};
        operand2 = {{12{coeff[pass1_row_base + 6'd2][11]}}, coeff[pass1_row_base + 6'd2]};
        operand3 = {{12{coeff[pass1_row_base + 6'd3][11]}}, coeff[pass1_row_base + 6'd3]};
        operand4 = {{12{coeff[pass1_row_base + 6'd4][11]}}, coeff[pass1_row_base + 6'd4]};
        operand5 = {{12{coeff[pass1_row_base + 6'd5][11]}}, coeff[pass1_row_base + 6'd5]};
        operand6 = {{12{coeff[pass1_row_base + 6'd6][11]}}, coeff[pass1_row_base + 6'd6]};
        operand7 = {{12{coeff[pass1_row_base + 6'd7][11]}}, coeff[pass1_row_base + 6'd7]};

        basis0 = basis_q14(transform_index[2:0], 3'd0);
        basis1 = basis_q14(transform_index[2:0], 3'd1);
        basis2 = basis_q14(transform_index[2:0], 3'd2);
        basis3 = basis_q14(transform_index[2:0], 3'd3);
        basis4 = basis_q14(transform_index[2:0], 3'd4);
        basis5 = basis_q14(transform_index[2:0], 3'd5);
        basis6 = basis_q14(transform_index[2:0], 3'd6);
        basis7 = basis_q14(transform_index[2:0], 3'd7);
    end
end

wire signed [38:0] product0 = $signed(operand0) * $signed(basis0);
wire signed [38:0] product1 = $signed(operand1) * $signed(basis1);
wire signed [38:0] product2 = $signed(operand2) * $signed(basis2);
wire signed [38:0] product3 = $signed(operand3) * $signed(basis3);
wire signed [38:0] product4 = $signed(operand4) * $signed(basis4);
wire signed [38:0] product5 = $signed(operand5) * $signed(basis5);
wire signed [38:0] product6 = $signed(operand6) * $signed(basis6);
wire signed [38:0] product7 = $signed(operand7) * $signed(basis7);

reg signed [38:0] product0_r;
reg signed [38:0] product1_r;
reg signed [38:0] product2_r;
reg signed [38:0] product3_r;
reg signed [38:0] product4_r;
reg signed [38:0] product5_r;
reg signed [38:0] product6_r;
reg signed [38:0] product7_r;

reg signed [47:0] pair0;
reg signed [47:0] pair1;
reg signed [47:0] pair2;
reg signed [47:0] pair3;
reg signed [47:0] quad0;
reg signed [47:0] quad1;
reg signed [47:0] shared_sum;
reg signed [31:0] pass2_integer;

always @* begin
    pair0 = {{9{product0_r[38]}}, product0_r} +
            {{9{product1_r[38]}}, product1_r};
    pair1 = {{9{product2_r[38]}}, product2_r} +
            {{9{product3_r[38]}}, product3_r};
    pair2 = {{9{product4_r[38]}}, product4_r} +
            {{9{product5_r[38]}}, product5_r};
    pair3 = {{9{product6_r[38]}}, product6_r} +
            {{9{product7_r[38]}}, product7_r};
    quad0 = pair0 + pair1;
    quad1 = pair2 + pair3;
    shared_sum = quad0 + quad1;
    pass2_integer = round_q24_to_integer(shared_sum);
end

always @(posedge clk) begin
    if (reset) begin
        capture_active      <= 1'b0;
        pass1_active        <= 1'b0;
        pass2_active        <= 1'b0;
        transform_index     <= 6'd0;
        pipe_valid          <= 1'b0;
        pipe_pass2          <= 1'b0;
        pipe_index          <= 6'd0;
        block_complete      <= 1'b0;
        idct_error          <= 1'b0;
        sample_valid        <= 1'b0;
        sample_index        <= 6'd0;
        sample_value        <= 16'sd0;
        first_luma_sample00 <= 16'sd0;
        first_luma_sample77 <= 16'sd0;

        product0_r <= 39'sd0;
        product1_r <= 39'sd0;
        product2_r <= 39'sd0;
        product3_r <= 39'sd0;
        product4_r <= 39'sd0;
        product5_r <= 39'sd0;
        product6_r <= 39'sd0;
        product7_r <= 39'sd0;

        for (i = 0; i < 64; i = i + 1) begin
            coeff[i] <= 12'sd0;
            temp[i]  <= 24'sd0;
        end
    end
    else begin
        sample_valid <= 1'b0;

        // Retire the product bank issued on the preceding cycle.
        if (pipe_valid) begin
            if (pipe_pass2) begin
                sample_valid <= 1'b1;
                sample_index <= pipe_index;
                sample_value <= pass2_integer[15:0];

                if (pipe_index == 6'd0)
                    first_luma_sample00 <= pass2_integer[15:0];
                if (pipe_index == 6'd63)
                    first_luma_sample77 <= pass2_integer[15:0];

                if (pipe_index == 6'd63)
                    block_complete <= 1'b1;
            end
            else begin
                temp[pipe_index] <= round_q14_to_q10(shared_sum);
                if (pipe_index == 6'd63) begin
                    pass2_active    <= 1'b1;
                    transform_index <= 6'd0;
                end
            end
        end

        // The shared product pipeline follows whichever pass is active.
        pipe_valid <= issue_active;
        if (issue_active) begin
            pipe_pass2 <= issue_pass2;
            pipe_index <= transform_index;
            product0_r <= product0;
            product1_r <= product1;
            product2_r <= product2;
            product3_r <= product3;
            product4_r <= product4;
            product5_r <= product5;
            product6_r <= product6;
            product7_r <= product7;

            if (transform_index == 6'd63) begin
                if (issue_pass2)
                    pass2_active <= 1'b0;
                else
                    pass1_active <= 1'b0;
            end
            else begin
                transform_index <= transform_index + 1'b1;
            end
        end

        if (coeff_block_start) begin
            if (capture_active || pass1_active || pass2_active || pipe_valid) begin
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
            if (!capture_active && !coeff_block_start)
                idct_error <= 1'b1;
            else
                coeff[coeff_index] <= coeff_value;
        end

        if (coeff_block_end) begin
            if ((!capture_active && !coeff_block_start) ||
                pass1_active || pass2_active || pipe_valid) begin
                idct_error <= 1'b1;
            end
            else begin
                capture_active  <= 1'b0;
                pass1_active    <= 1'b1;
                transform_index <= 6'd0;
            end
        end
    end
end

endmodule
