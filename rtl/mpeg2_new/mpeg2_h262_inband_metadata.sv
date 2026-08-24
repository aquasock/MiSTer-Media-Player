// ============================================================================
//  mpeg2_h262_inband_metadata
//
//  Entry 369: extract picture metadata carried in band with the elementary
//  stream, so the HPS can supply timestamps over the existing ioctl_download
//  path instead of requiring a side channel.
//
//  EXT_BUS was the obvious candidate for a side channel and was rejected: it
//  carries Main_MiSTer's user_io transactions, so using it would make this
//  project depend on changes to a binary it does not own -- the same class of
//  external dependency as the kernel configuration needed for USB optical
//  media.  The ingress byte path, by contrast, is already proven: it streams a
//  14,315-picture file with working backpressure.
//
//  Records are framed with 0x000001B0.  That is a *reserved* H.262 start code,
//  so no encoder emits it, and start-code emulation prevention guarantees the
//  0x000001 prefix cannot occur inside payload data.  A plain elementary
//  stream therefore contains no records and passes through unchanged; raw ES
//  compatibility is a property of the framing rather than a mode to select.
//
//  Detection uses a four-byte sliding window.  A byte is only emitted once it
//  has fallen out of the window without completing a marker, which costs three
//  bytes of latency and makes overlapping prefixes -- 00 00 00 01 B0 -- correct
//  without special cases, because the window always holds the true last four
//  bytes rather than a guess about how much of a marker has matched.
//
//  input_end flushes the residual window at end of transfer.  Without it the
//  final three bytes of a stream would never reach the decoder, which matters
//  because streams end with sequence_end_code 0x000001B7.
// ============================================================================

module mpeg2_h262_inband_metadata
(
    input  wire        clk,
    input  wire        reset,

    input  wire  [7:0] input_data,
    input  wire        input_valid,
    output wire        input_ready,
    input  wire        input_end,

    output reg   [7:0] stream_data,
    output wire        stream_valid,
    input  wire        stream_ready,

    output reg  [32:0] pts_90k,
    output reg   [1:0] picture_structure,
    output reg         top_field_first,
    output reg         repeat_first_field,
    output reg         progressive_frame,
    output reg         metadata_valid,      // one-cycle pulse
    output reg   [7:0] metadata_count
);

localparam [31:0] RECORD_MARKER = 32'h000001B0;
localparam integer PAYLOAD_BYTES = 5;

localparam [1:0] S_FILL    = 2'd0,
                 S_STREAM  = 2'd1,
                 S_PAYLOAD = 2'd2,
                 S_FLUSH   = 2'd3;

reg [1:0]  state;
reg [31:0] window;
reg [2:0]  window_fill;
reg [2:0]  payload_index;
reg [39:0] payload;
reg        stream_pending;

// The integrated decoder advances on stream_valid itself rather than on a
// conventional valid-and-ready transfer.  Retain a pending output byte while
// it is stalled, but expose valid only in the cycle the decoder accepts it.
// This preserves the pre-extractor pulse-valid contract and prevents a held
// byte from being parsed repeatedly during picture-ownership backpressure.
assign stream_valid = stream_pending && stream_ready;

// Accept input whenever the pending output is free or will transfer in this
// cycle, except while draining the window at end of transfer.
assign input_ready =
    (state != S_FLUSH) && (!stream_pending || stream_ready);

wire [31:0] window_next = {window[23:0], input_data};
// window_fill saturates at four; the window then always holds the true
// last four bytes, so the marker test is simply on the shifted-in value.
wire        marker_hit  = (window_fill == 3'd4) && (window_next == RECORD_MARKER);
wire [39:0] payload_full = {payload[31:0], input_data};

always @(posedge clk) begin
    if (reset) begin
        state              <= S_FILL;
        window             <= 32'd0;
        window_fill        <= 3'd0;
        payload_index      <= 3'd0;
        payload            <= 40'd0;
        stream_data        <= 8'd0;
        stream_pending     <= 1'b0;
        pts_90k            <= 33'd0;
        picture_structure  <= 2'd0;
        top_field_first    <= 1'b0;
        repeat_first_field <= 1'b0;
        progressive_frame  <= 1'b0;
        metadata_valid     <= 1'b0;
        metadata_count     <= 8'd0;
    end
    else begin
        metadata_valid <= 1'b0;

        if (stream_pending && stream_ready)
            stream_pending <= 1'b0;

        case (state)

        // Prime the window.  Nothing is emitted until four bytes are held,
        // because a marker cannot be ruled out before then.
        S_FILL:
            if (input_valid && input_ready) begin
                window      <= window_next;
                window_fill <= window_fill + 3'd1;
                if (window_fill == 3'd3) begin
                    if (window_next == RECORD_MARKER) begin
                        window        <= 32'd0;
                        window_fill   <= 3'd0;
                        payload_index <= 3'd0;
                        state         <= S_PAYLOAD;
                    end
                    else
                        state <= S_STREAM;
                end
            end
            else if (input_end && window_fill != 3'd0) begin
                // Left-justify a short window so the oldest byte is the one
                // the flush emits first.
                window <= window << ({3'd0, 3'd4 - window_fill} * 4'd8);
                state  <= S_FLUSH;
            end

        // Steady state: the window is full, so the byte falling out of it is
        // known not to begin a marker and can be emitted.
        S_STREAM:
            if (input_valid && input_ready) begin
                window      <= window_next;
                window_fill <= 3'd4;
                if (marker_hit) begin
                    // The three bytes still held are part of the marker and
                    // must not be emitted, but the byte falling out of the
                    // window precedes the marker and still belongs to the
                    // stream.  Dropping it here silently truncated the byte
                    // before every record.
                    stream_data   <= window[31:24];
                    stream_pending <= 1'b1;
                    window        <= 32'd0;
                    window_fill   <= 3'd0;
                    payload_index <= 3'd0;
                    state         <= S_PAYLOAD;
                end
                else begin
                    stream_data  <= window[31:24];
                    stream_pending <= 1'b1;
                end
            end
            else if (input_end)
                state <= S_FLUSH;

        // Collect the record payload.  These bytes never reach the decoder.
        S_PAYLOAD:
            if (input_valid && input_ready) begin
                payload <= {payload[31:0], input_data};
                if (payload_index == PAYLOAD_BYTES[2:0] - 3'd1) begin
                    pts_90k            <= payload_full[39:7];
                    picture_structure  <= payload_full[6:5];
                    top_field_first    <= payload_full[4];
                    repeat_first_field <= payload_full[3];
                    progressive_frame  <= payload_full[2];
                    metadata_valid     <= 1'b1;
                    if (metadata_count != 8'hFF)
                        metadata_count <= metadata_count + 8'd1;
                    payload_index      <= 3'd0;
                    state              <= S_FILL;
                end
                else
                    payload_index <= payload_index + 3'd1;
            end

        // Emit the residual window at end of transfer, oldest byte first.
        S_FLUSH:
            if (!stream_pending || stream_ready) begin
                if (window_fill != 3'd0) begin
                    stream_data  <= window[31:24];
                    stream_pending <= 1'b1;
                    window       <= {window[23:0], 8'd0};
                    window_fill  <= window_fill - 3'd1;
                end
                else begin
                    window <= 32'd0;
                    state  <= S_FILL;
                end
            end

        endcase
    end
end

endmodule
