//============================================================================
// MiSTer Media Player - H.262 picture timestamp ownership
//
// Entry 389: bind each in-band timestamp to the picture it describes and keep
// that timestamp with the physical frame that persists.  Reference pictures
// occupy one of the bookkeeper's frame banks; reordered B pictures occupy one
// of the scheduler's two scratch banks.  Separate validity bits make a missing
// record an intentional free-running-cadence picture, never a stale timestamp.
//============================================================================
module mpeg2_h262_picture_timestamp
(
    input  wire        clk,
    input  wire        reset,

    input  wire        metadata_valid,
    input  wire [32:0] metadata_pts,
    input  wire        picture_coding_extension_valid,
    input  wire        picture_top_field_first,
    input  wire        picture_repeat_first_field,
    input  wire        picture_progressive_frame,

    // Classified picture-header event and its destination class.
    input  wire        picture_start,
    input  wire        picture_is_b,
    input  wire        decode_scratch_bank,

    // Persistence events.  Reference persistence toggles active_frame_bank;
    // B success may be a level, so its rising edge is formed locally.
    input  wire        b_picture_complete,
    input  wire  [1:0] active_frame_bank,

    // Current display identity.
    input  wire  [1:0] display_frame_bank,
    input  wire        display_scratch,
    input  wire        display_scratch_bank,

    // Scheduler's next stable presentation identity.
    input  wire        candidate_frame_valid,
    input  wire        candidate_frame_scratch,
    input  wire        candidate_scratch_bank,
    input  wire  [1:0] candidate_frame_bank,

    output wire [32:0] display_pts,
    output wire        display_pts_valid,
    output wire        display_top_field_first,
    output wire        display_repeat_first_field,
    output wire        display_progressive_frame,
    output wire        display_descriptor_valid,
    output wire        candidate_top_field_first,
    output wire [32:0] candidate_pts,
    output wire        candidate_pts_valid,
    output reg   [7:0] associated_count
);

// A record precedes the picture it describes.
reg [32:0] pending_pts;
reg        pending_valid;

// Timestamp and destination of the picture currently decoding.
reg [32:0] current_pts;
reg        current_valid;
reg        current_is_b;
reg        current_top_field_first;
reg        current_repeat_first_field, current_progressive_frame;
reg        current_owned;
// Classification can precede persistence of the preceding picture. Keep
// that retiring descriptor separately while the new header/PCE fills current.
reg        retiring_owned, retiring_is_b, retiring_valid;
reg [32:0] retiring_pts;
reg        retiring_top_field_first, retiring_repeat_first_field;
reg        retiring_progressive_frame;
reg        retiring_scratch_bank;
reg [3:0] frame_bank_repeat,frame_bank_progressive,frame_bank_descriptor_valid;
reg [1:0] scratch_bank_repeat,scratch_bank_progressive,scratch_bank_descriptor_valid;

reg [32:0] frame_bank_pts [0:3];
reg  [3:0] frame_bank_valid;
reg  [3:0] frame_bank_top_field_first;
reg [32:0] scratch_bank_pts [0:1];
reg  [1:0] scratch_bank_valid;
reg  [1:0] scratch_bank_top_field_first;

reg [1:0] active_frame_bank_q;
reg       b_picture_complete_q;

wire owner_is_b = retiring_owned ? retiring_is_b : current_is_b;
wire owner_present = retiring_owned || current_owned;
wire [32:0] owner_pts = retiring_owned ? retiring_pts : current_pts;
wire owner_valid = retiring_owned ? retiring_valid : current_valid;
wire owner_top_field_first = retiring_owned ? retiring_top_field_first : current_top_field_first;
wire owner_repeat_first_field = retiring_owned ? retiring_repeat_first_field : current_repeat_first_field;
wire owner_progressive_frame = retiring_owned ? retiring_progressive_frame : current_progressive_frame;
wire owner_scratch_bank = retiring_owned ? retiring_scratch_bank : decode_scratch_bank;
wire reference_picture_committed = owner_present && !owner_is_b &&
    (active_frame_bank != active_frame_bank_q);
wire b_picture_committed = owner_present && owner_is_b &&
    b_picture_complete && !b_picture_complete_q;
wire picture_committed = reference_picture_committed || b_picture_committed;

assign display_pts = display_scratch ?
    scratch_bank_pts[display_scratch_bank] :
    frame_bank_pts[display_frame_bank];
assign display_pts_valid = display_scratch ?
    scratch_bank_valid[display_scratch_bank] :
    frame_bank_valid[display_frame_bank];
assign display_top_field_first = display_scratch ?
    scratch_bank_top_field_first[display_scratch_bank] :
    frame_bank_top_field_first[display_frame_bank];

assign display_repeat_first_field=display_scratch ? scratch_bank_repeat[display_scratch_bank] : frame_bank_repeat[display_frame_bank];
assign display_progressive_frame=display_scratch ? scratch_bank_progressive[display_scratch_bank] : frame_bank_progressive[display_frame_bank];
assign display_descriptor_valid=display_scratch ? scratch_bank_descriptor_valid[display_scratch_bank] : frame_bank_descriptor_valid[display_frame_bank];
assign candidate_top_field_first=candidate_frame_scratch ? scratch_bank_top_field_first[candidate_scratch_bank] : frame_bank_top_field_first[candidate_frame_bank];

assign candidate_pts = candidate_frame_scratch ?
    scratch_bank_pts[candidate_scratch_bank] :
    frame_bank_pts[candidate_frame_bank];
assign candidate_pts_valid = candidate_frame_valid &&
    (candidate_frame_scratch ?
        scratch_bank_valid[candidate_scratch_bank] :
        frame_bank_valid[candidate_frame_bank]);

integer i;

always @(posedge clk) begin
    if (reset) begin
        pending_pts          <= 33'd0;
        pending_valid        <= 1'b0;
        current_pts          <= 33'd0;
        current_valid        <= 1'b0;
        current_is_b         <= 1'b0;
        current_owned        <= 1'b0;
        retiring_owned       <= 1'b0;
        retiring_is_b        <= 1'b0;
        retiring_valid       <= 1'b0;
        retiring_pts         <= 33'd0;
        retiring_top_field_first <= 1'b1;
        retiring_repeat_first_field <= 1'b0;
        retiring_progressive_frame <= 1'b0;
        retiring_scratch_bank <= 1'b0;
        current_top_field_first <= 1'b1;
        current_repeat_first_field<=0;current_progressive_frame<=0;
        frame_bank_repeat<=0;frame_bank_progressive<=0;frame_bank_descriptor_valid<=0;
        scratch_bank_repeat<=0;scratch_bank_progressive<=0;scratch_bank_descriptor_valid<=0;
        frame_bank_valid     <= 4'd0;
        frame_bank_top_field_first <= 4'hF;
        scratch_bank_valid   <= 2'd0;
        scratch_bank_top_field_first <= 2'b11;
        active_frame_bank_q  <= 2'd0;
        b_picture_complete_q <= 1'b0;
        associated_count     <= 8'd0;
        for (i = 0; i < 4; i = i + 1)
            frame_bank_pts[i] <= 33'd0;
        for (i = 0; i < 2; i = i + 1)
            scratch_bank_pts[i] <= 33'd0;
    end
    else begin
        active_frame_bank_q  <= active_frame_bank;
        b_picture_complete_q <= b_picture_complete;

        if (picture_coding_extension_valid) begin
            current_top_field_first <= picture_top_field_first;
            current_repeat_first_field <= picture_repeat_first_field;
            current_progressive_frame <= picture_progressive_frame;
        end

        // A same-cycle record belongs directly to this picture.  Otherwise
        // consume the one pending record, or explicitly mark the picture as
        // unannotated so it cannot inherit an earlier value.
        if (picture_start) begin
            if (current_owned && (!picture_committed || retiring_owned)) begin
                retiring_owned <= 1'b1;
                retiring_is_b <= current_is_b;
                retiring_valid <= current_valid;
                retiring_pts <= current_pts;
                retiring_top_field_first <= current_top_field_first;
                retiring_repeat_first_field <= current_repeat_first_field;
                retiring_progressive_frame <= current_progressive_frame;
                retiring_scratch_bank <= decode_scratch_bank;
            end
            else if (picture_committed)
                retiring_owned <= 1'b0;
            current_owned        <= 1'b1;
            current_pts          <= metadata_valid ? metadata_pts : pending_pts;
            current_valid        <= metadata_valid | pending_valid;
            current_is_b         <= picture_is_b;
            pending_valid        <= 1'b0;
        end
        else if (metadata_valid) begin
            pending_pts   <= metadata_pts;
            pending_valid <= 1'b1;
        end

        if (reference_picture_committed) begin
            frame_bank_repeat[active_frame_bank_q]<=owner_repeat_first_field;
            frame_bank_progressive[active_frame_bank_q]<=owner_progressive_frame;
            frame_bank_descriptor_valid[active_frame_bank_q]<=1;
            frame_bank_pts[active_frame_bank_q]   <= owner_pts;
            frame_bank_valid[active_frame_bank_q] <= owner_valid;
            frame_bank_top_field_first[active_frame_bank_q] <=
                owner_top_field_first;
            if (owner_valid && (associated_count != 8'hFF))
                associated_count <= associated_count + 8'd1;
        end

        if (b_picture_committed) begin
            scratch_bank_repeat[owner_scratch_bank]<=owner_repeat_first_field;
            scratch_bank_progressive[owner_scratch_bank]<=owner_progressive_frame;
            scratch_bank_descriptor_valid[owner_scratch_bank]<=1;
            // The scheduler holds decode_scratch_bank for the entire B
            // transaction, so the persistence edge is the authoritative
            // physical destination (including queued-generation admission).
            scratch_bank_pts[owner_scratch_bank]   <= owner_pts;
            scratch_bank_valid[owner_scratch_bank] <= owner_valid;
            scratch_bank_top_field_first[owner_scratch_bank] <=
                owner_top_field_first;
            if (owner_valid && (associated_count != 8'hFF))
                associated_count <= associated_count + 8'd1;
        end

        // A completion and the following picture header may share a clock;
        // in that case the new header assignment above must survive.
        if (picture_committed && !picture_start) begin
            if (retiring_owned)
                retiring_owned <= 1'b0;
            else begin
                current_owned <= 1'b0;
                current_valid <= 1'b0;
            end
        end
    end
end

endmodule
