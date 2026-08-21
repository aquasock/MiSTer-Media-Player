//============================================================================
// MiSTer Media Player - controlled six-block H.262 P residual syntax parser
//
// Standards source: project-controlled core-reference.md, source_id H262.
// The controlled first 4:2:0 macroblock is decoded in block order
// Y0, Y1, Y2, Y3, Cb, Cr.  This parser remains intentionally bounded to the
// first P slice / first pattern-only macroblock proof used by Phase 1T.
//
// kate - Phase 1T-q extends the Phase 1T-p residual parser from four luma
// blocks to all six 4:2:0 blocks.  One downstream transform engine is reused;
// this parser stops consuming buffered syntax at every EOB until that engine
// reports block_done, preserving the exact bit position between blocks.
//============================================================================

module mpeg2_h262_p_residual_parser_420
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,
    input  wire        p_picture_expected,
    input  wire        transform_block_done,

    output reg         decision_complete,
    output reg         residual_required,
    output reg         residual_success,
    output reg  [4:0]  quantiser_scale_code,
    output reg         q_scale_type,
    output reg         alternate_scan,

    output reg  [2:0]  qfs_block_index,
    output reg         qfs_block_start,
    output reg         qfs_write_en,
    output reg  [5:0]  qfs_write_index,
    output reg signed [12:0] qfs_write_value,
    output reg         qfs_block_end,

    output reg         probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    SEQUENCE_HEADER_CODE = 8'hB3,
    EXTENSION_START_CODE = 8'hB5;
localparam [3:0]
    EXT_PICTURE_CODING = 4'h8,
    EXT_QUANT_MATRIX   = 4'h3;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);

// Controlled proof only supports the default non-intra matrix.
reg        sequence_capture_active;
reg [3:0]  sequence_payload_count;
reg [63:0] sequence_payload_shift;
wire [63:0] sequence_payload_next =
    {sequence_payload_shift[55:0], stream_data};
reg        sequence_seen;
reg        non_intra_quant_matrix_default;
reg        extension_id_pending;

// Picture-coding controls needed by the non-intra transform.
reg        pce_capture_active;
reg [2:0]  pce_payload_count;
reg [39:0] pce_payload_shift;
wire [39:0] pce_payload_next = {pce_payload_shift[31:0], stream_data};
reg        p_controls_seen;
reg [1:0]  p_picture_structure;
reg        p_frame_pred_frame_dct;

// Bounded capture of the first P slice.  Parsing runs from this private copy so
// the compressed-input stream can remain held while IQ/IDCT runs between blocks.
reg        slice_capture_active;
reg [7:0]  slice_capture_count;
reg [7:0]  slice_payload [0:255];
reg        decode_pending;
reg [8:0]  captured_byte_count;
reg [7:0]  decode_byte;
reg [7:0]  decode_byte_index;
reg [2:0]  decode_bit_offset;
wire       decode_bit = decode_byte[3'd7 - decode_bit_offset];

localparam [4:0]
    R_IDLE           = 5'd0,
    R_LOAD           = 5'd1,
    R_QSCALE         = 5'd2,
    R_EXTRA_ZERO     = 5'd3,
    R_MBA            = 5'd4,
    R_MBTYPE_FIRST   = 5'd5,
    R_MBTYPE_SECOND  = 5'd6,
    R_CBP            = 5'd7,
    R_FIRST_COEFF    = 5'd8,
    R_FIRST_VLC      = 5'd9,
    R_AC_VLC         = 5'd10,
    R_AC_SIGN        = 5'd11,
    R_ESCAPE_RUN     = 5'd12,
    R_ESCAPE_LEVEL   = 5'd13,
    R_WAIT_TRANSFORM = 5'd14;

reg [4:0] parse_state;
reg       parse_active;
wire parse_consumes_bit =
    parse_active &&
    (parse_state != R_LOAD) &&
    (parse_state != R_WAIT_TRANSFORM);

reg [2:0] field_bit_count;
reg [4:0] qscale_shift;
reg [5:0] cbp_shift;
wire [5:0] cbp_next = {cbp_shift[4:0], decode_bit};
reg [6:0] qfs_index;

reg [15:0] ac_vlc_code;
reg [4:0]  ac_vlc_len;
wire [15:0] ac_vlc_code_next = {ac_vlc_code[14:0], decode_bit};
wire [4:0]  ac_vlc_len_next  = ac_vlc_len + 5'd1;
wire        ac_vlc_match;
wire        ac_vlc_eob;
wire        ac_vlc_escape;
wire [5:0]  ac_vlc_run;
wire [5:0]  ac_vlc_level;

mpeg2_h262_dct_vlc p_residual_dct_vlc
(
    .table_one    (1'b0),
    .vlc_code     (ac_vlc_code_next),
    .vlc_len      (ac_vlc_len_next),
    .match        (ac_vlc_match),
    .end_of_block (ac_vlc_eob),
    .escape       (ac_vlc_escape),
    .run          (ac_vlc_run),
    .level        (ac_vlc_level)
);

reg [5:0] ac_run_pending;
reg [5:0] ac_level_pending;
wire [7:0] normal_target_index =
    {1'b0, qfs_index} + {2'b00, ac_run_pending};

reg [5:0] escape_run_shift;
reg [2:0] escape_run_bit_count;
wire [5:0] escape_run_next = {escape_run_shift[4:0], decode_bit};
reg [11:0] escape_level_shift;
reg [3:0]  escape_level_bit_count;
wire [11:0] escape_level_next =
    {escape_level_shift[10:0], decode_bit};
wire signed [11:0] escape_level_signed = $signed(escape_level_next);
wire [7:0] escape_target_index =
    {1'b0, qfs_index} + {2'b00, escape_run_shift};

always @(posedge clk) begin
    if (reset) begin
        byte_window                    <= 32'd0;
        sequence_capture_active        <= 1'b0;
        sequence_payload_count         <= 4'd0;
        sequence_payload_shift         <= 64'd0;
        sequence_seen                  <= 1'b0;
        non_intra_quant_matrix_default <= 1'b1;
        extension_id_pending           <= 1'b0;
        pce_capture_active             <= 1'b0;
        pce_payload_count              <= 3'd0;
        pce_payload_shift              <= 40'd0;
        p_controls_seen                <= 1'b0;
        p_picture_structure            <= 2'd0;
        p_frame_pred_frame_dct         <= 1'b0;
        q_scale_type                   <= 1'b0;
        alternate_scan                 <= 1'b0;
        slice_capture_active           <= 1'b0;
        slice_capture_count            <= 8'd0;
        decode_pending                 <= 1'b0;
        captured_byte_count            <= 9'd0;
        decode_byte                    <= 8'd0;
        decode_byte_index              <= 8'd0;
        decode_bit_offset              <= 3'd0;
        parse_state                    <= R_IDLE;
        parse_active                   <= 1'b0;
        field_bit_count                <= 3'd0;
        qscale_shift                   <= 5'd0;
        cbp_shift                      <= 6'd0;
        qfs_index                      <= 7'd0;
        ac_vlc_code                    <= 16'd0;
        ac_vlc_len                     <= 5'd0;
        ac_run_pending                 <= 6'd0;
        ac_level_pending               <= 6'd0;
        escape_run_shift               <= 6'd0;
        escape_run_bit_count           <= 3'd0;
        escape_level_shift             <= 12'd0;
        escape_level_bit_count         <= 4'd0;
        decision_complete              <= 1'b0;
        residual_required              <= 1'b0;
        residual_success               <= 1'b0;
        quantiser_scale_code           <= 5'd0;
        qfs_block_index                <= 3'd0;
        qfs_block_start                <= 1'b0;
        qfs_write_en                   <= 1'b0;
        qfs_write_index                <= 6'd0;
        qfs_write_value                <= 13'sd0;
        qfs_block_end                  <= 1'b0;
        probe_error                    <= 1'b0;
    end
    else begin
        qfs_block_start <= 1'b0;
        qfs_write_en    <= 1'b0;
        qfs_block_end   <= 1'b0;

        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (sequence_capture_active) begin
                sequence_payload_shift <= sequence_payload_next;
                if (sequence_payload_count == 4'd7) begin
                    sequence_capture_active <= 1'b0;
                    sequence_payload_count  <= 4'd0;
                    sequence_seen           <= 1'b1;
                    if (sequence_payload_next[1])
                        non_intra_quant_matrix_default <= 1'b0;
                    else
                        non_intra_quant_matrix_default <=
                            !sequence_payload_next[0];
                end
                else begin
                    sequence_payload_count <= sequence_payload_count + 4'd1;
                end
            end
            else if (start_code_now &&
                     (start_code_value == SEQUENCE_HEADER_CODE)) begin
                sequence_capture_active        <= 1'b1;
                sequence_payload_count         <= 4'd0;
                sequence_payload_shift         <= 64'd0;
                non_intra_quant_matrix_default <= 1'b1;
            end

            if (extension_id_pending) begin
                extension_id_pending <= 1'b0;
                if (stream_data[7:4] == EXT_QUANT_MATRIX)
                    non_intra_quant_matrix_default <= 1'b0;
            end
            if (start_code_now &&
                (start_code_value == EXTENSION_START_CODE))
                extension_id_pending <= 1'b1;

            if (pce_capture_active) begin
                pce_payload_shift <= pce_payload_next;
                if (pce_payload_count == 3'd4) begin
                    pce_capture_active <= 1'b0;
                    pce_payload_count  <= 3'd0;
                    if (pce_payload_next[39:36] != EXT_PICTURE_CODING) begin
                        probe_error <= 1'b1;
                    end
                    else begin
                        p_picture_structure    <= pce_payload_next[17:16];
                        p_frame_pred_frame_dct <= pce_payload_next[14];
                        q_scale_type           <= pce_payload_next[12];
                        alternate_scan         <= pce_payload_next[10];
                        p_controls_seen        <= 1'b1;
                    end
                end
                else begin
                    pce_payload_count <= pce_payload_count + 3'd1;
                end
            end
            else if (p_picture_expected && !decision_complete &&
                     start_code_now &&
                     (start_code_value == EXTENSION_START_CODE)) begin
                pce_capture_active <= 1'b1;
                pce_payload_count  <= 3'd0;
                pce_payload_shift  <= 40'd0;
            end

            if (slice_capture_active) begin
                if (start_code_now) begin
                    slice_capture_active <= 1'b0;
                    captured_byte_count  <= {1'b0, slice_capture_count};
                    decode_pending       <= (slice_capture_count != 8'd0);
                    if (slice_capture_count == 8'd0)
                        probe_error <= 1'b1;
                end
                else begin
                    slice_payload[slice_capture_count] <= stream_data;
                    if (slice_capture_count == 8'hFF) begin
                        slice_capture_active <= 1'b0;
                        captured_byte_count  <= 9'd256;
                        slice_capture_count  <= 8'd0;
                        decode_pending       <= 1'b1;
                    end
                    else begin
                        slice_capture_count <= slice_capture_count + 8'd1;
                    end
                end
            end
            else if (p_picture_expected && p_controls_seen &&
                     !decision_complete && !decode_pending &&
                     !parse_active && !probe_error && slice_start_now) begin
                slice_capture_active <= 1'b1;
                slice_capture_count  <= 8'd0;
            end
            else if (p_picture_expected && !decision_complete &&
                     start_code_now &&
                     (start_code_value == PICTURE_START_CODE) &&
                     p_controls_seen) begin
                probe_error <= 1'b1;
            end
        end

        if (decode_pending) begin
            decode_pending    <= 1'b0;
            decode_byte       <= slice_payload[0];
            decode_byte_index <= 8'd0;
            decode_bit_offset <= 3'd0;
            parse_state       <= R_LOAD;
            parse_active      <= 1'b1;
            field_bit_count   <= 3'd0;
            qscale_shift      <= 5'd0;
            cbp_shift         <= 6'd0;
            qfs_index         <= 7'd0;
            ac_vlc_code       <= 16'd0;
            ac_vlc_len        <= 5'd0;
            qfs_block_index   <= 3'd0;
        end

        if (parse_active) begin
            case (parse_state)
                R_LOAD: parse_state <= R_QSCALE;

                R_QSCALE: begin
                    qscale_shift <= {qscale_shift[3:0], decode_bit};
                    if (field_bit_count == 3'd4) begin
                        quantiser_scale_code <=
                            {qscale_shift[3:0], decode_bit};
                        field_bit_count <= 3'd0;
                        if ({qscale_shift[3:0], decode_bit} == 5'd0) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else parse_state <= R_EXTRA_ZERO;
                    end
                    else field_bit_count <= field_bit_count + 3'd1;
                end

                R_EXTRA_ZERO: begin
                    if (decode_bit) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else parse_state <= R_MBA;
                end

                R_MBA: begin
                    if (!decode_bit) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else parse_state <= R_MBTYPE_FIRST;
                end

                R_MBTYPE_FIRST: begin
                    if (decode_bit) begin
                        decision_complete <= 1'b1;
                        residual_required <= 1'b0;
                        parse_active      <= 1'b0;
                    end
                    else parse_state <= R_MBTYPE_SECOND;
                end

                R_MBTYPE_SECOND: begin
                    if (decode_bit) begin
                        decision_complete <= 1'b1;
                        residual_required <= 1'b1;
                        if (!sequence_seen ||
                            !non_intra_quant_matrix_default ||
                            !p_controls_seen ||
                            (p_picture_structure != 2'b11) ||
                            !p_frame_pred_frame_dct) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            cbp_shift       <= 6'd0;
                            field_bit_count <= 3'd0;
                            parse_state     <= R_CBP;
                        end
                    end
                    else begin
                        decision_complete <= 1'b1;
                        residual_required <= 1'b0;
                        parse_active      <= 1'b0;
                    end
                end

                R_CBP: begin
                    cbp_shift <= cbp_next;
                    if (field_bit_count == 3'd5) begin
                        field_bit_count <= 3'd0;
                        // Controlled test_ipii first macroblock uses the CBP VLC
                        // bit pattern already hardware-proven to represent all
                        // six blocks coded.
                        if (cbp_next != 6'b001100) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            qfs_block_index <= 3'd0;
                            qfs_block_start <= 1'b1;
                            qfs_index       <= 7'd0;
                            ac_vlc_code     <= 16'd0;
                            ac_vlc_len      <= 5'd0;
                            parse_state     <= R_FIRST_COEFF;
                        end
                    end
                    else field_bit_count <= field_bit_count + 3'd1;
                end

                // First coefficient of a non-intra block uses the special
                // leading-one run=0/level=1 form; a leading zero falls through
                // to the ordinary Table-B.14 decoder with that zero retained in
                // the VLC length.
                R_FIRST_COEFF: begin
                    if (decode_bit) begin
                        ac_run_pending   <= 6'd0;
                        ac_level_pending <= 6'd1;
                        parse_state      <= R_AC_SIGN;
                    end
                    else begin
                        ac_vlc_code <= 16'd0;
                        ac_vlc_len  <= 5'd1;
                        parse_state <= R_FIRST_VLC;
                    end
                end

                R_FIRST_VLC: begin
                    if (ac_vlc_match) begin
                        ac_vlc_code <= 16'd0;
                        ac_vlc_len  <= 5'd0;
                        if (ac_vlc_eob) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else if (ac_vlc_escape) begin
                            escape_run_shift     <= 6'd0;
                            escape_run_bit_count <= 3'd0;
                            parse_state          <= R_ESCAPE_RUN;
                        end
                        else begin
                            ac_run_pending   <= ac_vlc_run;
                            ac_level_pending <= ac_vlc_level;
                            parse_state      <= R_AC_SIGN;
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

                R_AC_VLC: begin
                    if (ac_vlc_match) begin
                        ac_vlc_code <= 16'd0;
                        ac_vlc_len  <= 5'd0;
                        if (ac_vlc_eob) begin
                            qfs_block_end <= 1'b1;
                            parse_state   <= R_WAIT_TRANSFORM;
                        end
                        else if (ac_vlc_escape) begin
                            escape_run_shift     <= 6'd0;
                            escape_run_bit_count <= 3'd0;
                            parse_state          <= R_ESCAPE_RUN;
                        end
                        else begin
                            ac_run_pending   <= ac_vlc_run;
                            ac_level_pending <= ac_vlc_level;
                            parse_state      <= R_AC_SIGN;
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

                R_AC_SIGN: begin
                    if (normal_target_index > 8'd63) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else begin
                        qfs_write_en    <= 1'b1;
                        qfs_write_index <= normal_target_index[5:0];
                        qfs_write_value <= decode_bit ?
                            -$signed({7'd0, ac_level_pending}) :
                             $signed({7'd0, ac_level_pending});
                        qfs_index <=
                            {1'b0, normal_target_index[5:0]} + 7'd1;
                        ac_vlc_code <= 16'd0;
                        ac_vlc_len  <= 5'd0;
                        parse_state <= R_AC_VLC;
                    end
                end

                R_ESCAPE_RUN: begin
                    escape_run_shift <= escape_run_next;
                    if (escape_run_bit_count == 3'd5) begin
                        escape_run_bit_count   <= 3'd0;
                        escape_level_shift     <= 12'd0;
                        escape_level_bit_count <= 4'd0;
                        parse_state            <= R_ESCAPE_LEVEL;
                    end
                    else escape_run_bit_count <= escape_run_bit_count + 3'd1;
                end

                R_ESCAPE_LEVEL: begin
                    escape_level_shift <= escape_level_next;
                    if (escape_level_bit_count == 4'd11) begin
                        if ((escape_level_next == 12'h000) ||
                            (escape_level_next == 12'h800) ||
                            (escape_target_index > 8'd63)) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            qfs_write_en    <= 1'b1;
                            qfs_write_index <= escape_target_index[5:0];
                            qfs_write_value <=
                                {escape_level_signed[11], escape_level_signed};
                            qfs_index <=
                                {1'b0, escape_target_index[5:0]} + 7'd1;
                            ac_vlc_code <= 16'd0;
                            ac_vlc_len  <= 5'd0;
                            parse_state <= R_AC_VLC;
                        end
                    end
                    else escape_level_bit_count <=
                        escape_level_bit_count + 4'd1;
                end

                R_WAIT_TRANSFORM: begin
                    if (transform_block_done) begin
                        if (qfs_block_index == 3'd5) begin
                            residual_success <= 1'b1;
                            parse_active     <= 1'b0;
                            parse_state      <= R_IDLE;
                        end
                        else begin
                            qfs_block_index <= qfs_block_index + 3'd1;
                            qfs_block_start <= 1'b1;
                            qfs_index       <= 7'd0;
                            ac_vlc_code     <= 16'd0;
                            ac_vlc_len      <= 5'd0;
                            escape_run_shift       <= 6'd0;
                            escape_run_bit_count   <= 3'd0;
                            escape_level_shift     <= 12'd0;
                            escape_level_bit_count <= 4'd0;
                            parse_state <= R_FIRST_COEFF;
                        end
                    end
                end

                default: begin
                    probe_error  <= 1'b1;
                    parse_active <= 1'b0;
                end
            endcase

            if (parse_consumes_bit) begin
                if (decode_bit_offset == 3'd7) begin
                    decode_bit_offset <= 3'd0;
                    if (({1'b0, decode_byte_index} + 9'd1) >=
                        captured_byte_count) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else begin
                        decode_byte_index <= decode_byte_index + 8'd1;
                        decode_byte <= slice_payload[decode_byte_index + 8'd1];
                    end
                end
                else decode_bit_offset <= decode_bit_offset + 3'd1;
            end
        end
    end
end

endmodule
