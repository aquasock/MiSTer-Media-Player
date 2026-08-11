//============================================================================
// MiSTer Media Player - H.262 DCT coefficient VLC decoder
//
// Standards source:
//   ITU-T H.262 (02/2000) / ISO/IEC 13818-2:2000
//   - 7.2.2 Other coefficients
//   - Table 7-3 DCT coefficient VLC table selection
//   - Annex B Table B.14 DCT coefficients Table zero
//   - Annex B Table B.15 DCT coefficients Table one
//
// The input code is accumulated MSB-first and right-aligned.  This decoder
// recognizes only the VLC portion.  For normal coefficients the following
// bit is the sign bit.  For Escape, H.262 7.2.2.3 requires a six-bit run and
// twelve-bit signed_level to follow.
//
// Table B.14's special "1 s" first-coefficient form is intentionally omitted:
// Phase 1C uses this module for an intra block after its separately coded DC
// coefficient, so H.262 7.2.2.2/7.2.2.1 require the unmodified subsequent-
// coefficient form of Table B.14 ("11 s" for run=0, level=1).
//============================================================================

module mpeg2_h262_dct_vlc
(
    input  wire        table_one,
    input  wire [15:0] vlc_code,
    input  wire [4:0]  vlc_len,

    output reg         match,
    output reg         end_of_block,
    output reg         escape,
    output reg  [5:0]  run,
    output reg  [5:0]  level
);

always @* begin
    match        = 1'b0;
    end_of_block = 1'b0;
    escape       = 1'b0;
    run          = 6'd0;
    level        = 6'd0;

    if (table_one) begin
        case (vlc_len)
            5'd2: begin
                case (vlc_code[1:0])
                    2'b10: begin match = 1'b1; run = 6'd0; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd3: begin
                case (vlc_code[2:0])
                    3'b010: begin match = 1'b1; run = 6'd1; level = 6'd1; end
                    3'b110: begin match = 1'b1; run = 6'd0; level = 6'd2; end
                    default: begin end
                endcase
            end
            5'd4: begin
                case (vlc_code[3:0])
                    4'b0110: begin match = 1'b1; end_of_block = 1'b1; end
                    4'b0111: begin match = 1'b1; run = 6'd0; level = 6'd3; end
                    default: begin end
                endcase
            end
            5'd5: begin
                case (vlc_code[4:0])
                    5'b00101: begin match = 1'b1; run = 6'd2; level = 6'd1; end
                    5'b00111: begin match = 1'b1; run = 6'd3; level = 6'd1; end
                    5'b00110: begin match = 1'b1; run = 6'd1; level = 6'd2; end
                    5'b11100: begin match = 1'b1; run = 6'd0; level = 6'd4; end
                    5'b11101: begin match = 1'b1; run = 6'd0; level = 6'd5; end
                    default: begin end
                endcase
            end
            5'd6: begin
                case (vlc_code[5:0])
                    6'b000110: begin match = 1'b1; run = 6'd4; level = 6'd1; end
                    6'b000111: begin match = 1'b1; run = 6'd5; level = 6'd1; end
                    6'b000001: begin match = 1'b1; escape = 1'b1; end
                    6'b000101: begin match = 1'b1; run = 6'd0; level = 6'd6; end
                    6'b000100: begin match = 1'b1; run = 6'd0; level = 6'd7; end
                    default: begin end
                endcase
            end
            5'd7: begin
                case (vlc_code[6:0])
                    7'b0000110: begin match = 1'b1; run = 6'd6; level = 6'd1; end
                    7'b0000100: begin match = 1'b1; run = 6'd7; level = 6'd1; end
                    7'b0000111: begin match = 1'b1; run = 6'd2; level = 6'd2; end
                    7'b0000101: begin match = 1'b1; run = 6'd8; level = 6'd1; end
                    7'b1111000: begin match = 1'b1; run = 6'd9; level = 6'd1; end
                    7'b1111001: begin match = 1'b1; run = 6'd1; level = 6'd3; end
                    7'b1111010: begin match = 1'b1; run = 6'd10; level = 6'd1; end
                    7'b1111011: begin match = 1'b1; run = 6'd0; level = 6'd8; end
                    7'b1111100: begin match = 1'b1; run = 6'd0; level = 6'd9; end
                    default: begin end
                endcase
            end
            5'd8: begin
                case (vlc_code[7:0])
                    8'b00100110: begin match = 1'b1; run = 6'd3; level = 6'd2; end
                    8'b00100001: begin match = 1'b1; run = 6'd11; level = 6'd1; end
                    8'b00100101: begin match = 1'b1; run = 6'd12; level = 6'd1; end
                    8'b00100100: begin match = 1'b1; run = 6'd13; level = 6'd1; end
                    8'b00100111: begin match = 1'b1; run = 6'd1; level = 6'd4; end
                    8'b11111100: begin match = 1'b1; run = 6'd2; level = 6'd3; end
                    8'b11111101: begin match = 1'b1; run = 6'd4; level = 6'd2; end
                    8'b00100011: begin match = 1'b1; run = 6'd0; level = 6'd10; end
                    8'b00100010: begin match = 1'b1; run = 6'd0; level = 6'd11; end
                    8'b00100000: begin match = 1'b1; run = 6'd1; level = 6'd5; end
                    8'b11111010: begin match = 1'b1; run = 6'd0; level = 6'd12; end
                    8'b11111011: begin match = 1'b1; run = 6'd0; level = 6'd13; end
                    8'b11111110: begin match = 1'b1; run = 6'd0; level = 6'd14; end
                    8'b11111111: begin match = 1'b1; run = 6'd0; level = 6'd15; end
                    default: begin end
                endcase
            end
            5'd9: begin
                case (vlc_code[8:0])
                    9'b000000100: begin match = 1'b1; run = 6'd5; level = 6'd2; end
                    9'b000000101: begin match = 1'b1; run = 6'd14; level = 6'd1; end
                    9'b000000111: begin match = 1'b1; run = 6'd15; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd10: begin
                case (vlc_code[9:0])
                    10'b0000001101: begin match = 1'b1; run = 6'd16; level = 6'd1; end
                    10'b0000001100: begin match = 1'b1; run = 6'd2; level = 6'd4; end
                    default: begin end
                endcase
            end
            5'd12: begin
                case (vlc_code[11:0])
                    12'b000000011100: begin match = 1'b1; run = 6'd3; level = 6'd3; end
                    12'b000000010010: begin match = 1'b1; run = 6'd4; level = 6'd3; end
                    12'b000000011110: begin match = 1'b1; run = 6'd6; level = 6'd2; end
                    12'b000000010101: begin match = 1'b1; run = 6'd7; level = 6'd2; end
                    12'b000000010001: begin match = 1'b1; run = 6'd8; level = 6'd2; end
                    12'b000000011111: begin match = 1'b1; run = 6'd17; level = 6'd1; end
                    12'b000000011010: begin match = 1'b1; run = 6'd18; level = 6'd1; end
                    12'b000000011001: begin match = 1'b1; run = 6'd19; level = 6'd1; end
                    12'b000000010111: begin match = 1'b1; run = 6'd20; level = 6'd1; end
                    12'b000000010110: begin match = 1'b1; run = 6'd21; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd13: begin
                case (vlc_code[12:0])
                    13'b0000000010110: begin match = 1'b1; run = 6'd1; level = 6'd6; end
                    13'b0000000010101: begin match = 1'b1; run = 6'd1; level = 6'd7; end
                    13'b0000000010100: begin match = 1'b1; run = 6'd2; level = 6'd5; end
                    13'b0000000010011: begin match = 1'b1; run = 6'd3; level = 6'd4; end
                    13'b0000000010010: begin match = 1'b1; run = 6'd5; level = 6'd3; end
                    13'b0000000010001: begin match = 1'b1; run = 6'd9; level = 6'd2; end
                    13'b0000000010000: begin match = 1'b1; run = 6'd10; level = 6'd2; end
                    13'b0000000011111: begin match = 1'b1; run = 6'd22; level = 6'd1; end
                    13'b0000000011110: begin match = 1'b1; run = 6'd23; level = 6'd1; end
                    13'b0000000011101: begin match = 1'b1; run = 6'd24; level = 6'd1; end
                    13'b0000000011100: begin match = 1'b1; run = 6'd25; level = 6'd1; end
                    13'b0000000011011: begin match = 1'b1; run = 6'd26; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd14: begin
                case (vlc_code[13:0])
                    14'b00000000011111: begin match = 1'b1; run = 6'd0; level = 6'd16; end
                    14'b00000000011110: begin match = 1'b1; run = 6'd0; level = 6'd17; end
                    14'b00000000011101: begin match = 1'b1; run = 6'd0; level = 6'd18; end
                    14'b00000000011100: begin match = 1'b1; run = 6'd0; level = 6'd19; end
                    14'b00000000011011: begin match = 1'b1; run = 6'd0; level = 6'd20; end
                    14'b00000000011010: begin match = 1'b1; run = 6'd0; level = 6'd21; end
                    14'b00000000011001: begin match = 1'b1; run = 6'd0; level = 6'd22; end
                    14'b00000000011000: begin match = 1'b1; run = 6'd0; level = 6'd23; end
                    14'b00000000010111: begin match = 1'b1; run = 6'd0; level = 6'd24; end
                    14'b00000000010110: begin match = 1'b1; run = 6'd0; level = 6'd25; end
                    14'b00000000010101: begin match = 1'b1; run = 6'd0; level = 6'd26; end
                    14'b00000000010100: begin match = 1'b1; run = 6'd0; level = 6'd27; end
                    14'b00000000010011: begin match = 1'b1; run = 6'd0; level = 6'd28; end
                    14'b00000000010010: begin match = 1'b1; run = 6'd0; level = 6'd29; end
                    14'b00000000010001: begin match = 1'b1; run = 6'd0; level = 6'd30; end
                    14'b00000000010000: begin match = 1'b1; run = 6'd0; level = 6'd31; end
                    default: begin end
                endcase
            end
            5'd15: begin
                case (vlc_code[14:0])
                    15'b000000000011000: begin match = 1'b1; run = 6'd0; level = 6'd32; end
                    15'b000000000010111: begin match = 1'b1; run = 6'd0; level = 6'd33; end
                    15'b000000000010110: begin match = 1'b1; run = 6'd0; level = 6'd34; end
                    15'b000000000010101: begin match = 1'b1; run = 6'd0; level = 6'd35; end
                    15'b000000000010100: begin match = 1'b1; run = 6'd0; level = 6'd36; end
                    15'b000000000010011: begin match = 1'b1; run = 6'd0; level = 6'd37; end
                    15'b000000000010010: begin match = 1'b1; run = 6'd0; level = 6'd38; end
                    15'b000000000010001: begin match = 1'b1; run = 6'd0; level = 6'd39; end
                    15'b000000000010000: begin match = 1'b1; run = 6'd0; level = 6'd40; end
                    15'b000000000011111: begin match = 1'b1; run = 6'd1; level = 6'd8; end
                    15'b000000000011110: begin match = 1'b1; run = 6'd1; level = 6'd9; end
                    15'b000000000011101: begin match = 1'b1; run = 6'd1; level = 6'd10; end
                    15'b000000000011100: begin match = 1'b1; run = 6'd1; level = 6'd11; end
                    15'b000000000011011: begin match = 1'b1; run = 6'd1; level = 6'd12; end
                    15'b000000000011010: begin match = 1'b1; run = 6'd1; level = 6'd13; end
                    15'b000000000011001: begin match = 1'b1; run = 6'd1; level = 6'd14; end
                    default: begin end
                endcase
            end
            5'd16: begin
                case (vlc_code[15:0])
                    16'b0000000000010011: begin match = 1'b1; run = 6'd1; level = 6'd15; end
                    16'b0000000000010010: begin match = 1'b1; run = 6'd1; level = 6'd16; end
                    16'b0000000000010001: begin match = 1'b1; run = 6'd1; level = 6'd17; end
                    16'b0000000000010000: begin match = 1'b1; run = 6'd1; level = 6'd18; end
                    16'b0000000000010100: begin match = 1'b1; run = 6'd6; level = 6'd3; end
                    16'b0000000000011010: begin match = 1'b1; run = 6'd11; level = 6'd2; end
                    16'b0000000000011001: begin match = 1'b1; run = 6'd12; level = 6'd2; end
                    16'b0000000000011000: begin match = 1'b1; run = 6'd13; level = 6'd2; end
                    16'b0000000000010111: begin match = 1'b1; run = 6'd14; level = 6'd2; end
                    16'b0000000000010110: begin match = 1'b1; run = 6'd15; level = 6'd2; end
                    16'b0000000000010101: begin match = 1'b1; run = 6'd16; level = 6'd2; end
                    16'b0000000000011111: begin match = 1'b1; run = 6'd27; level = 6'd1; end
                    16'b0000000000011110: begin match = 1'b1; run = 6'd28; level = 6'd1; end
                    16'b0000000000011101: begin match = 1'b1; run = 6'd29; level = 6'd1; end
                    16'b0000000000011100: begin match = 1'b1; run = 6'd30; level = 6'd1; end
                    16'b0000000000011011: begin match = 1'b1; run = 6'd31; level = 6'd1; end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
    else begin
        case (vlc_len)
            5'd2: begin
                case (vlc_code[1:0])
                    2'b10: begin match = 1'b1; end_of_block = 1'b1; end
                    2'b11: begin match = 1'b1; run = 6'd0; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd3: begin
                case (vlc_code[2:0])
                    3'b011: begin match = 1'b1; run = 6'd1; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd4: begin
                case (vlc_code[3:0])
                    4'b0100: begin match = 1'b1; run = 6'd0; level = 6'd2; end
                    4'b0101: begin match = 1'b1; run = 6'd2; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd5: begin
                case (vlc_code[4:0])
                    5'b00101: begin match = 1'b1; run = 6'd0; level = 6'd3; end
                    5'b00111: begin match = 1'b1; run = 6'd3; level = 6'd1; end
                    5'b00110: begin match = 1'b1; run = 6'd4; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd6: begin
                case (vlc_code[5:0])
                    6'b000110: begin match = 1'b1; run = 6'd1; level = 6'd2; end
                    6'b000111: begin match = 1'b1; run = 6'd5; level = 6'd1; end
                    6'b000101: begin match = 1'b1; run = 6'd6; level = 6'd1; end
                    6'b000100: begin match = 1'b1; run = 6'd7; level = 6'd1; end
                    6'b000001: begin match = 1'b1; escape = 1'b1; end
                    default: begin end
                endcase
            end
            5'd7: begin
                case (vlc_code[6:0])
                    7'b0000110: begin match = 1'b1; run = 6'd0; level = 6'd4; end
                    7'b0000100: begin match = 1'b1; run = 6'd2; level = 6'd2; end
                    7'b0000111: begin match = 1'b1; run = 6'd8; level = 6'd1; end
                    7'b0000101: begin match = 1'b1; run = 6'd9; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd8: begin
                case (vlc_code[7:0])
                    8'b00100110: begin match = 1'b1; run = 6'd0; level = 6'd5; end
                    8'b00100001: begin match = 1'b1; run = 6'd0; level = 6'd6; end
                    8'b00100101: begin match = 1'b1; run = 6'd1; level = 6'd3; end
                    8'b00100100: begin match = 1'b1; run = 6'd3; level = 6'd2; end
                    8'b00100111: begin match = 1'b1; run = 6'd10; level = 6'd1; end
                    8'b00100011: begin match = 1'b1; run = 6'd11; level = 6'd1; end
                    8'b00100010: begin match = 1'b1; run = 6'd12; level = 6'd1; end
                    8'b00100000: begin match = 1'b1; run = 6'd13; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd10: begin
                case (vlc_code[9:0])
                    10'b0000001010: begin match = 1'b1; run = 6'd0; level = 6'd7; end
                    10'b0000001100: begin match = 1'b1; run = 6'd1; level = 6'd4; end
                    10'b0000001011: begin match = 1'b1; run = 6'd2; level = 6'd3; end
                    10'b0000001111: begin match = 1'b1; run = 6'd4; level = 6'd2; end
                    10'b0000001001: begin match = 1'b1; run = 6'd5; level = 6'd2; end
                    10'b0000001110: begin match = 1'b1; run = 6'd14; level = 6'd1; end
                    10'b0000001101: begin match = 1'b1; run = 6'd15; level = 6'd1; end
                    10'b0000001000: begin match = 1'b1; run = 6'd16; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd12: begin
                case (vlc_code[11:0])
                    12'b000000011101: begin match = 1'b1; run = 6'd0; level = 6'd8; end
                    12'b000000011000: begin match = 1'b1; run = 6'd0; level = 6'd9; end
                    12'b000000010011: begin match = 1'b1; run = 6'd0; level = 6'd10; end
                    12'b000000010000: begin match = 1'b1; run = 6'd0; level = 6'd11; end
                    12'b000000011011: begin match = 1'b1; run = 6'd1; level = 6'd5; end
                    12'b000000010100: begin match = 1'b1; run = 6'd2; level = 6'd4; end
                    12'b000000011100: begin match = 1'b1; run = 6'd3; level = 6'd3; end
                    12'b000000010010: begin match = 1'b1; run = 6'd4; level = 6'd3; end
                    12'b000000011110: begin match = 1'b1; run = 6'd6; level = 6'd2; end
                    12'b000000010101: begin match = 1'b1; run = 6'd7; level = 6'd2; end
                    12'b000000010001: begin match = 1'b1; run = 6'd8; level = 6'd2; end
                    12'b000000011111: begin match = 1'b1; run = 6'd17; level = 6'd1; end
                    12'b000000011010: begin match = 1'b1; run = 6'd18; level = 6'd1; end
                    12'b000000011001: begin match = 1'b1; run = 6'd19; level = 6'd1; end
                    12'b000000010111: begin match = 1'b1; run = 6'd20; level = 6'd1; end
                    12'b000000010110: begin match = 1'b1; run = 6'd21; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd13: begin
                case (vlc_code[12:0])
                    13'b0000000011010: begin match = 1'b1; run = 6'd0; level = 6'd12; end
                    13'b0000000011001: begin match = 1'b1; run = 6'd0; level = 6'd13; end
                    13'b0000000011000: begin match = 1'b1; run = 6'd0; level = 6'd14; end
                    13'b0000000010111: begin match = 1'b1; run = 6'd0; level = 6'd15; end
                    13'b0000000010110: begin match = 1'b1; run = 6'd1; level = 6'd6; end
                    13'b0000000010101: begin match = 1'b1; run = 6'd1; level = 6'd7; end
                    13'b0000000010100: begin match = 1'b1; run = 6'd2; level = 6'd5; end
                    13'b0000000010011: begin match = 1'b1; run = 6'd3; level = 6'd4; end
                    13'b0000000010010: begin match = 1'b1; run = 6'd5; level = 6'd3; end
                    13'b0000000010001: begin match = 1'b1; run = 6'd9; level = 6'd2; end
                    13'b0000000010000: begin match = 1'b1; run = 6'd10; level = 6'd2; end
                    13'b0000000011111: begin match = 1'b1; run = 6'd22; level = 6'd1; end
                    13'b0000000011110: begin match = 1'b1; run = 6'd23; level = 6'd1; end
                    13'b0000000011101: begin match = 1'b1; run = 6'd24; level = 6'd1; end
                    13'b0000000011100: begin match = 1'b1; run = 6'd25; level = 6'd1; end
                    13'b0000000011011: begin match = 1'b1; run = 6'd26; level = 6'd1; end
                    default: begin end
                endcase
            end
            5'd14: begin
                case (vlc_code[13:0])
                    14'b00000000011111: begin match = 1'b1; run = 6'd0; level = 6'd16; end
                    14'b00000000011110: begin match = 1'b1; run = 6'd0; level = 6'd17; end
                    14'b00000000011101: begin match = 1'b1; run = 6'd0; level = 6'd18; end
                    14'b00000000011100: begin match = 1'b1; run = 6'd0; level = 6'd19; end
                    14'b00000000011011: begin match = 1'b1; run = 6'd0; level = 6'd20; end
                    14'b00000000011010: begin match = 1'b1; run = 6'd0; level = 6'd21; end
                    14'b00000000011001: begin match = 1'b1; run = 6'd0; level = 6'd22; end
                    14'b00000000011000: begin match = 1'b1; run = 6'd0; level = 6'd23; end
                    14'b00000000010111: begin match = 1'b1; run = 6'd0; level = 6'd24; end
                    14'b00000000010110: begin match = 1'b1; run = 6'd0; level = 6'd25; end
                    14'b00000000010101: begin match = 1'b1; run = 6'd0; level = 6'd26; end
                    14'b00000000010100: begin match = 1'b1; run = 6'd0; level = 6'd27; end
                    14'b00000000010011: begin match = 1'b1; run = 6'd0; level = 6'd28; end
                    14'b00000000010010: begin match = 1'b1; run = 6'd0; level = 6'd29; end
                    14'b00000000010001: begin match = 1'b1; run = 6'd0; level = 6'd30; end
                    14'b00000000010000: begin match = 1'b1; run = 6'd0; level = 6'd31; end
                    default: begin end
                endcase
            end
            5'd15: begin
                case (vlc_code[14:0])
                    15'b000000000011000: begin match = 1'b1; run = 6'd0; level = 6'd32; end
                    15'b000000000010111: begin match = 1'b1; run = 6'd0; level = 6'd33; end
                    15'b000000000010110: begin match = 1'b1; run = 6'd0; level = 6'd34; end
                    15'b000000000010101: begin match = 1'b1; run = 6'd0; level = 6'd35; end
                    15'b000000000010100: begin match = 1'b1; run = 6'd0; level = 6'd36; end
                    15'b000000000010011: begin match = 1'b1; run = 6'd0; level = 6'd37; end
                    15'b000000000010010: begin match = 1'b1; run = 6'd0; level = 6'd38; end
                    15'b000000000010001: begin match = 1'b1; run = 6'd0; level = 6'd39; end
                    15'b000000000010000: begin match = 1'b1; run = 6'd0; level = 6'd40; end
                    15'b000000000011111: begin match = 1'b1; run = 6'd1; level = 6'd8; end
                    15'b000000000011110: begin match = 1'b1; run = 6'd1; level = 6'd9; end
                    15'b000000000011101: begin match = 1'b1; run = 6'd1; level = 6'd10; end
                    15'b000000000011100: begin match = 1'b1; run = 6'd1; level = 6'd11; end
                    15'b000000000011011: begin match = 1'b1; run = 6'd1; level = 6'd12; end
                    15'b000000000011010: begin match = 1'b1; run = 6'd1; level = 6'd13; end
                    15'b000000000011001: begin match = 1'b1; run = 6'd1; level = 6'd14; end
                    default: begin end
                endcase
            end
            5'd16: begin
                case (vlc_code[15:0])
                    16'b0000000000010011: begin match = 1'b1; run = 6'd1; level = 6'd15; end
                    16'b0000000000010010: begin match = 1'b1; run = 6'd1; level = 6'd16; end
                    16'b0000000000010001: begin match = 1'b1; run = 6'd1; level = 6'd17; end
                    16'b0000000000010000: begin match = 1'b1; run = 6'd1; level = 6'd18; end
                    16'b0000000000010100: begin match = 1'b1; run = 6'd6; level = 6'd3; end
                    16'b0000000000011010: begin match = 1'b1; run = 6'd11; level = 6'd2; end
                    16'b0000000000011001: begin match = 1'b1; run = 6'd12; level = 6'd2; end
                    16'b0000000000011000: begin match = 1'b1; run = 6'd13; level = 6'd2; end
                    16'b0000000000010111: begin match = 1'b1; run = 6'd14; level = 6'd2; end
                    16'b0000000000010110: begin match = 1'b1; run = 6'd15; level = 6'd2; end
                    16'b0000000000010101: begin match = 1'b1; run = 6'd16; level = 6'd2; end
                    16'b0000000000011111: begin match = 1'b1; run = 6'd27; level = 6'd1; end
                    16'b0000000000011110: begin match = 1'b1; run = 6'd28; level = 6'd1; end
                    16'b0000000000011101: begin match = 1'b1; run = 6'd29; level = 6'd1; end
                    16'b0000000000011100: begin match = 1'b1; run = 6'd30; level = 6'd1; end
                    16'b0000000000011011: begin match = 1'b1; run = 6'd31; level = 6'd1; end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
end

endmodule
