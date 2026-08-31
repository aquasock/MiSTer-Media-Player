//============================================================================
// Stable native-interlaced field-order envelope
//
// The first native milestone presents complete frame pictures as two fields.
// Physical 480i timing must alternate top and bottom fields, so a session that
// changes its authored first-field order needs per-picture field admission.
// Film mode enables that path and stays set after any progressive frame in an
// interlaced sequence, so a chapter may move between ordinary and film frame
// pictures without withdrawing native timing. Before that transition, a pure
// ordinary-interlaced run retains the fixed-order mismatch guard.
//============================================================================
module mpeg2_h262_native_field_order
(
    input  wire clk,
    input  wire reset,
    input  wire picture_coding_extension_valid,
    input  wire progressive_sequence,
    input  wire picture_top_field_first,
    input  wire picture_progressive_frame,
    output reg film_mode,
    output reg  locked,
    output reg  top_field_first,
    output reg  mismatch
);

always @(posedge clk) begin
    if (reset) begin
        locked          <= 1'b0;
        film_mode       <= 1'b0;
        top_field_first <= 1'b1;
        mismatch        <= 1'b0;
    end
    else if (picture_coding_extension_valid && !progressive_sequence) begin
        if (!locked) begin
            locked          <= 1'b1;
            film_mode       <= picture_progressive_frame;
            top_field_first <= picture_top_field_first;
        end
        else if (!film_mode && !picture_progressive_frame &&
                 top_field_first != picture_top_field_first) begin
            mismatch <= 1'b1;
        end
        else if (picture_progressive_frame) begin
            film_mode <= 1'b1;
        end
    end
end

endmodule
