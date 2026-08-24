//============================================================================
// MiSTer Media Player - new H.262 decoder front end
//
// Passive first-stage parser used while the legacy MPEG2FPGA decoder remains
// connected to the video path.  This module observes the exact elementary-
// stream bytes accepted by the decoder and validates the fundamental H.262
// header hierarchy before we move decode ownership to the new implementation.
//
// Standards basis:
//   ITU-T H.262 (02/2000) / ISO/IEC 13818-2:2000
//   - 5.2.3 next_start_code()
//   - 6.2.1 start codes / Table 6-1
//   - 6.2.2.1 sequence_header()
//   - 6.2.2.3 sequence_extension()
//   - 6.2.3 picture_header()
//   - 6.2.3.1 picture_coding_extension()
//   - 6.3.3 frame_rate_code / Table 6-4
//   - 6.3.9 temporal_reference
//   - 6.3.10 picture coding extension semantics / f_code
//   - 6.3.11 quantisation matrix reset/download semantics
//   - 7.6.3.1 motion-vector decoding
//   - Table 6-2 extension_start_code_identifier
//   - Table 6-12 picture_coding_type
//   ITU-T H.222.0 / ISO/IEC 13818-1
//   - PTS is 33 bits and uses the 90 kHz system-clock/300 timebase.
//
// kate - New decoder work starts here.  Keep syntax requirements separate
// from implementation-support restrictions so valid H.262 is never labelled
// malformed merely because an early decoder milestone cannot decode it yet.
//============================================================================

module mpeg2_h262_frontend
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,

    output wire        frontend_ready,
    output wire        phase1_supported,
    output reg         syntax_error,
    // Commit 188 observability: stable first assertion site, 1..21.
    output reg  [4:0]  syntax_error_source,

    output reg         sequence_seen,
    output reg         sequence_extension_seen,
    output reg         sequence_scalable_extension_seen,
    output reg         picture_seen,
    output reg         picture_coding_extension_seen,
    output reg         slice_seen,
    output reg         sequence_end_seen,

    output reg  [13:0] horizontal_size,
    output reg  [13:0] vertical_size,
    output reg  [3:0]  aspect_ratio_information,
    output reg  [3:0]  frame_rate_code,
    output reg  [1:0]  frame_rate_extension_n,
    output reg  [4:0]  frame_rate_extension_d,
    output reg  [7:0]  profile_and_level_indication,
    output reg         progressive_sequence,
    output reg  [1:0]  chroma_format,

    output reg  [9:0]  temporal_reference,
    output reg  [2:0]  picture_coding_type,
    output reg  [1:0]  intra_dc_precision,
    output reg  [1:0]  picture_structure,
    output reg         frame_pred_frame_dct,
    output reg         concealment_motion_vectors,
    output reg         q_scale_type,
    output reg         intra_vlc_format,
    output reg         alternate_scan,
    output reg         progressive_frame,
    output reg         chroma_420_type,
    // Interlaced-output and pulldown signalling already lies inside the
    // five-byte picture_coding_extension window.  The bounded capability gate
    // consumes repeat/chroma state now; authored field order is carried onward
    // for the following native-presentation milestone.
    output reg         top_field_first,
    output reg         repeat_first_field,

    // kate - Phase 1T-b exposes the four H.262 f_code controls needed by the
    // future motion-vector decoder.  Index mapping follows H.262 Table 7-7:
    // [0][0] forward horizontal, [0][1] forward vertical,
    // [1][0] backward horizontal, [1][1] backward vertical.
    output reg  [3:0]  forward_f_code_horizontal,
    output reg  [3:0]  forward_f_code_vertical,
    output reg  [3:0]  backward_f_code_horizontal,
    output reg  [3:0]  backward_f_code_vertical,
    output reg         motion_f_code_seen,

    // kate - Phase 1S timing foundation.  These are local elementary-stream
    // schedule metadata, not PES PTS values: the current .m2v input has no
    // H.222.0 PES layer from which a normative PTS could be read.  The local
    // schedule deliberately uses the same 33-bit / 90 kHz representation so a
    // later H.222.0 demux can replace the synthetic source without changing the
    // downstream timestamp width or units.
    output reg         timing_seen,
    output reg         timing_advanced,
    output reg         timing_unsupported,
    output reg         timing_error,
    output reg  [32:0] timing_picture_time_90k,
    output reg  [9:0]  timing_picture_temporal_reference,

    // kate - Phase 1D currently implements the normative default intra
    // quantisation matrix.  A downloaded matrix is valid H.262 but is kept
    // as a separate capability boundary until matrix download support lands.
    output reg         intra_quant_matrix_default
);

localparam [7:0]
    PICTURE_START_CODE         = 8'h00,
    USER_DATA_START_CODE       = 8'hB2,
    SEQUENCE_HEADER_CODE       = 8'hB3,
    SEQUENCE_ERROR_CODE        = 8'hB4,
    EXTENSION_START_CODE       = 8'hB5,
    SEQUENCE_END_CODE          = 8'hB7,
    GROUP_START_CODE           = 8'hB8;

localparam [3:0]
    EXT_SEQUENCE               = 4'h1,
    EXT_SEQUENCE_DISPLAY       = 4'h2,
    EXT_QUANT_MATRIX           = 4'h3,
    EXT_SEQUENCE_SCALABLE      = 4'h5,
    EXT_PICTURE_DISPLAY        = 4'h7,
    EXT_PICTURE_CODING         = 4'h8,
    EXT_PICTURE_SPATIAL        = 4'h9,
    EXT_PICTURE_TEMPORAL       = 4'hA;

reg [31:0] byte_window;
reg [7:0]  active_start_code;
reg        active_start_code_valid;
reg [6:0]  payload_byte_index;
reg [63:0] payload_shift;
reg [3:0]  active_extension_id;
reg        active_extension_id_valid;

reg        expect_sequence_extension;
reg        expect_picture_coding_extension;
reg        first_picture_after_gop;

reg [11:0] horizontal_size_value;
reg [11:0] vertical_size_value;

// kate - Phase 1S synthetic elementary-stream presentation timeline.
// H.222.0 timestamps use integer 90 kHz units.  Two direct H.262 rates have
// fractional 90 kHz periods (24000/1001 and 60000/1001), so keep cumulative
// time internally in quarter-ticks.  That represents every direct Table 6-4
// frame period exactly and avoids long-term rounding drift.  The visible
// 33-bit value is floor(cumulative quarter-ticks / 4), matching integer PTS
// units when a real systems-layer source is added later.
reg [34:0] timing_next_time_quarters;
reg [32:0] timing_last_picture_time_90k;
reg [7:0]  timing_picture_count;

function automatic [15:0] direct_frame_duration_quarters;
    input [3:0] code;
    begin
        case (code)
            // 90 000 * frame_period * 4, from H.262 Table 6-4.
            4'h1: direct_frame_duration_quarters = 16'd15015; // 24000/1001
            4'h2: direct_frame_duration_quarters = 16'd15000; // 24
            4'h3: direct_frame_duration_quarters = 16'd14400; // 25
            4'h4: direct_frame_duration_quarters = 16'd12012; // 30000/1001
            4'h5: direct_frame_duration_quarters = 16'd12000; // 30
            4'h6: direct_frame_duration_quarters = 16'd7200;  // 50
            4'h7: direct_frame_duration_quarters = 16'd6006;  // 60000/1001
            4'h8: direct_frame_duration_quarters = 16'd6000;  // 60
            default:
                direct_frame_duration_quarters = 16'd0;
        endcase
    end
endfunction

wire [15:0] timing_frame_duration_quarters =
    direct_frame_duration_quarters(frame_rate_code);

// Implementation boundary only: this first scheduler handles the direct rates
// in H.262 Table 6-4.  Non-zero frame_rate_extension_n/d are valid H.262, but
// their rational scaling is deferred rather than silently assigning a wrong
// presentation time.
wire timing_direct_rate_supported =
    (timing_frame_duration_quarters != 16'd0) &&
    (frame_rate_extension_n == 2'd0) &&
    (frame_rate_extension_d == 5'd0);

wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire [63:0] payload_next     = {payload_shift[55:0], stream_data};

// kate - Phase 1T-b keeps the registered motion-vector control fields in the
// active I-picture support gate so the existing hardware regression proves that
// these new sideband outputs are real captured state, not dead/debug-only RTL.
// H.262 6.3.10 requires all four f_code values to be 15 in the current supported
// I-picture subset because concealment_motion_vectors is also required to be 0.
wire phase1_i_f_code_state_valid =
    motion_f_code_seen &&
    (forward_f_code_horizontal  == 4'hF) &&
    (forward_f_code_vertical    == 4'hF) &&
    (backward_f_code_horizontal == 4'hF) &&
    (backward_f_code_vertical   == 4'hF);

// These are capability limits, not H.262 syntax-validity rules.  The
// native-interlaced I subset deliberately reuses only frame-DCT/frame-predicted
// complete frame pictures; field pictures, field DCT/motion and repeated fields
// remain outside the gate.  concealment_motion_vectors is likewise excluded
// until the intra-macroblock motion-vector syntax is implemented.
assign frontend_ready =
    sequence_seen &&
    sequence_extension_seen &&
    picture_seen &&
    picture_coding_extension_seen &&
    slice_seen &&
    !syntax_error;

wire phase1_progressive_i_frame =
    progressive_sequence &&
    progressive_frame &&
    chroma_420_type;

// H262-028 through H262-034: a 30000/1001 interlaced sequence may carry a
// complete interlaced frame picture.  With frame_pred_frame_dct set, the
// existing frame raster remains the normative transform/prediction mapping;
// TFF/BFF affects later field presentation, not reconstruction coordinates.
wire phase1_native_480i_i_frame =
    !progressive_sequence &&
    !progressive_frame &&
    !chroma_420_type &&
    !repeat_first_field &&
    (horizontal_size == 14'd720) &&
    (vertical_size == 14'd480) &&
    (frame_rate_code == 4'h4);

assign phase1_supported =
    frontend_ready &&
    !sequence_scalable_extension_seen &&
    (chroma_format == 2'b01) &&
    (picture_coding_type == 3'b001) &&
    (picture_structure == 2'b11) &&
    frame_pred_frame_dct &&
    !concealment_motion_vectors &&
    (phase1_progressive_i_frame || phase1_native_480i_i_frame) &&
    phase1_i_f_code_state_valid &&
    !timing_unsupported &&
    !timing_error;

always @(posedge clk) begin
    if (reset) begin
        byte_window                         <= 32'd0;
        active_start_code                   <= 8'd0;
        active_start_code_valid             <= 1'b0;
        payload_byte_index                  <= 7'd0;
        payload_shift                       <= 64'd0;
        active_extension_id                 <= 4'd0;
        active_extension_id_valid           <= 1'b0;

        expect_sequence_extension           <= 1'b0;
        expect_picture_coding_extension     <= 1'b0;
        first_picture_after_gop             <= 1'b0;

        syntax_error                        <= 1'b0;
        syntax_error_source                 <= 5'd0;
        sequence_seen                       <= 1'b0;
        sequence_extension_seen             <= 1'b0;
        sequence_scalable_extension_seen    <= 1'b0;
        picture_seen                        <= 1'b0;
        picture_coding_extension_seen       <= 1'b0;
        slice_seen                          <= 1'b0;
        sequence_end_seen                   <= 1'b0;

        horizontal_size_value               <= 12'd0;
        vertical_size_value                 <= 12'd0;
        horizontal_size                     <= 14'd0;
        vertical_size                       <= 14'd0;
        aspect_ratio_information            <= 4'd0;
        frame_rate_code                     <= 4'd0;
        frame_rate_extension_n               <= 2'd0;
        frame_rate_extension_d               <= 5'd0;
        profile_and_level_indication        <= 8'd0;
        progressive_sequence                <= 1'b0;
        chroma_format                       <= 2'd0;

        temporal_reference                  <= 10'd0;
        picture_coding_type                 <= 3'd0;
        intra_dc_precision                  <= 2'd0;
        picture_structure                   <= 2'd0;
        frame_pred_frame_dct                <= 1'b0;
        concealment_motion_vectors          <= 1'b0;
        q_scale_type                        <= 1'b0;
        intra_vlc_format                    <= 1'b0;
        alternate_scan                      <= 1'b0;
        progressive_frame                   <= 1'b0;
        chroma_420_type                      <= 1'b0;
        top_field_first                     <= 1'b0;
        repeat_first_field                  <= 1'b0;
        forward_f_code_horizontal           <= 4'd0;
        forward_f_code_vertical             <= 4'd0;
        backward_f_code_horizontal          <= 4'd0;
        backward_f_code_vertical            <= 4'd0;
        motion_f_code_seen                  <= 1'b0;

        timing_seen                         <= 1'b0;
        timing_advanced                     <= 1'b0;
        timing_unsupported                  <= 1'b0;
        timing_error                        <= 1'b0;
        timing_picture_time_90k             <= 33'd0;
        timing_picture_temporal_reference   <= 10'd0;
        timing_next_time_quarters           <= 35'd0;
        timing_last_picture_time_90k        <= 33'd0;
        timing_picture_count                <= 8'd0;

        intra_quant_matrix_default           <= 1'b1;
    end
    else if (stream_valid) begin
        byte_window <= byte_window_next;

        if (start_code_now) begin
            // H.262 6.2 requires sequence_extension immediately after a
            // sequence_header, and picture_coding_extension immediately
            // after each MPEG-2 picture_header.  The B5 byte identifies an
            // extension; its four-bit ID is checked on the following byte.
            if (expect_sequence_extension &&
                (start_code_value != EXTENSION_START_CODE)) begin
                syntax_error <= 1'b1;
                if (!syntax_error) syntax_error_source <= 5'd1;
            end

            if (expect_picture_coding_extension &&
                (start_code_value != EXTENSION_START_CODE)) begin
                syntax_error <= 1'b1;
                if (!syntax_error) syntax_error_source <= 5'd2;
            end

            active_start_code           <= start_code_value;
            active_start_code_valid     <= 1'b1;
            payload_byte_index          <= 7'd0;
            payload_shift               <= 64'd0;
            active_extension_id         <= 4'd0;
            active_extension_id_valid   <= 1'b0;

            case (start_code_value)
                SEQUENCE_HEADER_CODE: begin
                    expect_sequence_extension     <= 1'b1;
                    // H.262 6.3.11: every sequence header resets all
                    // quantisation matrices to their default values before
                    // any optional matrix download in that header.
                    intra_quant_matrix_default   <= 1'b1;
                end

                PICTURE_START_CODE: begin
                    expect_picture_coding_extension <= 1'b1;
                end

                GROUP_START_CODE: begin
                    first_picture_after_gop <= 1'b1;
                end

                SEQUENCE_ERROR_CODE: begin
                    // H.262 allocates this code for a media interface to mark
                    // an uncorrectable error location.
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd3;
                end

                SEQUENCE_END_CODE: begin
                    sequence_end_seen <= 1'b1;
                end

                default: begin
                    // Table 6-1: 0x01 through 0xAF are slice start codes.
                    if ((start_code_value >= 8'h01) &&
                        (start_code_value <= 8'hAF))
                        slice_seen <= 1'b1;
                end
            endcase
        end
        else if (active_start_code_valid) begin
            payload_shift      <= payload_next;
            payload_byte_index <= payload_byte_index + 1'b1;

            // sequence_header(): first 64 payload bits contain all fixed
            // fields through load_intra_quantiser_matrix.
            if ((active_start_code == SEQUENCE_HEADER_CODE) &&
                (payload_byte_index == 7)) begin
                horizontal_size_value    <= payload_next[63:52];
                vertical_size_value      <= payload_next[51:40];
                horizontal_size[11:0]    <= payload_next[63:52];
                vertical_size[11:0]      <= payload_next[51:40];
                horizontal_size[13:12]   <= 2'b00;
                vertical_size[13:12]     <= 2'b00;
                aspect_ratio_information <= payload_next[39:36];
                frame_rate_code          <= payload_next[35:32];
                sequence_seen            <= 1'b1;

                // marker_bit follows bit_rate_value and shall be one.
                if (!payload_next[13]) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd4;
                end

                // H.262 6.2.2.1/6.3.11: after the fixed sequence-header
                // fields, load_intra_quantiser_matrix is the 63rd payload
                // bit.  The 64-bit window places it at payload_next[1].
                // A value of one is fully valid H.262; Phase 1D simply does
                // not yet implement the downloaded matrix values.
                if (payload_next[1])
                    intra_quant_matrix_default <= 1'b0;
            end

            // extension_start_code_identifier is the first four payload bits.
            if ((active_start_code == EXTENSION_START_CODE) &&
                (payload_byte_index == 0)) begin
                active_extension_id       <= stream_data[7:4];
                active_extension_id_valid <= 1'b1;

                if (expect_sequence_extension &&
                    (stream_data[7:4] != EXT_SEQUENCE)) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd5;
                end

                if (expect_picture_coding_extension &&
                    (stream_data[7:4] != EXT_PICTURE_CODING)) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd6;
                end

                // kate - Phase 1 deliberately excludes H.262 scalable syntax.
                // Track it explicitly so an unsupported scalable stream is not
                // accidentally interpreted with the non-scalable slice grammar.
                if (stream_data[7:4] == EXT_SEQUENCE_SCALABLE)
                    sequence_scalable_extension_seen <= 1'b1;

                // Conservatively treat any quant_matrix_extension as a
                // Phase 1D matrix-download capability boundary.  The
                // extension itself is valid H.262 and is not a syntax error.
                // Later phases will parse its individual load flags/matrices.
                if (stream_data[7:4] == EXT_QUANT_MATRIX)
                    intra_quant_matrix_default <= 1'b0;
            end

            // sequence_extension(): 48 payload bits.
            if ((active_start_code == EXTENSION_START_CODE) &&
                active_extension_id_valid &&
                (active_extension_id == EXT_SEQUENCE) &&
                (payload_byte_index == 5)) begin
                profile_and_level_indication <= payload_next[43:36];
                progressive_sequence         <= payload_next[35];
                chroma_format                <= payload_next[34:33];
                horizontal_size[13:12]       <= payload_next[32:31];
                horizontal_size[11:0]        <= horizontal_size_value;
                vertical_size[13:12]         <= payload_next[30:29];
                vertical_size[11:0]          <= vertical_size_value;
                frame_rate_extension_n       <= payload_next[6:5];
                frame_rate_extension_d       <= payload_next[4:0];
                sequence_extension_seen      <= 1'b1;
                expect_sequence_extension    <= 1'b0;

                // marker_bit in sequence_extension() shall be one.
                if (!payload_next[16]) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd7;
                end

                // chroma_format == 00 is reserved by H.262.
                if (payload_next[34:33] == 2'b00) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd8;
                end
            end

            // picture_header(): first 32 payload bits are sufficient for the
            // temporal reference, coding type and vbv_delay.
            if ((active_start_code == PICTURE_START_CODE) &&
                (payload_byte_index == 3)) begin
                temporal_reference  <= payload_next[31:22];
                picture_coding_type <= payload_next[21:19];
                picture_seen        <= 1'b1;

                // kate - Phase 1S timing metadata is attached at the picture
                // header, the same access-unit boundary to which a future PES
                // PTS refers.  Current all-I coded order is also display order.
                if (timing_picture_count != 8'hff)
                    timing_picture_count <= timing_picture_count + 8'd1;

                if (!timing_direct_rate_supported) begin
                    // This remains a capability boundary, never syntax_error:
                    // valid H.262 may use frame-rate extensions that this first
                    // local scheduler does not yet rationally scale.
                    timing_unsupported <= 1'b1;
                end
                else begin
                    timing_picture_time_90k <= timing_next_time_quarters[34:2];
                    timing_picture_temporal_reference <= payload_next[31:22];

                    if (timing_seen) begin
                        if (timing_next_time_quarters[34:2] >
                            timing_last_picture_time_90k)
                            timing_advanced <= 1'b1;
                        else
                            timing_error <= 1'b1;
                    end

                    timing_last_picture_time_90k <=
                        timing_next_time_quarters[34:2];
                    timing_next_time_quarters <=
                        timing_next_time_quarters +
                        {19'd0, timing_frame_duration_quarters};
                    timing_seen <= 1'b1;

                    // By the third picture header, the second timestamp must
                    // already have proved forward progress.  Since the Phase 1S
                    // USER diagnostic requires three persisted pictures, a
                    // complete playback with USER on now also proves this timing
                    // sideband progressed in hardware.
                    if ((timing_picture_count >= 8'd2) &&
                        !timing_advanced)
                        timing_error <= 1'b1;
                end

                // H.262 Table 6-12 defines 001 I, 010 P, 011 B.  000 is
                // forbidden; 100 shall not be used; 101-111 are reserved.
                if ((payload_next[21:19] < 3'b001) ||
                    (payload_next[21:19] > 3'b011)) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd9;
                end

                // H.262 requires the first coded frame after a GOP header to
                // be an I-frame.
                if (first_picture_after_gop) begin
                    if (payload_next[21:19] != 3'b001) begin
                        syntax_error <= 1'b1;
                        if (!syntax_error) syntax_error_source <= 5'd10;
                    end
                    first_picture_after_gop <= 1'b0;
                end
            end

            // picture_coding_extension(): progressive_frame is the 33rd bit,
            // so five payload bytes are enough to capture all fields we need.
            if ((active_start_code == EXTENSION_START_CODE) &&
                active_extension_id_valid &&
                (active_extension_id == EXT_PICTURE_CODING) &&
                (payload_byte_index == 4)) begin
                // H.262 6.2.3.1 picture_coding_extension() bit layout.
                // kate - Preserve fields that directly control block syntax,
                // coefficient reconstruction and future motion-vector decoding
                // instead of inferring defaults.
                forward_f_code_horizontal         <= payload_next[35:32];
                forward_f_code_vertical           <= payload_next[31:28];
                backward_f_code_horizontal        <= payload_next[27:24];
                backward_f_code_vertical          <= payload_next[23:20];
                motion_f_code_seen                <= 1'b1;
                intra_dc_precision               <= payload_next[19:18];
                picture_structure                 <= payload_next[17:16];
                frame_pred_frame_dct              <= payload_next[14];
                concealment_motion_vectors        <= payload_next[13];
                q_scale_type                      <= payload_next[12];
                intra_vlc_format                  <= payload_next[11];
                alternate_scan                    <= payload_next[10];
                top_field_first                   <= payload_next[15];
                repeat_first_field                <= payload_next[9];
                chroma_420_type                   <= payload_next[8];
                progressive_frame                 <= payload_next[7];
                picture_coding_extension_seen     <= 1'b1;
                expect_picture_coding_extension   <= 1'b0;

                // H.262 6.3.10: every f_code is a 4-bit unsigned value in
                // 1..9 or 15.  Zero is forbidden and 10..14 are reserved.
                if (!(((payload_next[35:32] >= 4'd1) &&
                      (payload_next[35:32] <= 4'd9)) ||
                      (payload_next[35:32] == 4'hF))) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd11;
                end
                if (!(((payload_next[31:28] >= 4'd1) &&
                       (payload_next[31:28] <= 4'd9)) ||
                      (payload_next[31:28] == 4'hF))) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd12;
                end
                if (!(((payload_next[27:24] >= 4'd1) &&
                       (payload_next[27:24] <= 4'd9)) ||
                      (payload_next[27:24] == 4'hF))) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd13;
                end
                if (!(((payload_next[23:20] >= 4'd1) &&
                       (payload_next[23:20] <= 4'd9)) ||
                      (payload_next[23:20] == 4'hF))) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd14;
                end

                // H.262 6.3.10: with no concealment motion vectors an I-picture
                // uses no motion vectors, so all four f_code values shall be 15.
                if ((picture_coding_type == 3'b001) &&
                    !payload_next[13] &&
                    (payload_next[35:20] != 16'hFFFF)) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd15;
                end

                // Backward motion vectors are unused in both I- and P-pictures;
                // the corresponding two f_code values shall therefore be 15.
                if (((picture_coding_type == 3'b001) ||
                     (picture_coding_type == 3'b010)) &&
                    (payload_next[27:20] != 8'hFF)) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd16;
                end

                // picture_structure == 00 is reserved.
                if (payload_next[17:16] == 2'b00) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd17;
                end

                // A progressive sequence contains only progressive frame
                // pictures; H.262 additionally requires frame structure.
                if (progressive_sequence) begin
                    if (payload_next[17:16] != 2'b11) begin
                        syntax_error <= 1'b1;
                        if (!syntax_error) syntax_error_source <= 5'd18;
                    end
                    if (!payload_next[14]) begin
                        syntax_error <= 1'b1;
                        if (!syntax_error) syntax_error_source <= 5'd19;
                    end
                    if (!payload_next[7]) begin
                        syntax_error <= 1'b1;
                        if (!syntax_error) syntax_error_source <= 5'd20;
                    end
                end

                // H.262 6.3.10: for 4:2:0 video chroma_420_type shall equal
                // progressive_frame.  This is syntax/semantic validity, not a
                // Phase 1 implementation restriction.
                if ((chroma_format == 2'b01) &&
                    (payload_next[8] != payload_next[7])) begin
                    syntax_error <= 1'b1;
                    if (!syntax_error) syntax_error_source <= 5'd21;
                end
            end
        end
    end
end

endmodule
