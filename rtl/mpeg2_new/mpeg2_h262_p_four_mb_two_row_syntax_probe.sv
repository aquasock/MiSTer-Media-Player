//============================================================================
// MiSTer Media Player - controlled multi-macroblock/multi-row H.262 P observer
//
// Standards authority: core-standards.md, source_id H262.
// Relevant established records:
//   H262-007 macroblock width = (horizontal_size + 15) / 16
//   H262-008 slice vertical position identifies the macroblock row
//   H262-009 macroblock address progression restarts from the slice basis
//   H262-011 P-picture motion-forward-only macroblock_type code 001
//   H262-012 motion_code 0 code 1
//   H262-013 macroblock_address_increment 1 code 1
//
// kate - Phase 1U-g accelerates the accepted controlled raster proof in both
// dimensions.  The observer now accepts two through four macroblocks per row
// and two or three progressive-frame macroblock rows, derived from the coded
// sequence geometry.  Every controlled macroblock remains adjacent,
// motion-forward-only, macroblock_address_increment=1, motion_code=(0,0), and
// forward f_code=(2,2).  The supported row payloads are therefore:
//   2 MB: 12 79 c0
//   3 MB: 12 79 e7
//   4 MB: 12 79 e7 9c
// The new 64x48 diagnostic uses three slices and 4x3=12 macroblocks.
//
// Compatibility note: public signal/module names retain "four_mb" and
// "two_row" so the hardware-accepted controller interface does not change in
// this increment.  This is a controlled diagnostic recognizer, not a general
// P-picture parser.
//============================================================================

module mpeg2_h262_p_four_mb_two_row_syntax_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] stream_data,
    input  wire       stream_valid,

    output reg        four_mb_candidate,
    output reg        four_mb_seen,
    output wire       four_mb_complete_now,
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

// A following I picture may be preceded by a new sequence header.  Both are
// valid boundaries for the completed controlled P picture.
wire post_p_boundary_now =
    (start_code_value == PICTURE_START_CODE) ||
    (start_code_value == SEQUENCE_HEADER_CODE);

// sequence_header() first 24 payload bits are horizontal_size_value followed
// by vertical_size_value.  The current decoder subset is progressive 4:2:0
// frame pictures, so the controlled row count uses the same ceil(size/16)
// geometry already activated in the reference pipeline.
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
reg [2:0]  controlled_mb_per_row;
reg [1:0]  controlled_row_count;

// picture_header() first 16 payload bits contain temporal_reference[9:0],
// picture_coding_type[2:0], then the first three vbv_delay bits.
reg        picture_capture;
reg        picture_count;
reg [15:0] picture_shift;
wire [15:0] picture_next = {picture_shift[7:0], stream_data};
reg        current_picture_is_p;

// Capture the first 40 bits of picture_coding_extension().
reg        pce_capture;
reg [2:0]  pce_count;
reg [39:0] pce_shift;
wire [39:0] pce_next = {pce_shift[31:0], stream_data};

// Controlled row payloads are three bytes for two/three macroblocks and four
// bytes for four macroblocks.  slice_count also sees the 00 00 01 prefix of the
// following start code, so the accepted boundary count is payload bytes + 3.
wire [2:0] expected_payload_bytes =
    (controlled_mb_per_row == 3'd4) ? 3'd4 : 3'd3;
wire [3:0] expected_slice_count =
    {1'b0, expected_payload_bytes} + 4'd3;

reg        slice_capture;
reg [1:0]  slice_row_number;
reg [3:0]  slice_count;
reg [31:0] payload_shift;
reg        payload_complete;
reg        proof_done;

wire controlled_payload_ok =
    ((controlled_mb_per_row == 3'd2) &&
     (payload_shift[23:0] == 24'h1279c0)) ||
    ((controlled_mb_per_row == 3'd3) &&
     (payload_shift[23:0] == 24'h1279e7)) ||
    ((controlled_mb_per_row == 3'd4) &&
     (payload_shift == 32'h1279e79c));

// Assert on the exact accepted boundary after the last controlled slice.  The
// controller uses this combinational pulse to stop compressed input before the
// following picture payload can enter while DDR copy/readback is in flight.
assign four_mb_complete_now =
    stream_valid &&
    slice_capture &&
    start_code_now &&
    post_p_boundary_now &&
    (slice_row_number == controlled_row_count) &&
    (slice_count == expected_slice_count) &&
    payload_complete &&
    controlled_payload_ok;

always @(posedge clk) begin
    if (reset) begin
        byte_window               <= 32'd0;
        sequence_capture          <= 1'b0;
        sequence_count            <= 2'd0;
        sequence_shift            <= 24'd0;
        geometry_supported_raster <= 1'b0;
        controlled_mb_per_row     <= 3'd0;
        controlled_row_count      <= 2'd0;
        picture_capture           <= 1'b0;
        picture_count             <= 1'b0;
        picture_shift             <= 16'd0;
        current_picture_is_p      <= 1'b0;
        pce_capture               <= 1'b0;
        pce_count                 <= 3'd0;
        pce_shift                 <= 40'd0;
        four_mb_candidate         <= 1'b0;
        slice_capture             <= 1'b0;
        slice_row_number          <= 2'd0;
        slice_count               <= 4'd0;
        payload_shift             <= 32'd0;
        payload_complete          <= 1'b0;
        proof_done                <= 1'b0;
        four_mb_seen              <= 1'b0;
        probe_error               <= 1'b0;
    end
    else if (stream_valid) begin
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
                    (sequence_macroblock_width  <= 9'd4) &&
                    (sequence_macroblock_height >= 9'd2) &&
                    (sequence_macroblock_height <= 9'd3);

                if ((sequence_macroblock_width >= 9'd2) &&
                    (sequence_macroblock_width <= 9'd4))
                    controlled_mb_per_row <= sequence_macroblock_width[2:0];
                else
                    controlled_mb_per_row <= 3'd0;

                if ((sequence_macroblock_height >= 9'd2) &&
                    (sequence_macroblock_height <= 9'd3))
                    controlled_row_count <= sequence_macroblock_height[1:0];
                else
                    controlled_row_count <= 2'd0;
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

                // Controlled progressive frame-P boundary.  Forward horizontal
                // and vertical f_code are both 2; motion_code=0 yields the
                // exact zero vector with no residual motion bits.
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

        if (!proof_done && slice_capture) begin
            if (start_code_now) begin
                if ((slice_count != expected_slice_count) ||
                    !payload_complete ||
                    !controlled_payload_ok) begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;
                    probe_error   <= 1'b1;
                end
                else if (slice_row_number < controlled_row_count) begin
                    // H262-008: each next slice start code selects the following
                    // macroblock row. H262-009 restarts the MBA basis for it.
                    if (start_code_value ==
                        {6'd0, slice_row_number} + 8'd1) begin
                        slice_capture    <= 1'b1;
                        slice_row_number <= slice_row_number + 2'd1;
                        slice_count      <= 4'd0;
                        payload_shift    <= 32'd0;
                        payload_complete <= 1'b0;
                    end
                    else begin
                        slice_capture <= 1'b0;
                        proof_done    <= 1'b1;
                        probe_error   <= 1'b1;
                    end
                end
                else begin
                    slice_capture <= 1'b0;
                    proof_done    <= 1'b1;

                    if (post_p_boundary_now)
                        four_mb_seen <= 1'b1;
                    else
                        probe_error <= 1'b1;
                end
            end
            else begin
                if (slice_count < {1'b0, expected_payload_bytes}) begin
                    payload_shift <= {payload_shift[23:0], stream_data};
                    if ((slice_count + 4'd1) ==
                        {1'b0, expected_payload_bytes})
                        payload_complete <= 1'b1;
                end

                if (slice_count != 4'hF)
                    slice_count <= slice_count + 4'd1;
            end
        end
        else if (!proof_done && four_mb_candidate && slice_start_now) begin
            if (start_code_value == 8'h01) begin
                slice_capture    <= 1'b1;
                slice_row_number <= 2'd1;
                slice_count      <= 4'd0;
                payload_shift    <= 32'd0;
                payload_complete <= 1'b0;
            end
            else begin
                proof_done  <= 1'b1;
                probe_error <= 1'b1;
            end
        end
    end
end

endmodule
