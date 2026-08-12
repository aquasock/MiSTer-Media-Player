//============================================================================
// MiSTer Media Player - Phase 1T-d passive H.262 P-picture syntax probe
//
// Normative standards basis:
//   ITU-T H.262 / ISO/IEC 13818-2:2000
//   - 6.2.4 slice()
//   - 6.2.5 macroblock()
//   - Annex B Table B.1 macroblock_address_increment
//   - Annex B Table B.3 P-picture macroblock_type
//
// kate - This is a deliberately narrow live-stream proof before prediction is
// enabled.  The proven decoder still reconstructs only I-pictures.  When the
// existing front end reports that the supported-I condition has fallen for the
// controlled I/P diagnostic stream, this observer waits for the next P-picture
// slice and validates its first macroblock prefix without backpressuring or
// writing any reconstructed data.
//
// Phase 1T-d diagnostic boundary:
//   - non-scalable P-picture slice syntax;
//   - non-zero quantiser_scale_code;
//   - optional slice_extension_flag fields are skipped if present;
//   - extra_bit_slice must be the normative zero value;
//   - the controlled diagnostic stream's first macroblock has
//     macroblock_address_increment == 1 (Table B.1 code '1');
//   - all seven legal non-scalable P macroblock_type codewords from Table B.3
//     are accepted.
//
// This module is passive: stream_valid means the byte was already accepted by
// the main decoder path.  It never supplies ready/backpressure and never emits
// coefficients, pixels, DDR writes, or frame-publication events.
//============================================================================

module mpeg2_h262_p_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    input  wire       p_picture_expected,

    output reg        p_macroblock_type_seen,
    output reg        probe_error
);

localparam [7:0]
    PICTURE_START_CODE = 8'h00;

reg [31:0] byte_window;
wire [31:0] byte_window_next = {byte_window[23:0], stream_data};
wire        start_code_now   = (byte_window_next[31:8] == 24'h000001);
wire [7:0]  start_code_value = byte_window_next[7:0];
wire        slice_start_now  = start_code_now &&
                               (start_code_value >= 8'h01) &&
                               (start_code_value <= 8'hAF);

reg        slice_capture_active;
reg [2:0]  slice_payload_count;
reg [31:0] slice_payload_shift;
reg        decode_pending;

// Decode only the bounded first-macroblock prefix needed for the Phase 1T-d
// hardware proof.  Bit index 31 is the first bit after slice_start_code.
function automatic decode_first_p_macroblock_type;
    input [31:0] payload;
    integer pos;
    reg [4:0] qscale;
    reg       ok;
    begin
        ok     = 1'b1;
        qscale = payload[31:27];
        pos    = 5;

        // H.262 6.2.4: quantiser_scale_code shall not be zero.
        if (qscale == 5'd0)
            ok = 1'b0;

        // nextbits() tests slice_extension_flag without consuming it.  If it is
        // one, consume the flag plus intra_slice, slice_picture_id_enable and
        // six slice_picture_id bits.  If it is zero, the same zero bit is the
        // mandatory trailing extra_bit_slice below.
        if (payload[31 - pos])
            pos = pos + 9;

        // H.262 6.3.16: extra_bit_slice == 1 is reserved; conforming streams
        // use the zero value at this boundary.
        if (payload[31 - pos] != 1'b0)
            ok = 1'b0;
        pos = pos + 1;

        // Phase 1T-d controlled-stream restriction: first macroblock begins at
        // the first slice column, so Table B.1 macroblock_address_increment is
        // the one-bit code '1'.  General Table B.1 P-picture traversal follows
        // in the next parser expansion.
        if (payload[31 - pos] != 1'b1)
            ok = 1'b0;
        pos = pos + 1;

        // H.262 Annex B Table B.3, non-scalable P-picture macroblock_type.
        if (payload[31 - pos] == 1'b1) begin
            // 1: motion_forward + pattern
            pos = pos + 1;
        end
        else if (payload[31 - (pos + 1)] == 1'b1) begin
            // 01: pattern
            pos = pos + 2;
        end
        else if (payload[31 - (pos + 2)] == 1'b1) begin
            // 001: motion_forward
            pos = pos + 3;
        end
        else if ((payload[31 - (pos + 3)] == 1'b1) &&
                 (payload[31 - (pos + 4)] == 1'b1)) begin
            // 00011: intra
            pos = pos + 5;
        end
        else if ((payload[31 - (pos + 3)] == 1'b1) &&
                 (payload[31 - (pos + 4)] == 1'b0)) begin
            // 00010: quant + motion_forward + pattern
            pos = pos + 5;
        end
        else if ((payload[31 - (pos + 3)] == 1'b0) &&
                 (payload[31 - (pos + 4)] == 1'b1)) begin
            // 00001: quant + pattern
            pos = pos + 5;
        end
        else if ((payload[31 - (pos + 3)] == 1'b0) &&
                 (payload[31 - (pos + 4)] == 1'b0) &&
                 (payload[31 - (pos + 5)] == 1'b1)) begin
            // 000001: quant + intra
            pos = pos + 6;
        end
        else begin
            ok = 1'b0;
        end

        decode_first_p_macroblock_type = ok;
    end
endfunction

wire p_prefix_decode_ok =
    decode_first_p_macroblock_type(slice_payload_shift);

always @(posedge clk) begin
    if (reset) begin
        byte_window                 <= 32'd0;
        slice_capture_active        <= 1'b0;
        slice_payload_count         <= 3'd0;
        slice_payload_shift         <= 32'd0;
        decode_pending              <= 1'b0;
        p_macroblock_type_seen      <= 1'b0;
        probe_error                 <= 1'b0;
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

            if (slice_capture_active) begin
                // Four payload bytes are ample for this bounded prefix even
                // when slice_extension_flag is present.  A new start code before
                // that point means the diagnostic prefix was not available.
                if (start_code_now) begin
                    slice_capture_active <= 1'b0;
                    probe_error          <= 1'b1;
                end
                else begin
                    slice_payload_shift <=
                        {slice_payload_shift[23:0], stream_data};

                    if (slice_payload_count == 3'd3) begin
                        slice_capture_active <= 1'b0;
                        slice_payload_count  <= 3'd0;
                        decode_pending       <= 1'b1;
                    end
                    else begin
                        slice_payload_count <= slice_payload_count + 3'd1;
                    end
                end
            end
            else if (p_picture_expected && !p_macroblock_type_seen &&
                     !decode_pending && !probe_error) begin
                if (slice_start_now) begin
                    slice_capture_active <= 1'b1;
                    slice_payload_count  <= 3'd0;
                    slice_payload_shift  <= 32'd0;
                end
                else if (start_code_now &&
                         (start_code_value == PICTURE_START_CODE)) begin
                    // The expected P picture reached another picture header
                    // before a live Table B.3 macroblock type was verified.
                    probe_error <= 1'b1;
                end
            end
        end
    end
end

endmodule
