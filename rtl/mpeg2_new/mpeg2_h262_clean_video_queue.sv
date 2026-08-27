//============================================================================
// MiSTer Media Player - post-extraction clean-video queue
//
// Entry 464: video and PCM share the HPS byte stream until the in-band
// extractor.  If the decoder refuses a clean video byte, the extractor used to
// stop at that byte and could not reach later PCM records, allowing the audio
// sink to drain.  This queue is the first point at which the two streams can be
// decoupled: clean video waits here while PCM events continue directly to the
// audio FIFO.
//
// Timestamp records must remain ordered with the clean byte position at which
// they appeared.  A small companion FIFO stores {byte_position, PTS}; an entry
// is released only when the decoder-side read position reaches that byte.  The
// extractor therefore cannot make timestamps outrun their pictures even while
// it scans ahead through PCM records.
//============================================================================
module mpeg2_h262_clean_video_queue
(
    input  wire        clk,
    input  wire        reset,

    input  wire  [7:0] input_data,
    input  wire        input_valid,
    output wire        input_ready,

    input  wire [32:0] input_metadata_pts,
    input  wire        input_metadata_valid,
    output wire        input_metadata_ready,

    output wire  [7:0] output_data,
    output wire        output_valid,
    input  wire        output_ready,
    output wire        output_pending_debug,

    output wire [32:0] output_metadata_pts,
    output wire        output_metadata_valid
);

localparam integer VIDEO_DEPTH = 65536;
localparam integer VIDEO_ADDRESS_WIDTH = 16;
localparam integer METADATA_DEPTH = 16;
localparam integer METADATA_ADDRESS_WIDTH = 4;
localparam integer METADATA_WIDTH = 65;

wire video_full;
wire video_empty;
wire video_write = input_valid && input_ready;
wire video_read = !video_empty && output_ready;

wire metadata_full;
wire metadata_empty;
wire [METADATA_WIDTH-1:0] metadata_q;
wire metadata_write = input_metadata_valid && input_metadata_ready;
reg [31:0] video_write_position;
reg [31:0] video_read_position;
wire [31:0] metadata_position = metadata_q[64:33];
wire metadata_due = !metadata_empty &&
    (metadata_position == video_read_position);

assign input_ready = !video_full;
assign input_metadata_ready = !metadata_full;

// The integrated decoder advances on a valid pulse, not on a held ready/valid
// level.  Preserve that established contract at the queue output.
assign output_valid = video_read;
// Passive availability before ready gating; upstream FIFO empty is unrelated.
assign output_pending_debug = !video_empty;
assign output_metadata_valid = metadata_due;
assign output_metadata_pts = metadata_q[32:0];

always @(posedge clk) begin
    if (reset) begin
        video_write_position <= 32'd0;
        video_read_position  <= 32'd0;
    end
    else begin
        if (video_write)
            video_write_position <= video_write_position + 32'd1;
        if (video_read)
            video_read_position <= video_read_position + 32'd1;
    end
end

scfifo #(
    // Entry 561: retain more compressed video across host delivery pauses.
    // This is capacity, not a fixed delay or a promise about source bitrate.
    // Metadata remains paired with decoder-consumed byte positions below.
    .lpm_numwords         (VIDEO_DEPTH),
    .lpm_showahead        ("ON"),
    .lpm_type             ("scfifo"),
    .lpm_width            (8),
    .lpm_widthu           (VIDEO_ADDRESS_WIDTH),
    .overflow_checking    ("ON"),
    .underflow_checking   ("ON"),
    .use_eab              ("ON")
) video_fifo
(
    .aclr  (reset),
    .clock (clk),
    .data  (input_data),
    .wrreq (video_write),
    .full  (video_full),
    .q     (output_data),
    .rdreq (video_read),
    .empty (video_empty)
);

scfifo #(
    .lpm_numwords         (METADATA_DEPTH),
    .lpm_showahead        ("ON"),
    .lpm_type             ("scfifo"),
    .lpm_width            (METADATA_WIDTH),
    .lpm_widthu           (METADATA_ADDRESS_WIDTH),
    .overflow_checking    ("ON"),
    .underflow_checking   ("ON"),
    .use_eab              ("ON")
) metadata_fifo
(
    .aclr  (reset),
    .clock (clk),
    .data  ({video_write_position,input_metadata_pts}),
    .wrreq (metadata_write),
    .full  (metadata_full),
    .q     (metadata_q),
    .rdreq (metadata_due),
    .empty (metadata_empty)
);

endmodule
