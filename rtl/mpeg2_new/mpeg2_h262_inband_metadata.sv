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
//  Records use reserved H.262 start codes: B0 carries picture metadata, B1 a
//  run of PCM frames, and B6 a zero-payload PCM end token. No encoder emits
//  these codes. Payload lengths are declared rather than scanned, so arbitrary
//  signed PCM bytes are consumed as data and can never be mistaken for a nested
//  marker. A plain elementary stream contains no records and passes through
//  unchanged.
//
//  Entry 462: one frame per record put 48,000 records and 422 KiB/s of audio on
//  a path carrying 138 KiB/s of video, three quarters of everything crossing,
//  and hardware measured a cost per record in late presentations.  The mode
//  byte's six unused bits now carry a frame count, so one record can deliver a
//  run of frames: {count[5:0],rate_48k,stereo} then count frames of
//  {left[15:8],left[7:0],right[15:8],right[7:0]}.  A count of zero means one
//  frame, which is exactly the encoding streams used before this change, so
//  older transports decode unchanged.  Each frame's final byte still waits for
//  the audio sink, so backpressure reaches the producer at frame granularity
//  rather than record granularity.
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
    input  wire        metadata_ready,
    output reg   [7:0] metadata_count,

    output reg  [15:0] pcm_left,
    output reg  [15:0] pcm_right,
    output reg         pcm_stereo,
    output reg         pcm_rate_48k,
    output reg         pcm_valid,           // one-cycle pulse
    output reg         pcm_end,             // one-cycle pulse
    input  wire        pcm_ready,
    output reg  [13:0] pcm_sample_count,
    output reg         pcm_protocol_error
);

localparam [31:0] PTS_MARKER     = 32'h000001B0;
localparam [31:0] PCM_MARKER     = 32'h000001B1;
localparam [31:0] PCM_END_MARKER = 32'h000001B6;
localparam integer PAYLOAD_BYTES = 5;
localparam [5:0]   MAX_PCM_FRAMES = 6'd32;

localparam [2:0] S_FILL        = 3'd0,
                 S_STREAM      = 3'd1,
                 S_PTS_PAYLOAD = 3'd2,
                 S_PCM_PAYLOAD = 3'd3,
                 S_PCM_END     = 3'd4,
                 S_FLUSH       = 3'd5;

reg [2:0]  state;
reg [31:0] window;
reg [2:0]  window_fill;
reg [2:0]  payload_index;
reg [39:0] payload;
reg        stream_pending;
reg [5:0]  pcm_frames_left;
reg        pcm_mode_seen;
reg [1:0]  pcm_byte_index;
reg [23:0] pcm_frame;

// The integrated decoder advances on stream_valid itself rather than on a
// conventional valid-and-ready transfer.  Retain a pending output byte while
// it is stalled, but expose valid only in the cycle the decoder accepts it.
// This preserves the pre-extractor pulse-valid contract and prevents a held
// byte from being parsed repeatedly during picture-ownership backpressure.
assign stream_valid = stream_pending && stream_ready;

// Accept input whenever the pending output is free or will transfer in this
// cycle, except while draining the window at end of transfer.
// The last byte of every frame, not merely of every record, is the one the
// sink must be ready for.
wire pcm_payload_final =
    (state == S_PCM_PAYLOAD) && pcm_mode_seen && (pcm_byte_index == 2'd3);
wire pts_payload_final =
    (state == S_PTS_PAYLOAD) &&
    (payload_index == PAYLOAD_BYTES[2:0] - 3'd1);

assign input_ready =
    (state != S_FLUSH) &&
    (state != S_PCM_END) &&
    (!stream_pending || stream_ready) &&
    (!pts_payload_final || metadata_ready) &&
    (!pcm_payload_final || pcm_ready);

wire [31:0] window_next = {window[23:0], input_data};
// window_fill saturates at four; the window then always holds the true
// last four bytes, so the marker test is simply on the shifted-in value.
wire pts_marker_hit = (window_next == PTS_MARKER);
wire pcm_marker_hit = (window_next == PCM_MARKER);
wire pcm_end_marker_hit = (window_next == PCM_END_MARKER);
wire marker_hit = (window_fill == 3'd4) &&
    (pts_marker_hit || pcm_marker_hit || pcm_end_marker_hit);
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
        pcm_left           <= 16'd0;
        pcm_right          <= 16'd0;
        pcm_stereo         <= 1'b0;
        pcm_rate_48k       <= 1'b0;
        pcm_valid          <= 1'b0;
        pcm_end            <= 1'b0;
        pcm_sample_count   <= 14'd0;
        pcm_protocol_error <= 1'b0;
        pcm_frames_left    <= 6'd0;
        pcm_mode_seen      <= 1'b0;
        pcm_byte_index     <= 2'd0;
        pcm_frame          <= 24'd0;
    end
    else begin
        metadata_valid <= 1'b0;
        pcm_valid      <= 1'b0;
        pcm_end        <= 1'b0;

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
                    if (pts_marker_hit || pcm_marker_hit || pcm_end_marker_hit) begin
                        window        <= 32'd0;
                        window_fill   <= 3'd0;
                        payload_index <= 3'd0;
                        if (pts_marker_hit)
                            state <= S_PTS_PAYLOAD;
                        else if (pcm_marker_hit)
                            state <= S_PCM_PAYLOAD;
                        else
                            state <= S_PCM_END;
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
                    if (pts_marker_hit)
                        state <= S_PTS_PAYLOAD;
                    else if (pcm_marker_hit)
                        state <= S_PCM_PAYLOAD;
                    else
                        state <= S_PCM_END;
                end
                else begin
                    stream_data  <= window[31:24];
                    stream_pending <= 1'b1;
                end
            end
            else if (input_end)
                state <= S_FLUSH;

        // Collect the record payload.  These bytes never reach the decoder.
        S_PTS_PAYLOAD:
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

        // A PCM record is {count,rate,stereo} followed by count frames of
        // {left[15:8],left[7:0],right[15:8],right[7:0]}.  The final byte of
        // each frame is not consumed until the audio FIFO can accept the
        // assembled sample, extending existing file-channel backpressure all
        // the way to the FPGA-owned PCM sink at frame granularity.
        S_PCM_PAYLOAD:
            if (input_valid && input_ready) begin
                if (!pcm_mode_seen) begin
                    pcm_rate_48k   <= input_data[1];
                    pcm_stereo     <= input_data[0];
                    pcm_mode_seen  <= 1'b1;
                    pcm_byte_index <= 2'd0;
                    // A count of zero is the pre-entry-462 encoding of one
                    // frame.  A count past the supported run is reported and
                    // treated as one, which consumes the same five bytes a
                    // malformed record consumed before.
                    if (input_data[7:2] > MAX_PCM_FRAMES) begin
                        pcm_protocol_error <= 1'b1;
                        pcm_frames_left    <= 6'd1;
                    end
                    else if (input_data[7:2] == 6'd0)
                        pcm_frames_left <= 6'd1;
                    else
                        pcm_frames_left <= input_data[7:2];
                end
                else begin
                    pcm_frame <= {pcm_frame[15:0], input_data};
                    if (pcm_byte_index == 2'd3) begin
                        pcm_left  <= {pcm_frame[23:16], pcm_frame[15:8]};
                        pcm_right <= {pcm_frame[7:0], input_data};
                        pcm_valid <= 1'b1;
                        if (pcm_sample_count != 14'h3FFF)
                            pcm_sample_count <= pcm_sample_count + 14'd1;
                        pcm_byte_index <= 2'd0;
                        if (pcm_frames_left == 6'd1) begin
                            pcm_mode_seen <= 1'b0;
                            payload_index <= 3'd0;
                            state         <= S_FILL;
                        end
                        else
                            pcm_frames_left <= pcm_frames_left - 6'd1;
                    end
                    else
                        pcm_byte_index <= pcm_byte_index + 2'd1;
                end
            end

        // The end token enters the same FIFO behind the final sample. The
        // output adapter consumes it on a sample boundary and stops cleanly.
        S_PCM_END:
            if (pcm_ready) begin
                pcm_end <= 1'b1;
                state   <= S_FILL;
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
