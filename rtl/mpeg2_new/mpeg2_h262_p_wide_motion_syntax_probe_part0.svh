//============================================================================
// MiSTer Media Player - wide progressive H.262 P syntax parser
//
// kate - Commit 166: extend the generalized progressive 4:2:0 P path beyond
// the historical 128x96 / 8x6 regression envelope without exporting a packed
// whole-picture motion plan. Motion metadata is emitted in macroblock order as
// each buffered slice row is parsed. kate - Commit 167: this same streamed
// parser now also owns the exact 128x96 generalized-P regression geometry so
// the duplicate packed-plan parser can be retired from active synthesis.
// Sparse residual metadata remains bounded
// to 16 coded blocks / 64 coefficient events (implementation limits, not H.262).
//
// kate - Commit 193: picture-signalled horizontal/vertical f_code values 1..4
// now drive residual length, differential reconstruction and component wrap.
// Standards authority: .ai/core-standards.md (H262-007..H262-022).
//============================================================================
module mpeg2_h262_p_wide_motion_syntax_probe
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,

    output reg         wide_candidate,
    output reg         wide_seen,
    output reg         wide_complete_now,

    output reg         motion_event_valid,
    output reg [10:0]  motion_event_index,
    output reg signed [7:0] motion_event_x,
    output reg signed [7:0] motion_event_y,

    output reg [5:0]   picture_mb_width,
    output reg [5:0]   picture_mb_height,
    output reg [10:0]  picture_mb_count,

    output reg [351:0] residual_mb_plan,
    output reg [95:0]  residual_block_index_plan,
    output reg [5:0]   residual_block_count,
    output reg         residual_present,
    output reg [383:0] residual_coeff_index_plan,
    output reg [831:0] residual_coeff_value_plan,
    output reg [63:0]  residual_coeff_last_plan,
    output reg [6:0]   residual_coeff_count,
    output reg [159:0] residual_qscale_plan,
    output reg         q_scale_type,
    output reg         alternate_scan,

    output reg         parse_hold,
    output reg         probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5,
    SEQUENCE_END_CODE    = 8'hB7;
localparam integer ROW_BUFFER_BYTES = 512;
localparam [5:0] MAX_RESIDUAL_BLOCKS = 6'd32;
localparam [6:0] MAX_COEFF_EVENTS = 7'd64;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire start_code_now = (byte_window_next[31:8] == 24'h000001);
wire [7:0] start_code_value = byte_window_next[7:0];
wire slice_start_now = start_code_now &&
                       (start_code_value >= 8'h01) &&
                       (start_code_value <= 8'hAF);
wire post_p_boundary_now = start_code_now &&
                           ((start_code_value == PICTURE_START_CODE) ||
                            (start_code_value == SEQUENCE_HEADER_CODE) ||
                            (start_code_value == SEQUENCE_END_CODE));

reg sequence_capture;
reg [1:0] sequence_count;
reg [23:0] sequence_shift;
wire [23:0] sequence_next = {sequence_shift[15:0], stream_data};
wire [11:0] sequence_h_next = sequence_next[23:12];
wire [11:0] sequence_v_next = sequence_next[11:0];
wire [12:0] sequence_h_rounded = {1'b0,sequence_h_next} + 13'd15;
wire [12:0] sequence_v_rounded = {1'b0,sequence_v_next} + 13'd15;
wire [5:0] sequence_mb_width_next = sequence_h_rounded[9:4];
wire [5:0] sequence_mb_height_next = sequence_v_rounded[9:4];
reg geometry_supported;

reg picture_capture;
reg picture_count;
reg [15:0] picture_shift;
wire [15:0] picture_next = {picture_shift[7:0], stream_data};
reg current_picture_is_p;

reg pce_capture;
reg [2:0] pce_count;
reg [39:0] pce_shift;
wire [39:0] pce_next = {pce_shift[31:0], stream_data};
reg [3:0] p_forward_f_code_horizontal;
reg [3:0] p_forward_f_code_vertical;

reg [7:0] row_bytes [0:ROW_BUFFER_BYTES-1];
reg slice_capture;
reg [5:0] slice_row_number;
reg [8:0] row_byte_count;
reg [10:0] row_base_index;
reg proof_done, parse_active, boundary_final, final_release_pending;
reg [8:0] parse_byte_limit, parse_byte_index;
reg [2:0] parse_bit_index;
wire parser_at_end = (parse_byte_index >= parse_byte_limit);
wire parser_current_bit = row_bytes[parse_byte_index][parse_bit_index];

localparam [5:0]
    R_H_QSCALE       = 6'd0,
    R_H_EXTRA_FLAG   = 6'd1,
    R_H_EXTRA_INFO   = 6'd2,
    R_MBA            = 6'd3,
    R_APPLY          = 6'd4,
    R_SKIP_EMIT      = 6'd5,
    R_MBTYPE         = 6'd6,
    R_MB_QSCALE      = 6'd7,
    R_MOTION_X       = 6'd8,
    R_MOTION_X_RES   = 6'd9,
    R_MOTION_Y       = 6'd10,
    R_MOTION_Y_RES   = 6'd11,
    R_CBP            = 6'd12,
    R_BLOCK          = 6'd13,
    R_FIRST_COEFF    = 6'd14,
    R_COEFF_VLC      = 6'd15,
    R_COEFF_SIGN     = 6'd16,
    R_ESCAPE_RUN     = 6'd17,
    R_ESCAPE_LEVEL   = 6'd18,
    R_MB_DONE        = 6'd19,
    R_STUFF          = 6'd20,
    R_SUCCESS        = 6'd21,
    R_ERROR          = 6'd22;
reg [5:0] parser_state;

reg [2:0] field_bit_count;
reg [4:0] qscale_shift, current_qscale;
reg [3:0] extra_info_count;

reg [10:0] mba_vlc_bits;
reg [3:0] mba_vlc_len;
reg [9:0] mba_escape_accum, mba_increment;
reg signed [7:0] previous_col;
reg [5:0] current_col;
reg row_has_coded_mb;
reg [5:0] skip_emit_col, skip_remaining;

reg [5:0] mbtype_bits;
reg [2:0] mbtype_len;
reg current_has_motion, current_has_pattern, current_has_quant;

reg signed [7:0] predictor_x, predictor_y;
reg signed [7:0] current_motion_x, current_motion_y;
reg signed [5:0] motion_code_pending;
reg [10:0] motion_vlc_bits;
reg [3:0] motion_vlc_len;
reg [2:0] motion_residual_shift;
reg [1:0] motion_residual_count;

reg [8:0] cbp_vlc_bits;
reg [3:0] cbp_vlc_len;
reg [5:0] current_cbp;
reg [2:0] current_block_index;
reg [4:0] current_residual_slot;

reg [15:0] coeff_vlc_code;
reg [4:0] coeff_vlc_len;
wire [15:0] coeff_vlc_code_next = {coeff_vlc_code[14:0], parser_current_bit};
wire [4:0] coeff_vlc_len_next = coeff_vlc_len + 5'd1;
wire coeff_vlc_match, coeff_vlc_eob, coeff_vlc_escape;
wire [5:0] coeff_vlc_run, coeff_vlc_level;

mpeg2_h262_dct_vlc p_wide_dct_vlc
(
    .table_one    (1'b0),
    .vlc_code     (coeff_vlc_code_next),
    .vlc_len      (coeff_vlc_len_next),
    .match        (coeff_vlc_match),
    .end_of_block (coeff_vlc_eob),
    .escape       (coeff_vlc_escape),
    .run          (coeff_vlc_run),
    .level        (coeff_vlc_level)
);

reg [6:0] qfs_index;
reg [5:0] coeff_run_pending, coeff_level_pending;
reg current_block_has_coeff;
wire [7:0] normal_target_index =
    {1'b0,qfs_index} + {2'b00,coeff_run_pending};

reg [5:0] escape_run_shift;
reg [2:0] escape_run_bit_count;
wire [5:0] escape_run_next = {escape_run_shift[4:0], parser_current_bit};
reg [11:0] escape_level_shift;
reg [3:0] escape_level_bit_count;
wire [11:0] escape_level_next =
    {escape_level_shift[10:0], parser_current_bit};
wire signed [11:0] escape_level_signed = $signed(escape_level_next);
wire [7:0] escape_target_index =
    {1'b0,qfs_index} + {2'b00,escape_run_shift};

wire parser_state_consumes_bit =
    (parser_state == R_H_QSCALE) ||
    (parser_state == R_H_EXTRA_FLAG) ||
    (parser_state == R_H_EXTRA_INFO) ||
    (parser_state == R_MBA) ||
    (parser_state == R_MBTYPE) ||
    (parser_state == R_MB_QSCALE) ||
    (parser_state == R_MOTION_X) ||
    (parser_state == R_MOTION_X_RES) ||
    (parser_state == R_MOTION_Y) ||
    (parser_state == R_MOTION_Y_RES) ||
    (parser_state == R_CBP) ||
    (parser_state == R_FIRST_COEFF) ||
    (parser_state == R_COEFF_VLC) ||
    (parser_state == R_COEFF_SIGN) ||
    (parser_state == R_ESCAPE_RUN) ||
    (parser_state == R_ESCAPE_LEVEL) ||
    (parser_state == R_STUFF);
wire parser_consume_bit =
    parse_active && parser_state_consumes_bit && !parser_at_end;

wire [10:0] mba_vlc_bits_next =
    {mba_vlc_bits[9:0], parser_current_bit};
wire [3:0] mba_vlc_len_next = mba_vlc_len + 4'd1;
wire [5:0] mbtype_bits_next =
    {mbtype_bits[4:0], parser_current_bit};
wire [2:0] mbtype_len_next = mbtype_len + 3'd1;
wire [10:0] motion_vlc_bits_next =
    {motion_vlc_bits[9:0], parser_current_bit};
wire [3:0] motion_vlc_len_next = motion_vlc_len + 4'd1;
wire [8:0] cbp_vlc_bits_next =
    {cbp_vlc_bits[7:0], parser_current_bit};
wire [3:0] cbp_vlc_len_next = cbp_vlc_len + 4'd1;
wire signed [10:0] next_col_calc =
    $signed(previous_col) + $signed({1'b0,mba_increment});
wire [10:0] current_mb_index =
    row_base_index + {5'd0,current_col};
wire [4:0] qscale_next =
    {qscale_shift[3:0], parser_current_bit};
wire [2:0] motion_residual_next =
    {motion_residual_shift[1:0], parser_current_bit};

function automatic [6:0] match_mba_code;
    input [10:0] bits;
    input [3:0] len;
    reg valid;
    reg [5:0] value;
    begin
        valid=0; value=0;
        case(len)
        4'd1: if(bits[0]) begin valid=1;value=1;end
        4'd3: case(bits[2:0])
            3'b011:begin valid=1;value=2;end
            3'b010:begin valid=1;value=3;end
            default:;
        endcase
        4'd4: case(bits[3:0])
            4'b0011:begin valid=1;value=4;end
            4'b0010:begin valid=1;value=5;end
            default:;
        endcase
        4'd5: case(bits[4:0])
            5'b00011:begin valid=1;value=6;end
            5'b00010:begin valid=1;value=7;end
            default:;
        endcase
        4'd7: case(bits[6:0])
            7'b0000111:begin valid=1;value=8;end
            7'b0000110:begin valid=1;value=9;end
            default:;
        endcase
        4'd8: case(bits[7:0])
            8'b00001011:begin valid=1;value=10;end
            8'b00001010:begin valid=1;value=11;end
            8'b00001001:begin valid=1;value=12;end
            8'b00001000:begin valid=1;value=13;end
            8'b00000111:begin valid=1;value=14;end
            8'b00000110:begin valid=1;value=15;end
            default:;
        endcase
        4'd10: case(bits[9:0])
            10'b0000010111:begin valid=1;value=16;end
            10'b0000010110:begin valid=1;value=17;end
            10'b0000010101:begin valid=1;value=18;end
            10'b0000010100:begin valid=1;value=19;end
            10'b0000010011:begin valid=1;value=20;end
            10'b0000010010:begin valid=1;value=21;end
            default:;
        endcase
        4'd11: case(bits[10:0])
            11'b00000100011:begin valid=1;value=22;end
            11'b00000100010:begin valid=1;value=23;end
            11'b00000100001:begin valid=1;value=24;end
            11'b00000100000:begin valid=1;value=25;end
            11'b00000011111:begin valid=1;value=26;end
            11'b00000011110:begin valid=1;value=27;end
            11'b00000011101:begin valid=1;value=28;end
            11'b00000011100:begin valid=1;value=29;end
            11'b00000011011:begin valid=1;value=30;end
            11'b00000011010:begin valid=1;value=31;end
            11'b00000011001:begin valid=1;value=32;end
            11'b00000011000:begin valid=1;value=33;end
            default:;
        endcase
        default:;
        endcase
        match_mba_code={valid,value};
    end
endfunction

wire [6:0] mba_match =
    match_mba_code(mba_vlc_bits_next,mba_vlc_len_next);
wire mba_escape_match =
    (mba_vlc_len_next==4'd11) &&
    (mba_vlc_bits_next==11'b00000001000);

// {valid,motion_forward,pattern,quant,intra}
function automatic [4:0] match_p_mbtype;
    input [5:0] bits;
    input [2:0] len;
    begin
        match_p_mbtype=5'b00000;
        case(len)
        3'd1: if(bits[0]) match_p_mbtype=5'b11100;
        3'd2: if(bits[1:0]==2'b01) match_p_mbtype=5'b10100;
        3'd3: if(bits[2:0]==3'b001) match_p_mbtype=5'b11000;
        3'd5: case(bits[4:0])
            5'b00011: match_p_mbtype=5'b10001;
            5'b00010: match_p_mbtype=5'b11110;
            5'b00001: match_p_mbtype=5'b10110;
