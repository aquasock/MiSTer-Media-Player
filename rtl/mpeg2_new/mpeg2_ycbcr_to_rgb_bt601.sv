//============================================================================
// MiSTer Media Player - BT.601/BT.709 YCbCr to RGB presentation converter
//
// Normative colour basis:
//   ITU-R BT.601-7 digital Y, Cb and Cr coding for standard-definition video.
//   ITU-R BT.709-6, items 3.2 through 3.4, for the selectable 709 matrix.
//
// Matrix selection changes presentation only. The legacy BT.601 coefficients
// and rounding remain exact for the accepted output. Both paths use nominal
// limited-range Y/Cb/Cr coding and clip only the final RGB result.
//============================================================================

module mpeg2_ycbcr_to_rgb
(
    input  wire       matrix_bt709,
    input  wire [7:0] y,
    input  wire [7:0] cb,
    input  wire [7:0] cr,

    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

// Limited-range BT.601 offsets.  Ten signed bits cover the full 8-bit input
// excursion around the nominal Y=16 and Cb/Cr=128 reference levels.
wire signed [9:0] y_off  = $signed({1'b0, y }) - 10'sd16;
wire signed [9:0] cb_off = $signed({1'b0, cb}) - 10'sd128;
wire signed [9:0] cr_off = $signed({1'b0, cr}) - 10'sd128;

wire signed [19:0] y20  = {{10{y_off[9]}},  y_off};
wire signed [19:0] cb20 = {{10{cb_off[9]}}, cb_off};
wire signed [19:0] cr20 = {{10{cr_off[9]}}, cr_off};

// kate - Constant shift/add form avoids spending general multipliers on the
// presentation matrix.  Coefficients are 298, 409, 100, 208 and 516 / 256.
wire signed [19:0] y_298 =
    (y20 <<< 8) + (y20 <<< 5) + (y20 <<< 3) + (y20 <<< 1);
wire signed [19:0] cr_409 =
    (cr20 <<< 8) + (cr20 <<< 7) + (cr20 <<< 4) + (cr20 <<< 3) + cr20;
wire signed [19:0] cb_100 =
    (cb20 <<< 6) + (cb20 <<< 5) + (cb20 <<< 2);
wire signed [19:0] cr_208 =
    (cr20 <<< 7) + (cr20 <<< 6) + (cr20 <<< 4);
wire signed [19:0] cb_516 =
    (cb20 <<< 9) + (cb20 <<< 2);

// 8-bit fixed-point limited-range BT.709 coefficients. The 601 path above
// remains unchanged; selection adds no general multipliers or pixel latency.
wire signed [19:0] cr_459 =
    (cr20 <<< 8)+(cr20 <<< 7)+(cr20 <<< 6)+(cr20 <<< 3)+(cr20 <<< 1)+cr20;
wire signed [19:0] cb_55 = (cb20 <<< 5)+(cb20 <<< 4)+(cb20 <<< 2)+(cb20 <<< 1)+cb20;
wire signed [19:0] cr_136 = (cr20 <<< 7)+(cr20 <<< 3);
wire signed [19:0] cb_541 = (cb20 <<< 9)+(cb20 <<< 4)+(cb20 <<< 3)+(cb20 <<< 2)+cb20;
wire signed [19:0] r_scaled = y_298 + (matrix_bt709 ? cr_459 : cr_409) + 20'sd128;
wire signed [19:0] g_scaled = y_298 - (matrix_bt709 ? cb_55 : cb_100)
                                      - (matrix_bt709 ? cr_136 : cr_208) + 20'sd128;
wire signed [19:0] b_scaled = y_298 + (matrix_bt709 ? cb_541 : cb_516) + 20'sd128;

wire signed [19:0] r_unclipped = r_scaled >>> 8;
wire signed [19:0] g_unclipped = g_scaled >>> 8;
wire signed [19:0] b_unclipped = b_scaled >>> 8;

function automatic [7:0] clip_rgb;
    input signed [19:0] value;
    begin
        if (value < 20'sd0)
            clip_rgb = 8'd0;
        else if (value > 20'sd255)
            clip_rgb = 8'd255;
        else
            clip_rgb = value[7:0];
    end
endfunction

assign r = clip_rgb(r_unclipped);
assign g = clip_rgb(g_unclipped);
assign b = clip_rgb(b_unclipped);

endmodule

// Compatibility wrapper for existing 601-only benches and callers.
module mpeg2_ycbcr_to_rgb_bt601(
 input wire [7:0] y,cb,cr,
 output wire [7:0] r,g,b
);
mpeg2_ycbcr_to_rgb converter(.matrix_bt709(1'b0),.y(y),.cb(cb),.cr(cr),.r(r),.g(g),.b(b));
endmodule
