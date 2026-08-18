//============================================================================
// MiSTer Media Player - passive final-GOP progress diagnostic
//
// Entry 223: arm on the third accepted I-picture header and retain the deepest
// post-I50 transaction boundary.  This module is observational only: none of
// its outputs feed compressed-stream, raster, DDR, publication, ownership, or
// presentation control.
//============================================================================
module mpeg2_h262_final_gop_progress_probe
(
    input  wire       clk,
    input  wire       reset,
    input  wire       picture_header,
    input  wire [2:0] picture_header_type,
    input  wire       picture_complete,
    input  wire [2:0] picture_coding_type,
    input  wire       sideband_valid,
    input  wire [5:0] sideband_index,
    input  wire       row_persisted,
    input  wire       picture_persisted,
    input  wire       b_success,
    input  wire       display_scratch,
    input  wire       presentation_complete,
    output reg  [4:0] progress_stage
);

localparam [2:0] PICTURE_I = 3'b001;
localparam [2:0] PICTURE_P = 3'b010;
localparam [2:0] PICTURE_B = 3'b011;

reg [1:0] i_header_count;
reg       armed;
reg       b_success_d;
reg       display_scratch_d;

wire p_metadata = sideband_valid &&
    ((sideband_index == 6'h3e) || (sideband_index == 6'h3b));
wire b_success_edge = b_success && !b_success_d;
wire scratch_select_edge = display_scratch && !display_scratch_d;

always @(posedge clk) begin
    if (reset) begin
        i_header_count   <= 2'd0;
        armed            <= 1'b0;
        b_success_d      <= 1'b0;
        display_scratch_d <= 1'b0;
        progress_stage   <= 5'd0;
    end
    else begin
        b_success_d       <= b_success;
        display_scratch_d <= display_scratch;

        if (picture_header && (picture_header_type == PICTURE_I)) begin
            if (i_header_count != 2'd3)
                i_header_count <= i_header_count + 2'd1;
            if (i_header_count == 2'd2) begin
                armed          <= 1'b1;
                progress_stage <= 5'd1;
            end
        end

        if (armed) begin
            if (picture_complete &&
                (picture_coding_type == PICTURE_I) &&
                (progress_stage < 5'd2))
                progress_stage <= 5'd2;

            if (picture_header &&
                (picture_header_type == PICTURE_P) &&
                (progress_stage >= 5'd2) &&
                (progress_stage < 5'd3))
                progress_stage <= 5'd3;

            if (p_metadata &&
                (progress_stage >= 5'd3) &&
                (progress_stage < 5'd4))
                progress_stage <= 5'd4;

            if (row_persisted &&
                (progress_stage >= 5'd4) &&
                (progress_stage < 5'd5))
                progress_stage <= 5'd5;

            if (picture_persisted &&
                (progress_stage >= 5'd4) &&
                (progress_stage < 5'd6))
                progress_stage <= 5'd6;

            if (picture_complete &&
                (picture_coding_type == PICTURE_P) &&
                (progress_stage >= 5'd3) &&
                (progress_stage < 5'd7))
                progress_stage <= 5'd7;

            if (picture_header &&
                (picture_header_type == PICTURE_B) &&
                (progress_stage >= 5'd7) &&
                (progress_stage < 5'd8))
                progress_stage <= 5'd8;

            if (b_success_edge &&
                (progress_stage >= 5'd8) &&
                (progress_stage < 5'd9))
                progress_stage <= 5'd9;

            if (scratch_select_edge &&
                (progress_stage >= 5'd8) &&
                (progress_stage < 5'd10))
                progress_stage <= 5'd10;

            if (presentation_complete &&
                (progress_stage >= 5'd8) &&
                (progress_stage < 5'd11))
                progress_stage <= 5'd11;
        end
    end
end

endmodule
