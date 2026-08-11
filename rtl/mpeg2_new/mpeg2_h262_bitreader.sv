//============================================================================
// MiSTer Media Player - streaming H.262 byte-to-bit reader
//
// kate - Phase 1K removes the temporary whole-slice capture buffer.  This
// module accepts the existing byte stream through a ready/valid handshake and
// presents one MSB-first bit at a time to the syntax parser.
//
// The reader intentionally holds at most one payload byte.  Backpressure is
// propagated to the existing asynchronous HPS->decoder FIFO while the parser
// is consuming bits or waiting for IQ/IDCT/reconstruction to finish.  This is
// an implementation choice; H.262 defines the bitstream syntax, not this
// buffering arrangement.
//============================================================================

module mpeg2_h262_bitreader
(
    input  wire       clk,
    input  wire       reset,

    input  wire [7:0] stream_data,
    input  wire       stream_valid,
    output wire       stream_ready,

    input  wire       enable,
    input  wire       bit_consume,
    output wire       bit_valid,
    output wire       bit_value
);

reg [7:0] byte_data;
reg [2:0] bit_position;
reg       byte_valid;

// When disabled the reader is transparent to stream flow: bytes are allowed to
// pass to other stream observers (notably the H.262 front end/start-code
// scanner) and are not retained here.  When enabled, one byte is retained until
// all eight bits have been consumed.
assign stream_ready = !enable || !byte_valid;
assign bit_valid    = enable && byte_valid;
assign bit_value    = byte_data[3'd7 - bit_position];

always @(posedge clk) begin
    if (reset) begin
        byte_data    <= 8'd0;
        bit_position <= 3'd0;
        byte_valid   <= 1'b0;
    end
    else if (!enable) begin
        bit_position <= 3'd0;
        byte_valid   <= 1'b0;
    end
    else begin
        if (stream_valid && stream_ready) begin
            byte_data    <= stream_data;
            bit_position <= 3'd0;
            byte_valid   <= 1'b1;
        end

        if (bit_consume && bit_valid) begin
            if (bit_position == 3'd7) begin
                bit_position <= 3'd0;
                byte_valid   <= 1'b0;
            end
            else begin
                bit_position <= bit_position + 3'd1;
            end
        end
    end
end

endmodule
