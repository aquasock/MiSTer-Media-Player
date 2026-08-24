//============================================================================
// MiSTer Media Player - H.262 PTS presentation timeline
//
// Entry 389: advance a decoder-domain 33-bit 90 kHz timeline from the proven
// audio-derived tick.  New-file and seek-like download rearm reset this module,
// so a later session can establish a fresh origin without a multi-bit CDC.
//
// Entry 426: the origin is the first candidate picture, not the first metadata
// record.  Anchoring on metadata made the origin whatever timestamp happened to
// appear first in the multiplex, so a first picture whose own timestamp sat
// ahead of that origin waited the difference before it could be admitted --
// measured on hardware as 1.372 s of black screen while ungated audio played.
// Anchoring on the first candidate makes that picture due at once and leaves
// every subsequent interval unchanged, since only the origin moves.  Streams
// without timestamps never present a valid candidate, never anchor, and keep
// the scheduler's free-running cadence exactly as before.
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

always @(posedge clk) begin
    if (reset) begin
        anchored <= 1'b0;
        stc_90k  <= 33'd0;
    end
    else if (candidate_valid && !anchored) begin
        anchored <= 1'b1;
        stc_90k  <= candidate_pts;
    end
    else if (anchored && tick_90k) begin
        stc_90k <= stc_90k + 33'd1;
    end
end

endmodule
