//============================================================================
// MiSTer Media Player - H.262 PTS presentation timeline
//
// Entry 389: advance a decoder-domain 33-bit 90 kHz timeline from the proven
// audio-derived tick.  The first metadata record after reset anchors the local
// clock exactly once.  New-file and seek-like download rearm reset this module,
// so a later session can establish a fresh origin without a multi-bit CDC.
//
// PTS arithmetic is modulo 2^33.  A candidate is due when STC-PTS lies in the
// non-negative half of that ring (including equality); values in the opposite
// half are future timestamps.  Individually missing timestamps remain inactive
// and therefore select the scheduler's established free-running cadence.
//============================================================================
module mpeg2_h262_pts_presentation_timeline
(
    input  wire        clk,
    input  wire        reset,
    input  wire        tick_90k,
    input  wire        metadata_valid,
    input  wire [32:0] metadata_pts,
    input  wire        candidate_valid,
    input  wire [32:0] candidate_pts,
    output reg         anchored,
    output reg  [32:0] stc_90k,
    output wire        candidate_active,
    output wire        candidate_due
);

wire [32:0] candidate_lateness = stc_90k - candidate_pts;

assign candidate_active = anchored && candidate_valid;
assign candidate_due = candidate_active && !candidate_lateness[32];

// Entry 143: a delivered record lying implausibly far from the running clock
// is a stream timing discontinuity, not a picture to wait for.  Commercial
// media carry these at cell boundaries, and a decoder crossing one
// re-establishes its clock rather than stalling until wall time catches up.
// The threshold sits well above the ordinary half-second record spacing and
// the observed sub-quarter-second lead, and well below a real discontinuity.
localparam [32:0] DISCONTINUITY_TICKS = 33'd90000;

// Observability only: counts re-anchors after the initial one.  Not a port, so
// no instantiation changes and no synthesis impact beyond a saturating count.
reg [7:0] reanchor_count;

wire [32:0] record_ahead  = metadata_pts - stc_90k;
wire [32:0] record_behind = stc_90k - metadata_pts;
wire record_discontinuity =
    anchored && metadata_valid &&
    ((!record_ahead[32]  && (record_ahead  > DISCONTINUITY_TICKS)) ||
     (!record_behind[32] && (record_behind > DISCONTINUITY_TICKS)));

always @(posedge clk) begin
    if (reset) begin
        anchored <= 1'b0;
        stc_90k  <= 33'd0;
        reanchor_count <= 8'd0;
    end
    else if (metadata_valid && (!anchored || record_discontinuity)) begin
        anchored <= 1'b1;
        stc_90k  <= metadata_pts;
        if (anchored && (reanchor_count != 8'hFF))
            reanchor_count <= reanchor_count + 8'd1;
    end
    else if (anchored && tick_90k) begin
        stc_90k <= stc_90k + 33'd1;
    end
end

endmodule
