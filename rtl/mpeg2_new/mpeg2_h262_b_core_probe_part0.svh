//============================================================================
// MiSTer Media Player - generalized progressive 4:2:0 B-picture core probe
//
// kate - Commit 169: widen the established controlled B path through the
// 720x480 / 45x30 progressive frame envelope. Motion metadata is streamed in
// macroblock order while each buffered slice row is parsed, avoiding a scaled
// whole-picture register plan.
// kate - Commit 170: generalize coded_block_pattern and non-intra residual
// syntax across all six 4:2:0 blocks. Sparse residual metadata remains bounded
// to 16 blocks / 64 coefficient events (implementation limits, not H.262).
// kate - Commit 171: accept the full Table-B.1 macroblock_address_increment
// VLC set plus macroblock_escape accumulation needed inside a 45-MB row.
// Leading/trailing skipped-B semantics remain outside this boundary.
// kate - Commit 172: register each decoded B macroblock-address symbol before
// row-bound/skip arithmetic so the Commit-171 syntax does not sit on one long
// 54 MHz combinational path. Address semantics and consumed bits are unchanged.
//
// Standards authority: .ai/core-standards.md H262-006, H262-010, H262-014,
// H262-021, H262-024 plus the established motion/address records used by
// Commit 169.
//============================================================================
module mpeg2_h262_b_core_probe
(
    input  wire clk,
    input  wire reset,
    input  wire [7:0] stream_data,
    input  wire stream_valid,

    output reg  b_candidate,
    output reg  b_seen,
    output reg  b_complete_now,
    output reg  parse_hold,

    output reg  replay_active,
    output reg  sideband_valid,
    output reg  [5:0] sideband_index,
    output reg  signed [15:0] sideband_value,
    output reg  first_sample_valid,
    output reg  signed [15:0] first_sample_value,
    output wire probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5,
    SEQUENCE_END_CODE    = 8'hB7;
localparam integer ROW_BUFFER_BYTES = 512;
localparam [4:0] MAX_RESIDUAL_BLOCKS = 5'd16;
localparam [6:0] MAX_COEFF_EVENTS = 7'd64;

reg [10:0] residual_mb [0:15];
reg [2:0] residual_block [0:15];
reg [4:0] residual_qscale [0:15];
reg [4:0] residual_count;
reg [5:0] residual_coeff_index [0:63];
reg signed [12:0] residual_coeff_value [0:63];
reg residual_coeff_last [0:63];
reg [6:0] residual_coeff_count;
reg q_scale_type, alternate_scan;

reg parser_error, replay_error, prior_error;
assign probe_error = prior_error | parser_error | replay_error;

reg [31:0] byte_window;
wire [31:0] byte_window_next={byte_window[23:0],stream_data};
wire start_code_now=(byte_window_next[31:8]==24'h000001);
wire [7:0] start_code_value=byte_window_next[7:0];
wire slice_start_now=start_code_now&&(start_code_value>=8'h01)&&(start_code_value<=8'hAF);
wire post_b_boundary_now=start_code_now&&
    ((start_code_value==PICTURE_START_CODE)||(start_code_value==SEQUENCE_HEADER_CODE)||(start_code_value==SEQUENCE_END_CODE));

reg sequence_capture; reg [1:0] sequence_count; reg [23:0] sequence_shift;
wire [23:0] sequence_next={sequence_shift[15:0],stream_data};
wire [11:0] sequence_h_next=sequence_next[23:12];
wire [11:0] sequence_v_next=sequence_next[11:0];
wire [12:0] sequence_h_rounded={1'b0,sequence_h_next}+13'd15;
wire [12:0] sequence_v_rounded={1'b0,sequence_v_next}+13'd15;
wire [5:0] sequence_mb_width_next=sequence_h_rounded[9:4];
wire [5:0] sequence_mb_height_next=sequence_v_rounded[9:4];
reg geometry_supported;
reg [5:0] picture_mb_width,picture_mb_height;

reg picture_capture,picture_count; reg [15:0] picture_shift;
wire [15:0] picture_next={picture_shift[7:0],stream_data};
reg current_picture_is_b;

reg pce_capture; reg [2:0] pce_count; reg [39:0] pce_shift;
wire [39:0] pce_next={pce_shift[31:0],stream_data};

reg [7:0] row_bytes [0:ROW_BUFFER_BYTES-1];
reg slice_capture; reg [5:0] slice_row_number; reg [8:0] row_byte_count;
reg [10:0] row_base_index;
reg parse_active,proof_done,boundary_final;
reg [8:0] parse_byte_limit,parse_byte_index; reg [2:0] parse_bit_index;
wire parser_at_end=(parse_byte_index>=parse_byte_limit);
wire parser_current_bit=row_bytes[parse_byte_index][parse_bit_index];

localparam [5:0]
    S_QSCALE=0,S_EXTRA_FLAG=1,S_EXTRA_INFO=2,S_MBA=3,S_MBTYPE=4,
    S_FX=5,S_FX_RES=6,S_FY=7,S_FY_RES=8,
    S_BX=9,S_BX_RES=10,S_BY=11,S_BY_RES=12,
    S_CBP=13,S_BLOCK=14,S_FIRST_COEFF=15,S_COEFF_VLC=16,
    S_COEFF_SIGN=17,S_ESCAPE_RUN=18,S_ESCAPE_LEVEL=19,
    S_MB_DONE=20,S_STUFF=21,S_SUCCESS=22,S_ERROR=23,
    S_SKIP_A=24,S_SKIP_B=25,S_GEOMETRY=26,S_MB_B=27,S_MBA_APPLY=28;
reg [5:0] state;

reg [2:0] field_bit_count; reg [4:0] qscale_shift,current_qscale; reg [3:0] extra_info_count;
reg [5:0] current_col; reg row_has_coded_mb; reg [5:0] skip_remaining; reg geometry_sent;
// Historical 1..8 decoder state remains below for source compatibility; Commit
// 171 drives S_MBA from the wider Table-B.1 state and Quartus prunes the old path.
reg [6:0] mba_bits; reg [2:0] mba_len;
reg [10:0] mba_wide_bits; reg [3:0] mba_wide_len; reg [6:0] mba_escape_accum;
reg mba_symbol_escape_q; reg [5:0] mba_symbol_value_q;
wire [10:0] mba_wide_bits_next={mba_wide_bits[9:0],parser_current_bit};
wire [3:0] mba_wide_len_next=mba_wide_len+1'b1;

function automatic [7:0] match_mba_symbol;
    input [10:0] bits; input [3:0] len;
    reg valid,escape; reg [5:0] value;
    begin
        valid=0;escape=0;value=0;
        case(len)
        4'd1: if(bits[0])begin valid=1;value=1;end
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
            11'b00000001000:begin valid=1;escape=1;value=0;end
            default:;
        endcase
        default:;
        endcase
        match_mba_symbol={valid,escape,value};
    end
endfunction

wire [7:0] mba_symbol=match_mba_symbol(mba_wide_bits_next,mba_wide_len_next);
wire [7:0] mba_increment_total_q={1'b0,mba_escape_accum}+{2'b00,mba_symbol_value_q};
wire [7:0] mba_target_col_q={2'b00,current_col}+mba_increment_total_q-8'd1;
wire [7:0] mba_escape_accum_next_q={1'b0,mba_escape_accum}+8'd33;
wire [7:0] mba_escape_min_target_q={2'b00,current_col}+mba_escape_accum_next_q;

reg [3:0] mbtype_bits; reg [2:0] mbtype_len; reg [1:0] current_direction,last_direction; reg current_pattern;
reg signed [7:0] fpx,fpy,bpx,bpy,cur_fx,cur_fy,cur_bx,cur_by;
reg signed [5:0] motion_code_pending; reg [10:0] motion_bits; reg [3:0] motion_len;
reg [1:0] motion_residual_shift; reg motion_residual_count;

reg [8:0] cbp_bits; reg [3:0] cbp_len; reg [5:0] current_cbp; reg [2:0] current_block_index;
reg [15:0] coeff_vlc_code; reg [4:0] coeff_vlc_len;
wire [15:0] coeff_vlc_code_next={coeff_vlc_code[14:0],parser_current_bit};
wire [4:0] coeff_vlc_len_next=coeff_vlc_len+5'd1;
wire coeff_vlc_match,coeff_vlc_eob,coeff_vlc_escape;
wire [5:0] coeff_vlc_run,coeff_vlc_level;