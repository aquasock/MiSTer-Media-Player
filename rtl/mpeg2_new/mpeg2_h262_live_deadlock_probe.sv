//============================================================================
// MiSTer Media Player - live decode/display stall probe
//
// The existing hardware cadence profiler's overlay is a one-shot snapshot:
// it arms on the first overlay commit after reset and never re-arms, so it
// is useless for inspecting state during a hang that develops later in a
// long session. This probe is deliberately the opposite: two small words,
// continuously re-drawn every video frame from live mpeg2-domain state, with
// no arming and no latch. It exists purely to distinguish, from a screenshot
// taken during a live freeze, whether decode has stopped producing pictures,
// whether display has stopped advancing, and whether either of the two
// picture-ownership holds is currently asserted - without requiring a reset
// (which would destroy the hung state before it could be inspected).
//
// Drawn last in the video chain, after the cadence profiler, so it is never
// obscured by that overlay. Placed well clear of the profiler's own overlay
// box (which runs from y=344 for up to 62*4=248 rows) at a fixed corner
// location decoded by tools/decode-live-deadlock-probe.py.
//============================================================================
module mpeg2_h262_live_deadlock_probe
(
    input  wire        clk_mpeg2,
    input  wire        reset_mpeg2,
    input  wire        clk_video,
    input  wire        reset_video,
    input  wire        pixel_ce,
    input  wire [11:0] h_pos,
    input  wire [11:0] v_pos,
    input  wire [7:0]  base_r,
    input  wire [7:0]  base_g,
    input  wire [7:0]  base_b,

    // mpeg2-domain live state. Sampled continuously; nothing here is armed
    // or latched, unlike the cadence profiler's snapshot.
    input  wire        stream_full,
    input  wire        burst_ready,
    input  wire        p_destination_ownership_hold,
    input  wire        b_presentation_hold,
    input  wire [1:0]  active_frame_bank,
    input  wire [1:0]  display_frame_bank,
    input  wire        display_scratch,
    input  wire        picture_complete_pulse,
    input  wire        display_swap_pulse,

    output reg  [7:0]  video_r,
    output reg  [7:0]  video_g,
    output reg  [7:0]  video_b
);

// Free-running progress counters in the mpeg2 domain. A counter that has
// stopped incrementing across two screenshots taken seconds apart means
// that side of the pipeline has genuinely stalled - not merely a slow or
// static scene, which is indistinguishable from a real hang by eye alone.
reg [15:0] decode_progress_count;
reg [15:0] display_progress_count;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        decode_progress_count  <= 16'd0;
        display_progress_count <= 16'd0;
    end else begin
        if (picture_complete_pulse)
            decode_progress_count <= decode_progress_count + 16'd1;
        if (display_swap_pulse)
            display_progress_count <= display_progress_count + 16'd1;
    end
end

wire [31:0] live_word0 = {
    7'd0,
    b_presentation_hold,
    p_destination_ownership_hold,
    burst_ready,
    stream_full,
    display_scratch,
    display_frame_bank,
    active_frame_bank,
    decode_progress_count
};
wire [31:0] live_word1 = {16'd0, display_progress_count};

// Whole-bus double-flop into the video domain. These words change at most
// once per decoded or presented picture - far slower than the video pixel
// clock samples them - so, exactly like this file's own snapshot_sync_1/2
// convention, an occasional single-frame value torn across a bit change is
// a non-issue: this is read back from screenshots seconds apart, not
// sampled for cycle-accurate content.
reg [31:0] word0_sync1, word0_sync2;
reg [31:0] word1_sync1, word1_sync2;
always @(posedge clk_video) begin
    word0_sync1 <= live_word0; word0_sync2 <= word0_sync1;
    word1_sync1 <= live_word1; word1_sync2 <= word1_sync1;
end

localparam integer PX0   = 8;
localparam integer PY0   = 616;
localparam integer PCELL = 4;
localparam integer PCOLS = 36; // 4-bit fixed prefix + 32 data bits

wire in_box = pixel_ce && (h_pos >= PX0) && (h_pos < PX0 + PCOLS * PCELL) &&
              (v_pos >= PY0) && (v_pos < PY0 + 2 * PCELL);
wire [11:0] col_idx = (h_pos - PX0) >> 2;
wire        row_idx = v_pos[2]; // (v_pos-PY0)>>2 low bit, since PY0%8==0
wire [31:0] row_word = row_idx ? word1_sync2 : word0_sync2;
wire cell_bit = (col_idx == 12'd0) ? 1'b1 :
                (col_idx == 12'd1) ? 1'b0 :
                (col_idx == 12'd2) ? 1'b1 :
                (col_idx == 12'd3) ? 1'b0 :
                row_word[col_idx - 12'd4];

always @(posedge clk_video) begin
    if (pixel_ce) begin
        if (in_box) begin
            video_r <= cell_bit ? 8'hFF : 8'h00;
            video_g <= cell_bit ? 8'hFF : 8'h00;
            video_b <= cell_bit ? 8'hFF : 8'h00;
        end else begin
            video_r <= base_r;
            video_g <= base_g;
            video_b <= base_b;
        end
    end
end

endmodule
