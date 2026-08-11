//============================================================================
// MiSTer Media Player - new H.262 decoder Phase 1D coefficient probe
//
// This module is intentionally passive.  It observes the same elementary-
// stream bytes as the legacy MPEG2FPGA path, captures the beginning of the
// first slice, and proves that the new decoder can cross from byte-aligned
// start codes into bit-aligned slice and macroblock VLC syntax.
//
// Normative standards basis:
//   ITU-T H.262 (02/2000) / ISO/IEC 13818-2:2000
//   - 6.2.4 slice()
//   - 6.2.5 macroblock()
//   - 6.3.16 slice semantics
//   - 6.3.17 macroblock semantics
//   - Annex B, Table B.1 macroblock_address_increment
//   - Annex B, Table B.2 macroblock_type in non-scalable I-pictures
//   - 6.2.6 block()
//   - 7.2.1 DC coefficients in intra blocks / Table 7-2
//   - Annex B, Table B.12 dct_dc_size_luminance
//   - 7.2.2 other coefficients and Table 7-3 table selection
//   - Annex B, Tables B.14/B.15 DCT coefficient VLCs
//   - 7.2.2.3 / Table B.16 Escape coding
//
// Phase 1 capability boundary:
//   - Non-scalable sequence syntax only.
//   - Progressive 4:2:0 frame-picture I video is selected by the front end.
//   - Phase 1D retains the complete first-luma coefficient decode and exports
//     each non-zero QFS[] entry plus block boundaries to the inverse quantiser.
//   - The bounded capture buffer is a diagnostic implementation choice, not an
//     H.262 syntax restriction; the production decoder will use a streaming bitreader.
//
// H.262 requires decoders to ignore extra_information_slice when encountered;
// this probe therefore skips such bytes instead of assigning them meaning.
//============================================================================

module mpeg2_h262_slice_probe
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,

    input  wire        phase1_supported,
    input  wire [13:0] vertical_size,
    input  wire [1:0]  intra_dc_precision,
    input  wire        intra_vlc_format,

    output reg         slice_header_seen,
    output reg         macroblock_address_seen,
    output reg         first_i_macroblock_seen,
    output reg         first_luma_dc_seen,
    output reg         first_luma_block_complete,
    output reg         probe_error,

    output reg  [4:0]  quantiser_scale_code,
    output reg  [11:0] macroblock_address_increment,
    output reg         macroblock_quant,
    output reg  [4:0]  macroblock_quantiser_scale_code,
    output reg  [7:0]  slice_vertical_position,
    // kate - H.262 6.3.16 extension used when vertical_size > 2800.
    output reg  [2:0]  slice_vertical_position_extension,
    output reg  [3:0]  first_luma_dc_size,
    output reg signed [12:0] first_luma_dc_differential,
    output reg  [10:0] first_luma_dc_coefficient,
    output reg  [6:0]  first_luma_ac_nonzero_count,
    output reg  [5:0]  first_luma_last_coeff_index,
    output reg signed [11:0] first_luma_last_ac_level,

    // kate - Phase 1D coefficient handoff.  Run-created and EOB-created zero
    // entries are implicit; qfs_block_start clears the destination array.
    output reg         qfs_block_start,
    output reg         qfs_write_en,
    output reg  [5:0]  qfs_write_index,
    output reg signed [12:0] qfs_write_value,
    output reg         qfs_block_end
);

// H.262 Table 6-1: slice_start_code values are 0x01 through 0xAF.
wire [31:0] byte_window_next;
wire        start_code_now;
wire [7:0]  start_code_value;
wire        slice_start_now;

reg [31:0] byte_window;

assign byte_window_next = {byte_window[23:0], stream_data};
assign start_code_now   = (byte_window_next[31:8] == 24'h000001);
assign start_code_value = byte_window_next[7:0];
assign slice_start_now  = start_code_now &&
                          (start_code_value >= 8'h01) &&
                          (start_code_value <= 8'hAF);

// kate - Phase 1C expands the passive capture to 64 bytes so ordinary first
// blocks can exercise the complete AC VLC path.  This remains only a probe;
// H.262 does not impose this 64-byte block limit.
reg         capture_active;
reg [5:0]   capture_byte_count;
reg [511:0] slice_prefix;

reg         parse_active;
reg [9:0]   bit_index;

wire current_bit = (bit_index < 10'd512) ?
                   slice_prefix[10'd511 - bit_index] : 1'b0;

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
    ST_ESCAPE_LEVEL  = 5'd17;

reg [4:0] parse_state;
reg [3:0] field_bit_count;
reg [4:0] qscale_shift;
reg       slice_picture_id_enable;
reg [5:0] slice_picture_id_shift;

// Macroblock-level quantiser_scale_code is present only for the Table B.2
// "Intra, Quant" macroblock type.
reg [4:0] macroblock_qscale_shift;

// H.262 Table B.12 decoder for the first luminance block.  As with Table B.1,
// the candidate code is accumulated MSB-first and right-aligned.
reg [8:0] dc_vlc_code;
reg [3:0] dc_vlc_len;
reg [3:0] dc_size;
reg [10:0] dc_diff_shift;
reg [3:0] dc_diff_bit_count;

wire [8:0] dc_vlc_code_next = {dc_vlc_code[7:0], current_bit};
wire [3:0] dc_vlc_len_next  = dc_vlc_len + 1'b1;
wire [10:0] dc_diff_bits_next = {dc_diff_shift[9:0], current_bit};

reg       dc_size_match;
reg [3:0] dc_size_value;

// Table 7-2 predictor reset value.  For the first block in a slice this is the
// active Y predictor because H.262 resets all three DC predictors at slice start.
wire [10:0] dc_predictor_reset = 11'd128 << intra_dc_precision;
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
    $signed({2'b00, dc_predictor_reset}) + dc_diff_decoded;
wire [11:0] dc_coefficient_max =
    (12'd256 << intra_dc_precision) - 1'b1;
wire signed [12:0] dc_coefficient_max_signed =
    $signed({1'b0, dc_coefficient_max});

// H.262 7.2.2: after intra DC, n starts at one.  Every normal/escape
// coefficient advances n by run zeroes plus one signed coefficient.  EOB
// completes the block and implies zero for all remaining QFS entries.
reg [15:0] ac_vlc_code;
reg [4:0]  ac_vlc_len;
wire [15:0] ac_vlc_code_next = {ac_vlc_code[14:0], current_bit};
wire [4:0]  ac_vlc_len_next  = ac_vlc_len + 1'b1;

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

// Table B.1 VLC accumulator.  Codes are accumulated MSB-first and remain
// right-aligned in vlc_code.  macroblock_escape contributes 33 and causes
// another Table B.1 codeword to follow.
reg [10:0] vlc_code;
reg [3:0]  vlc_len;
reg [11:0] mba_escape_base;

wire [10:0] vlc_code_next = {vlc_code[9:0], current_bit};
wire [3:0]  vlc_len_next  = vlc_len + 1'b1;

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
                // H.262 6.3.17 and Table B.1.
                11'b00000001000: begin mba_escape = 1'b1; end
                default: begin end
            endcase
        end

        default: begin end
    endcase
end

// H.262 Annex B Table B.12: dct_dc_size_luminance.
always @* begin
    dc_size_match = 1'b0;
    dc_size_value = 4'd0;

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
        4'd4: begin
            if (dc_vlc_code_next[3:0] == 4'b1110) begin
                dc_size_match = 1'b1;
                dc_size_value = 4'd5;
            end
        end
        4'd5: begin
            if (dc_vlc_code_next[4:0] == 5'b11110) begin
                dc_size_match = 1'b1;
                dc_size_value = 4'd6;
            end
        end
        4'd6: begin
            if (dc_vlc_code_next[5:0] == 6'b111110) begin
                dc_size_match = 1'b1;
                dc_size_value = 4'd7;
            end
        end
        4'd7: begin
            if (dc_vlc_code_next[6:0] == 7'b1111110) begin
                dc_size_match = 1'b1;
                dc_size_value = 4'd8;
            end
        end
        4'd8: begin
            if (dc_vlc_code_next[7:0] == 8'b11111110) begin
                dc_size_match = 1'b1;
                dc_size_value = 4'd9;
            end
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

always @(posedge clk) begin
    if (reset) begin
        byte_window                       <= 32'd0;
        capture_active                    <= 1'b0;
        capture_byte_count                <= 6'd0;
        slice_prefix                      <= 512'd0;
        parse_active                      <= 1'b0;
        bit_index                         <= 10'd0;
        parse_state                       <= ST_QSCALE;
        field_bit_count                   <= 4'd0;
        qscale_shift                      <= 5'd0;
        slice_vertical_position_extension <= 3'd0;
        slice_picture_id_enable           <= 1'b0;
        slice_picture_id_shift            <= 6'd0;
        macroblock_qscale_shift           <= 5'd0;
        dc_vlc_code                       <= 9'd0;
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
        qfs_block_start                    <= 1'b0;
        qfs_write_en                       <= 1'b0;
        qfs_write_index                    <= 6'd0;
        qfs_write_value                    <= 13'sd0;
        qfs_block_end                      <= 1'b0;
    end
    else begin
        // Phase 1D handoff signals are one-cycle pulses.
        qfs_block_start <= 1'b0;
        qfs_write_en    <= 1'b0;
        qfs_block_end   <= 1'b0;
        // Byte-aligned capture begins immediately after a slice start code.
        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (!capture_active && !parse_active && !probe_error &&
                !first_luma_block_complete && slice_start_now) begin
                capture_active          <= 1'b1;
                capture_byte_count      <= 6'd0;
                slice_prefix            <= 512'd0;
                slice_vertical_position <= start_code_value;
            end
            else if (capture_active) begin
                slice_prefix <= {slice_prefix[503:0], stream_data};

                if (capture_byte_count == 6'd63) begin
                    capture_active   <= 1'b0;
                    capture_byte_count <= 6'd0;
                    parse_active     <= 1'b1;
                    bit_index        <= 10'd0;
                    field_bit_count  <= 4'd0;
                    qscale_shift     <= 5'd0;
                    slice_picture_id_enable <= 1'b0;
                    slice_picture_id_shift  <= 6'd0;
                    vlc_code         <= 11'd0;
                    vlc_len          <= 4'd0;
                    mba_escape_base  <= 12'd0;
                    macroblock_qscale_shift <= 5'd0;
                    dc_vlc_code      <= 9'd0;
                    dc_vlc_len       <= 4'd0;
                    dc_size          <= 4'd0;
                    dc_diff_shift    <= 11'd0;
                    dc_diff_bit_count<= 4'd0;
                    ac_vlc_code      <= 16'd0;
                    ac_vlc_len       <= 5'd0;
                    qfs_index        <= 7'd1;
                    ac_run_pending   <= 6'd0;
                    ac_level_pending <= 6'd0;
                    escape_run_shift <= 6'd0;
                    escape_run_bit_count <= 3'd0;
                    escape_level_shift <= 12'd0;
                    escape_level_bit_count <= 4'd0;
                    first_luma_ac_nonzero_count <= 7'd0;
                    first_luma_last_coeff_index <= 6'd0;
                    first_luma_last_ac_level <= 12'sd0;
                    parse_state      <= (vertical_size > 14'd2800) ?
                                        ST_VPOS_EXT : ST_QSCALE;
                end
                else begin
                    capture_byte_count <= capture_byte_count + 1'b1;
                end
            end
        end

        if (parse_active) begin
            // The front end separates syntax validity from Phase 1 capability.
            // If this is not the selected non-scalable progressive I subset,
            // simply abandon the probe rather than declaring valid H.262 bad.
            if (!phase1_supported) begin
                parse_active <= 1'b0;
            end
            else if (bit_index >= 10'd512) begin
                probe_error  <= 1'b1;
                parse_active <= 1'b0;
            end
            else begin
                case (parse_state)
                    ST_VPOS_EXT: begin
                        slice_vertical_position_extension <=
                            {slice_vertical_position_extension[1:0], current_bit};
                        bit_index <= bit_index + 1'b1;

                        if (field_bit_count == 4'd2) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_QSCALE;
                        end
                        else begin
                            field_bit_count <= field_bit_count + 1'b1;
                        end
                    end

                    ST_QSCALE: begin
                        qscale_shift <= {qscale_shift[3:0], current_bit};
                        bit_index    <= bit_index + 1'b1;

                        if (field_bit_count == 4'd4) begin
                            quantiser_scale_code <= {qscale_shift[3:0], current_bit};
                            field_bit_count      <= 4'd0;

                            // H.262 6.3.16: quantiser_scale_code is 1..31;
                            // zero is forbidden.
                            if ({qscale_shift[3:0], current_bit} == 5'd0) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                parse_state <= ST_AFTER_QSCALE;
                            end
                        end
                        else begin
                            field_bit_count <= field_bit_count + 1'b1;
                        end
                    end

                    ST_AFTER_QSCALE: begin
                        bit_index <= bit_index + 1'b1;

                        if (current_bit) begin
                            // nextbits() == 1 means slice_extension_flag is present;
                            // consume that flag here, then parse its fields.
                            parse_state <= ST_INTRA_SLICE;
                        end
                        else begin
                            // With no slice extension, this zero is the final
                            // extra_bit_slice and macroblock() follows.
                            slice_header_seen <= 1'b1;
                            vlc_code           <= 11'd0;
                            vlc_len            <= 4'd0;
                            mba_escape_base    <= 12'd0;
                            parse_state        <= ST_MBA;
                        end
                    end

                    ST_INTRA_SLICE: begin
                        // H.262 (02/2000) 6.2.4 carries intra_slice after the
                        // slice_extension_flag.  It is not needed by the
                        // decoding process, but it must still be consumed.
                        bit_index   <= bit_index + 1'b1;
                        parse_state <= ST_PIC_ID_ENABLE;
                    end

                    ST_PIC_ID_ENABLE: begin
                        // H.262 (02/2000) 6.2.4/6.3.16: the enable flag is
                        // followed by the six-bit slice_picture_id.
                        slice_picture_id_enable <= current_bit;
                        slice_picture_id_shift  <= 6'd0;
                        field_bit_count          <= 4'd0;
                        bit_index                <= bit_index + 1'b1;
                        parse_state              <= ST_PIC_ID;
                    end

                    ST_PIC_ID: begin
                        slice_picture_id_shift <=
                            {slice_picture_id_shift[4:0], current_bit};
                        bit_index <= bit_index + 1'b1;

                        if (field_bit_count == 4'd5) begin
                            field_bit_count <= 4'd0;

                            // 6.3.16 requires slice_picture_id == 0 when its
                            // enable flag is zero.
                            if (!slice_picture_id_enable &&
                                ({slice_picture_id_shift[4:0], current_bit} != 6'd0)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                parse_state <= ST_EXTRA_FLAG;
                            end
                        end
                        else begin
                            field_bit_count <= field_bit_count + 1'b1;
                        end
                    end

                    ST_EXTRA_FLAG: begin
                        bit_index <= bit_index + 1'b1;

                        if (current_bit) begin
                            // extra_information_slice is reserved, but H.262
                            // requires a decoder that encounters it to discard
                            // it.  Skip its eight payload bits, then inspect the
                            // following extra_bit_slice.
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_EXTRA_INFO;
                        end
                        else begin
                            slice_header_seen <= 1'b1;
                            vlc_code           <= 11'd0;
                            vlc_len            <= 4'd0;
                            mba_escape_base    <= 12'd0;
                            parse_state        <= ST_MBA;
                        end
                    end

                    ST_EXTRA_INFO: begin
                        bit_index <= bit_index + 1'b1;

                        if (field_bit_count == 4'd7) begin
                            field_bit_count <= 4'd0;
                            parse_state     <= ST_EXTRA_FLAG;
                        end
                        else begin
                            field_bit_count <= field_bit_count + 1'b1;
                        end
                    end

                    ST_MBA: begin
                        bit_index <= bit_index + 1'b1;

                        if (mba_escape) begin
                            // macroblock_escape adds 33, then another escape or
                            // a normal Table B.1 codeword follows.
                            mba_escape_base <= mba_escape_base + 12'd33;
                            vlc_code        <= 11'd0;
                            vlc_len         <= 4'd0;
                        end
                        else if (mba_match) begin
                            macroblock_address_increment <=
                                mba_escape_base + mba_value;
                            macroblock_address_seen <= 1'b1;
                            vlc_code               <= 11'd0;
                            vlc_len                <= 4'd0;
                            parse_state            <= ST_MBTYPE_FIRST;
                        end
                        else if (vlc_len_next >= 4'd11) begin
                            // No Table B.1 code matched by the maximum length.
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            vlc_code <= vlc_code_next;
                            vlc_len  <= vlc_len_next;
                        end
                    end

                    ST_MBTYPE_FIRST: begin
                        bit_index <= bit_index + 1'b1;

                        // H.262 Table B.2, non-scalable I-picture:
                        //   1  = Intra
                        //   01 = Intra, Quant
                        if (current_bit) begin
                            macroblock_quant        <= 1'b0;
                            first_i_macroblock_seen <= 1'b1;
                            qfs_block_start          <= 1'b1;
                            dc_vlc_code             <= 9'd0;
                            dc_vlc_len              <= 4'd0;
                            parse_state             <= ST_DC_LUMA;
                        end
                        else begin
                            parse_state <= ST_MBTYPE_SECOND;
                        end
                    end

                    ST_MBTYPE_SECOND: begin
                        bit_index <= bit_index + 1'b1;

                        if (current_bit) begin
                            macroblock_quant          <= 1'b1;
                            first_i_macroblock_seen   <= 1'b1;
                            qfs_block_start            <= 1'b1;
                            macroblock_qscale_shift   <= 5'd0;
                            field_bit_count           <= 4'd0;
                            parse_state               <= ST_MB_QSCALE;
                        end
                        else begin
                            // No non-scalable I-picture Table B.2 code begins 00.
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                    end

                    ST_MB_QSCALE: begin
                        macroblock_qscale_shift <=
                            {macroblock_qscale_shift[3:0], current_bit};
                        bit_index <= bit_index + 1'b1;

                        if (field_bit_count == 4'd4) begin
                            macroblock_quantiser_scale_code <=
                                {macroblock_qscale_shift[3:0], current_bit};
                            field_bit_count <= 4'd0;

                            // H.262 6.3.16/6.3.17: quantiser_scale_code zero
                            // is forbidden regardless of whether it is carried
                            // by slice() or macroblock().
                            if ({macroblock_qscale_shift[3:0], current_bit} == 5'd0) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                dc_vlc_code <= 9'd0;
                                dc_vlc_len  <= 4'd0;
                                parse_state <= ST_DC_LUMA;
                            end
                        end
                        else begin
                            field_bit_count <= field_bit_count + 1'b1;
                        end
                    end

                    ST_DC_LUMA: begin
                        bit_index <= bit_index + 1'b1;

                        if (dc_size_match) begin
                            first_luma_dc_size <= dc_size_value;
                            dc_size            <= dc_size_value;
                            dc_vlc_code        <= 9'd0;
                            dc_vlc_len         <= 4'd0;

                            if (dc_size_value == 4'd0) begin
                                // H.262 7.2.1: size zero means differential zero.
                                // At slice start the Y predictor is the Table 7-2
                                // reset value, so QFS[0] is that reset value.
                                first_luma_dc_differential <= 13'sd0;
                                first_luma_dc_coefficient  <= dc_predictor_reset;
                                first_luma_dc_seen         <= 1'b1;
                                qfs_write_en               <= 1'b1;
                                qfs_write_index            <= 6'd0;
                                qfs_write_value            <= {2'b00, dc_predictor_reset};
                                // H.262 7.2.2.4: n starts at one for intra blocks.
                                qfs_index                   <= 7'd1;
                                ac_vlc_code                 <= 16'd0;
                                ac_vlc_len                  <= 5'd0;
                                parse_state                 <= ST_AC_VLC;
                            end
                            else begin
                                dc_diff_shift     <= 11'd0;
                                dc_diff_bit_count <= 4'd0;
                                parse_state       <= ST_DC_DIFF;
                            end
                        end
                        else if (dc_vlc_len_next >= 4'd9) begin
                            // Table B.12 has no code longer than nine bits.
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
                        bit_index     <= bit_index + 1'b1;

                        if (dc_diff_bit_count == (dc_size - 1'b1)) begin
                            // H.262 7.2.1 differential reconstruction followed
                            // by the Table 7-2 predictor.  A conforming stream
                            // constrains QFS[0] to 8+intra_dc_precision bits.
                            if ((dc_coefficient_decoded < 13'sd0) ||
                                (dc_coefficient_decoded > dc_coefficient_max_signed)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                first_luma_dc_differential <= dc_diff_decoded;
                                first_luma_dc_coefficient  <= dc_coefficient_decoded[10:0];
                                first_luma_dc_seen         <= 1'b1;
                                qfs_write_en               <= 1'b1;
                                qfs_write_index            <= 6'd0;
                                qfs_write_value            <= dc_coefficient_decoded;
                                qfs_index                   <= 7'd1;
                                ac_vlc_code                 <= 16'd0;
                                ac_vlc_len                  <= 5'd0;
                                parse_state                 <= ST_AC_VLC;
                            end
                        end
                        else begin
                            dc_diff_bit_count <= dc_diff_bit_count + 1'b1;
                        end
                    end

                    ST_AC_VLC: begin
                        bit_index <= bit_index + 1'b1;

                        if (ac_vlc_match) begin
                            ac_vlc_code <= 16'd0;
                            ac_vlc_len  <= 5'd0;

                            if (ac_vlc_eob) begin
                                // H.262 7.2.2.4: EOB makes all remaining
                                // QFS[n] values zero.  DC already exists, so
                                // Table B.14 Note 2 is satisfied.
                                first_luma_block_complete <= 1'b1;
                                qfs_block_end              <= 1'b1;
                                parse_active               <= 1'b0;
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
                            // Tables B.14/B.15 have no VLC longer than 16 bits.
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            ac_vlc_code <= ac_vlc_code_next;
                            ac_vlc_len  <= ac_vlc_len_next;
                        end
                    end

                    ST_AC_SIGN: begin
                        // H.262 7.2.2: the bit following a normal run/level VLC
                        // is sign, zero for positive and one for negative.
                        bit_index <= bit_index + 1'b1;

                        if (normal_target_index > 8'd63) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            first_luma_ac_nonzero_count <=
                                first_luma_ac_nonzero_count + 1'b1;
                            first_luma_last_coeff_index <= normal_target_index[5:0];
                            first_luma_last_ac_level <= current_bit ?
                                -$signed({6'd0, ac_level_pending}) :
                                 $signed({6'd0, ac_level_pending});
                            qfs_write_en    <= 1'b1;
                            qfs_write_index <= normal_target_index[5:0];
                            qfs_write_value <= current_bit ?
                                -$signed({7'd0, ac_level_pending}) :
                                 $signed({7'd0, ac_level_pending});
                            qfs_index <= normal_target_index + 1'b1;
                            parse_state <= ST_AC_VLC;
                        end
                    end

                    ST_ESCAPE_RUN: begin
                        // H.262 7.2.2.3 / Table B.16: six fixed run bits.
                        escape_run_shift <= escape_run_next;
                        bit_index        <= bit_index + 1'b1;

                        if (escape_run_bit_count == 3'd5) begin
                            escape_run_bit_count   <= 3'd0;
                            escape_level_shift     <= 12'd0;
                            escape_level_bit_count <= 4'd0;
                            parse_state            <= ST_ESCAPE_LEVEL;
                        end
                        else begin
                            escape_run_bit_count <= escape_run_bit_count + 1'b1;
                        end
                    end

                    ST_ESCAPE_LEVEL: begin
                        // H.262 7.2.2.3 / Table B.16: twelve-bit two's-
                        // complement signed_level.  Zero is forbidden and
                        // 0x800 (-2048) is reserved; valid range is
                        // -2047..-1 and +1..+2047.
                        escape_level_shift <= escape_level_next;
                        bit_index          <= bit_index + 1'b1;

                        if (escape_level_bit_count == 4'd11) begin
                            if ((escape_level_next == 12'h000) ||
                                (escape_level_next == 12'h800) ||
                                (escape_target_index > 8'd63)) begin
                                probe_error  <= 1'b1;
                                parse_active <= 1'b0;
                            end
                            else begin
                                first_luma_ac_nonzero_count <=
                                    first_luma_ac_nonzero_count + 1'b1;
                                first_luma_last_coeff_index <=
                                    escape_target_index[5:0];
                                first_luma_last_ac_level <=
                                    escape_level_signed;
                                qfs_write_en    <= 1'b1;
                                qfs_write_index <= escape_target_index[5:0];
                                qfs_write_value <=
                                    {escape_level_signed[11], escape_level_signed};
                                qfs_index <= escape_target_index + 1'b1;
                                ac_vlc_code <= 16'd0;
                                ac_vlc_len  <= 5'd0;
                                parse_state <= ST_AC_VLC;
                            end
                        end
                        else begin
                            escape_level_bit_count <=
                                escape_level_bit_count + 1'b1;
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
