//============================================================================
// MiSTer Media Player - H.262 Phase 1N complete first-picture 4:2:0 probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2
//   - 6.2.4 slice()
//   - 6.2.5 macroblock()
//   - 6.2.6 block()
//   - 6.3.16 slice semantics
//   - 6.3.17 macroblock semantics
//   - 7.2.1 intra DC differential reconstruction / Table 7-2
//   - 7.2.2 intra AC coefficient decoding
//   - Annex B Tables B.1, B.2, B.3, B.12, B.13, B.14 and B.15
//
// Phase 1N capability boundary:
//   - Non-scalable progressive 4:2:0 frame-picture I video only, selected by
//     the standards-driven front end.
//   - Decode and reconstruct all six intra blocks (Y0..Y3,Cb,Cr) for every
//     macroblock in every slice of the first picture.
//   - The same serialized QFS -> inverse quantisation -> IDCT -> reconstruction
//     pipeline is used for luma and chroma; the parser does not advance to the
//     next block until reconstruction reports the current block complete.
//   - H.262 6.2.4 terminates each slice when the next 23 bits are all zero.
//     Phase 1N then performs the required next_start_code() traversal.  Another
//     slice_start_code restarts slice parsing; any other start code completes
//     the first picture_data() region.
//   - No whole-slice capture buffer.  Bits remain streaming and upstream FIFO
//     backpressure preserves exact bit position while this parser or the
//     reconstruction pipeline pauses.
//
// kate - Every 4:2:0 block now pauses after EOB until reconstruction reports
// completion.  DC predictors and macroblock-address state are reset at every
// slice boundary as required by H.262.
//
// kate - Phase 1T-c adds the non-scalable P-picture macroblock_type VLC table
// from H.262 Annex B Table B.3.  Live P-picture slice consumption remains
// disabled in this substep; a reset-time sequential self-check walks all seven
// legal Table B.3 codewords before the stream is allowed to advance.  This makes
// the ordinary all-I hardware regression a positive proof that the future
// P-picture macroblock-type primitive is synthesized and functioning.
//============================================================================

module mpeg2_h262_luma4_probe
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,
    output wire        stream_ready,

    input  wire        phase1_supported,
    input  wire [13:0] vertical_size,
    input  wire [1:0]  intra_dc_precision,
    input  wire        intra_vlc_format,

    // One-cycle pulse from the reconstruction stage after sample 63 of the
    // previously submitted block.  The next block is not submitted before it.
    input  wire        pipeline_block_done,

    output reg         slice_header_seen,
    output reg         macroblock_address_seen,
    output reg         first_i_macroblock_seen,
    output reg         first_luma_dc_seen,
    output reg         first_luma_block_complete,
    // Sticky completion after every slice of the first picture has been parsed
    // and picture_data() reaches the next non-slice start code.
    output reg         first_picture_420_parsed,
    output reg         probe_error,

    output reg  [4:0]  quantiser_scale_code,
    output reg  [11:0] macroblock_address_increment,
    output reg         macroblock_quant,
    output reg  [4:0]  macroblock_quantiser_scale_code,
    output reg  [7:0]  slice_vertical_position,
    output reg  [2:0]  slice_vertical_position_extension,

    // First-block diagnostics retained from the earlier probe.
    output reg  [3:0]  first_luma_dc_size,
    output reg signed [12:0] first_luma_dc_differential,
    output reg  [10:0] first_luma_dc_coefficient,
    output reg  [6:0]  first_luma_ac_nonzero_count,
    output reg  [5:0]  first_luma_last_coeff_index,
    output reg signed [11:0] first_luma_last_ac_level,

    // One-cycle pulse for every accepted slice_start_code.  Reconstruction
    // uses this to reset slice-local macroblock-address state.
    output reg         slice_start,

    // Starts each accepted intra macroblock reconstruction context.
    output reg         luma_macroblock_start,

    // Coefficient handoff to inverse quantisation.  qfs_block_index remains
    // stable for the complete serialized block pipeline: 0..3 Y, 4 Cb, 5 Cr.
    output wire [2:0]  qfs_block_index,
    output reg         qfs_block_start,
    output reg         qfs_write_en,
    output reg  [5:0]  qfs_write_index,
    output reg signed [12:0] qfs_write_value,
    output reg         qfs_block_end
);

// H.262 Table 6-1: slice_start_code values are 0x01 through 0xAF.
reg  [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);

// kate - Phase 1N streaming bitreader state.  The bitreader retains only one
// payload byte and backpressures the existing asynchronous input FIFO whenever
// that byte has not yet been consumed.
reg  parse_active;
wire bit_valid;
wire current_bit;
wire bit_consume;

localparam [4:0]
    ST_VPOS_EXT      = 5'd0,
    ST_QSCALE        = 5'd1,
    ST_AFTER_QSCALE  = 5'd2,
    ST_INTRA_SLICE   = 5'd3,
    ST_PIC_ID_ENABLE = 5'd4,
    ST_PIC_ID        = 5'd5,
    ST_EXTRA_FLAG    = 5'd6,
    ST_EXTRA_INFO    = 5'd7,
    ST_MBA           = 5'd8,
    ST_MBTYPE_FIRST  = 5'd9,
    ST_MBTYPE_SECOND = 5'd10,
    ST_MB_QSCALE     = 5'd11,
    ST_DC_LUMA       = 5'd12,
    ST_DC_DIFF       = 5'd13,
    ST_AC_VLC        = 5'd14,
    ST_AC_SIGN       = 5'd15,
    ST_ESCAPE_RUN    = 5'd16,
    ST_ESCAPE_LEVEL     = 5'd17,
    ST_WAIT_PIPELINE    = 5'd18,
    ST_SLICE_END_ZEROS  = 5'd19,
    ST_START_CODE_PREFIX = 5'd20,
    ST_START_CODE_VALUE  = 5'd21;

reg [4:0] parse_state;

// kate - Phase 1T-c Table B.3 P-picture macroblock_type primitive.  The decoder
// accepts a right-aligned VLC plus its explicit length so prefix-sharing entries
// such as 1, 01, 001 and 000001 remain unambiguous.  Flag order is
// {quant, motion_forward, motion_backward, pattern, intra}.
reg [2:0] p_mbtype_selftest_index;
reg       p_mbtype_table_verified;
reg       p_mbtype_selftest_error;
reg [5:0] p_mbtype_decode_code;
reg [2:0] p_mbtype_decode_len;
reg [4:0] p_mbtype_expected_flags;
reg       p_mbtype_match;
reg       p_mbtype_quant;
reg       p_mbtype_motion_forward;
reg       p_mbtype_motion_backward;
reg       p_mbtype_pattern;
reg       p_mbtype_intra;
wire [4:0] p_mbtype_decoded_flags = {
    p_mbtype_quant,
    p_mbtype_motion_forward,
    p_mbtype_motion_backward,
    p_mbtype_pattern,
    p_mbtype_intra
};

wire bitreader_stream_ready;
assign stream_ready = p_mbtype_table_verified &&
                      !p_mbtype_selftest_error &&
                      bitreader_stream_ready;

// kate - bit_mod8 mirrors the bitreader's current position.  Slice syntax starts
// on a byte boundary immediately after slice_start_code.  After the 23-zero
// nextbits() condition is consumed, next_start_code() is recovered by consuming
// zero stuffing until the terminating '1' of the byte-aligned 0x000001 prefix.
// The following eight bits are the next start_code_value.
reg [2:0] bit_mod8;
reg [7:0] next_start_code_shift;
reg [2:0] next_start_code_bit_count;
reg [10:0] picture_slice_index;

assign bit_consume = parse_active && bit_valid &&
                     (parse_state != ST_WAIT_PIPELINE);

mpeg2_h262_bitreader mpeg2_h262_bitreader
(
    .clk          (clk),
    .reset        (reset),
    .stream_data  (stream_data),
    .stream_valid (stream_valid),
    .stream_ready (bitreader_stream_ready),
    .enable       (parse_active),
    .bit_consume  (bit_consume),
    .bit_valid    (bit_valid),
    .bit_value    (current_bit)
);
reg [3:0] field_bit_count;
reg [4:0] qscale_shift;
reg       slice_picture_id_enable;
reg [5:0] slice_picture_id_shift;
reg [4:0] macroblock_qscale_shift;

// H.262 6.1.3 / Figure 6-10 block order for 4:2:0 is Y0,Y1,Y2,Y3,Cb,Cr.
// block_index therefore runs 0..5 for each macroblock.  macroblock_index counts
// completed macroblocks in the current slice; 11 bits cover the H.262 maximum
// row width.  picture_slice_index distinguishes the first block of the picture
// from the first block of later slices for retained diagnostics.
reg [2:0]  block_index;
reg [10:0] macroblock_index;
assign qfs_block_index = block_index;

// H.262 6.2.4 ends the slice macroblock loop when the next 23 bits are zero.
// ST_MBA already accumulates up to 11 bits for Table B.1; if those 11 bits are
// all zero, no legal MBA codeword has matched, so the remaining 12 zeros are
// checked in ST_SLICE_END_ZEROS.
reg [4:0] slice_zero_count;

// H.262 7.2.1 / Table 7-2: all three intra DC predictors reset at slice start
// and then persist across subsequent intra blocks/macroblocks in the slice.
wire [10:0] dc_predictor_reset = 11'd128 << intra_dc_precision;
reg  [10:0] dc_predictor_y;
reg  [10:0] dc_predictor_cb;
reg  [10:0] dc_predictor_cr;
wire [10:0] dc_predictor_current =
    (block_index < 3'd4) ? dc_predictor_y :
    (block_index == 3'd4) ? dc_predictor_cb : dc_predictor_cr;
wire        current_block_is_luma = (block_index < 3'd4);
wire        first_diagnostic_block =
    (picture_slice_index == 11'd0) &&
    (macroblock_index == 11'd0) &&
    (block_index == 3'd0);

// Annex B Tables B.12/B.13 DC-size accumulator.
reg [9:0] dc_vlc_code;
reg [3:0] dc_vlc_len;
reg [3:0] dc_size;
reg [10:0] dc_diff_shift;
reg [3:0] dc_diff_bit_count;

wire [9:0] dc_vlc_code_next = {dc_vlc_code[8:0], current_bit};
wire [3:0] dc_vlc_len_next  = dc_vlc_len + 4'd1;
wire [10:0] dc_diff_bits_next = {dc_diff_shift[9:0], current_bit};

reg       dc_size_match;
reg [3:0] dc_size_value;

wire [12:0] dc_half_range = (dc_size == 0) ? 13'd0 :
                            (13'd1 << (dc_size - 1'b1));
wire [12:0] dc_raw_extended = {2'b00, dc_diff_bits_next};
wire signed [12:0] dc_diff_decoded =
    (dc_size == 0) ? 13'sd0 :
    (dc_raw_extended >= dc_half_range) ?
        $signed(dc_raw_extended) :
        ($signed(dc_raw_extended) + 13'sd1 -
         $signed(dc_half_range << 1));
wire signed [12:0] dc_coefficient_decoded =
    $signed({2'b00, dc_predictor_current}) + dc_diff_decoded;
wire [11:0] dc_coefficient_max =
    (12'd256 << intra_dc_precision) - 12'd1;
wire signed [12:0] dc_coefficient_max_signed =
    $signed({1'b0, dc_coefficient_max});

// H.262 7.2.2 AC VLC state.
reg [15:0] ac_vlc_code;
reg [4:0]  ac_vlc_len;
wire [15:0] ac_vlc_code_next = {ac_vlc_code[14:0], current_bit};
wire [4:0]  ac_vlc_len_next  = ac_vlc_len + 5'd1;

wire       ac_vlc_match;
wire       ac_vlc_eob;
wire       ac_vlc_escape;
wire [5:0] ac_vlc_run;
wire [5:0] ac_vlc_level;

mpeg2_h262_dct_vlc dct_vlc
(
    .table_one   (intra_vlc_format),
    .vlc_code    (ac_vlc_code_next),
    .vlc_len     (ac_vlc_len_next),
    .match       (ac_vlc_match),
    .end_of_block(ac_vlc_eob),
    .escape      (ac_vlc_escape),
    .run         (ac_vlc_run),
    .level       (ac_vlc_level)
);

reg [6:0] qfs_index;
reg [5:0] ac_run_pending;
reg [5:0] ac_level_pending;

reg [5:0] escape_run_shift;
reg [2:0] escape_run_bit_count;
wire [5:0] escape_run_next = {escape_run_shift[4:0], current_bit};

reg [11:0] escape_level_shift;
reg [3:0]  escape_level_bit_count;
wire [11:0] escape_level_next = {escape_level_shift[10:0], current_bit};
wire signed [11:0] escape_level_signed = $signed(escape_level_next);

wire [7:0] normal_target_index =
    {1'b0, qfs_index} + {2'b00, ac_run_pending};
wire [7:0] escape_target_index =
    {1'b0, qfs_index} + {2'b00, escape_run_shift};

// H.262 Annex B Table B.1 macroblock_address_increment accumulator.
reg [10:0] vlc_code;
reg [3:0]  vlc_len;
reg [11:0] mba_escape_base;
wire [10:0] vlc_code_next = {vlc_code[9:0], current_bit};
wire [3:0]  vlc_len_next  = vlc_len + 4'd1;

reg        mba_match;
reg        mba_escape;
reg [5:0]  mba_value;

always @* begin
    mba_match  = 1'b0;
    mba_escape = 1'b0;
    mba_value  = 6'd0;

    case (vlc_len_next)
        4'd1: begin
            if (vlc_code_next[0] == 1'b1) begin
                mba_match = 1'b1;
                mba_value = 6'd1;
            end
        end
        4'd3: begin
            case (vlc_code_next[2:0])
                3'b011: begin mba_match = 1'b1; mba_value = 6'd2; end
                3'b010: begin mba_match = 1'b1; mba_value = 6'd3; end
                default: begin end
            endcase
        end
        4'd4: begin
            case (vlc_code_next[3:0])
                4'b0011: begin mba_match = 1'b1; mba_value = 6'd4; end
                4'b0010: begin mba_match = 1'b1; mba_value = 6'd5; end
                default: begin end
            endcase
        end
        4'd5: begin
            case (vlc_code_next[4:0])
                5'b00011: begin mba_match = 1'b1; mba_value = 6'd6; end
                5'b00010: begin mba_match = 1'b1; mba_value = 6'd7; end
                default: begin end
            endcase
        end
        4'd7: begin
            case (vlc_code_next[6:0])
                7'b0000111: begin mba_match = 1'b1; mba_value = 6'd8; end
                7'b0000110: begin mba_match = 1'b1; mba_value = 6'd9; end
                default: begin end
            endcase
        end
        4'd8: begin
            case (vlc_code_next[7:0])
                8'b00001011: begin mba_match = 1'b1; mba_value = 6'd10; end
                8'b00001010: begin mba_match = 1'b1; mba_value = 6'd11; end
                8'b00001001: begin mba_match = 1'b1; mba_value = 6'd12; end
                8'b00001000: begin mba_match = 1'b1; mba_value = 6'd13; end
                8'b00000111: begin mba_match = 1'b1; mba_value = 6'd14; end
                8'b00000110: begin mba_match = 1'b1; mba_value = 6'd15; end
                default: begin end
            endcase
        end
        4'd10: begin
            case (vlc_code_next[9:0])
                10'b0000010111: begin mba_match = 1'b1; mba_value = 6'd16; end
                10'b0000010110: begin mba_match = 1'b1; mba_value = 6'd17; end
                10'b0000010101: begin mba_match = 1'b1; mba_value = 6'd18; end
                10'b0000010100: begin mba_match = 1'b1; mba_value = 6'd19; end
                10'b0000010011: begin mba_match = 1'b1; mba_value = 6'd20; end
                10'b0000010010: begin mba_match = 1'b1; mba_value = 6'd21; end
                default: begin end
            endcase
        end
        4'd11: begin
            case (vlc_code_next[10:0])
                11'b00000100011: begin mba_match = 1'b1; mba_value = 6'd22; end
                11'b00000100010: begin mba_match = 1'b1; mba_value = 6'd23; end
                11'b00000100001: begin mba_match = 1'b1; mba_value = 6'd24; end
                11'b00000100000: begin mba_match = 1'b1; mba_value = 6'd25; end
                11'b00000011111: begin mba_match = 1'b1; mba_value = 6'd26; end
                11'b00000011110: begin mba_match = 1'b1; mba_value = 6'd27; end
                11'b00000011101: begin mba_match = 1'b1; mba_value = 6'd28; end
                11'b00000011100: begin mba_match = 1'b1; mba_value = 6'd29; end
                11'b00000011011: begin mba_match = 1'b1; mba_value = 6'd30; end
                11'b00000011010: begin mba_match = 1'b1; mba_value = 6'd31; end
                11'b00000011001: begin mba_match = 1'b1; mba_value = 6'd32; end
                11'b00000011000: begin mba_match = 1'b1; mba_value = 6'd33; end
                11'b00000001000: begin mba_escape = 1'b1; end
                default: begin end
            endcase
        end
        default: begin end
    endcase
end

// H.262 Annex B Table B.3: macroblock_type in non-scalable P-pictures.
// The current substep uses this decoder for a sequential reset-time self-check;
// the same live code/length interface will be connected to ST_MBTYPE in the next
// Phase 1T substep when P-picture slice consumption is enabled.
always @* begin
    p_mbtype_match           = 1'b0;
    p_mbtype_quant           = 1'b0;
    p_mbtype_motion_forward  = 1'b0;
    p_mbtype_motion_backward = 1'b0;
    p_mbtype_pattern         = 1'b0;
    p_mbtype_intra           = 1'b0;

    case (p_mbtype_decode_len)
        3'd1: begin
            if (p_mbtype_decode_code[0] == 1'b1) begin
                p_mbtype_match          = 1'b1;
                p_mbtype_motion_forward = 1'b1;
                p_mbtype_pattern        = 1'b1;
            end
        end

        3'd2: begin
            if (p_mbtype_decode_code[1:0] == 2'b01) begin
                p_mbtype_match   = 1'b1;
                p_mbtype_pattern = 1'b1;
            end
        end

        3'd3: begin
            if (p_mbtype_decode_code[2:0] == 3'b001) begin
                p_mbtype_match          = 1'b1;
                p_mbtype_motion_forward = 1'b1;
            end
        end

        3'd5: begin
            case (p_mbtype_decode_code[4:0])
                5'b00011: begin
                    p_mbtype_match = 1'b1;
                    p_mbtype_intra = 1'b1;
                end
                5'b00010: begin
                    p_mbtype_match          = 1'b1;
                    p_mbtype_quant          = 1'b1;
                    p_mbtype_motion_forward = 1'b1;
                    p_mbtype_pattern        = 1'b1;
                end
                5'b00001: begin
                    p_mbtype_match   = 1'b1;
                    p_mbtype_quant   = 1'b1;
                    p_mbtype_pattern = 1'b1;
                end
                default: begin end
            endcase
        end

        3'd6: begin
            if (p_mbtype_decode_code[5:0] == 6'b000001) begin
                p_mbtype_match = 1'b1;
                p_mbtype_quant = 1'b1;
                p_mbtype_intra = 1'b1;
            end
        end

        default: begin end
    endcase
end

// Sequential Table B.3 test vectors.  Keeping code and expected properties in
// a registered walk prevents this syntax primitive from becoming a dead source
// artifact before live P-picture slice wiring is introduced.
always @* begin
    p_mbtype_decode_code    = 6'd0;
    p_mbtype_decode_len     = 3'd0;
    p_mbtype_expected_flags = 5'd0;

    case (p_mbtype_selftest_index)
        3'd0: begin
            p_mbtype_decode_code    = 6'b000001; // 1
            p_mbtype_decode_len     = 3'd1;
            p_mbtype_expected_flags = 5'b01010;  // MC, Coded
        end
        3'd1: begin
            p_mbtype_decode_code    = 6'b000001; // 01
            p_mbtype_decode_len     = 3'd2;
            p_mbtype_expected_flags = 5'b00010;  // No MC, Coded
        end
        3'd2: begin
            p_mbtype_decode_code    = 6'b000001; // 001
            p_mbtype_decode_len     = 3'd3;
            p_mbtype_expected_flags = 5'b01000;  // MC, Not Coded
        end
        3'd3: begin
            p_mbtype_decode_code    = 6'b000011; // 00011
            p_mbtype_decode_len     = 3'd5;
            p_mbtype_expected_flags = 5'b00001;  // Intra
        end
        3'd4: begin
            p_mbtype_decode_code    = 6'b000010; // 00010
            p_mbtype_decode_len     = 3'd5;
            p_mbtype_expected_flags = 5'b11010;  // MC, Coded, Quant
        end
        3'd5: begin
            p_mbtype_decode_code    = 6'b000001; // 00001
            p_mbtype_decode_len     = 3'd5;
            p_mbtype_expected_flags = 5'b10010;  // No MC, Coded, Quant
        end
        3'd6: begin
            p_mbtype_decode_code    = 6'b000001; // 000001
            p_mbtype_decode_len     = 3'd6;
            p_mbtype_expected_flags = 5'b10001;  // Intra, Quant
        end
        default: begin end
    endcase
end

always @(posedge clk) begin
    if (reset) begin
        p_mbtype_selftest_index <= 3'd0;
        p_mbtype_table_verified <= 1'b0;
        p_mbtype_selftest_error <= 1'b0;
    end
    else if (!p_mbtype_table_verified && !p_mbtype_selftest_error) begin
        if (!p_mbtype_match ||
            (p_mbtype_decoded_flags != p_mbtype_expected_flags)) begin
            p_mbtype_selftest_error <= 1'b1;
        end
        else if (p_mbtype_selftest_index == 3'd6) begin
            p_mbtype_table_verified <= 1'b1;
        end
        else begin
            p_mbtype_selftest_index <= p_mbtype_selftest_index + 3'd1;
        end
    end
end

// H.262 Annex B Tables B.12 and B.13: dct_dc_size for luma/chroma.
always @* begin
    dc_size_match = 1'b0;
    dc_size_value = 4'd0;

    if (current_block_is_luma) begin
        case (dc_vlc_len_next)
            4'd2: begin
                case (dc_vlc_code_next[1:0])
                    2'b00: begin dc_size_match = 1'b1; dc_size_value = 4'd1; end
                    2'b01: begin dc_size_match = 1'b1; dc_size_value = 4'd2; end
                    default: begin end
                endcase
            end
            4'd3: begin
                case (dc_vlc_code_next[2:0])
                    3'b100: begin dc_size_match = 1'b1; dc_size_value = 4'd0; end
                    3'b101: begin dc_size_match = 1'b1; dc_size_value = 4'd3; end
                    3'b110: begin dc_size_match = 1'b1; dc_size_value = 4'd4; end
                    default: begin end
                endcase
            end
            4'd4: if (dc_vlc_code_next[3:0] == 4'b1110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd5;
            end
            4'd5: if (dc_vlc_code_next[4:0] == 5'b11110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd6;
            end
            4'd6: if (dc_vlc_code_next[5:0] == 6'b111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd7;
            end
            4'd7: if (dc_vlc_code_next[6:0] == 7'b1111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd8;
            end
            4'd8: if (dc_vlc_code_next[7:0] == 8'b11111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd9;
            end
            4'd9: begin
                case (dc_vlc_code_next[8:0])
                    9'b111111110: begin dc_size_match = 1'b1; dc_size_value = 4'd10; end
                    9'b111111111: begin dc_size_match = 1'b1; dc_size_value = 4'd11; end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
    else begin
        // Table B.13 dct_dc_size_chrominance.
        case (dc_vlc_len_next)
            4'd2: begin
                case (dc_vlc_code_next[1:0])
                    2'b00: begin dc_size_match = 1'b1; dc_size_value = 4'd0; end
                    2'b01: begin dc_size_match = 1'b1; dc_size_value = 4'd1; end
                    2'b10: begin dc_size_match = 1'b1; dc_size_value = 4'd2; end
                    default: begin end
                endcase
            end
            4'd3: if (dc_vlc_code_next[2:0] == 3'b110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd3;
            end
            4'd4: if (dc_vlc_code_next[3:0] == 4'b1110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd4;
            end
            4'd5: if (dc_vlc_code_next[4:0] == 5'b11110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd5;
            end
            4'd6: if (dc_vlc_code_next[5:0] == 6'b111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd6;
            end
            4'd7: if (dc_vlc_code_next[6:0] == 7'b1111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd7;
            end
            4'd8: if (dc_vlc_code_next[7:0] == 8'b11111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd8;
            end
            4'd9: if (dc_vlc_code_next[8:0] == 9'b111111110) begin
                dc_size_match = 1'b1; dc_size_value = 4'd9;
            end
            4'd10: begin
                case (dc_vlc_code_next[9:0])
                    10'b1111111110: begin dc_size_match = 1'b1; dc_size_value = 4'd10; end
                    10'b1111111111: begin dc_size_match = 1'b1; dc_size_value = 4'd11; end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
end

// Start a new luma block after all downstream one-block storage is free.
task automatic start_luma_block;
    begin
        qfs_block_start     <= 1'b1;
        dc_vlc_code         <= 10'd0;
        dc_vlc_len          <= 4'd0;
        dc_size             <= 4'd0;
        dc_diff_shift       <= 11'd0;
        dc_diff_bit_count   <= 4'd0;
        ac_vlc_code         <= 16'd0;
        ac_vlc_len          <= 5'd0;
        qfs_index           <= 7'd1;
        ac_run_pending      <= 6'd0;
        ac_level_pending    <= 6'd0;
        escape_run_shift    <= 6'd0;
        escape_run_bit_count <= 3'd0;
        escape_level_shift  <= 12'd0;
        escape_level_bit_count <= 4'd0;
        parse_state         <= ST_DC_LUMA;
    end
endtask

// kate - Phase 1N submits Cb/Cr through the same one-block IQ/IDCT pipeline.
task automatic start_chroma_block;
    begin
        qfs_block_start     <= 1'b1;
        dc_vlc_code         <= 10'd0;
        dc_vlc_len          <= 4'd0;
        dc_size             <= 4'd0;
        dc_diff_shift       <= 11'd0;
        dc_diff_bit_count   <= 4'd0;
        ac_vlc_code         <= 16'd0;
        ac_vlc_len          <= 5'd0;
        qfs_index           <= 7'd1;
        ac_run_pending      <= 6'd0;
        ac_level_pending    <= 6'd0;
        escape_run_shift    <= 6'd0;
        escape_run_bit_count <= 3'd0;
        escape_level_shift  <= 12'd0;
        escape_level_bit_count <= 4'd0;
        parse_state         <= ST_DC_LUMA;
    end
endtask

always @(posedge clk) begin
    if (reset) begin
        byte_window                       <= 32'd0;
        parse_active                      <= 1'b0;
        parse_state                       <= ST_QSCALE;
        bit_mod8                          <= 3'd0;
        next_start_code_shift             <= 8'd0;
        next_start_code_bit_count         <= 3'd0;
        picture_slice_index               <= 11'd0;
        field_bit_count                   <= 4'd0;
        qscale_shift                      <= 5'd0;
        slice_vertical_position_extension <= 3'd0;
        slice_picture_id_enable           <= 1'b0;
        slice_picture_id_shift            <= 6'd0;
        macroblock_qscale_shift           <= 5'd0;
        block_index                       <= 3'd0;
        macroblock_index                  <= 11'd0;
        slice_zero_count                 <= 5'd0;
        dc_predictor_y                    <= 11'd128;
        dc_predictor_cb                   <= 11'd128;
        dc_predictor_cr                   <= 11'd128;
        dc_vlc_code                       <= 10'd0;
        dc_vlc_len                        <= 4'd0;
        dc_size                           <= 4'd0;
        dc_diff_shift                     <= 11'd0;
        dc_diff_bit_count                 <= 4'd0;
        ac_vlc_code                       <= 16'd0;
        ac_vlc_len                        <= 5'd0;
        qfs_index                         <= 7'd1;
        ac_run_pending                    <= 6'd0;
        ac_level_pending                  <= 6'd0;
        escape_run_shift                  <= 6'd0;
        escape_run_bit_count              <= 3'd0;
        escape_level_shift                <= 12'd0;
        escape_level_bit_count            <= 4'd0;
        vlc_code                          <= 11'd0;
        vlc_len                           <= 4'd0;
        mba_escape_base                   <= 12'd0;

        slice_header_seen                 <= 1'b0;
        macroblock_address_seen           <= 1'b0;
        first_i_macroblock_seen           <= 1'b0;
        first_luma_dc_seen                <= 1'b0;
        first_luma_block_complete         <= 1'b0;
        first_picture_420_parsed         <= 1'b0;
        probe_error                       <= 1'b0;
        quantiser_scale_code              <= 5'd0;
        macroblock_address_increment      <= 12'd0;
        macroblock_quant                  <= 1'b0;
        macroblock_quantiser_scale_code   <= 5'd0;
        slice_vertical_position           <= 8'd0;
        first_luma_dc_size                <= 4'd0;
        first_luma_dc_differential        <= 13'sd0;
        first_luma_dc_coefficient         <= 11'd0;
        first_luma_ac_nonzero_count       <= 7'd0;
        first_luma_last_coeff_index       <= 6'd0;
        first_luma_last_ac_level          <= 12'sd0;
        slice_start                       <= 1'b0;
        luma_macroblock_start             <= 1'b0;
        qfs_block_start                   <= 1'b0;
        qfs_write_en                      <= 1'b0;
        qfs_write_index                   <= 6'd0;
        qfs_write_value                   <= 13'sd0;
        qfs_block_end                     <= 1'b0;
    end
    else begin
        qfs_block_start       <= 1'b0;
        qfs_write_en          <= 1'b0;
        qfs_block_end         <= 1'b0;
        slice_start           <= 1'b0;
        luma_macroblock_start <= 1'b0;

        if (p_mbtype_selftest_error)
            probe_error <= 1'b1;

        if (bit_consume)
            bit_mod8 <= bit_mod8 + 3'd1;

        // kate - Search the first slice start code at byte granularity.  Once
        // picture_data() parsing begins, later start codes remain in the same
        // streaming bitreader so slice boundaries do not discard partial bytes.
        // slice_start_code is consumed while parse_active is still low, so the
        // bitreader begins with the following byte at the first slice-header bit.
        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (!parse_active && !probe_error &&
                p_mbtype_table_verified &&
                !first_picture_420_parsed && slice_start_now) begin
                parse_active                      <= 1'b1;
                slice_start                       <= 1'b1;
                slice_vertical_position           <= start_code_value;
                bit_mod8                          <= 3'd0;
                next_start_code_shift             <= 8'd0;
                next_start_code_bit_count         <= 3'd0;
                picture_slice_index               <= 11'd0;
                field_bit_count                   <= 4'd0;
                qscale_shift                      <= 5'd0;
                slice_vertical_position_extension <= 3'd0;
                slice_picture_id_enable           <= 1'b0;
                slice_picture_id_shift            <= 6'd0;
                vlc_code                          <= 11'd0;
                vlc_len                           <= 4'd0;
                mba_escape_base                   <= 12'd0;
                macroblock_qscale_shift           <= 5'd0;
                block_index                       <= 3'd0;
                macroblock_index                  <= 11'd0;
                slice_zero_count                 <= 5'd0;
                dc_predictor_y                    <= dc_predictor_reset;
                dc_predictor_cb                   <= dc_predictor_reset;
                dc_predictor_cr                   <= dc_predictor_reset;
                first_luma_ac_nonzero_count       <= 7'd0;
                first_luma_last_coeff_index       <= 6'd0;
                first_luma_last_ac_level          <= 12'sd0;
                parse_state <= (vertical_size > 14'd2800) ?
                               ST_VPOS_EXT : ST_QSCALE;
            end
        end

        if (parse_active) begin
            if (!phase1_supported) begin
                parse_active <= 1'b0;
            end
            else if ((parse_state != ST_WAIT_PIPELINE) && !bit_valid) begin
                // Wait for the streaming bitreader to accept the next byte.
            end
            else begin
                case (parse_state)
                    ST_VPOS_EXT: begin
                        slice_vertical_position_extension <=
                            {slice_vertical_position_extension[1:0], current_bit};
                        if (field_bit_count == 4'd2) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_QSCALE;
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_QSCALE: begin
                        qscale_shift <= {qscale_shift[3:0], current_bit};
                        if (field_bit_count == 4'd4) begin
                            quantiser_scale_code <= {qscale_shift[3:0], current_bit};
                            field_bit_count <= 4'd0;
                            if ({qscale_shift[3:0], current_bit} == 5'd0) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else parse_state <= ST_AFTER_QSCALE;
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_AFTER_QSCALE: begin
                        if (current_bit)
                            parse_state <= ST_INTRA_SLICE;
                        else begin
                            slice_header_seen <= 1'b1;
                            vlc_code        <= 11'd0;
                            vlc_len         <= 4'd0;
                            mba_escape_base <= 12'd0;
                            parse_state     <= ST_MBA;
                        end
                    end

                    ST_INTRA_SLICE: begin
                        parse_state <= ST_PIC_ID_ENABLE;
                    end

                    ST_PIC_ID_ENABLE: begin
                        slice_picture_id_enable <= current_bit;
                        slice_picture_id_shift  <= 6'd0;
                        field_bit_count         <= 4'd0;
                        parse_state             <= ST_PIC_ID;
                    end

                    ST_PIC_ID: begin
                        slice_picture_id_shift <=
                            {slice_picture_id_shift[4:0], current_bit};
                        if (field_bit_count == 4'd5) begin
                            field_bit_count <= 4'd0;
                            if (!slice_picture_id_enable &&
                                ({slice_picture_id_shift[4:0], current_bit} != 6'd0)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else parse_state <= ST_EXTRA_FLAG;
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_EXTRA_FLAG: begin
                        if (current_bit) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_EXTRA_INFO;
                        end
                        else begin
                            slice_header_seen <= 1'b1;
                            vlc_code        <= 11'd0;
                            vlc_len         <= 4'd0;
                            mba_escape_base <= 12'd0;
                            parse_state     <= ST_MBA;
                        end
                    end

                    ST_EXTRA_INFO: begin
                        if (field_bit_count == 4'd7) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_EXTRA_FLAG;
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_MBA: begin
                        if (mba_escape) begin
                            mba_escape_base <= mba_escape_base + 12'd33;
                            vlc_code <= 11'd0;
                            vlc_len  <= 4'd0;
                        end
                        else if (mba_match) begin
                            // H.262 6.3.17: skipped macroblocks are prohibited
                            // in the non-scalable I-picture subset supported by
                            // this phase.  The first macroblock may start at any
                            // legal slice column; every later MBA must be one.
                            if ((macroblock_index != 11'd0) &&
                                ((mba_escape_base + mba_value) != 12'd1)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                macroblock_address_increment <= mba_escape_base + mba_value;
                                macroblock_address_seen <= 1'b1;
                                vlc_code <= 11'd0;
                                vlc_len  <= 4'd0;
                                slice_zero_count <= 5'd0;
                                parse_state <= ST_MBTYPE_FIRST;
                            end
                        end
                        else if (vlc_len_next >= 4'd11) begin
                            // H.262 6.2.4: after at least one macroblock, eleven
                            // leading zero bits cannot be a Table B.1 MBA.  They
                            // can, however, be the prefix of the 23-zero slice
                            // terminator tested by the syntax's nextbits().
                            if ((macroblock_index != 11'd0) &&
                                (mba_escape_base == 12'd0) &&
                                (vlc_code_next == 11'd0)) begin
                                slice_zero_count <= 5'd11;
                                parse_state      <= ST_SLICE_END_ZEROS;
                            end
                            else begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                        end
                        else begin
                            vlc_code <= vlc_code_next;
                            vlc_len  <= vlc_len_next;
                        end
                    end

                    ST_SLICE_END_ZEROS: begin
                        // We arrive here after consuming eleven zero bits.  The
                        // current bit is therefore zero number 12 through 23.
                        // A one before zero 23 cannot be a valid MBA because the
                        // first eleven bits have already ruled out every Table
                        // B.1 codeword and macroblock_escape.
                        if (current_bit) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else if (slice_zero_count == 5'd22) begin
                            // The 23-zero nextbits() condition has been consumed.
                            // Continue with H.262 next_start_code() rather than
                            // releasing the bitreader and losing alignment.
                            parse_state <= ST_START_CODE_PREFIX;
                        end
                        else begin
                            slice_zero_count <= slice_zero_count + 5'd1;
                        end
                    end

                    ST_START_CODE_PREFIX: begin
                        // H.262 5.2.3: next_start_code() consumes zero stuffing
                        // until the byte-aligned 0x000001 prefix.  Because the
                        // slice-end test already consumed 23 zeros, simply keep
                        // consuming zeros until the prefix's terminating '1'.
                        // That '1' must be bit 7 of its byte.
                        if (!current_bit) begin
                            // Continue through zero_bit / zero_byte stuffing.
                        end
                        else if (bit_mod8 != 3'd7) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            next_start_code_shift     <= 8'd0;
                            next_start_code_bit_count <= 3'd0;
                            parse_state               <= ST_START_CODE_VALUE;
                        end
                    end

                    ST_START_CODE_VALUE: begin
                        next_start_code_shift <=
                            {next_start_code_shift[6:0], current_bit};

                        if (next_start_code_bit_count == 3'd7) begin
                            next_start_code_bit_count <= 3'd0;

                            if (({next_start_code_shift[6:0], current_bit} >= 8'h01) &&
                                ({next_start_code_shift[6:0], current_bit} <= 8'hAF)) begin
                                // picture_data() continues with another slice().
                                if (picture_slice_index == 11'd2047) begin
                                    probe_error  <= 1'b1;
                                    parse_active <= 1'b0;
                                end
                                else begin
                                    picture_slice_index               <= picture_slice_index + 11'd1;
                                    slice_start                       <= 1'b1;
                                    slice_vertical_position           <=
                                        {next_start_code_shift[6:0], current_bit};
                                    slice_vertical_position_extension <= 3'd0;
                                    field_bit_count                   <= 4'd0;
                                    qscale_shift                      <= 5'd0;
                                    slice_picture_id_enable           <= 1'b0;
                                    slice_picture_id_shift            <= 6'd0;
                                    macroblock_qscale_shift           <= 5'd0;
                                    block_index                       <= 3'd0;
                                    macroblock_index                  <= 11'd0;
                                    slice_zero_count                  <= 5'd0;
                                    vlc_code                          <= 11'd0;
                                    vlc_len                           <= 4'd0;
                                    mba_escape_base                   <= 12'd0;
                                    dc_predictor_y                    <= dc_predictor_reset;
                                    dc_predictor_cb                   <= dc_predictor_reset;
                                    dc_predictor_cr                   <= dc_predictor_reset;
                                    parse_state <= (vertical_size > 14'd2800) ?
                                                   ST_VPOS_EXT : ST_QSCALE;
                                end
                            end
                            else begin
                                // H.262 6.2.3.7: picture_data() repeats slice()
                                // only while the next start code is a slice code.
                                // Any other start code therefore completes the
                                // first picture_data() region for this phase.
                                first_picture_420_parsed <= 1'b1;
                                parse_active              <= 1'b0;
                            end
                        end
                        else begin
                            next_start_code_bit_count <=
                                next_start_code_bit_count + 3'd1;
                        end
                    end

                    ST_MBTYPE_FIRST: begin
                        if (current_bit) begin
                            macroblock_quant        <= 1'b0;
                            first_i_macroblock_seen <= 1'b1;
                            luma_macroblock_start   <= 1'b1;
                            block_index              <= 3'd0;
                            start_luma_block();
                        end
                        else parse_state <= ST_MBTYPE_SECOND;
                    end

                    ST_MBTYPE_SECOND: begin
                        if (current_bit) begin
                            macroblock_quant        <= 1'b1;
                            first_i_macroblock_seen <= 1'b1;
                            luma_macroblock_start   <= 1'b1;
                            block_index              <= 3'd0;
                            macroblock_qscale_shift <= 5'd0;
                            field_bit_count         <= 4'd0;
                            parse_state             <= ST_MB_QSCALE;
                        end
                        else begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                    end

                    ST_MB_QSCALE: begin
                        macroblock_qscale_shift <=
                            {macroblock_qscale_shift[3:0], current_bit};
                        if (field_bit_count == 4'd4) begin
                            macroblock_quantiser_scale_code <=
                                {macroblock_qscale_shift[3:0], current_bit};
                            quantiser_scale_code <=
                                {macroblock_qscale_shift[3:0], current_bit};
                            field_bit_count <= 4'd0;
                            if ({macroblock_qscale_shift[3:0], current_bit} == 5'd0) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else start_luma_block();
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_DC_LUMA: begin
                        if (dc_size_match) begin
                            dc_size     <= dc_size_value;
                            dc_vlc_code <= 10'd0;
                            dc_vlc_len  <= 4'd0;
                            if (first_diagnostic_block)
                                first_luma_dc_size <= dc_size_value;

                            if (dc_size_value == 4'd0) begin
                                if (first_diagnostic_block) begin
                                    first_luma_dc_differential <= 13'sd0;
                                    first_luma_dc_coefficient  <= dc_predictor_y;
                                    first_luma_dc_seen         <= 1'b1;
                                end
                                qfs_write_en    <= 1'b1;
                                qfs_write_index <= 6'd0;
                                qfs_write_value <= {2'b00, dc_predictor_current};
                                qfs_index   <= 7'd1;
                                ac_vlc_code <= 16'd0;
                                ac_vlc_len  <= 5'd0;
                                parse_state <= ST_AC_VLC;
                            end
                            else begin
                                dc_diff_shift     <= 11'd0;
                                dc_diff_bit_count <= 4'd0;
                                parse_state       <= ST_DC_DIFF;
                            end
                        end
                        else if (dc_vlc_len_next >= (current_block_is_luma ? 4'd9 : 4'd10)) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            dc_vlc_code <= dc_vlc_code_next;
                            dc_vlc_len  <= dc_vlc_len_next;
                        end
                    end

                    ST_DC_DIFF: begin
                        dc_diff_shift <= dc_diff_bits_next;
                        if (dc_diff_bit_count == (dc_size - 1'b1)) begin
                            if ((dc_coefficient_decoded < 13'sd0) ||
                                (dc_coefficient_decoded > dc_coefficient_max_signed)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                if (block_index < 3'd4)
                                    dc_predictor_y <= dc_coefficient_decoded[10:0];
                                else if (block_index == 3'd4)
                                    dc_predictor_cb <= dc_coefficient_decoded[10:0];
                                else
                                    dc_predictor_cr <= dc_coefficient_decoded[10:0];

                                if (first_diagnostic_block) begin
                                    first_luma_dc_differential <= dc_diff_decoded;
                                    first_luma_dc_coefficient  <= dc_coefficient_decoded[10:0];
                                    first_luma_dc_seen         <= 1'b1;
                                end
                                qfs_write_en    <= 1'b1;
                                qfs_write_index <= 6'd0;
                                qfs_write_value <= dc_coefficient_decoded;
                                qfs_index   <= 7'd1;
                                ac_vlc_code <= 16'd0;
                                ac_vlc_len  <= 5'd0;
                                parse_state <= ST_AC_VLC;
                            end
                        end
                        else dc_diff_bit_count <= dc_diff_bit_count + 4'd1;
                    end

                    ST_AC_VLC: begin
                        if (ac_vlc_match) begin
                            ac_vlc_code <= 16'd0;
                            ac_vlc_len  <= 5'd0;
                            if (ac_vlc_eob) begin
                                // kate - Phase 1N sends Y, Cb and Cr EOB through
                                // the same serialized IQ/IDCT/reconstruction path.
                                qfs_block_end <= 1'b1;
                                if (first_diagnostic_block)
                                    first_luma_block_complete <= 1'b1;
                                parse_state <= ST_WAIT_PIPELINE;
                            end
                            else if (ac_vlc_escape) begin
                                escape_run_shift     <= 6'd0;
                                escape_run_bit_count <= 3'd0;
                                parse_state          <= ST_ESCAPE_RUN;
                            end
                            else begin
                                ac_run_pending   <= ac_vlc_run;
                                ac_level_pending <= ac_vlc_level;
                                parse_state      <= ST_AC_SIGN;
                            end
                        end
                        else if (ac_vlc_len_next >= 5'd16) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            ac_vlc_code <= ac_vlc_code_next;
                            ac_vlc_len  <= ac_vlc_len_next;
                        end
                    end

                    ST_AC_SIGN: begin
                        if (normal_target_index > 8'd63) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            if (first_diagnostic_block) begin
                                first_luma_ac_nonzero_count <=
                                    first_luma_ac_nonzero_count + 7'd1;
                                first_luma_last_coeff_index <= normal_target_index[5:0];
                                first_luma_last_ac_level <= current_bit ?
                                    -$signed({6'd0, ac_level_pending}) :
                                     $signed({6'd0, ac_level_pending});
                            end
                            qfs_write_en    <= 1'b1;
                            qfs_write_index <= normal_target_index[5:0];
                            qfs_write_value <= current_bit ?
                                -$signed({7'd0, ac_level_pending}) :
                                 $signed({7'd0, ac_level_pending});
                            qfs_index <= {1'b0, normal_target_index[5:0]} + 7'd1;
                            parse_state <= ST_AC_VLC;
                        end
                    end

                    ST_ESCAPE_RUN: begin
                        escape_run_shift <= escape_run_next;
                        if (escape_run_bit_count == 3'd5) begin
                            escape_run_bit_count   <= 3'd0;
                            escape_level_shift     <= 12'd0;
                            escape_level_bit_count <= 4'd0;
                            parse_state            <= ST_ESCAPE_LEVEL;
                        end
                        else escape_run_bit_count <= escape_run_bit_count + 3'd1;
                    end

                    ST_ESCAPE_LEVEL: begin
                        escape_level_shift <= escape_level_next;
                        if (escape_level_bit_count == 4'd11) begin
                            if ((escape_level_next == 12'h000) ||
                                (escape_level_next == 12'h800) ||
                                (escape_target_index > 8'd63)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                if (first_diagnostic_block) begin
                                    first_luma_ac_nonzero_count <=
                                        first_luma_ac_nonzero_count + 7'd1;
                                    first_luma_last_coeff_index <= escape_target_index[5:0];
                                    first_luma_last_ac_level <= escape_level_signed;
                                end
                                qfs_write_en    <= 1'b1;
                                qfs_write_index <= escape_target_index[5:0];
                                qfs_write_value <=
                                    {escape_level_signed[11], escape_level_signed};
                                qfs_index <= {1'b0, escape_target_index[5:0]} + 7'd1;
                                ac_vlc_code <= 16'd0;
                                ac_vlc_len  <= 5'd0;
                                parse_state <= ST_AC_VLC;
                            end
                        end
                        else escape_level_bit_count <= escape_level_bit_count + 4'd1;
                    end

                    ST_WAIT_PIPELINE: begin
                        // Do not consume another H.262 bit while the one-block
                        // IQ/IDCT/reconstruction storage is still occupied.
                        // The bitreader holds position and backpressures the
                        // outer async FIFO until pipeline_block_done arrives.
                        if (pipeline_block_done) begin
                            if (block_index < 3'd3) begin
                                block_index <= block_index + 3'd1;
                                start_luma_block();
                            end
                            else if (block_index == 3'd3) begin
                                block_index <= 3'd4;
                                start_chroma_block();
                            end
                            else if (block_index == 3'd4) begin
                                block_index <= 3'd5;
                                start_chroma_block();
                            end
                            else if (block_index == 3'd5) begin
                                // Cr reconstruction completes the six-block
                                // 4:2:0 macroblock.  Only now may syntax advance
                                // to the following macroblock/slice terminator.
                                if (macroblock_index == 11'd2047) begin
                                    probe_error  <= 1'b1;
                                    parse_active <= 1'b0;
                                end
                                else begin
                                    macroblock_index  <= macroblock_index + 11'd1;
                                    vlc_code          <= 11'd0;
                                    vlc_len           <= 4'd0;
                                    mba_escape_base   <= 12'd0;
                                    slice_zero_count  <= 5'd0;
                                    parse_state       <= ST_MBA;
                                end
                            end
                            else begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                        end
                    end

                    default: begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                endcase
            end
        end
    end
end

endmodule
