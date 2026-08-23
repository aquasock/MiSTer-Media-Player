// ============================================================================
//  mpeg2_h262_picture_timestamp
//
//  Entry 372: bind in-band timestamps to pictures and carry them through frame
//  ownership, so a timestamp is available for the frame actually being
//  displayed rather than the one most recently decoded.
//
//  Pictures are decoded out of display order.  A B picture decodes after the
//  reference that follows it on screen, so "the last timestamp extracted" is
//  not the timestamp of what the viewer is seeing.  The timestamp therefore
//  travels with the frame: it is captured at the picture start that follows
//  its record, held while that picture decodes, and committed to the frame
//  bank the picture lands in.  Reading it back by display_frame_bank then
//  yields the timestamp of the displayed frame regardless of decode order.
//
//  A picture completion is detected as a toggle of active_frame_bank, which
//  the bookkeeper inverts only when a picture persists.  That avoids adding an
//  output to the bookkeeper for an event already visible.
//
//  Nothing here changes when frames are presented.  Presentation remains free
//  running; this cycle proves the association and the carry, which are the
//  parts that reordering makes difficult, before anything depends on them.
// ============================================================================

module mpeg2_h262_picture_timestamp
(
    input  wire        clk,
    input  wire        reset,

    // From the in-band metadata extractor.
    input  wire        metadata_valid,
    input  wire [32:0] metadata_pts,

    // A one-cycle pulse at each picture header.  This must NOT be the
    // frontend's picture_seen, which is a sticky level set at the first
    // picture and cleared only by reset: with a level here the pending
    // timestamp is cleared in the same cycle it arrives and nothing is ever
    // associated.  Hardware caught that; simulation did not, because the test
    // modelled the assumption rather than the signal.
    input  wire        picture_start,

    // Frame ownership.
    input  wire  [1:0] active_frame_bank,
    input  wire  [1:0] display_frame_bank,

    output wire [32:0] display_pts,
    output wire        display_pts_valid,
    output reg   [7:0] associated_count
);

// A record precedes the picture it describes, so the timestamp waits here
// until that picture actually starts.
reg [32:0] pending_pts;
reg        pending_valid;

// The picture currently decoding.
reg [32:0] current_pts;
reg        current_valid;

reg [32:0] bank_pts   [0:3];
reg  [3:0] bank_valid;

reg [1:0] active_frame_bank_q;
wire      picture_committed = (active_frame_bank != active_frame_bank_q);

assign display_pts       = bank_pts[display_frame_bank];
assign display_pts_valid = bank_valid[display_frame_bank];

integer i;

always @(posedge clk) begin
    if (reset) begin
        pending_pts         <= 33'd0;
        pending_valid       <= 1'b0;
        current_pts         <= 33'd0;
        current_valid       <= 1'b0;
        bank_valid          <= 4'd0;
        active_frame_bank_q <= 2'd0;
        associated_count    <= 8'd0;
        for (i = 0; i < 4; i = i + 1)
            bank_pts[i] <= 33'd0;
    end
    else begin
        active_frame_bank_q <= active_frame_bank;

        // The first picture start after a record claims it.  A picture with no
        // preceding record carries no timestamp rather than inheriting a stale
        // one, which is what keeps mixed and unannotated streams honest.  A
        // record completing in the same cycle as a picture start belongs to
        // that picture, so it is taken directly rather than through pending.
        if (picture_start) begin
            current_pts   <= metadata_valid ? metadata_pts : pending_pts;
            current_valid <= metadata_valid | pending_valid;
            pending_valid <= 1'b0;
        end
        else if (metadata_valid) begin
            pending_pts   <= metadata_pts;
            pending_valid <= 1'b1;
        end

        if (picture_committed) begin
            bank_pts[active_frame_bank_q]   <= current_pts;
            bank_valid[active_frame_bank_q] <= current_valid;
            current_valid                   <= 1'b0;
            if (current_valid && (associated_count != 8'hFF))
                associated_count <= associated_count + 8'd1;
        end
    end
end

endmodule
