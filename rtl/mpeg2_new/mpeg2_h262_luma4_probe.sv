//============================================================================
// MiSTer Media Player - H.262 Phase 1J first-slice macroblock probe
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
//   - Annex B Tables B.1, B.2, B.12, B.13, B.14 and B.15
//
// Phase 1J capability boundary:
//   - Non-scalable progressive 4:2:0 frame-picture I video only, selected by
//     the standards-driven front end.
//   - Decode and reconstruct luminance blocks 0..3 for the first four
//     macroblocks in the first captured slice.
//   - Chroma blocks 4 and 5 are parsed completely (including their DC VLC and
//     AC coefficient syntax) so the parser can advance to the next macroblock,
//     but chroma samples are deliberately not submitted to IQ/IDCT yet.
//   - The temporary 1024-byte slice-prefix capture is a diagnostic engineering
//     bound, not an H.262 bitstream limit.  The production decoder will replace
//     this probe with a streaming bitreader.
//
// kate - Luma parsing pauses after every EOB until reconstruction reports the
// previous block complete.  This preserves the existing one-block IQ/IDCT
// storage while we prove repeated macroblock progression.
//============================================================================

module mpeg2_h262_luma4_probe
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,

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
    // Legacy signal name retained at the top-level boundary.  In Phase 1J it
    // asserts only after the four-macroblock target has been parsed through Cr.
    output reg         first_macroblock_luma_parsed,
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

    // Starts each of the first four macroblock reconstruction contexts.
    output reg         luma_macroblock_start,

    // kate - Phase 1J diagnostic-3 sticky milestones.  These observe only the
    // fourth macroblock's chroma syntax and do not alter parser decisions.
    output reg         diag_mb3_cb_dc_seen,
    output reg         diag_mb3_cb_eob_seen,
    output reg         diag_mb3_cr_dc_seen,
    output reg         diag_mb3_cr_eob_seen,

    // kate - Phase 1J diagnostic-4 sticky milestones for MB3 Y3 only.
    // These signals observe parser progress/error classification and do not
    // alter any decode decision or bitstream state transition.
    output reg         diag_mb3_y3_started,
    output reg         diag_mb3_y3_dc_size_seen,
    output reg         diag_mb3_y3_dc_recon_seen,
    output reg         diag_mb3_y3_ac_seen,
    output reg         diag_mb3_y3_eob_seen,
    output reg         diag_mb3_y3_bad_dc,
    output reg         diag_mb3_y3_bad_ac_vlc,
    output reg         diag_mb3_y3_coeff_overrun,
    output reg         diag_mb3_y3_bad_escape,
    output reg         diag_mb3_y3_capture_exhausted,

    // Coefficient handoff to inverse quantisation.
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

// kate - Phase 1J bounded capture.  1024 bytes is deliberately generous for
// the first four macroblocks of our SD test streams while remaining temporary
// diagnostic storage rather than a production bitreader.
reg          capture_active;
reg [9:0]    capture_byte_count;
reg [8191:0] slice_prefix;
reg [13:0]   captured_bit_count;

reg          parse_active;
reg [13:0]   bit_index;
wire [13:0] capture_read_index =
    captured_bit_count - 14'd1 - bit_index;
wire current_bit = ((captured_bit_count != 14'd0) &&
                    (bit_index < captured_bit_count)) ?
                   slice_prefix[capture_read_index[12:0]] : 1'b0;

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
    ST_ESCAPE_LEVEL  = 5'd17,
    ST_WAIT_PIPELINE = 5'd18;

reg [4:0] parse_state;
reg [3:0] field_bit_count;
reg [4:0] qscale_shift;
reg       slice_picture_id_enable;
reg [5:0] slice_picture_id_shift;
reg [4:0] macroblock_qscale_shift;

// H.262 6.1.3 / Figure 6-10 block order for 4:2:0 is Y0,Y1,Y2,Y3,Cb,Cr.
// block_index therefore runs 0..5 for each macroblock.  macroblock_index runs
// 0..3 for the Phase 1J horizontal strip target.
reg [2:0] block_index;
reg [1:0] macroblock_index;

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
    (macroblock_index == 2'd0) && (block_index == 3'd0);
wire        diagnostic_mb3_y3 =
    (macroblock_index == 2'd3) && (block_index == 3'd3);

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

// Chroma blocks must be consumed to reach the following macroblock, but Phase
// 1J deliberately does not submit them to the luma IQ/IDCT pipeline.
task automatic start_chroma_block;
    begin
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
        capture_active                    <= 1'b0;
        capture_byte_count                <= 10'd0;
        slice_prefix                      <= 8192'd0;
        captured_bit_count                <= 14'd0;
        parse_active                      <= 1'b0;
        bit_index                         <= 14'd0;
        parse_state                       <= ST_QSCALE;
        field_bit_count                   <= 4'd0;
        qscale_shift                      <= 5'd0;
        slice_vertical_position_extension <= 3'd0;
        slice_picture_id_enable           <= 1'b0;
        slice_picture_id_shift            <= 6'd0;
        macroblock_qscale_shift           <= 5'd0;
        block_index                       <= 3'd0;
        macroblock_index                  <= 2'd0;
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
        first_macroblock_luma_parsed      <= 1'b0;
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
        luma_macroblock_start             <= 1'b0;
        diag_mb3_cb_dc_seen               <= 1'b0;
        diag_mb3_cb_eob_seen              <= 1'b0;
        diag_mb3_cr_dc_seen               <= 1'b0;
        diag_mb3_cr_eob_seen              <= 1'b0;
        diag_mb3_y3_started               <= 1'b0;
        diag_mb3_y3_dc_size_seen          <= 1'b0;
        diag_mb3_y3_dc_recon_seen         <= 1'b0;
        diag_mb3_y3_ac_seen               <= 1'b0;
        diag_mb3_y3_eob_seen              <= 1'b0;
        diag_mb3_y3_bad_dc                <= 1'b0;
        diag_mb3_y3_bad_ac_vlc            <= 1'b0;
        diag_mb3_y3_coeff_overrun         <= 1'b0;
        diag_mb3_y3_bad_escape            <= 1'b0;
        diag_mb3_y3_capture_exhausted     <= 1'b0;
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
        luma_macroblock_start <= 1'b0;

        // Capture the first slice prefix.  If the next start code arrives before
        // the diagnostic maximum, start parsing immediately; otherwise parse at
        // the 1024-byte bound.  Phase 1J stops after macroblock 3.
        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (!capture_active && !parse_active && !probe_error &&
                !first_macroblock_luma_parsed && slice_start_now) begin
                capture_active          <= 1'b1;
                capture_byte_count      <= 10'd0;
                slice_prefix            <= 8192'd0;
                captured_bit_count      <= 14'd0;
                slice_vertical_position <= start_code_value;
            end
            else if (capture_active) begin
                slice_prefix <= {slice_prefix[8183:0], stream_data};

                if (((start_code_now) && (capture_byte_count >= 10'd4)) ||
                    (capture_byte_count == 10'd1023)) begin
                    capture_active     <= 1'b0;
                    captured_bit_count <= ({4'd0, capture_byte_count} + 14'd1) << 3;
                    parse_active       <= 1'b1;
                    bit_index          <= 14'd0;
                    field_bit_count    <= 4'd0;
                    qscale_shift       <= 5'd0;
                    slice_picture_id_enable <= 1'b0;
                    slice_picture_id_shift  <= 6'd0;
                    vlc_code           <= 11'd0;
                    vlc_len            <= 4'd0;
                    mba_escape_base     <= 12'd0;
                    macroblock_qscale_shift <= 5'd0;
                    block_index        <= 3'd0;
                    macroblock_index     <= 2'd0;
                    dc_predictor_y       <= dc_predictor_reset;
                    dc_predictor_cb      <= dc_predictor_reset;
                    dc_predictor_cr      <= dc_predictor_reset;
                    first_luma_ac_nonzero_count <= 7'd0;
                    first_luma_last_coeff_index <= 6'd0;
                    first_luma_last_ac_level <= 12'sd0;
                    parse_state <= (vertical_size > 14'd2800) ?
                                   ST_VPOS_EXT : ST_QSCALE;
                end
                else begin
                    capture_byte_count <= capture_byte_count + 10'd1;
                end
            end
        end

        if (parse_active) begin
            if (!phase1_supported) begin
                parse_active <= 1'b0;
            end
            else if (bit_index >= captured_bit_count) begin
                // kate - Diagnostic only: distinguish temporary capture-bound
                // exhaustion from a malformed VLC while MB3 Y3 is active.
                if (diagnostic_mb3_y3)
                    diag_mb3_y3_capture_exhausted <= 1'b1;
                probe_error  <= 1'b1;
                parse_active <= 1'b0;
            end
            else begin
                case (parse_state)
                    ST_VPOS_EXT: begin
                        slice_vertical_position_extension <=
                            {slice_vertical_position_extension[1:0], current_bit};
                        bit_index <= bit_index + 14'd1;
                        if (field_bit_count == 4'd2) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_QSCALE;
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_QSCALE: begin
                        qscale_shift <= {qscale_shift[3:0], current_bit};
                        bit_index    <= bit_index + 14'd1;
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
                        bit_index <= bit_index + 14'd1;
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
                        bit_index   <= bit_index + 14'd1;
                        parse_state <= ST_PIC_ID_ENABLE;
                    end

                    ST_PIC_ID_ENABLE: begin
                        slice_picture_id_enable <= current_bit;
                        slice_picture_id_shift  <= 6'd0;
                        field_bit_count         <= 4'd0;
                        bit_index               <= bit_index + 14'd1;
                        parse_state             <= ST_PIC_ID;
                    end

                    ST_PIC_ID: begin
                        slice_picture_id_shift <=
                            {slice_picture_id_shift[4:0], current_bit};
                        bit_index <= bit_index + 14'd1;
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
                        bit_index <= bit_index + 14'd1;
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
                        bit_index <= bit_index + 14'd1;
                        if (field_bit_count == 4'd7) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_EXTRA_FLAG;
                        end
                        else field_bit_count <= field_bit_count + 4'd1;
                    end

                    ST_MBA: begin
                        bit_index <= bit_index + 14'd1;
                        if (mba_escape) begin
                            mba_escape_base <= mba_escape_base + 12'd33;
                            vlc_code <= 11'd0;
                            vlc_len  <= 4'd0;
                        end
                        else if (mba_match) begin
                            // Phase 1J deliberately proves four consecutive
                            // macroblocks.  The first macroblock may begin at
                            // any legal slice column; the next three must have
                            // macroblock_address_increment == 1.
                            if ((macroblock_index != 2'd0) &&
                                ((mba_escape_base + mba_value) != 12'd1)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                macroblock_address_increment <= mba_escape_base + mba_value;
                                macroblock_address_seen <= 1'b1;
                                vlc_code <= 11'd0;
                                vlc_len  <= 4'd0;
                                parse_state <= ST_MBTYPE_FIRST;
                            end
                        end
                        else if (vlc_len_next >= 4'd11) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            vlc_code <= vlc_code_next;
                            vlc_len  <= vlc_len_next;
                        end
                    end

                    ST_MBTYPE_FIRST: begin
                        bit_index <= bit_index + 14'd1;
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
                        bit_index <= bit_index + 14'd1;
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
                        bit_index <= bit_index + 14'd1;
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
                        bit_index <= bit_index + 14'd1;
                        if (dc_size_match) begin
                            if (diagnostic_mb3_y3)
                                diag_mb3_y3_dc_size_seen <= 1'b1;
                            dc_size     <= dc_size_value;
                            dc_vlc_code <= 10'd0;
                            dc_vlc_len  <= 4'd0;
                            if (first_diagnostic_block)
                                first_luma_dc_size <= dc_size_value;

                            if (dc_size_value == 4'd0) begin
                                if (diagnostic_mb3_y3)
                                    diag_mb3_y3_dc_recon_seen <= 1'b1;
                                // kate - Diagnostic only: a zero-size DC VLC is
                                // itself the complete DC decode for this block.
                                if (macroblock_index == 2'd3) begin
                                    if (block_index == 3'd4)
                                        diag_mb3_cb_dc_seen <= 1'b1;
                                    else if (block_index == 3'd5)
                                        diag_mb3_cr_dc_seen <= 1'b1;
                                end
                                if (first_diagnostic_block) begin
                                    first_luma_dc_differential <= 13'sd0;
                                    first_luma_dc_coefficient  <= dc_predictor_y;
                                    first_luma_dc_seen         <= 1'b1;
                                end
                                if (current_block_is_luma) begin
                                    qfs_write_en    <= 1'b1;
                                    qfs_write_index <= 6'd0;
                                    qfs_write_value <= {2'b00, dc_predictor_y};
                                end
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
                            if (diagnostic_mb3_y3)
                                diag_mb3_y3_bad_dc <= 1'b1;
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
                        bit_index     <= bit_index + 14'd1;
                        if (dc_diff_bit_count == (dc_size - 1'b1)) begin
                            if ((dc_coefficient_decoded < 13'sd0) ||
                                (dc_coefficient_decoded > dc_coefficient_max_signed)) begin
                                if (diagnostic_mb3_y3)
                                    diag_mb3_y3_bad_dc <= 1'b1;
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                if (diagnostic_mb3_y3)
                                    diag_mb3_y3_dc_recon_seen <= 1'b1;
                                // kate - Diagnostic only: all nonzero DC
                                // differential bits for this chroma block have
                                // now been accepted and reconstructed.
                                if (macroblock_index == 2'd3) begin
                                    if (block_index == 3'd4)
                                        diag_mb3_cb_dc_seen <= 1'b1;
                                    else if (block_index == 3'd5)
                                        diag_mb3_cr_dc_seen <= 1'b1;
                                end

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
                                if (current_block_is_luma) begin
                                    qfs_write_en    <= 1'b1;
                                    qfs_write_index <= 6'd0;
                                    qfs_write_value <= dc_coefficient_decoded;
                                end
                                qfs_index   <= 7'd1;
                                ac_vlc_code <= 16'd0;
                                ac_vlc_len  <= 5'd0;
                                parse_state <= ST_AC_VLC;
                            end
                        end
                        else dc_diff_bit_count <= dc_diff_bit_count + 4'd1;
                    end

                    ST_AC_VLC: begin
                        bit_index <= bit_index + 14'd1;
                        if (ac_vlc_match) begin
                            ac_vlc_code <= 16'd0;
                            ac_vlc_len  <= 5'd0;
                            if (ac_vlc_eob) begin
                                if (diagnostic_mb3_y3)
                                    diag_mb3_y3_eob_seen <= 1'b1;
                                if (current_block_is_luma) begin
                                    qfs_block_end <= 1'b1;
                                    if (first_diagnostic_block)
                                        first_luma_block_complete <= 1'b1;
                                    // Wait for reconstruction of every Y block,
                                    // including block 3, before parsing chroma.
                                    parse_state <= ST_WAIT_PIPELINE;
                                end
                                else if (block_index == 3'd4) begin
                                    // kate - Diagnostic only: Cb syntax reached
                                    // a legal end_of_block before moving to Cr.
                                    if (macroblock_index == 2'd3)
                                        diag_mb3_cb_eob_seen <= 1'b1;
                                    block_index <= 3'd5;
                                    start_chroma_block();
                                end
                                else begin
                                    // Cr completes the macroblock syntax.  Four
                                    // macroblocks are the Phase 1J target.
                                    if (macroblock_index == 2'd3) begin
                                        // kate - Diagnostic only: a legal Cr EOB
                                        // was accepted immediately before the
                                        // normal Phase-1J completion flag.
                                        diag_mb3_cr_eob_seen <= 1'b1;
                                        first_macroblock_luma_parsed <= 1'b1;
                                        parse_active <= 1'b0;
                                    end
                                    else begin
                                        macroblock_index <= macroblock_index + 2'd1;
                                        vlc_code        <= 11'd0;
                                        vlc_len         <= 4'd0;
                                        mba_escape_base <= 12'd0;
                                        parse_state     <= ST_MBA;
                                    end
                                end
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
                            if (diagnostic_mb3_y3)
                                diag_mb3_y3_bad_ac_vlc <= 1'b1;
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            ac_vlc_code <= ac_vlc_code_next;
                            ac_vlc_len  <= ac_vlc_len_next;
                        end
                    end

                    ST_AC_SIGN: begin
                        bit_index <= bit_index + 14'd1;
                        if (normal_target_index > 8'd63) begin
                            if (diagnostic_mb3_y3)
                                diag_mb3_y3_coeff_overrun <= 1'b1;
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            if (diagnostic_mb3_y3)
                                diag_mb3_y3_ac_seen <= 1'b1;
                            if (first_diagnostic_block) begin
                                first_luma_ac_nonzero_count <=
                                    first_luma_ac_nonzero_count + 7'd1;
                                first_luma_last_coeff_index <= normal_target_index[5:0];
                                first_luma_last_ac_level <= current_bit ?
                                    -$signed({6'd0, ac_level_pending}) :
                                     $signed({6'd0, ac_level_pending});
                            end
                            if (current_block_is_luma) begin
                                qfs_write_en    <= 1'b1;
                                qfs_write_index <= normal_target_index[5:0];
                                qfs_write_value <= current_bit ?
                                    -$signed({7'd0, ac_level_pending}) :
                                     $signed({7'd0, ac_level_pending});
                            end
                            qfs_index <= {1'b0, normal_target_index[5:0]} + 7'd1;
                            parse_state <= ST_AC_VLC;
                        end
                    end

                    ST_ESCAPE_RUN: begin
                        escape_run_shift <= escape_run_next;
                        bit_index        <= bit_index + 14'd1;
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
                        bit_index          <= bit_index + 14'd1;
                        if (escape_level_bit_count == 4'd11) begin
                            if ((escape_level_next == 12'h000) ||
                                (escape_level_next == 12'h800) ||
                                (escape_target_index > 8'd63)) begin
                                if (diagnostic_mb3_y3) begin
                                    if ((escape_level_next == 12'h000) ||
                                        (escape_level_next == 12'h800))
                                        diag_mb3_y3_bad_escape <= 1'b1;
                                    if (escape_target_index > 8'd63)
                                        diag_mb3_y3_coeff_overrun <= 1'b1;
                                end
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                if (diagnostic_mb3_y3)
                                    diag_mb3_y3_ac_seen <= 1'b1;
                                if (first_diagnostic_block) begin
                                    first_luma_ac_nonzero_count <=
                                        first_luma_ac_nonzero_count + 7'd1;
                                    first_luma_last_coeff_index <= escape_target_index[5:0];
                                    first_luma_last_ac_level <= escape_level_signed;
                                end
                                if (current_block_is_luma) begin
                                    qfs_write_en    <= 1'b1;
                                    qfs_write_index <= escape_target_index[5:0];
                                    qfs_write_value <=
                                        {escape_level_signed[11], escape_level_signed};
                                end
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
                        if (pipeline_block_done) begin
                            if (block_index < 3'd3) begin
                                // kate - Diagnostic only: when MB3 Y2 completes,
                                // the next submitted block is MB3 Y3.
                                if ((macroblock_index == 2'd3) &&
                                    (block_index == 3'd2))
                                    diag_mb3_y3_started <= 1'b1;
                                block_index <= block_index + 3'd1;
                                start_luma_block();
                            end
                            else if (block_index == 3'd3) begin
                                block_index <= 3'd4;
                                start_chroma_block();
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
