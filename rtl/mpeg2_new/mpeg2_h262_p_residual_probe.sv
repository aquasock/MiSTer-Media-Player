//============================================================================
// MiSTer Media Player - Phase 1T controlled H.262 P residual transform probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000
//   - 6.2.2.1 sequence_header() quantiser-matrix signalling
//   - 6.2.3.1 picture_coding_extension()
//   - 6.2.4 slice()
//   - 6.2.5 macroblock()
//   - 6.2.6 block()
//   - 7.2.2 non-intra DCT coefficient decoding
//   - 7.3 coefficient scan order
//   - 7.4 inverse quantisation and mismatch control
//   - 7.5 inverse DCT
//   - Annex B Tables B.9 and B.14
//
// kate - Phase 1T-k is deliberately diagnostic and passive. It observes only
// bytes already accepted by the main decoder and never backpressures the stream.
// The controlled test_ipii.m2v first P macroblock is pattern-only (Table B.3
// code 01) with CBP=63. This probe captures a bounded first-slice prefix,
// decodes the complete first non-intra Y0 block through EOB, performs the H.262
// non-intra inverse-quantisation rule with the normative default non-intra
// matrix (all weights 16), applies saturation/mismatch control, and sends the
// resulting 8x8 coefficient block through the existing H.262 IDCT module.
//
// The 256-byte first-slice capture is an implementation regression boundary,
// not an H.262 limit. Downloaded non-intra quantiser matrices remain a valid
// H.262 feature but are outside this diagnostic and therefore fail this proof
// rather than being described as invalid syntax.
//============================================================================

module mpeg2_h262_p_residual_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_expected,

    // decision_complete says the first P macroblock type was classified for
    // this diagnostic. residual_required is asserted only for the controlled
    // pattern-only (01) macroblock. Other P macroblock types are left to the
    // already-proven Phase 1T motion/syntax diagnostics.
    output reg        decision_complete,
    output reg        residual_required,
    output reg        residual_success,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE      = 8'h00,
    SEQUENCE_HEADER_CODE    = 8'hB3,
    EXTENSION_START_CODE    = 8'hB5;

localparam [3:0]
    EXT_PICTURE_CODING = 4'h8,
    EXT_QUANT_MATRIX   = 4'h3;

// -------------------------------------------------------------------------
// Byte-level start-code observation.
// -------------------------------------------------------------------------
reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);

// -------------------------------------------------------------------------
// Sequence-level non-intra matrix capability tracking.
//
// For the ordinary fixed 64-bit sequence-header prefix, load_intra... is bit
// 63 and is payload_next[1]. If it is zero, load_non_intra... immediately
// follows at payload_next[0]. If a downloaded intra matrix is present, this
// small observer does not walk the following 64 bytes to find the later
// non-intra flag, so it conservatively marks the non-intra default unavailable.
// Any quant_matrix_extension is likewise outside this first diagnostic.
// -------------------------------------------------------------------------
reg        sequence_capture_active;
reg [3:0]  sequence_payload_count;
reg [63:0] sequence_payload_shift;
wire [63:0] sequence_payload_next =
    {sequence_payload_shift[55:0], stream_data};
reg        sequence_seen;
reg        non_intra_quant_matrix_default;

reg extension_id_pending;

// -------------------------------------------------------------------------
// P picture_coding_extension controls used by coefficient reconstruction.
// -------------------------------------------------------------------------
reg        pce_capture_active;
reg [2:0]  pce_payload_count;
reg [39:0] pce_payload_shift;
wire [39:0] pce_payload_next = {pce_payload_shift[31:0], stream_data};
reg        p_controls_seen;
reg [1:0]  p_picture_structure;
reg        p_frame_pred_frame_dct;
reg        p_q_scale_type;
reg        p_alternate_scan;

// -------------------------------------------------------------------------
// Passive bounded first-slice capture.
// -------------------------------------------------------------------------
reg        slice_capture_active;
reg [7:0]  slice_capture_count;
reg [7:0]  slice_payload [0:255];
reg        decode_pending;
reg [8:0]  captured_byte_count;

// The capture is decoded later one bit per clock. A registered byte reader
// avoids a 2048-bit barrel shift and keeps the parser path sequential.
reg [7:0] decode_byte;
reg [7:0] decode_byte_index;
reg [2:0] decode_bit_offset;
wire      decode_bit = decode_byte[3'd7 - decode_bit_offset];

localparam [4:0]
    R_IDLE          = 5'd0,
    R_LOAD          = 5'd1,
    R_QSCALE        = 5'd2,
    R_EXTRA_ZERO    = 5'd3,
    R_MBA           = 5'd4,
    R_MBTYPE_FIRST  = 5'd5,
    R_MBTYPE_SECOND = 5'd6,
    R_CBP           = 5'd7,
    R_FIRST_COEFF   = 5'd8,
    R_FIRST_SIGN    = 5'd9,
    R_AC_VLC        = 5'd10,
    R_AC_SIGN       = 5'd11,
    R_ESCAPE_RUN    = 5'd12,
    R_ESCAPE_LEVEL  = 5'd13;

reg [4:0] parse_state;
reg       parse_active;

wire parse_consumes_bit = parse_active && (parse_state != R_LOAD);

reg [2:0] field_bit_count;
reg [4:0] qscale_shift;
reg [4:0] p_quantiser_scale_code;

reg [5:0] cbp_shift;
wire [5:0] cbp_next = {cbp_shift[4:0], decode_bit};

reg [9:0] first_coeff_shift;
reg [3:0] first_coeff_bit_count;
wire [9:0] first_coeff_next = {first_coeff_shift[8:0], decode_bit};

// -------------------------------------------------------------------------
// Complete first non-intra block VLC walk.
// -------------------------------------------------------------------------
reg signed [12:0] qfs [0:63];
reg [6:0] qfs_index;
integer i;

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

// -------------------------------------------------------------------------
// H.262 scan and quantiser-scale helpers.
// -------------------------------------------------------------------------
function automatic [5:0] scan_index;
    input       alternate;
    input [5:0] linear;
    begin
        if (!alternate) begin
            case (linear)
                 0: scan_index =  0;  1: scan_index =  1;
                 2: scan_index =  5;  3: scan_index =  6;
                 4: scan_index = 14;  5: scan_index = 15;
                 6: scan_index = 27;  7: scan_index = 28;
                 8: scan_index =  2;  9: scan_index =  4;
                10: scan_index =  7; 11: scan_index = 13;
                12: scan_index = 16; 13: scan_index = 26;
                14: scan_index = 29; 15: scan_index = 42;
                16: scan_index =  3; 17: scan_index =  8;
                18: scan_index = 12; 19: scan_index = 17;
                20: scan_index = 25; 21: scan_index = 30;
                22: scan_index = 41; 23: scan_index = 43;
                24: scan_index =  9; 25: scan_index = 11;
                26: scan_index = 18; 27: scan_index = 24;
                28: scan_index = 31; 29: scan_index = 40;
                30: scan_index = 44; 31: scan_index = 53;
                32: scan_index = 10; 33: scan_index = 19;
                34: scan_index = 23; 35: scan_index = 32;
                36: scan_index = 39; 37: scan_index = 45;
                38: scan_index = 52; 39: scan_index = 54;
                40: scan_index = 20; 41: scan_index = 22;
                42: scan_index = 33; 43: scan_index = 38;
                44: scan_index = 46; 45: scan_index = 51;
                46: scan_index = 55; 47: scan_index = 60;
                48: scan_index = 21; 49: scan_index = 34;
                50: scan_index = 37; 51: scan_index = 47;
                52: scan_index = 50; 53: scan_index = 56;
                54: scan_index = 59; 55: scan_index = 61;
                56: scan_index = 35; 57: scan_index = 36;
                58: scan_index = 48; 59: scan_index = 49;
                60: scan_index = 57; 61: scan_index = 58;
                62: scan_index = 62; 63: scan_index = 63;
                default: scan_index = 6'd0;
            endcase
        end
        else begin
            case (linear)
                 0: scan_index =  0;  1: scan_index =  4;
                 2: scan_index =  6;  3: scan_index = 20;
                 4: scan_index = 22;  5: scan_index = 36;
                 6: scan_index = 38;  7: scan_index = 52;
                 8: scan_index =  1;  9: scan_index =  5;
                10: scan_index =  7; 11: scan_index = 21;
                12: scan_index = 23; 13: scan_index = 37;
                14: scan_index = 39; 15: scan_index = 53;
                16: scan_index =  2; 17: scan_index =  8;
                18: scan_index = 19; 19: scan_index = 24;
                20: scan_index = 34; 21: scan_index = 40;
                22: scan_index = 50; 23: scan_index = 54;
                24: scan_index =  3; 25: scan_index =  9;
                26: scan_index = 18; 27: scan_index = 25;
                28: scan_index = 35; 29: scan_index = 41;
                30: scan_index = 51; 31: scan_index = 55;
                32: scan_index = 10; 33: scan_index = 17;
                34: scan_index = 26; 35: scan_index = 30;
                36: scan_index = 42; 37: scan_index = 46;
                38: scan_index = 56; 39: scan_index = 60;
                40: scan_index = 11; 41: scan_index = 16;
                42: scan_index = 27; 43: scan_index = 31;
                44: scan_index = 43; 45: scan_index = 47;
                46: scan_index = 57; 47: scan_index = 61;
                48: scan_index = 12; 49: scan_index = 15;
                50: scan_index = 28; 51: scan_index = 32;
                52: scan_index = 44; 53: scan_index = 48;
                54: scan_index = 58; 55: scan_index = 62;
                56: scan_index = 13; 57: scan_index = 14;
                58: scan_index = 29; 59: scan_index = 33;
                60: scan_index = 45; 61: scan_index = 49;
                62: scan_index = 59; 63: scan_index = 63;
                default: scan_index = 6'd0;
            endcase
        end
    end
endfunction

function automatic [7:0] quantiser_scale_value;
    input       nonlinear;
    input [4:0] code;
    begin
        if (!nonlinear) begin
            quantiser_scale_value = {code, 1'b0};
        end
        else begin
            case (code)
                 1: quantiser_scale_value =   1;
                 2: quantiser_scale_value =   2;
                 3: quantiser_scale_value =   3;
                 4: quantiser_scale_value =   4;
                 5: quantiser_scale_value =   5;
                 6: quantiser_scale_value =   6;
                 7: quantiser_scale_value =   7;
                 8: quantiser_scale_value =   8;
                 9: quantiser_scale_value =  10;
                10: quantiser_scale_value =  12;
                11: quantiser_scale_value =  14;
                12: quantiser_scale_value =  16;
                13: quantiser_scale_value =  18;
                14: quantiser_scale_value =  20;
                15: quantiser_scale_value =  22;
                16: quantiser_scale_value =  24;
                17: quantiser_scale_value =  28;
                18: quantiser_scale_value =  32;
                19: quantiser_scale_value =  36;
                20: quantiser_scale_value =  40;
                21: quantiser_scale_value =  44;
                22: quantiser_scale_value =  48;
                23: quantiser_scale_value =  52;
                24: quantiser_scale_value =  56;
                25: quantiser_scale_value =  64;
                26: quantiser_scale_value =  72;
                27: quantiser_scale_value =  80;
                28: quantiser_scale_value =  88;
                29: quantiser_scale_value =  96;
                30: quantiser_scale_value = 104;
                31: quantiser_scale_value = 112;
                default: quantiser_scale_value = 8'd0;
            endcase
        end
    end
endfunction

// -------------------------------------------------------------------------
// Non-intra inverse quantisation. For the default non-intra matrix W=16,
// H.262 7.4.2.3 reduces algebraically to
//   F'' = ((2*QF + Sign(QF)) * quantiser_scale) / 2.
// Signed division preserves the required truncation toward zero. Saturation
// and mismatch control are then applied exactly as separate H.262 stages.
// -------------------------------------------------------------------------
reg        iq_active;
reg [5:0]  iq_index;
reg        iq_parity;
reg signed [11:0] iq_coeff [0:63];
reg        f00_proven;

wire [5:0] iq_qfs_index = scan_index(p_alternate_scan, iq_index);
wire signed [12:0] iq_qf = qfs[iq_qfs_index];
wire [7:0] iq_qscale =
    quantiser_scale_value(p_q_scale_type, p_quantiser_scale_code);

reg signed [14:0] iq_precondition;
reg signed [23:0] iq_product;
reg signed [23:0] iq_unclipped;
reg signed [11:0] iq_saturated;
reg signed [11:0] iq_final_value;
reg               iq_parity_with_current;

always @* begin
    if (iq_qf > 13'sd0)
        iq_precondition = ($signed(iq_qf) <<< 1) + 15'sd1;
    else if (iq_qf < 13'sd0)
        iq_precondition = ($signed(iq_qf) <<< 1) - 15'sd1;
    else
        iq_precondition = 15'sd0;

    iq_product   = iq_precondition * $signed({1'b0, iq_qscale});
    iq_unclipped = iq_product / 24'sd2;

    if (iq_unclipped > 24'sd2047)
        iq_saturated = 12'sd2047;
    else if (iq_unclipped < -24'sd2048)
        iq_saturated = 12'sh800;
    else
        iq_saturated = iq_unclipped[11:0];

    iq_parity_with_current = iq_parity ^ iq_saturated[0];
    if ((iq_index == 6'd63) && !iq_parity_with_current)
        iq_final_value = {iq_saturated[11:1], ~iq_saturated[0]};
    else
        iq_final_value = iq_saturated;
end

// -------------------------------------------------------------------------
// Feed the completely reconstructed coefficient block to the existing IDCT.
// This is a second diagnostic instance; the normal I-picture transform path is
// untouched by Phase 1T-k.
// -------------------------------------------------------------------------
reg        emit_pending;
reg        emit_active;
reg [5:0]  emit_index;
reg        idct_coeff_block_start;
reg        idct_coeff_valid;
reg [5:0]  idct_coeff_index;
reg signed [11:0] idct_coeff_value;
reg        idct_coeff_block_end;

wire       idct_block_complete;
wire       idct_error;
wire       idct_sample_valid;
wire [5:0] idct_sample_index;
wire signed [15:0] idct_sample_value;
wire signed [15:0] idct_first_sample00;
wire signed [15:0] idct_first_sample77;

mpeg2_h262_idct p_residual_idct
(
    .clk                 (clk),
    .reset               (reset),
    .coeff_block_start   (idct_coeff_block_start),
    .coeff_valid         (idct_coeff_valid),
    .coeff_index         (idct_coeff_index),
    .coeff_value         (idct_coeff_value),
    .coeff_block_end     (idct_coeff_block_end),
    .block_complete      (idct_block_complete),
    .idct_error          (idct_error),
    .sample_valid        (idct_sample_valid),
    .sample_index        (idct_sample_index),
    .sample_value        (idct_sample_value),
    .first_luma_sample00 (idct_first_sample00),
    .first_luma_sample77 (idct_first_sample77)
);

reg [6:0] idct_sample_count;
wire unused_idct_values =
    &{1'b0, idct_sample_value[0], idct_first_sample00[0], idct_first_sample77[0]};

// -------------------------------------------------------------------------
// Sequential control.
// -------------------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        byte_window                     <= 32'd0;
        sequence_capture_active         <= 1'b0;
        sequence_payload_count          <= 4'd0;
        sequence_payload_shift          <= 64'd0;
        sequence_seen                   <= 1'b0;
        non_intra_quant_matrix_default  <= 1'b1;
        extension_id_pending            <= 1'b0;
        pce_capture_active              <= 1'b0;
        pce_payload_count               <= 3'd0;
        pce_payload_shift               <= 40'd0;
        p_controls_seen                 <= 1'b0;
        p_picture_structure             <= 2'd0;
        p_frame_pred_frame_dct          <= 1'b0;
        p_q_scale_type                  <= 1'b0;
        p_alternate_scan                <= 1'b0;
        slice_capture_active            <= 1'b0;
        slice_capture_count             <= 8'd0;
        decode_pending                  <= 1'b0;
        captured_byte_count             <= 9'd0;
        decode_byte                     <= 8'd0;
        decode_byte_index               <= 8'd0;
        decode_bit_offset               <= 3'd0;
        parse_state                     <= R_IDLE;
        parse_active                    <= 1'b0;
        field_bit_count                 <= 3'd0;
        qscale_shift                    <= 5'd0;
        p_quantiser_scale_code          <= 5'd0;
        cbp_shift                       <= 6'd0;
        first_coeff_shift               <= 10'd0;
        first_coeff_bit_count           <= 4'd0;
        qfs_index                       <= 7'd0;
        ac_vlc_code                     <= 16'd0;
        ac_vlc_len                      <= 5'd0;
        ac_run_pending                  <= 6'd0;
        ac_level_pending                <= 6'd0;
        escape_run_shift                <= 6'd0;
        escape_run_bit_count            <= 3'd0;
        escape_level_shift              <= 12'd0;
        escape_level_bit_count          <= 4'd0;
        iq_active                       <= 1'b0;
        iq_index                        <= 6'd0;
        iq_parity                       <= 1'b0;
        f00_proven                      <= 1'b0;
        emit_pending                    <= 1'b0;
        emit_active                     <= 1'b0;
        emit_index                      <= 6'd0;
        idct_coeff_block_start          <= 1'b0;
        idct_coeff_valid                <= 1'b0;
        idct_coeff_index                <= 6'd0;
        idct_coeff_value                <= 12'sd0;
        idct_coeff_block_end            <= 1'b0;
        idct_sample_count               <= 7'd0;
        decision_complete               <= 1'b0;
        residual_required               <= 1'b0;
        residual_success                <= 1'b0;
        probe_error                     <= 1'b0;

        for (i = 0; i < 64; i = i + 1) begin
            qfs[i]      <= 13'sd0;
            iq_coeff[i] <= 12'sd0;
        end
    end
    else begin
        idct_coeff_block_start <= 1'b0;
        idct_coeff_valid       <= 1'b0;
        idct_coeff_block_end   <= 1'b0;

        if (idct_error)
            probe_error <= 1'b1;

        // -------------------------------------------------------------
        // Byte observers / capture.
        // -------------------------------------------------------------
        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (sequence_capture_active) begin
                sequence_payload_shift <= sequence_payload_next;
                if (sequence_payload_count == 4'd7) begin
                    sequence_capture_active <= 1'b0;
                    sequence_payload_count  <= 4'd0;
                    sequence_seen           <= 1'b1;

                    if (sequence_payload_next[1]) begin
                        // A downloaded intra matrix moves the later non-intra
                        // load flag beyond this bounded sequence observer.
                        non_intra_quant_matrix_default <= 1'b0;
                    end
                    else begin
                        non_intra_quant_matrix_default <=
                            !sequence_payload_next[0];
                    end
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

            // Read the extension_start_code_identifier on the next payload byte.
            if (extension_id_pending) begin
                extension_id_pending <= 1'b0;
                if (stream_data[7:4] == EXT_QUANT_MATRIX)
                    non_intra_quant_matrix_default <= 1'b0;
            end
            if (start_code_now &&
                (start_code_value == EXTENSION_START_CODE)) begin
                extension_id_pending <= 1'b1;
            end

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
                        p_q_scale_type         <= pce_payload_next[12];
                        p_alternate_scan       <= pce_payload_next[10];
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
                    // A short slice is still usable: decode the bytes captured
                    // before the following start_code_value. The trailing
                    // 00 00 01 prefix bytes may be present, but a valid first
                    // block must reach EOB before them.
                    slice_capture_active <= 1'b0;
                    captured_byte_count  <= {1'b0, slice_capture_count};
                    decode_pending       <= (slice_capture_count != 8'd0);
                    if (slice_capture_count == 8'd0)
                        probe_error <= 1'b1;
                end
                else begin
                    slice_payload[slice_capture_count] <= stream_data;
                    if (slice_capture_count == 8'hff) begin
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

        // -------------------------------------------------------------
        // Begin the sequential first-macroblock decode after all captured
        // bytes are stable.
        // -------------------------------------------------------------
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
            first_coeff_shift <= 10'd0;
            first_coeff_bit_count <= 4'd0;
            qfs_index         <= 7'd0;
            ac_vlc_code       <= 16'd0;
            ac_vlc_len        <= 5'd0;
            for (i = 0; i < 64; i = i + 1)
                qfs[i] <= 13'sd0;
        end

        if (parse_active) begin
            case (parse_state)
                R_LOAD: begin
                    // One cycle allows the registered byte read to settle.
                    parse_state <= R_QSCALE;
                end

                R_QSCALE: begin
                    qscale_shift <= {qscale_shift[3:0], decode_bit};
                    if (field_bit_count == 3'd4) begin
                        p_quantiser_scale_code <=
                            {qscale_shift[3:0], decode_bit};
                        field_bit_count <= 3'd0;
                        if ({qscale_shift[3:0], decode_bit} == 5'd0) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            parse_state <= R_EXTRA_ZERO;
                        end
                    end
                    else begin
                        field_bit_count <= field_bit_count + 3'd1;
                    end
                end

                R_EXTRA_ZERO: begin
                    // Controlled non-scalable stream: the next bit is the zero
                    // extra_bit_slice terminator, as already proven in 1T-d.
                    if (decode_bit) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else begin
                        parse_state <= R_MBA;
                    end
                end

                R_MBA: begin
                    // Controlled first macroblock_address_increment == 1.
                    if (!decode_bit) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else begin
                        parse_state <= R_MBTYPE_FIRST;
                    end
                end

                R_MBTYPE_FIRST: begin
                    if (decode_bit) begin
                        // Table B.3 code 1: motion_forward + pattern. The
                        // existing Phase 1T motion path remains authoritative.
                        decision_complete <= 1'b1;
                        residual_required <= 1'b0;
                        parse_active      <= 1'b0;
                    end
                    else begin
                        parse_state <= R_MBTYPE_SECOND;
                    end
                end

                R_MBTYPE_SECOND: begin
                    if (decode_bit) begin
                        // Table B.3 code 01: pattern-only, implicit (0,0)
                        // prediction. This is the controlled residual target.
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
                        // Any longer Table B.3 code is outside this residual
                        // diagnostic. It remains handled by p_syntax_probe.
                        decision_complete <= 1'b1;
                        residual_required <= 1'b0;
                        parse_active      <= 1'b0;
                    end
                end

                R_CBP: begin
                    cbp_shift <= cbp_next;
                    if (field_bit_count == 3'd5) begin
                        field_bit_count <= 3'd0;
                        // Controlled Table B.9 CBP 63 VLC = 001100.
                        if (cbp_next != 6'b001100) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            first_coeff_shift <= 10'd0;
                            ac_vlc_len        <= 5'd0;
                            parse_state       <= R_FIRST_COEFF;
                        end
                    end
                    else begin
                        field_bit_count <= field_bit_count + 3'd1;
                    end
                end

                R_FIRST_COEFF: begin
                    first_coeff_shift <= first_coeff_next;
                    if (first_coeff_bit_count == 4'd9) begin
                        first_coeff_bit_count <= 4'd0;
                        if (first_coeff_next != 10'b0000001010) begin
                            probe_error  <= 1'b1;
                            parse_active <= 1'b0;
                        end
                        else begin
                            parse_state <= R_FIRST_SIGN;
                        end
                    end
                    else begin
                        first_coeff_bit_count <= first_coeff_bit_count + 4'd1;
                    end
                end

                R_FIRST_SIGN: begin
                    // Sign zero gives the already-proven first QFS value +7.
                    if (decode_bit) begin
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else begin
                        qfs[0]      <= 13'sd7;
                        qfs_index   <= 7'd1;
                        ac_vlc_code <= 16'd0;
                        ac_vlc_len  <= 5'd0;
                        parse_state <= R_AC_VLC;
                    end
                end

                R_AC_VLC: begin
                    if (ac_vlc_match) begin
                        ac_vlc_code <= 16'd0;
                        ac_vlc_len  <= 5'd0;
                        if (ac_vlc_eob) begin
                            parse_active <= 1'b0;
                            iq_active    <= 1'b1;
                            iq_index     <= 6'd0;
                            iq_parity    <= 1'b0;
                            f00_proven   <= 1'b0;
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
                        qfs[normal_target_index[5:0]] <= decode_bit ?
                            -$signed({7'd0, ac_level_pending}) :
                             $signed({7'd0, ac_level_pending});
                        qfs_index <=
                            {1'b0, normal_target_index[5:0]} + 7'd1;
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
                    else begin
                        escape_run_bit_count <= escape_run_bit_count + 3'd1;
                    end
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
                            qfs[escape_target_index[5:0]] <=
                                {escape_level_signed[11], escape_level_signed};
                            qfs_index <=
                                {1'b0, escape_target_index[5:0]} + 7'd1;
                            ac_vlc_code <= 16'd0;
                            ac_vlc_len  <= 5'd0;
                            parse_state <= R_AC_VLC;
                        end
                    end
                    else begin
                        escape_level_bit_count <=
                            escape_level_bit_count + 4'd1;
                    end
                end

                default: begin
                    probe_error  <= 1'b1;
                    parse_active <= 1'b0;
                end
            endcase

            // Advance one captured bit after every bit-consuming decode state.
            if (parse_consumes_bit) begin
                if (decode_bit_offset == 3'd7) begin
                    decode_bit_offset <= 3'd0;
                    if (({1'b0, decode_byte_index} + 9'd1) >=
                        captured_byte_count) begin
                        // EOB was not found inside the captured first-slice
                        // diagnostic prefix.
                        probe_error  <= 1'b1;
                        parse_active <= 1'b0;
                    end
                    else begin
                        decode_byte_index <= decode_byte_index + 8'd1;
                        decode_byte <= slice_payload[decode_byte_index + 8'd1];
                    end
                end
                else begin
                    decode_bit_offset <= decode_bit_offset + 3'd1;
                end
            end
        end

        // -------------------------------------------------------------
        // One coefficient per clock non-intra inverse quantisation.
        // -------------------------------------------------------------
        if (iq_active) begin
            iq_coeff[iq_index] <= iq_final_value;
            iq_parity <= iq_parity_with_current;

            if (iq_index == 6'd0) begin
                // Controlled test_ipii has qscale code 2 and linear scale,
                // therefore QFS[0]=+7 must reconstruct exactly to F[0][0]=30.
                if ((p_quantiser_scale_code == 5'd2) &&
                    !p_q_scale_type &&
                    (iq_qf == 13'sd7) &&
                    (iq_final_value == 12'sd30)) begin
                    f00_proven <= 1'b1;
                end
                else begin
                    probe_error <= 1'b1;
                end
            end

            if (iq_index == 6'd63) begin
                iq_active    <= 1'b0;
                emit_pending <= 1'b1;
                emit_index   <= 6'd0;
            end
            else begin
                iq_index <= iq_index + 6'd1;
            end
        end

        // -------------------------------------------------------------
        // Serialize reconstructed coefficients into the IDCT.
        // -------------------------------------------------------------
        if (emit_pending) begin
            emit_pending           <= 1'b0;
            emit_active            <= 1'b1;
            emit_index             <= 6'd1;
            idct_coeff_block_start <= 1'b1;
            idct_coeff_valid       <= 1'b1;
            idct_coeff_index       <= 6'd0;
            idct_coeff_value       <= iq_coeff[0];
            idct_sample_count      <= 7'd0;
        end
        else if (emit_active) begin
            idct_coeff_valid <= 1'b1;
            idct_coeff_index <= emit_index;
            idct_coeff_value <= iq_coeff[emit_index];

            if (emit_index == 6'd63) begin
                idct_coeff_block_end <= 1'b1;
                emit_active          <= 1'b0;
            end
            else begin
                emit_index <= emit_index + 6'd1;
            end
        end

        // Positive transform proof: all 64 row-major IDCT outputs must arrive
        // in sequence, and the independently constrained F[0][0]=30 proof must
        // already have passed.
        if (idct_sample_valid) begin
            if (idct_sample_index != idct_sample_count[5:0]) begin
                probe_error <= 1'b1;
            end
            else if (idct_sample_index == 6'd63) begin
                if ((idct_sample_count == 7'd63) &&
                    f00_proven && idct_block_complete && !idct_error)
                    residual_success <= 1'b1;
                else
                    probe_error <= 1'b1;
            end

            if (idct_sample_count < 7'd64)
                idct_sample_count <= idct_sample_count + 7'd1;
        end
    end
end

endmodule
