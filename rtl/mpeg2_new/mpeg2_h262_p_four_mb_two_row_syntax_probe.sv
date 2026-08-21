//============================================================================
// MiSTer Media Player - controlled multi-macroblock/multi-row H.262 P observer
//
// Standards authority: core-reference.md, source_id H262.
// Relevant established records:
//   H262-007 macroblock width = (horizontal_size + 15) / 16
//   H262-008 slice vertical position identifies the macroblock row
//   H262-009 slice-local macroblock address progression
//   H262-011 P-picture motion-forward-only macroblock_type code 001
//   H262-012 motion_code 0 code 1
//   H262-014 complete Table B.1 macroblock_address_increment VLCs/escape
//   H262-015 skipped P-frame macroblocks use frame-based zero-vector prediction
//
// kate - Phase 1U-j replaces the repeated MBA=1 byte-pattern observer with a
// sequential standards-derived row parser. Each complete slice row is buffered
// only until its following start code, then compressed input is held while the
// parser consumes the row one bit per clock. This deliberately avoids placing
// a long variable-length-code traversal on the 54 MHz decoder input path.
//
// The controlled semantic boundary remains intentionally narrower than a full
// P parser: every transmitted macroblock must be Table B.3 motion-forward-only
// (001), motion_code=(0,0), no residual. Unlike the preceding observer, however,
// macroblock_address_increment is decoded from the full Table B.1, including
// macroblock_escape accumulation. Address gaps are therefore recognized as
// skipped P-frame macroblocks under H262-015. The existing raster copy engine
// reconstructs both transmitted zero-vector/no-residual macroblocks and skipped
// zero-vector/no-residual macroblocks from the same forward reference.
//
// Compatibility note: public signal/module names retain "four_mb" and
// "two_row" so the hardware-accepted controller interface remains stable.
//============================================================================

module mpeg2_h262_p_four_mb_two_row_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,

    output reg        four_mb_candidate,
    output reg        four_mb_seen,
    output reg        four_mb_complete_now,
    output reg        parse_hold,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);
wire post_p_boundary_now =
    (start_code_value == PICTURE_START_CODE) ||
    (start_code_value == SEQUENCE_HEADER_CODE);

reg        sequence_capture;
reg [1:0]  sequence_count;
reg [23:0] sequence_shift;
wire [23:0] sequence_next = {sequence_shift[15:0], stream_data};
wire [11:0] sequence_horizontal_size = sequence_next[23:12];
wire [11:0] sequence_vertical_size   = sequence_next[11:0];
wire [12:0] sequence_horizontal_rounded =
    {1'b0, sequence_horizontal_size} + 13'd15;
wire [12:0] sequence_vertical_rounded =
    {1'b0, sequence_vertical_size} + 13'd15;
wire [8:0] sequence_macroblock_width  = sequence_horizontal_rounded[12:4];
wire [8:0] sequence_macroblock_height = sequence_vertical_rounded[12:4];
reg        geometry_supported_raster;
reg [5:0]  controlled_mb_per_row;
reg [5:0]  controlled_row_count;

reg        picture_capture;
reg        picture_count;
reg [15:0] picture_shift;
wire [15:0] picture_next = {picture_shift[7:0], stream_data};
reg        current_picture_is_p;

reg        pce_capture;
reg [2:0]  pce_count;
reg [39:0] pce_shift;
wire [39:0] pce_next = {pce_shift[31:0], stream_data};

localparam integer ROW_BUFFER_BYTES = 100;
reg [7:0] row_bytes [0:ROW_BUFFER_BYTES-1];
reg       slice_capture;
reg [5:0] slice_row_number;
reg [6:0] row_byte_count;
reg       proof_done;

reg       parse_active;
reg       boundary_final;
reg       final_release_pending;
reg [6:0] parse_byte_limit;
reg [6:0] parse_byte_index;
reg [2:0] parse_bit_index;
wire      parser_at_end = (parse_byte_index >= parse_byte_limit);
wire      parser_current_bit = row_bytes[parse_byte_index][parse_bit_index];

localparam [3:0]
    R_HEADER   = 4'd0,
    R_MBA      = 4'd1,
    R_APPLY    = 4'd2,
    R_MBTYPE0  = 4'd3,
    R_MBTYPE1  = 4'd4,
    R_MBTYPE2  = 4'd5,
    R_MOTION_X = 4'd6,
    R_MOTION_Y = 4'd7,
    R_STUFF    = 4'd8,
    R_SUCCESS  = 4'd9,
    R_ERROR    = 4'd10;

reg [3:0] parser_state;
reg [2:0] header_bit_index;
reg [10:0] mba_vlc_bits;
reg [3:0]  mba_vlc_len;
reg [9:0]  mba_escape_accum;
reg [9:0]  mba_increment;
reg signed [7:0] previous_col;
reg [5:0]  current_col;
reg        row_has_coded_mb;
reg        skipped_seen_picture;

wire parser_state_consumes_bit =
    (parser_state == R_HEADER)   ||
    (parser_state == R_MBA)      ||
    (parser_state == R_MBTYPE0)  ||
    (parser_state == R_MBTYPE1)  ||
    (parser_state == R_MBTYPE2)  ||
    (parser_state == R_MOTION_X) ||
    (parser_state == R_MOTION_Y) ||
    (parser_state == R_STUFF);
wire parser_consume_bit =
    parse_active && parser_state_consumes_bit && !parser_at_end;

wire [10:0] mba_vlc_bits_next = {mba_vlc_bits[9:0], parser_current_bit};
wire [3:0]  mba_vlc_len_next  = mba_vlc_len + 4'd1;

function automatic [6:0] match_mba_code;
    input [10:0] bits;
    input [3:0]  len;
    reg valid;
    reg [5:0] value;
    begin
        valid = 1'b0;
        value = 6'd0;
        case (len)
            4'd1: begin
                if (bits[0] == 1'b1) begin valid=1'b1; value=6'd1; end
            end
            4'd3: begin
                case (bits[2:0])
                    3'b011: begin valid=1'b1; value=6'd2; end
                    3'b010: begin valid=1'b1; value=6'd3; end
                    default: ;
                endcase
            end
            4'd4: begin
                case (bits[3:0])
                    4'b0011: begin valid=1'b1; value=6'd4; end
                    4'b0010: begin valid=1'b1; value=6'd5; end
                    default: ;
                endcase
            end
            4'd5: begin
                case (bits[4:0])
                    5'b00011: begin valid=1'b1; value=6'd6; end
                    5'b00010: begin valid=1'b1; value=6'd7; end
                    default: ;
                endcase
            end
            4'd7: begin
                case (bits[6:0])
                    7'b0000111: begin valid=1'b1; value=6'd8; end
                    7'b0000110: begin valid=1'b1; value=6'd9; end
                    default: ;
                endcase
            end
            4'd8: begin
                case (bits[7:0])
                    8'b00001011: begin valid=1'b1; value=6'd10; end
                    8'b00001010: begin valid=1'b1; value=6'd11; end
                    8'b00001001: begin valid=1'b1; value=6'd12; end
                    8'b00001000: begin valid=1'b1; value=6'd13; end
                    8'b00000111: begin valid=1'b1; value=6'd14; end
                    8'b00000110: begin valid=1'b1; value=6'd15; end
                    default: ;
                endcase
            end
            4'd10: begin
                case (bits[9:0])
                    10'b0000010111: begin valid=1'b1; value=6'd16; end
                    10'b0000010110: begin valid=1'b1; value=6'd17; end
                    10'b0000010101: begin valid=1'b1; value=6'd18; end
                    10'b0000010100: begin valid=1'b1; value=6'd19; end
                    10'b0000010011: begin valid=1'b1; value=6'd20; end
                    10'b0000010010: begin valid=1'b1; value=6'd21; end
                    default: ;
                endcase
            end
            4'd11: begin
                case (bits[10:0])
                    11'b00000100011: begin valid=1'b1; value=6'd22; end
                    11'b00000100010: begin valid=1'b1; value=6'd23; end
                    11'b00000100001: begin valid=1'b1; value=6'd24; end
                    11'b00000100000: begin valid=1'b1; value=6'd25; end
                    11'b00000011111: begin valid=1'b1; value=6'd26; end
                    11'b00000011110: begin valid=1'b1; value=6'd27; end
                    11'b00000011101: begin valid=1'b1; value=6'd28; end
                    11'b00000011100: begin valid=1'b1; value=6'd29; end
                    11'b00000011011: begin valid=1'b1; value=6'd30; end
                    11'b00000011010: begin valid=1'b1; value=6'd31; end
                    11'b00000011001: begin valid=1'b1; value=6'd32; end
                    11'b00000011000: begin valid=1'b1; value=6'd33; end
                    default: ;
                endcase
            end
            default: ;
        endcase
        match_mba_code = {valid, value};
    end
endfunction

wire [6:0] mba_match = match_mba_code(mba_vlc_bits_next, mba_vlc_len_next);
wire mba_escape_match =
    (mba_vlc_len_next == 4'd11) &&
    (mba_vlc_bits_next == 11'b00000001000);
wire signed [10:0] next_col_calc =
    $signed(previous_col) + $signed({1'b0, mba_increment});

always @(posedge clk) begin
    if (reset) begin
        byte_window               <= 32'd0;
        sequence_capture          <= 1'b0;
        sequence_count            <= 2'd0;
        sequence_shift            <= 24'd0;
        geometry_supported_raster <= 1'b0;
        controlled_mb_per_row     <= 6'd0;
        controlled_row_count      <= 6'd0;
        picture_capture           <= 1'b0;
        picture_count             <= 1'b0;
        picture_shift             <= 16'd0;
        current_picture_is_p      <= 1'b0;
        pce_capture               <= 1'b0;
        pce_count                 <= 3'd0;
        pce_shift                 <= 40'd0;
        four_mb_candidate         <= 1'b0;
        four_mb_seen              <= 1'b0;
        four_mb_complete_now      <= 1'b0;
        parse_hold                <= 1'b0;
        probe_error               <= 1'b0;
        slice_capture             <= 1'b0;
        slice_row_number          <= 6'd0;
        row_byte_count            <= 7'd0;
        proof_done                <= 1'b0;
        parse_active              <= 1'b0;
        boundary_final            <= 1'b0;
        final_release_pending     <= 1'b0;
        parse_byte_limit          <= 7'd0;
        parse_byte_index          <= 7'd0;
        parse_bit_index           <= 3'd7;
        parser_state              <= R_HEADER;
        header_bit_index          <= 3'd0;
        mba_vlc_bits              <= 11'd0;
        mba_vlc_len               <= 4'd0;
        mba_escape_accum          <= 10'd0;
        mba_increment             <= 10'd0;
        previous_col              <= -8'sd1;
        current_col               <= 6'd0;
        row_has_coded_mb          <= 1'b0;
        skipped_seen_picture      <= 1'b0;
    end
    else begin
        four_mb_complete_now <= 1'b0;

        if (final_release_pending) begin
            parse_hold            <= 1'b0;
            final_release_pending <= 1'b0;
        end

        if (parse_active) begin
            if (parser_consume_bit) begin
                if (parse_bit_index == 3'd0) begin
                    parse_bit_index  <= 3'd7;
                    parse_byte_index <= parse_byte_index + 7'd1;
                end
                else begin
                    parse_bit_index <= parse_bit_index - 3'd1;
                end
            end

            case (parser_state)
                R_HEADER: begin
                    if (parser_at_end) begin
                        parser_state <= R_ERROR;
                    end
                    else if (parser_current_bit !=
                             ((header_bit_index == 3'd3) ? 1'b1 : 1'b0)) begin
                        parser_state <= R_ERROR;
                    end
                    else if (header_bit_index == 3'd5) begin
                        header_bit_index <= 3'd0;
                        mba_vlc_bits     <= 11'd0;
                        mba_vlc_len      <= 4'd0;
                        mba_escape_accum <= 10'd0;
                        parser_state     <= R_MBA;
                    end
                    else begin
                        header_bit_index <= header_bit_index + 3'd1;
                    end
                end

                R_MBA: begin
                    if (parser_at_end) begin
                        parser_state <= R_ERROR;
                    end
                    else if (mba_escape_match) begin
                        if (mba_escape_accum > 10'd957) begin
                            parser_state <= R_ERROR;
                        end
                        else begin
                            mba_escape_accum <= mba_escape_accum + 10'd33;
                            mba_vlc_bits     <= 11'd0;
                            mba_vlc_len      <= 4'd0;
                        end
                    end
                    else if (mba_match[6]) begin
                        mba_increment <= mba_escape_accum + {4'd0, mba_match[5:0]};
                        mba_vlc_bits     <= 11'd0;
                        mba_vlc_len      <= 4'd0;
                        mba_escape_accum <= 10'd0;
                        parser_state     <= R_APPLY;
                    end
                    else if (mba_vlc_len_next == 4'd11) begin
                        parser_state <= R_ERROR;
                    end
                    else begin
                        mba_vlc_bits <= mba_vlc_bits_next;
                        mba_vlc_len  <= mba_vlc_len_next;
                    end
                end

                R_APPLY: begin
                    if ((mba_increment == 10'd0) ||
                        (!row_has_coded_mb && (mba_increment != 10'd1)) ||
                        (next_col_calc < 0) ||
                        (next_col_calc >= $signed({1'b0, controlled_mb_per_row}))) begin
                        parser_state <= R_ERROR;
                    end
                    else begin
                        if (row_has_coded_mb && (mba_increment > 10'd1))
                            skipped_seen_picture <= 1'b1;
                        previous_col <= next_col_calc[7:0];
                        current_col  <= next_col_calc[5:0];
                        parser_state <= R_MBTYPE0;
                    end
                end

                R_MBTYPE0: begin
                    if (parser_at_end || (parser_current_bit != 1'b0))
                        parser_state <= R_ERROR;
                    else
                        parser_state <= R_MBTYPE1;
                end
                R_MBTYPE1: begin
                    if (parser_at_end || (parser_current_bit != 1'b0))
                        parser_state <= R_ERROR;
                    else
                        parser_state <= R_MBTYPE2;
                end
                R_MBTYPE2: begin
                    if (parser_at_end || (parser_current_bit != 1'b1))
                        parser_state <= R_ERROR;
                    else
                        parser_state <= R_MOTION_X;
                end
                R_MOTION_X: begin
                    if (parser_at_end || (parser_current_bit != 1'b1))
                        parser_state <= R_ERROR;
                    else
                        parser_state <= R_MOTION_Y;
                end
                R_MOTION_Y: begin
                    if (parser_at_end || (parser_current_bit != 1'b1)) begin
                        parser_state <= R_ERROR;
                    end
                    else begin
                        row_has_coded_mb <= 1'b1;
                        if (current_col == (controlled_mb_per_row - 6'd1)) begin
                            parser_state <= R_STUFF;
                        end
                        else begin
                            mba_vlc_bits     <= 11'd0;
                            mba_vlc_len      <= 4'd0;
                            mba_escape_accum <= 10'd0;
                            parser_state     <= R_MBA;
                        end
                    end
                end

                R_STUFF: begin
                    if (parser_at_end) begin
                        parser_state <= R_SUCCESS;
                    end
                    else if (parser_current_bit != 1'b0) begin
                        parser_state <= R_ERROR;
                    end
                end

                R_SUCCESS: begin
                    parse_active <= 1'b0;
                    if (!row_has_coded_mb ||
                        (current_col != (controlled_mb_per_row - 6'd1))) begin
                        probe_error <= 1'b1;
                        proof_done  <= 1'b1;
                        parse_hold  <= 1'b0;
                    end
                    else if (boundary_final) begin
                        four_mb_seen          <= 1'b1;
                        four_mb_complete_now  <= 1'b1;
                        proof_done            <= 1'b1;
                        final_release_pending <= 1'b1;
                    end
                    else begin
                        slice_row_number <= slice_row_number + 6'd1;
                        row_byte_count   <= 7'd0;
                        slice_capture    <= 1'b1;
                        parse_hold       <= 1'b0;
                    end
                end

                default: begin
                    parse_active <= 1'b0;
                    parse_hold   <= 1'b0;
                    proof_done   <= 1'b1;
                    probe_error  <= 1'b1;
                end
            endcase
        end

        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (sequence_capture) begin
                sequence_shift <= sequence_next;
                if (sequence_count == 2'd2) begin
                    sequence_capture <= 1'b0;
                    sequence_count   <= 2'd0;
                    geometry_supported_raster <=
                        (sequence_horizontal_size != 12'd0) &&
                        (sequence_vertical_size   != 12'd0) &&
                        (sequence_macroblock_width  >= 9'd2) &&
                        (sequence_macroblock_width  <= 9'd45) &&
                        (sequence_macroblock_height >= 9'd2) &&
                        (sequence_macroblock_height <= 9'd30);
                    if ((sequence_macroblock_width >= 9'd2) &&
                        (sequence_macroblock_width <= 9'd45))
                        controlled_mb_per_row <= sequence_macroblock_width[5:0];
                    else
                        controlled_mb_per_row <= 6'd0;
                    if ((sequence_macroblock_height >= 9'd2) &&
                        (sequence_macroblock_height <= 9'd30))
                        controlled_row_count <= sequence_macroblock_height[5:0];
                    else
                        controlled_row_count <= 6'd0;
                end
                else begin
                    sequence_count <= sequence_count + 2'd1;
                end
            end
            else if (start_code_now &&
                     (start_code_value == SEQUENCE_HEADER_CODE)) begin
                sequence_capture <= 1'b1;
                sequence_count   <= 2'd0;
                sequence_shift   <= 24'd0;
            end

            if (picture_capture) begin
                picture_shift <= picture_next;
                if (picture_count) begin
                    picture_capture      <= 1'b0;
                    picture_count        <= 1'b0;
                    current_picture_is_p <= (picture_next[5:3] == 3'd2);
                    four_mb_candidate    <= 1'b0;
                end
                else begin
                    picture_count <= 1'b1;
                end
            end
            else if (start_code_now &&
                     (start_code_value == PICTURE_START_CODE)) begin
                picture_capture <= 1'b1;
                picture_count   <= 1'b0;
                picture_shift   <= 16'd0;
            end

            if (pce_capture) begin
                pce_shift <= pce_next;
                if (pce_count == 3'd4) begin
                    pce_capture <= 1'b0;
                    pce_count   <= 3'd0;
                    four_mb_candidate <=
                        geometry_supported_raster &&
                        current_picture_is_p &&
                        (pce_next[39:36] == 4'h8) &&
                        (pce_next[35:32] == 4'd2) &&
                        (pce_next[31:28] == 4'd2) &&
                        (pce_next[17:16] == 2'b11) &&
                        (pce_next[14]    == 1'b1) &&
                        (pce_next[13]    == 1'b0) &&
                        (pce_next[12]    == 1'b0) &&
                        (pce_next[10]    == 1'b0);
                end
                else begin
                    pce_count <= pce_count + 3'd1;
                end
            end
            else if (current_picture_is_p && start_code_now &&
                     (start_code_value == EXTENSION_START_CODE)) begin
                pce_capture <= 1'b1;
                pce_count   <= 3'd0;
                pce_shift   <= 40'd0;
            end

            if (!parse_active && !proof_done && slice_capture) begin
                if (start_code_now) begin
                    if (row_byte_count < 7'd3) begin
                        slice_capture <= 1'b0;
                        proof_done    <= 1'b1;
                        probe_error   <= 1'b1;
                    end
                    else if (slice_row_number < controlled_row_count) begin
                        if (start_code_value ==
                            {2'd0, slice_row_number} + 8'd1) begin
                            slice_capture     <= 1'b0;
                            parse_active      <= 1'b1;
                            parse_hold        <= 1'b1;
                            boundary_final    <= 1'b0;
                            parse_byte_limit  <= row_byte_count - 7'd3;
                            parse_byte_index  <= 7'd0;
                            parse_bit_index   <= 3'd7;
                            parser_state      <= R_HEADER;
                            header_bit_index  <= 3'd0;
                            mba_vlc_bits      <= 11'd0;
                            mba_vlc_len       <= 4'd0;
                            mba_escape_accum  <= 10'd0;
                            mba_increment     <= 10'd0;
                            previous_col      <= -8'sd1;
                            current_col       <= 6'd0;
                            row_has_coded_mb  <= 1'b0;
                        end
                        else begin
                            slice_capture <= 1'b0;
                            proof_done    <= 1'b1;
                            probe_error   <= 1'b1;
                        end
                    end
                    else if (post_p_boundary_now) begin
                        slice_capture     <= 1'b0;
                        parse_active      <= 1'b1;
                        parse_hold        <= 1'b1;
                        boundary_final    <= 1'b1;
                        parse_byte_limit  <= row_byte_count - 7'd3;
                        parse_byte_index  <= 7'd0;
                        parse_bit_index   <= 3'd7;
                        parser_state      <= R_HEADER;
                        header_bit_index  <= 3'd0;
                        mba_vlc_bits      <= 11'd0;
                        mba_vlc_len       <= 4'd0;
                        mba_escape_accum  <= 10'd0;
                        mba_increment     <= 10'd0;
                        previous_col      <= -8'sd1;
                        current_col       <= 6'd0;
                        row_has_coded_mb  <= 1'b0;
                    end
                    else begin
                        slice_capture <= 1'b0;
                        proof_done    <= 1'b1;
                        probe_error   <= 1'b1;
                    end
                end
                else if (row_byte_count < ROW_BUFFER_BYTES) begin
                    row_bytes[row_byte_count] <= stream_data;
                    row_byte_count <= row_byte_count + 7'd1;
                end
                else begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;
                    probe_error   <= 1'b1;
                end
            end
            else if (!parse_active && !proof_done &&
                     four_mb_candidate && slice_start_now) begin
                if (start_code_value == 8'h01) begin
                    slice_capture        <= 1'b1;
                    slice_row_number     <= 6'd1;
                    row_byte_count       <= 7'd0;
                    skipped_seen_picture <= 1'b0;
                end
                else begin
                    proof_done  <= 1'b1;
                    probe_error <= 1'b1;
                end
            end
        end
    end
end

endmodule
