//============================================================================
// MiSTer Media Player - Phase 1T passive H.262 P-picture syntax probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000
//   - 6.2.3.1 picture_coding_extension()
//   - 6.2.4 slice()
//   - 6.2.5 macroblock()
//   - 6.2.5.2 motion_vectors()
//   - 6.2.5.2.1 motion_vector()
//   - 7.6.3.1 motion-vector reconstruction
//   - 7.6.3.4 motion-vector predictor reset at each slice
//   - 7.6.3.5 implicit zero-vector prediction in P frame pictures
//   - Annex B Table B.1 macroblock_address_increment
//   - Annex B Table B.3 P-picture macroblock_type
//   - Annex B Table B.10 motion_code
//
// kate - Phase 1T-d established a passive live-stream proof through the first
// P-picture macroblock_type.  Phase 1T-e extends that same bounded diagnostic to
// the prediction-vector semantics needed before any reference pixels are read.
// The proven decoder still reconstructs only I-pictures; this observer never
// backpressures the stream and never emits pixels, DDR requests or publications.
//
// Phase 1T-e controlled diagnostic boundary:
//   - non-scalable progressive frame P picture;
//   - frame_pred_frame_dct == 1, therefore frame-based prediction is implied;
//   - first macroblock_address_increment == 1;
//   - all seven Table B.3 macroblock_type VLCs remain recognized;
//   - a non-intra P macroblock without macroblock_motion_forward derives the
//     normative implicit zero prediction vector;
//   - a macroblock with macroblock_motion_forward decodes both forward motion
//     components using Table B.10, f_code-1 residuals and 7.6.3.1 reconstruction;
//   - the controlled coded-motion vector is vector'[0][0] == (4, 0).
//
// The final (4,0) check is a hardware-test restriction, not an H.262 validity
// rule.  It deliberately keeps the reconstructed vector in the USER proof until
// the next phase consumes that vector in the reference-pixel read path.
//============================================================================

module mpeg2_h262_p_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_expected,

    // Historical name retained at the wrapper boundary.  From Phase 1T-e this
    // positive result means the first P macroblock type AND its required first
    // prediction-vector semantics have been verified.
    output reg        p_macroblock_type_seen,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE   = 8'h00,
    EXTENSION_START_CODE = 8'hB5;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);

// Capture the first 40 bits of the P picture_coding_extension so the passive
// probe has its own standards-derived f_code and frame-prediction controls.
reg        pce_capture_active;
reg [2:0]  pce_payload_count;
reg [39:0] pce_payload_shift;
wire [39:0] pce_payload_next = {pce_payload_shift[31:0], stream_data};
reg        p_picture_controls_seen;
reg [3:0]  p_forward_f_code_horizontal;
reg [3:0]  p_forward_f_code_vertical;
reg [1:0]  p_picture_structure;
reg        p_frame_pred_frame_dct;

// Ten bytes cover the bounded first-macroblock prefix even for the longest
// Table B.10 codes plus the maximum residual length used by f_code 1..9.
reg        slice_capture_active;
reg [3:0]  slice_payload_count;
reg [79:0] slice_payload_shift;
reg        decode_pending;

function automatic f_code_supported_for_probe;
    input [3:0] code;
    begin
        // H.262 permits 1..9 or 15.  This coded-motion diagnostic needs at most
        // eight residual bits, so values 1..9 are the implemented boundary.
        f_code_supported_for_probe =
            (code >= 4'd1) && (code <= 4'd9);
    end
endfunction

// Return {valid, length[3:0], signed motion_code[5:0]} for Table B.10.
function automatic [10:0] decode_motion_code;
    input [79:0] payload;
    input integer pos;
    reg          valid;
    reg [3:0]    len;
    reg signed [5:0] value;
    begin
        valid = 1'b1;
        len   = 4'd0;
        value = 6'sd0;

        if (payload[79-pos] == 1'b1) begin len=4'd1; value= 6'sd0; end
        else if (payload[79-pos -: 3]  == 3'b010)          begin len=4'd3;  value= 6'sd1;  end
        else if (payload[79-pos -: 3]  == 3'b011)          begin len=4'd3;  value=-6'sd1;  end
        else if (payload[79-pos -: 4]  == 4'b0010)         begin len=4'd4;  value= 6'sd2;  end
        else if (payload[79-pos -: 4]  == 4'b0011)         begin len=4'd4;  value=-6'sd2;  end
        else if (payload[79-pos -: 5]  == 5'b00010)        begin len=4'd5;  value= 6'sd3;  end
        else if (payload[79-pos -: 5]  == 5'b00011)        begin len=4'd5;  value=-6'sd3;  end
        else if (payload[79-pos -: 7]  == 7'b0000110)      begin len=4'd7;  value= 6'sd4;  end
        else if (payload[79-pos -: 7]  == 7'b0000111)      begin len=4'd7;  value=-6'sd4;  end
        else if (payload[79-pos -: 8]  == 8'b00001010)     begin len=4'd8;  value= 6'sd5;  end
        else if (payload[79-pos -: 8]  == 8'b00001011)     begin len=4'd8;  value=-6'sd5;  end
        else if (payload[79-pos -: 8]  == 8'b00001000)     begin len=4'd8;  value= 6'sd6;  end
        else if (payload[79-pos -: 8]  == 8'b00001001)     begin len=4'd8;  value=-6'sd6;  end
        else if (payload[79-pos -: 8]  == 8'b00000110)     begin len=4'd8;  value= 6'sd7;  end
        else if (payload[79-pos -: 8]  == 8'b00000111)     begin len=4'd8;  value=-6'sd7;  end
        else if (payload[79-pos -: 10] == 10'b0000010110)  begin len=4'd10; value= 6'sd8;  end
        else if (payload[79-pos -: 10] == 10'b0000010111)  begin len=4'd10; value=-6'sd8;  end
        else if (payload[79-pos -: 10] == 10'b0000010100)  begin len=4'd10; value= 6'sd9;  end
        else if (payload[79-pos -: 10] == 10'b0000010101)  begin len=4'd10; value=-6'sd9;  end
        else if (payload[79-pos -: 10] == 10'b0000010010)  begin len=4'd10; value= 6'sd10; end
        else if (payload[79-pos -: 10] == 10'b0000010011)  begin len=4'd10; value=-6'sd10; end
        else if (payload[79-pos -: 11] == 11'b00000100010) begin len=4'd11; value= 6'sd11; end
        else if (payload[79-pos -: 11] == 11'b00000100011) begin len=4'd11; value=-6'sd11; end
        else if (payload[79-pos -: 11] == 11'b00000100000) begin len=4'd11; value= 6'sd12; end
        else if (payload[79-pos -: 11] == 11'b00000100001) begin len=4'd11; value=-6'sd12; end
        else if (payload[79-pos -: 11] == 11'b00000011110) begin len=4'd11; value= 6'sd13; end
        else if (payload[79-pos -: 11] == 11'b00000011111) begin len=4'd11; value=-6'sd13; end
        else if (payload[79-pos -: 11] == 11'b00000011100) begin len=4'd11; value= 6'sd14; end
        else if (payload[79-pos -: 11] == 11'b00000011101) begin len=4'd11; value=-6'sd14; end
        else if (payload[79-pos -: 11] == 11'b00000011010) begin len=4'd11; value= 6'sd15; end
        else if (payload[79-pos -: 11] == 11'b00000011011) begin len=4'd11; value=-6'sd15; end
        else if (payload[79-pos -: 11] == 11'b00000011000) begin len=4'd11; value= 6'sd16; end
        else if (payload[79-pos -: 11] == 11'b00000011001) begin len=4'd11; value=-6'sd16; end
        else begin
            valid = 1'b0;
            len   = 4'd0;
            value = 6'sd0;
        end

        decode_motion_code = {valid, len, value[5:0]};
    end
endfunction

reg p_prefix_decode_ok;
reg p_prefix_controlled_prediction_ok;
reg p_prefix_motion_forward;
reg p_prefix_intra;
reg signed [12:0] p_prefix_vector_x;
reg signed [12:0] p_prefix_vector_y;

integer pos;
integer i;
integer r_size;
integer f;
integer low;
integer high;
integer range;
integer residual;
integer motion_code_i;
integer abs_motion_code;
integer delta;
integer vector_value;
reg [10:0] motion_decode;
reg [3:0]  motion_len;
reg signed [5:0] motion_value;
reg mb_quant;
reg mb_pattern;
reg mb_valid;

// Decode the bounded first P macroblock and derive its first frame-prediction
// vector.  The predictor is zero because H.262 7.6.3.4 resets PMV at every slice.
always @* begin
    p_prefix_decode_ok                = 1'b1;
    p_prefix_controlled_prediction_ok = 1'b0;
    p_prefix_motion_forward           = 1'b0;
    p_prefix_intra                    = 1'b0;
    p_prefix_vector_x                 = 13'sd0;
    p_prefix_vector_y                 = 13'sd0;
    mb_quant                          = 1'b0;
    mb_pattern                        = 1'b0;
    mb_valid                          = 1'b1;
    motion_decode                     = 11'd0;
    motion_len                        = 4'd0;
    motion_value                      = 6'sd0;
    pos                               = 5;
    i                                 = 0;
    r_size                            = 0;
    f                                 = 0;
    low                               = 0;
    high                              = 0;
    range                             = 0;
    residual                          = 0;
    motion_code_i                     = 0;
    abs_motion_code                   = 0;
    delta                             = 0;
    vector_value                      = 0;

    if (slice_payload_shift[79:75] == 5'd0)
        p_prefix_decode_ok = 1'b0;

    // Optional slice extension: flag plus eight following syntax bits.
    if (slice_payload_shift[79-pos])
        pos = pos + 9;

    // Reserved extra_bit_slice == 1 is not accepted by this controlled stream.
    if (slice_payload_shift[79-pos] != 1'b0)
        p_prefix_decode_ok = 1'b0;
    pos = pos + 1;

    // Controlled first macroblock starts at the first slice column.
    if (slice_payload_shift[79-pos] != 1'b1)
        p_prefix_decode_ok = 1'b0;
    pos = pos + 1;

    // H.262 Annex B Table B.3.
    if (slice_payload_shift[79-pos] == 1'b1) begin
        p_prefix_motion_forward = 1'b1;
        mb_pattern = 1'b1;
        pos = pos + 1;
    end
    else if (slice_payload_shift[79-pos -: 2] == 2'b01) begin
        mb_pattern = 1'b1;
        pos = pos + 2;
    end
    else if (slice_payload_shift[79-pos -: 3] == 3'b001) begin
        p_prefix_motion_forward = 1'b1;
        pos = pos + 3;
    end
    else if (slice_payload_shift[79-pos -: 5] == 5'b00011) begin
        p_prefix_intra = 1'b1;
        pos = pos + 5;
    end
    else if (slice_payload_shift[79-pos -: 5] == 5'b00010) begin
        mb_quant = 1'b1;
        p_prefix_motion_forward = 1'b1;
        mb_pattern = 1'b1;
        pos = pos + 5;
    end
    else if (slice_payload_shift[79-pos -: 5] == 5'b00001) begin
        mb_quant = 1'b1;
        mb_pattern = 1'b1;
        pos = pos + 5;
    end
    else if (slice_payload_shift[79-pos -: 6] == 6'b000001) begin
        mb_quant = 1'b1;
        p_prefix_intra = 1'b1;
        pos = pos + 6;
    end
    else begin
        mb_valid = 1'b0;
        p_prefix_decode_ok = 1'b0;
    end

    if (mb_valid && mb_quant)
        pos = pos + 5; // macroblock_quantiser_scale_code

    if (mb_valid && !p_prefix_intra && !p_prefix_motion_forward) begin
        // H.262 7.6.3.5: P frame prediction is formed with vector (0,0).
        if (!p_picture_controls_seen ||
            (p_picture_structure != 2'b11) ||
            !p_frame_pred_frame_dct) begin
            p_prefix_decode_ok = 1'b0;
        end
        else begin
            p_prefix_vector_x = 13'sd0;
            p_prefix_vector_y = 13'sd0;
            p_prefix_controlled_prediction_ok = 1'b1;
        end
    end
    else if (mb_valid && p_prefix_motion_forward) begin
        // Phase 1T-e handles the frame-based one-vector case.  With
        // frame_pred_frame_dct==1 H.262 omits frame_motion_type from the stream.
        if (!p_picture_controls_seen ||
            (p_picture_structure != 2'b11) ||
            !p_frame_pred_frame_dct ||
            !f_code_supported_for_probe(p_forward_f_code_horizontal) ||
            !f_code_supported_for_probe(p_forward_f_code_vertical)) begin
            p_prefix_decode_ok = 1'b0;
        end
        else begin
            // Horizontal component.
            motion_decode = decode_motion_code(slice_payload_shift, pos);
            motion_len    = motion_decode[9:6];
            motion_value  = $signed(motion_decode[5:0]);
            if (!motion_decode[10]) begin
                p_prefix_decode_ok = 1'b0;
            end
            else begin
                pos = pos + motion_len;
                motion_code_i = motion_value;
                r_size = p_forward_f_code_horizontal - 1;
                residual = 0;
                if ((motion_code_i != 0) && (r_size != 0)) begin
                    for (i = 0; i < 8; i = i + 1)
                        if (i < r_size)
                            residual = (residual << 1) |
                                       slice_payload_shift[79-pos-i];
                    pos = pos + r_size;
                end
                f     = 1 << r_size;
                low   = -16 * f;
                high  = (16 * f) - 1;
                range = 32 * f;
                if ((f == 1) || (motion_code_i == 0))
                    delta = motion_code_i;
                else begin
                    abs_motion_code = (motion_code_i < 0) ?
                                      -motion_code_i : motion_code_i;
                    delta = ((abs_motion_code - 1) * f) + residual + 1;
                    if (motion_code_i < 0)
                        delta = -delta;
                end
                if ((delta < low) || (delta > high))
                    p_prefix_decode_ok = 1'b0;
                vector_value = delta; // PMV == 0 at slice start.
                if (vector_value < low)
                    vector_value = vector_value + range;
                if (vector_value > high)
                    vector_value = vector_value - range;
                p_prefix_vector_x = vector_value;
            end

            // Vertical component follows immediately after horizontal residual.
            motion_decode = decode_motion_code(slice_payload_shift, pos);
            motion_len    = motion_decode[9:6];
            motion_value  = $signed(motion_decode[5:0]);
            if (!motion_decode[10]) begin
                p_prefix_decode_ok = 1'b0;
            end
            else begin
                pos = pos + motion_len;
                motion_code_i = motion_value;
                r_size = p_forward_f_code_vertical - 1;
                residual = 0;
                if ((motion_code_i != 0) && (r_size != 0)) begin
                    for (i = 0; i < 8; i = i + 1)
                        if (i < r_size)
                            residual = (residual << 1) |
                                       slice_payload_shift[79-pos-i];
                    pos = pos + r_size;
                end
                f     = 1 << r_size;
                low   = -16 * f;
                high  = (16 * f) - 1;
                range = 32 * f;
                if ((f == 1) || (motion_code_i == 0))
                    delta = motion_code_i;
                else begin
                    abs_motion_code = (motion_code_i < 0) ?
                                      -motion_code_i : motion_code_i;
                    delta = ((abs_motion_code - 1) * f) + residual + 1;
                    if (motion_code_i < 0)
                        delta = -delta;
                end
                if ((delta < low) || (delta > high))
                    p_prefix_decode_ok = 1'b0;
                vector_value = delta; // PMV == 0 at slice start.
                if (vector_value < low)
                    vector_value = vector_value + range;
                if (vector_value > high)
                    vector_value = vector_value - range;
                p_prefix_vector_y = vector_value;
            end

            // Controlled hardware vector generated by test_ip_motion.m2v.
            if (p_prefix_decode_ok &&
                (p_prefix_vector_x == 13'sd4) &&
                (p_prefix_vector_y == 13'sd0))
                p_prefix_controlled_prediction_ok = 1'b1;
        end
    end
    else if (mb_valid && p_prefix_intra) begin
        // No prediction vector belongs to an ordinary intra macroblock.
        p_prefix_controlled_prediction_ok = 1'b1;
    end

    if (!p_prefix_controlled_prediction_ok)
        p_prefix_decode_ok = 1'b0;
end

always @(posedge clk) begin
    if (reset) begin
        byte_window                    <= 32'd0;
        pce_capture_active             <= 1'b0;
        pce_payload_count              <= 3'd0;
        pce_payload_shift              <= 40'd0;
        p_picture_controls_seen        <= 1'b0;
        p_forward_f_code_horizontal    <= 4'd0;
        p_forward_f_code_vertical      <= 4'd0;
        p_picture_structure            <= 2'd0;
        p_frame_pred_frame_dct         <= 1'b0;
        slice_capture_active           <= 1'b0;
        slice_payload_count            <= 4'd0;
        slice_payload_shift            <= 80'd0;
        decode_pending                 <= 1'b0;
        p_macroblock_type_seen         <= 1'b0;
        probe_error                    <= 1'b0;
    end
    else begin
        if (decode_pending) begin
            decode_pending <= 1'b0;
            if (p_prefix_decode_ok)
                p_macroblock_type_seen <= 1'b1;
            else
                probe_error <= 1'b1;
        end

        if (stream_valid) begin
            byte_window <= byte_window_next;

            if (pce_capture_active) begin
                pce_payload_shift <= pce_payload_next;
                if (pce_payload_count == 3'd4) begin
                    pce_capture_active <= 1'b0;
                    pce_payload_count  <= 3'd0;

                    if (pce_payload_next[39:36] != 4'h8) begin
                        probe_error <= 1'b1;
                    end
                    else begin
                        p_forward_f_code_horizontal <=
                            pce_payload_next[35:32];
                        p_forward_f_code_vertical <=
                            pce_payload_next[31:28];
                        p_picture_structure <=
                            pce_payload_next[17:16];
                        p_frame_pred_frame_dct <=
                            pce_payload_next[14];
                        p_picture_controls_seen <= 1'b1;
                    end
                end
                else begin
                    pce_payload_count <= pce_payload_count + 3'd1;
                end
            end
            else if (slice_capture_active) begin
                if (start_code_now) begin
                    slice_capture_active <= 1'b0;
                    probe_error          <= 1'b1;
                end
                else begin
                    slice_payload_shift <=
                        {slice_payload_shift[71:0], stream_data};

                    if (slice_payload_count == 4'd9) begin
                        slice_capture_active <= 1'b0;
                        slice_payload_count  <= 4'd0;
                        decode_pending       <= 1'b1;
                    end
                    else begin
                        slice_payload_count <= slice_payload_count + 4'd1;
                    end
                end
            end
            else if (p_picture_expected && !p_macroblock_type_seen &&
                     !decode_pending && !probe_error) begin
                if (start_code_now &&
                    (start_code_value == EXTENSION_START_CODE)) begin
                    pce_capture_active <= 1'b1;
                    pce_payload_count  <= 3'd0;
                    pce_payload_shift  <= 40'd0;
                end
                else if (slice_start_now) begin
                    if (!p_picture_controls_seen) begin
                        probe_error <= 1'b1;
                    end
                    else begin
                        slice_capture_active <= 1'b1;
                        slice_payload_count  <= 4'd0;
                        slice_payload_shift  <= 80'd0;
                    end
                end
                else if (start_code_now &&
                         (start_code_value == PICTURE_START_CODE)) begin
                    // The expected P picture reached another picture header
                    // before its controlled first prediction vector was verified.
                    probe_error <= 1'b1;
                end
            end
        end
    end
end

endmodule
