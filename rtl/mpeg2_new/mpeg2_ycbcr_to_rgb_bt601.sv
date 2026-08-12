//============================================================================
// MiSTer Media Player - fixed BT.601 YCbCr to RGB presentation converter
//
// Normative colour basis:
//   ITU-R BT.601-7 digital Y, Cb and Cr coding for standard-definition video.
//
// Phase 1N implementation choice:
//   The current H.262 front end does not yet retain sequence_display_extension
//   matrix_coefficients, so this first colour-picture milestone deliberately
//   uses the BT.601 limited-range matrix appropriate to the present SD tests.
//   The shift/add constants below are the conventional 8-bit fixed-point
//   approximation (scale 256) of that matrix; final RGB values are clipped to
//   [0,255].  Future colour-description support can select other matrices
//   without changing the decoded component planes.
//============================================================================

module mpeg2_ycbcr_to_rgb_bt601
(
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

wire signed [19:0] r_scaled = y_298 + cr_409 + 20'sd128;
wire signed [19:0] g_scaled = y_298 - cb_100 - cr_208 + 20'sd128;
wire signed [19:0] b_scaled = y_298 + cb_516 + 20'sd128;

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
