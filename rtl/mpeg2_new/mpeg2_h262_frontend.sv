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
//   - Table 6-2 extension_start_code_identifier
//   - Table 6-12 picture_coding_type
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

    output reg         sequence_seen,
    output reg         sequence_extension_seen,
    output reg         picture_seen,
    output reg         picture_coding_extension_seen,
    output reg         slice_seen,
    output reg         sequence_end_seen,

    output reg  [13:0] horizontal_size,
    output reg  [13:0] vertical_size,
    output reg  [3:0]  aspect_ratio_information,
    output reg  [3:0]  frame_rate_code,
    output reg  [7:0]  profile_and_level_indication,
    output reg         progressive_sequence,
    output reg  [1:0]  chroma_format,

    output reg  [9:0]  temporal_reference,
    output reg  [2:0]  picture_coding_type,
    output reg  [1:0]  picture_structure,
    output reg         progressive_frame
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

wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire [63:0] payload_next     = {payload_shift[55:0], stream_data};

// Phase 0 proves that we can identify the required H.262 hierarchy without
// disturbing legacy playback.  Phase 1 will initially decode progressive,
// 4:2:0, frame-picture I video; these are capability limits, not H.262 syntax
// validity rules.
assign frontend_ready =
    sequence_seen &&
    sequence_extension_seen &&
    picture_seen &&
    picture_coding_extension_seen &&
    slice_seen &&
    !syntax_error;

assign phase1_supported =
    frontend_ready &&
    progressive_sequence &&
    (chroma_format == 2'b01) &&
    (picture_coding_type == 3'b001) &&
    (picture_structure == 2'b11) &&
    progressive_frame;

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
        sequence_seen                       <= 1'b0;
        sequence_extension_seen             <= 1'b0;
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
        profile_and_level_indication        <= 8'd0;
        progressive_sequence                <= 1'b0;
        chroma_format                       <= 2'd0;

        temporal_reference                  <= 10'd0;
        picture_coding_type                 <= 3'd0;
        picture_structure                   <= 2'd0;
        progressive_frame                   <= 1'b0;
    end
    else if (stream_valid) begin
        byte_window <= byte_window_next;

        if (start_code_now) begin
            // H.262 6.2 requires sequence_extension immediately after a
            // sequence_header, and picture_coding_extension immediately
            // after each MPEG-2 picture_header.  The B5 byte identifies an
            // extension; its four-bit ID is checked on the following byte.
            if (expect_sequence_extension &&
                (start_code_value != EXTENSION_START_CODE))
                syntax_error <= 1'b1;

            if (expect_picture_coding_extension &&
                (start_code_value != EXTENSION_START_CODE))
                syntax_error <= 1'b1;

            active_start_code           <= start_code_value;
            active_start_code_valid     <= 1'b1;
            payload_byte_index          <= 7'd0;
            payload_shift               <= 64'd0;
            active_extension_id         <= 4'd0;
            active_extension_id_valid   <= 1'b0;

            case (start_code_value)
                SEQUENCE_HEADER_CODE: begin
                    expect_sequence_extension <= 1'b1;
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
                if (!payload_next[13])
                    syntax_error <= 1'b1;
            end

            // extension_start_code_identifier is the first four payload bits.
            if ((active_start_code == EXTENSION_START_CODE) &&
                (payload_byte_index == 0)) begin
                active_extension_id       <= stream_data[7:4];
                active_extension_id_valid <= 1'b1;

                if (expect_sequence_extension &&
                    (stream_data[7:4] != EXT_SEQUENCE))
                    syntax_error <= 1'b1;

                if (expect_picture_coding_extension &&
                    (stream_data[7:4] != EXT_PICTURE_CODING))
                    syntax_error <= 1'b1;
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
                sequence_extension_seen      <= 1'b1;
                expect_sequence_extension    <= 1'b0;

                // marker_bit in sequence_extension() shall be one.
                if (!payload_next[16])
                    syntax_error <= 1'b1;

                // chroma_format == 00 is reserved by H.262.
                if (payload_next[34:33] == 2'b00)
                    syntax_error <= 1'b1;
            end

            // picture_header(): first 32 payload bits are sufficient for the
            // temporal reference, coding type and vbv_delay.
            if ((active_start_code == PICTURE_START_CODE) &&
                (payload_byte_index == 3)) begin
                temporal_reference  <= payload_next[31:22];
                picture_coding_type <= payload_next[21:19];
                picture_seen        <= 1'b1;

                // H.262 Table 6-12 defines 001 I, 010 P, 011 B.  000 is
                // forbidden; 100 shall not be used; 101-111 are reserved.
                if ((payload_next[21:19] < 3'b001) ||
                    (payload_next[21:19] > 3'b011))
                    syntax_error <= 1'b1;

                // H.262 requires the first coded frame after a GOP header to
                // be an I-frame.
                if (first_picture_after_gop) begin
                    if (payload_next[21:19] != 3'b001)
                        syntax_error <= 1'b1;
                    first_picture_after_gop <= 1'b0;
                end
            end

            // picture_coding_extension(): progressive_frame is the 33rd bit,
            // so five payload bytes are enough to capture all fields we need.
            if ((active_start_code == EXTENSION_START_CODE) &&
                active_extension_id_valid &&
                (active_extension_id == EXT_PICTURE_CODING) &&
                (payload_byte_index == 4)) begin
                picture_structure                 <= payload_next[17:16];
                progressive_frame                 <= payload_next[7];
                picture_coding_extension_seen     <= 1'b1;
                expect_picture_coding_extension   <= 1'b0;

                // picture_structure == 00 is reserved.
                if (payload_next[17:16] == 2'b00)
                    syntax_error <= 1'b1;

                // A progressive sequence contains only progressive frame
                // pictures; H.262 additionally requires frame structure.
                if (progressive_sequence) begin
                    if (payload_next[17:16] != 2'b11)
                        syntax_error <= 1'b1;
                    if (!payload_next[7])
                        syntax_error <= 1'b1;
                end
            end
        end
    end
end

endmodule
