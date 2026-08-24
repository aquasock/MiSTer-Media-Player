//============================================================================
// Stable native-interlaced field-order envelope
//
// The first native milestone presents complete frame pictures as two fields.
// Physical 480i timing must alternate top and bottom fields, so a session that
// changes its authored first-field order cannot be presented by this bounded
// path without an additional repeat/drop policy. Lock the first interlaced
// picture's order and withdraw native eligibility on any later mismatch.
//============================================================================
module mpeg2_h262_native_field_order
(
    input  wire clk,
    input  wire reset,
    input  wire picture_coding_extension_valid,
    input  wire progressive_sequence,
    input  wire picture_top_field_first,
    output reg  locked,
    output reg  top_field_first,
    output reg  mismatch
);

always @(posedge clk) begin
    if (reset) begin
        locked          <= 1'b0;
        top_field_first <= 1'b1;
        mismatch        <= 1'b0;
    end
    else if (picture_coding_extension_valid && !progressive_sequence) begin
        if (!locked) begin
            locked          <= 1'b1;
            top_field_first <= picture_top_field_first;
        end
        else if (top_field_first != picture_top_field_first) begin
            mismatch <= 1'b1;
        end
    end
end

endmodule
