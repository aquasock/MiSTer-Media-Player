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
// P-picture macroblock_type.  Phase 1T-e extends that bounded diagnostic through
// the first P prediction-vector semantics, before any reference pixels are read.
// The proven decoder still reconstructs only I-pictures; this observer never
// backpressures the stream and never emits pixels, DDR requests or publications.
//
// kate - The first Phase 1T-e candidate attempted the whole Table B.10 decode,
// residual decode and 7.6.3.1 reconstruction in one combinational path.  Real
// TimeQuest evidence showed that implementation violated the 54 MHz decoder
// setup requirement.  This implementation intentionally consumes the captured
// first-macroblock prefix over multiple clocks.  No timing exception is used.
//
// kate - Phase 1T-f is the final address-generation proof before an actual
// reference DDR transaction is added.  H.262 frame motion vectors are in
// half-sample units.  For the controlled first luma sample at current x=7,
// vector x=0 addresses luma sample 7 (DDR word 0) and vector x=4 addresses
// luma sample 9 (DDR word 1).  USER success is therefore withheld until the
// vector-to-integer-sample conversion crosses the expected 8-pixel DDR word
// boundary.  The 8-pixel packing is an implementation choice of this core.
//
// Phase 1T-f controlled diagnostic boundary:
//   - non-scalable progressive frame P picture;
//   - frame_pred_frame_dct == 1, therefore frame-based prediction is implied;
//   - first macroblock_address_increment == 1;
//   - all seven Table B.3 macroblock_type VLCs remain recognized;
//   - a non-intra P macroblock without macroblock_motion_forward derives the
//     normative implicit zero prediction vector and reference word 0;
//   - a macroblock with macroblock_motion_forward decodes both forward motion
//     components using Table B.10, f_code-1 residuals and 7.6.3.1 reconstruction;
//   - the controlled coded-motion vector is vector'[0][0] == (4, 0) and derives
//     reference luma word index 1 for current sample x=7.
//
// The final (4,0) and word-index checks are hardware-test restrictions, not
// H.262 validity rules.  They deliberately keep the reconstructed vector and
// storage-address boundary in the USER proof until the next phase performs the
// corresponding reference DDR read.
//============================================================================

module mpeg2_h262_p_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_expected,

    // Historical name retained at the wrapper boundary.  From Phase 1T-f this
    // positive result means the first P macroblock type, required prediction
    // vector semantics and controlled reference-word derivation are verified.
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

// Ten bytes are retained only as a bounded diagnostic prefix.  The decoder FSM
// below then consumes those bits over multiple clocks so no long dynamic VLC /
// arithmetic path is placed between registers.
reg        slice_capture_active;
reg [3:0]  slice_payload_count;
reg [79:0] slice_payload_shift;
reg        decode_pending;
reg        decode_active;
reg [79:0] decode_shift;

localparam [4:0]
    D_IDLE          = 5'd0,
    D_QSCALE        = 5'd1,
    D_SLICE_EXT     = 5'd2,
    D_EXTRA_BIT     = 5'd3,
    D_MBA           = 5'd4,
    D_MBTYPE        = 5'd5,
    D_MB_QUANT      = 5'd6,
    D_IMPLICIT_ZERO = 5'd7,
    D_INTRA_DONE    = 5'd8,
    D_MOTION_PREP   = 5'd9,
    D_MCODE_BIT     = 5'd10,
    D_RESIDUAL_BIT  = 5'd11,
    D_RECONSTRUCT   = 5'd12;

reg [4:0] decode_state;
reg       mb_motion_forward;
reg       mb_intra;

reg        motion_component_vertical;
reg [10:0] vlc_accum;
reg [3:0]  vlc_length;
reg signed [5:0] motion_code_reg;
reg [7:0]  motion_residual_reg;
reg [3:0]  residual_bits_remaining;
reg signed [12:0] forward_vector_x;
reg signed [12:0] forward_vector_y;

wire [3:0] current_forward_f_code =
    motion_component_vertical ?
        p_forward_f_code_vertical :
        p_forward_f_code_horizontal;

function automatic f_code_supported_for_probe;
    input [3:0] code;
    begin
        // H.262 permits 1..9 or 15.  A used motion-vector component uses 1..9.
        f_code_supported_for_probe =
            (code >= 4'd1) && (code <= 4'd9);
    end
endfunction

// Match one complete Table B.10 codeword.  bits contains the accumulated VLC in
// its least-significant len bits.  Return {valid, signed motion_code[5:0]}.
function automatic [6:0] match_motion_code;
    input [10:0] bits;
    input [3:0]  len;
    reg          valid;
    reg signed [5:0] value;
    begin
        valid = 1'b0;
        value = 6'sd0;

        case (len)
            4'd1: begin
                if (bits[0] == 1'b1) begin valid=1'b1; value= 6'sd0; end
            end
            4'd3: begin
                case (bits[2:0])
                    3'b010: begin valid=1'b1; value= 6'sd1; end
                    3'b011: begin valid=1'b1; value=-6'sd1; end
                    default: ;
                endcase
            end
            4'd4: begin
                case (bits[3:0])
                    4'b0010: begin valid=1'b1; value= 6'sd2; end
                    4'b0011: begin valid=1'b1; value=-6'sd2; end
                    default: ;
                endcase
            end
            4'd5: begin
                case (bits[4:0])
                    5'b00010: begin valid=1'b1; value= 6'sd3; end
                    5'b00011: begin valid=1'b1; value=-6'sd3; end
                    default: ;
                endcase
            end
            4'd7: begin
                case (bits[6:0])
                    7'b0000110: begin valid=1'b1; value= 6'sd4; end
                    7'b0000111: begin valid=1'b1; value=-6'sd4; end
                    default: ;
                endcase
            end
            4'd8: begin
                case (bits[7:0])
                    8'b00001010: begin valid=1'b1; value= 6'sd5; end
                    8'b00001011: begin valid=1'b1; value=-6'sd5; end
                    8'b00001000: begin valid=1'b1; value= 6'sd6; end
                    8'b00001001: begin valid=1'b1; value=-6'sd6; end
                    8'b00000110: begin valid=1'b1; value= 6'sd7; end
                    8'b00000111: begin valid=1'b1; value=-6'sd7; end
                    default: ;
                endcase
            end
            4'd10: begin
                case (bits[9:0])
                    10'b0000010110: begin valid=1'b1; value= 6'sd8; end
                    10'b0000010111: begin valid=1'b1; value=-6'sd8; end
                    10'b0000010100: begin valid=1'b1; value= 6'sd9; end
                    10'b0000010101: begin valid=1'b1; value=-6'sd9; end
                    10'b0000010010: begin valid=1'b1; value= 6'sd10; end
                    10'b0000010011: begin valid=1'b1; value=-6'sd10; end
                    default: ;
                endcase
            end
            4'd11: begin
                case (bits[10:0])
                    11'b00000100010: begin valid=1'b1; value= 6'sd11; end
                    11'b00000100011: begin valid=1'b1; value=-6'sd11; end
                    11'b00000100000: begin valid=1'b1; value= 6'sd12; end
                    11'b00000100001: begin valid=1'b1; value=-6'sd12; end
                    11'b00000011110: begin valid=1'b1; value= 6'sd13; end
                    11'b00000011111: begin valid=1'b1; value=-6'sd13; end
                    11'b00000011100: begin valid=1'b1; value= 6'sd14; end
                    11'b00000011101: begin valid=1'b1; value=-6'sd14; end
                    11'b00000011010: begin valid=1'b1; value= 6'sd15; end
                    11'b00000011011: begin valid=1'b1; value=-6'sd15; end
                    11'b00000011000: begin valid=1'b1; value= 6'sd16; end
                    11'b00000011001: begin valid=1'b1; value=-6'sd16; end
                    default: ;
                endcase
            end
            default: ;
        endcase

        match_motion_code = {valid, value[5:0]};
    end
endfunction

wire [10:0] vlc_accum_next = {vlc_accum[9:0], decode_shift[79]};
wire [3:0]  vlc_length_next = vlc_length + 4'd1;
wire [6:0]  motion_match = match_motion_code(vlc_accum_next, vlc_length_next);
wire signed [5:0] motion_match_value = $signed(motion_match[5:0]);

// H.262 7.6.3.1 with PMV == 0 at the beginning of a slice.  The fixed shifts
// keep this arithmetic small and bounded; Table B.10 VLC traversal is already
// complete before this function is evaluated for the registered component.
function automatic signed [12:0] reconstruct_zero_pmv_delta;
    input signed [5:0] code;
    input [3:0]        f_code;
    input [7:0]        residual;
    reg [5:0]          abs_code;
    reg [12:0]         abs_minus_one;
    reg [12:0]         magnitude;
    begin
        abs_code = code[5] ? -code : code;
        abs_minus_one = {7'd0, abs_code} - 13'd1;
        magnitude = 13'd0;

        if ((f_code == 4'd1) || (code == 6'sd0)) begin
            reconstruct_zero_pmv_delta = {{7{code[5]}}, code};
        end
        else begin
            case (f_code)
                4'd2: magnitude = (abs_minus_one << 1) + residual + 13'd1;
                4'd3: magnitude = (abs_minus_one << 2) + residual + 13'd1;
                4'd4: magnitude = (abs_minus_one << 3) + residual + 13'd1;
                4'd5: magnitude = (abs_minus_one << 4) + residual + 13'd1;
                4'd6: magnitude = (abs_minus_one << 5) + residual + 13'd1;
                4'd7: magnitude = (abs_minus_one << 6) + residual + 13'd1;
                4'd8: magnitude = (abs_minus_one << 7) + residual + 13'd1;
                4'd9: magnitude = (abs_minus_one << 8) + residual + 13'd1;
                default: magnitude = 13'd0;
            endcase

            if (code[5])
                reconstruct_zero_pmv_delta = -$signed(magnitude);
            else
                reconstruct_zero_pmv_delta = $signed(magnitude);
        end
    end
endfunction

wire signed [12:0] reconstructed_component =
    reconstruct_zero_pmv_delta(
        motion_code_reg,
        current_forward_f_code,
        motion_residual_reg);

function automatic reconstructed_component_in_range;
    input signed [12:0] value;
    input [3:0]         f_code;
    begin
        case (f_code)
            4'd1: reconstructed_component_in_range =
                (value >= -13'sd16) && (value <= 13'sd15);
            4'd2: reconstructed_component_in_range =
                (value >= -13'sd32) && (value <= 13'sd31);
            4'd3: reconstructed_component_in_range =
                (value >= -13'sd64) && (value <= 13'sd63);
            4'd4: reconstructed_component_in_range =
                (value >= -13'sd128) && (value <= 13'sd127);
            4'd5: reconstructed_component_in_range =
                (value >= -13'sd256) && (value <= 13'sd255);
            4'd6: reconstructed_component_in_range =
                (value >= -13'sd512) && (value <= 13'sd511);
            4'd7: reconstructed_component_in_range =
                (value >= -13'sd1024) && (value <= 13'sd1023);
            4'd8: reconstructed_component_in_range =
                (value >= -13'sd2048) && (value <= 13'sd2047);
            4'd9: reconstructed_component_in_range =
                (value >= -13'sd4096) && (value <= 13'sd4095);
            default: reconstructed_component_in_range = 1'b0;
        endcase
    end
endfunction

// kate - Phase 1T-f controlled luma reference-word derivation.  The selected
// current sample is x=7 so vector x=4 half-samples moves the integer prediction
// location to x=9 and across the 8-pixel DDR packing boundary into word 1.
wire signed [12:0] controlled_integer_dx = forward_vector_x >>> 1;
wire signed [13:0] controlled_reference_x = 14'sd7 + controlled_integer_dx;
wire [10:0] controlled_reference_word = controlled_reference_x[13:3];

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
        decode_active                  <= 1'b0;
        decode_shift                   <= 80'd0;
        decode_state                   <= D_IDLE;
        mb_motion_forward              <= 1'b0;
        mb_intra                       <= 1'b0;
        motion_component_vertical      <= 1'b0;
        vlc_accum                      <= 11'd0;
        vlc_length                     <= 4'd0;
        motion_code_reg                <= 6'sd0;
        motion_residual_reg            <= 8'd0;
        residual_bits_remaining        <= 4'd0;
        forward_vector_x               <= 13'sd0;
        forward_vector_y               <= 13'sd0;
        p_macroblock_type_seen         <= 1'b0;
        probe_error                    <= 1'b0;
    end
    else begin
        // Start the multi-cycle decode only after all ten captured bytes have
        // reached slice_payload_shift.  Stream reception continues passively.
        if (decode_pending) begin
            decode_pending            <= 1'b0;
            decode_active             <= 1'b1;
            decode_shift              <= slice_payload_shift;
            decode_state              <= D_QSCALE;
            mb_motion_forward         <= 1'b0;
            mb_intra                  <= 1'b0;
            motion_component_vertical <= 1'b0;
            vlc_accum                 <= 11'd0;
            vlc_length                <= 4'd0;
            motion_code_reg           <= 6'sd0;
            motion_residual_reg       <= 8'd0;
            residual_bits_remaining   <= 4'd0;
            forward_vector_x          <= 13'sd0;
            forward_vector_y          <= 13'sd0;
        end

        if (decode_active) begin
            case (decode_state)
                D_QSCALE: begin
                    if (decode_shift[79:75] == 5'd0) begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                    else begin
                        decode_shift <= decode_shift << 5;
                        decode_state <= D_SLICE_EXT;
                    end
                end

                D_SLICE_EXT: begin
                    // H.262 slice_extension_flag is consumed only when the
                    // next bit is one; otherwise that same zero is the following
                    // extra_bit_slice terminator.
                    if (decode_shift[79]) begin
                        decode_shift <= decode_shift << 9;
                    end
                    decode_state <= D_EXTRA_BIT;
                end

                D_EXTRA_BIT: begin
                    if (decode_shift[79] != 1'b0) begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                    else begin
                        decode_shift <= decode_shift << 1;
                        decode_state <= D_MBA;
                    end
                end

                D_MBA: begin
                    // Controlled stream restriction: first MBA increment is the
                    // one-bit Table B.1 code for value 1.
                    if (decode_shift[79] != 1'b1) begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                    else begin
                        decode_shift <= decode_shift << 1;
                        decode_state <= D_MBTYPE;
                    end
                end

                D_MBTYPE: begin
                    // H.262 Annex B Table B.3, non-scalable P picture.
                    if (decode_shift[79] == 1'b1) begin
                        // 1: motion_forward + pattern
                        mb_motion_forward <= 1'b1;
                        mb_intra          <= 1'b0;
                        decode_shift      <= decode_shift << 1;
                        decode_state      <= D_MOTION_PREP;
                    end
                    else if (decode_shift[79:78] == 2'b01) begin
                        // 01: pattern; P frame uses implicit (0,0) prediction.
                        mb_motion_forward <= 1'b0;
                        mb_intra          <= 1'b0;
                        decode_shift      <= decode_shift << 2;
                        decode_state      <= D_IMPLICIT_ZERO;
                    end
                    else if (decode_shift[79:77] == 3'b001) begin
                        // 001: motion_forward
                        mb_motion_forward <= 1'b1;
                        mb_intra          <= 1'b0;
                        decode_shift      <= decode_shift << 3;
                        decode_state      <= D_MOTION_PREP;
                    end
                    else if (decode_shift[79:75] == 5'b00011) begin
                        // 00011: intra
                        mb_motion_forward <= 1'b0;
                        mb_intra          <= 1'b1;
                        decode_shift      <= decode_shift << 5;
                        decode_state      <= D_INTRA_DONE;
                    end
                    else if (decode_shift[79:75] == 5'b00010) begin
                        // 00010: quant + motion_forward + pattern
                        mb_motion_forward <= 1'b1;
                        mb_intra          <= 1'b0;
                        decode_shift      <= decode_shift << 5;
                        decode_state      <= D_MB_QUANT;
                    end
                    else if (decode_shift[79:75] == 5'b00001) begin
                        // 00001: quant + pattern
                        mb_motion_forward <= 1'b0;
                        mb_intra          <= 1'b0;
                        decode_shift      <= decode_shift << 5;
                        decode_state      <= D_MB_QUANT;
                    end
                    else if (decode_shift[79:74] == 6'b000001) begin
                        // 000001: quant + intra
                        mb_motion_forward <= 1'b0;
                        mb_intra          <= 1'b1;
                        decode_shift      <= decode_shift << 6;
                        decode_state      <= D_MB_QUANT;
                    end
                    else begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                end

                D_MB_QUANT: begin
                    // macroblock_quantiser_scale_code is a five-bit syntax field.
                    decode_shift <= decode_shift << 5;
                    if (mb_intra)
                        decode_state <= D_INTRA_DONE;
                    else if (mb_motion_forward)
                        decode_state <= D_MOTION_PREP;
                    else
                        decode_state <= D_IMPLICIT_ZERO;
                end

                D_IMPLICIT_ZERO: begin
                    // H.262 7.6.3.5: in a P frame, a non-intra macroblock with
                    // macroblock_motion_forward==0 forms prediction with (0,0).
                    // Phase 1T-f also proves current x=7 remains in DDR word 0.
                    if (!p_picture_controls_seen ||
                        (p_picture_structure != 2'b11) ||
                        !p_frame_pred_frame_dct) begin
                        probe_error <= 1'b1;
                    end
                    else begin
                        forward_vector_x <= 13'sd0;
                        forward_vector_y <= 13'sd0;
                        if (((14'sd7 + (13'sd0 >>> 1)) >>> 3) == 14'sd0)
                            p_macroblock_type_seen <= 1'b1;
                        else
                            probe_error <= 1'b1;
                    end
                    decode_active <= 1'b0;
                    decode_state  <= D_IDLE;
                end

                D_INTRA_DONE: begin
                    // An ordinary intra P macroblock carries no prediction vector.
                    p_macroblock_type_seen <= 1'b1;
                    decode_active          <= 1'b0;
                    decode_state           <= D_IDLE;
                end

                D_MOTION_PREP: begin
                    if (!p_picture_controls_seen ||
                        (p_picture_structure != 2'b11) ||
                        !p_frame_pred_frame_dct ||
                        !f_code_supported_for_probe(p_forward_f_code_horizontal) ||
                        !f_code_supported_for_probe(p_forward_f_code_vertical)) begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                    else begin
                        motion_component_vertical <= 1'b0;
                        vlc_accum                 <= 11'd0;
                        vlc_length                <= 4'd0;
                        motion_code_reg           <= 6'sd0;
                        motion_residual_reg       <= 8'd0;
                        residual_bits_remaining   <= 4'd0;
                        decode_state               <= D_MCODE_BIT;
                    end
                end

                D_MCODE_BIT: begin
                    // One Table B.10 bit per clock.  This is deliberately not a
                    // variable-position combinational walk.
                    decode_shift <= decode_shift << 1;
                    vlc_accum    <= vlc_accum_next;
                    vlc_length   <= vlc_length_next;

                    if (motion_match[6]) begin
                        motion_code_reg         <= motion_match_value;
                        motion_residual_reg     <= 8'd0;
                        vlc_accum               <= 11'd0;
                        vlc_length              <= 4'd0;

                        if ((motion_match_value == 6'sd0) ||
                            (current_forward_f_code == 4'd1)) begin
                            residual_bits_remaining <= 4'd0;
                            decode_state             <= D_RECONSTRUCT;
                        end
                        else begin
                            residual_bits_remaining <=
                                current_forward_f_code - 4'd1;
                            decode_state <= D_RESIDUAL_BIT;
                        end
                    end
                    else if (vlc_length_next == 4'd11) begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                end

                D_RESIDUAL_BIT: begin
                    decode_shift <= decode_shift << 1;
                    motion_residual_reg <=
                        {motion_residual_reg[6:0], decode_shift[79]};

                    if (residual_bits_remaining == 4'd1) begin
                        residual_bits_remaining <= 4'd0;
                        decode_state             <= D_RECONSTRUCT;
                    end
                    else begin
                        residual_bits_remaining <=
                            residual_bits_remaining - 4'd1;
                    end
                end

                D_RECONSTRUCT: begin
                    // H.262 7.6.3.4 resets PMV at slice start, so the controlled
                    // first vector equals the reconstructed differential here.
                    if (!reconstructed_component_in_range(
                            reconstructed_component,
                            current_forward_f_code)) begin
                        probe_error   <= 1'b1;
                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                    else if (!motion_component_vertical) begin
                        forward_vector_x          <= reconstructed_component;
                        motion_component_vertical <= 1'b1;
                        vlc_accum                 <= 11'd0;
                        vlc_length                <= 4'd0;
                        motion_code_reg           <= 6'sd0;
                        motion_residual_reg       <= 8'd0;
                        residual_bits_remaining   <= 4'd0;
                        decode_state               <= D_MCODE_BIT;
                    end
                    else begin
                        forward_vector_y <= reconstructed_component;

                        // Controlled test_ip_motion_end.m2v proof: the first
                        // forward luminance vector must reconstruct to (4,0).
                        // Phase 1T-f additionally proves that +4 half-samples is
                        // +2 integer luma samples, moving current x=7 to x=9 and
                        // therefore selecting packed DDR luma word index 1.
                        if ((forward_vector_x == 13'sd4) &&
                            (reconstructed_component == 13'sd0) &&
                            (controlled_integer_dx == 13'sd2) &&
                            (controlled_reference_x == 14'sd9) &&
                            (controlled_reference_word == 11'd1)) begin
                            p_macroblock_type_seen <= 1'b1;
                        end
                        else begin
                            probe_error <= 1'b1;
                        end

                        decode_active <= 1'b0;
                        decode_state  <= D_IDLE;
                    end
                end

                default: begin
                    probe_error   <= 1'b1;
                    decode_active <= 1'b0;
                    decode_state  <= D_IDLE;
                end
            endcase
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
                        p_forward_f_code_horizontal <= pce_payload_next[35:32];
                        p_forward_f_code_vertical   <= pce_payload_next[31:28];
                        p_picture_structure         <= pce_payload_next[17:16];
                        p_frame_pred_frame_dct      <= pce_payload_next[14];
                        p_picture_controls_seen     <= 1'b1;
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
                     !decode_pending && !decode_active && !probe_error) begin
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
