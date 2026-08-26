//============================================================================
// MiSTer Media Player - passive accepted-luma-write fingerprint retention
//
// One position-mixed contribution arrives with each DDR writer acceptance.
// Contributions are retained independently for the five physical framebuffer
// regions and two luma row parities.  No output feeds writer, DDR, scheduler or
// presentation control; the selected pair is diagnostic evidence only.
//============================================================================

module mpeg2_h262_luma_write_fingerprint
(
    input  wire        clk,
    input  wire        reset,
    input  wire        writer_accept,
    input  wire        luma_word,
    input  wire [2:0]  luma_region,
    input  wire        luma_row_parity,
    input  wire        luma_picture_start,
    input  wire        luma_picture_complete,
    input  wire [31:0] luma_position_fingerprint,
    input  wire [2:0]  display_region,
    output wire [31:0] expected_even_fingerprint,
    output wire [31:0] expected_odd_fingerprint,
    output wire        expected_valid
);

reg [31:0] even_fingerprint [0:7];
reg [31:0] odd_fingerprint [0:7];
reg        fingerprint_valid [0:7];
integer region_index;

always @(posedge clk) begin
    if (reset) begin
        for (region_index = 0; region_index < 8;
             region_index = region_index + 1) begin
            even_fingerprint[region_index] <= 32'd0;
            odd_fingerprint[region_index] <= 32'd0;
            fingerprint_valid[region_index] <= 1'b0;
        end
    end
    else if (writer_accept && luma_word && (luma_region < 3'd5)) begin
        if (luma_picture_start) begin
            even_fingerprint[luma_region] <=
                luma_row_parity ? 32'd0 : luma_position_fingerprint;
            odd_fingerprint[luma_region] <=
                luma_row_parity ? luma_position_fingerprint : 32'd0;
            fingerprint_valid[luma_region] <= 1'b0;
        end
        else if (luma_row_parity)
            odd_fingerprint[luma_region] <=
                odd_fingerprint[luma_region] ^ luma_position_fingerprint;
        else
            even_fingerprint[luma_region] <=
                even_fingerprint[luma_region] ^ luma_position_fingerprint;

        if (luma_picture_complete)
            fingerprint_valid[luma_region] <= 1'b1;
    end
end

assign expected_even_fingerprint = even_fingerprint[display_region];
assign expected_odd_fingerprint = odd_fingerprint[display_region];
assign expected_valid = fingerprint_valid[display_region];

endmodule
