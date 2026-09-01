//============================================================================
// MiSTer Media Player - production 720x480p / 720x480i output timing
//
// The reset and fallback mode is CTA 720x480p at 60000/1001 Hz:
//   H: 720 active, sync 736..797, total 858 (negative polarity)
//   V: 480 active, sync 489..494, total 525 (negative polarity)
//
// Supported interlaced sequences select CTA 720x480i at 30000/1001 Hz:
//   H: 720 active, sync 739..800, total 858 (negative polarity)
//   V: 480 active over two half-line-phased fields, total 525 lines.
//
// clk is 54 MHz. Progressive ce_pixel is an exact divide-by-two (27 MHz);
// interlaced ce_pixel is an exact divide-by-four (13.5 MHz). Mode changes occur
// only after a complete progressive or interlaced frame, so MiSTer's scaler and
// direct-video outputs never observe a torn raster.
//============================================================================

module mpeg2_video_output_timing
(
    input  wire        clk,
    input  wire        reset,
    input  wire        interlaced_request_async,
    input  wire        top_field_first_async,

    output reg         interlaced_active,
    output wire        ce_pixel,
    output wire [11:0] h_pos,
    output wire [11:0] v_pos,
    output wire        pixel_en,
    output wire        h_sync,
    output wire        v_sync,
    output wire        field,
    output wire        field_window,
    output wire        field_swap_window,
    output wire        frame_window
);

localparam integer H_ACTIVE = 720;
localparam integer H_TOTAL  = 858;

localparam integer PROG_H_SYNC_START = 736;
localparam integer PROG_H_SYNC_END   = 798;
localparam integer PROG_V_ACTIVE     = 480;
localparam integer PROG_V_SYNC_START = 489;
localparam integer PROG_V_SYNC_END   = 495;
localparam integer PROG_V_TOTAL      = 525;

localparam integer INT_H_SYNC_START = 739;
localparam integer INT_H_SYNC_END   = 801;
localparam integer INT_FIELD_TICKS  = 225225;
localparam integer INT_TOP_VS_START = 209352;
localparam integer INT_TOP_VS_END   = 211926;
localparam integer INT_BOT_VS_START = 209781;
localparam integer INT_BOT_VS_END   = 212355;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] interlaced_request_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] top_field_first_sync;

reg       progressive_ce_div;
reg [1:0] interlaced_ce_div;
wire progressive_ce = progressive_ce_div;
wire interlaced_ce = (interlaced_ce_div == 2'd3);
assign ce_pixel = interlaced_active ? interlaced_ce : progressive_ce;

reg [11:0] progressive_h;
reg [11:0] progressive_v;

reg [11:0] interlaced_h;
reg [17:0] interlaced_field_tick;
reg [7:0]  interlaced_field_line;
reg        interlaced_field;
reg        interlaced_first_field;
reg        interlaced_active_line;
reg        interlaced_active_seen;
reg        interlaced_tail_window_d;

wire progressive_hsync_low =
    (progressive_h >= PROG_H_SYNC_START) &&
    (progressive_h <  PROG_H_SYNC_END);
wire progressive_vsync_low =
    (progressive_v >= PROG_V_SYNC_START) &&
    (progressive_v <  PROG_V_SYNC_END);

wire interlaced_hsync_low =
    (interlaced_h >= INT_H_SYNC_START) &&
    (interlaced_h <  INT_H_SYNC_END);
wire interlaced_vsync_low = !interlaced_field ?
    ((interlaced_field_tick >= INT_TOP_VS_START) &&
     (interlaced_field_tick <  INT_TOP_VS_END)) :
    ((interlaced_field_tick >= INT_BOT_VS_START) &&
     (interlaced_field_tick <  INT_BOT_VS_END));

wire interlaced_tail_window =
    !interlaced_active_line && interlaced_active_seen;
// Delay the interlaced frame-bank window one logical sample after the authored
// second-field cadence edge, preserving the accepted ready/swap ordering.
wire interlaced_frame_window =
    interlaced_tail_window &&
    interlaced_tail_window_d &&
    (interlaced_field != interlaced_first_field) &&
    interlaced_active;

assign h_pos = interlaced_active ? interlaced_h : progressive_h;
assign v_pos = interlaced_active ?
    {3'd0, interlaced_field_line, interlaced_field} : progressive_v;
assign pixel_en = interlaced_active ?
    (interlaced_active_line && (interlaced_h < H_ACTIVE)) :
    ((progressive_h < H_ACTIVE) && (progressive_v < PROG_V_ACTIVE));
assign h_sync = interlaced_active ?
    !interlaced_hsync_low : !progressive_hsync_low;
assign v_sync = interlaced_active ?
    !interlaced_vsync_low : !progressive_vsync_low;

assign field = interlaced_active && interlaced_field;
assign field_swap_window =
    interlaced_active && interlaced_tail_window && interlaced_tail_window_d;
assign field_window = interlaced_active ?
    interlaced_tail_window : (progressive_v >= PROG_V_ACTIVE);
assign frame_window = interlaced_active ?
    interlaced_frame_window : (progressive_v >= PROG_V_ACTIVE);

always @(posedge clk) begin
    if (reset) begin
        interlaced_request_sync <= 2'b00;
        top_field_first_sync    <= 2'b11;
        interlaced_active       <= 1'b0;
        progressive_ce_div      <= 1'b0;
        interlaced_ce_div       <= 2'd0;
        progressive_h           <= 12'd0;
        progressive_v           <= 12'd0;
        interlaced_h            <= 12'd0;
        interlaced_field_tick   <= 18'd0;
        interlaced_field_line   <= 8'd0;
        interlaced_field        <= 1'b0;
        interlaced_first_field  <= 1'b0;
        interlaced_active_line  <= 1'b1;
        interlaced_active_seen  <= 1'b1;
        interlaced_tail_window_d <= 1'b0;
    end
    else begin
        interlaced_request_sync <=
            {interlaced_request_sync[0], interlaced_request_async};
        top_field_first_sync <=
            {top_field_first_sync[0], top_field_first_async};

        if (interlaced_active) begin
            progressive_ce_div <= 1'b0;
            interlaced_ce_div <= interlaced_ce_div + 2'd1;

            if (interlaced_ce) begin
                interlaced_tail_window_d <= interlaced_tail_window;

                if (interlaced_h == H_TOTAL-1)
                    interlaced_h <= 12'd0;
                else
                    interlaced_h <= interlaced_h + 12'd1;

                if (interlaced_field_tick == INT_FIELD_TICKS-1) begin
                    interlaced_field_tick <= 18'd0;
                    interlaced_field      <= ~interlaced_field;
                    interlaced_field_line <= 8'd0;

                    // A top field starts at horizontal phase zero. A bottom
                    // field begins at the half-line phase and reaches active
                    // h=0 after 429 logical samples.
                    if (interlaced_field) begin
                        interlaced_active_line <= 1'b1;
                        interlaced_active_seen <= 1'b1;
                    end
                    else begin
                        interlaced_active_line <= 1'b0;
                        interlaced_active_seen <= 1'b0;
                    end

                    // Return to progressive only at the complete-frame edge,
                    // immediately before the session's authored first field.
                    if (!interlaced_request_sync[1] &&
                        ((~interlaced_field) == interlaced_first_field)) begin
                        interlaced_active   <= 1'b0;
                        progressive_ce_div <= 1'b0;
                        progressive_h       <= 12'd0;
                        progressive_v       <= 12'd0;
                    end
                end
                else begin
                    interlaced_field_tick <= interlaced_field_tick + 18'd1;

                    if (interlaced_h == H_TOTAL-1) begin
                        if (interlaced_active_line) begin
                            if (interlaced_field_line == 8'd239)
                                interlaced_active_line <= 1'b0;
                            else
                                interlaced_field_line <=
                                    interlaced_field_line + 8'd1;
                        end
                        else if (interlaced_field &&
                                 !interlaced_active_seen) begin
                            interlaced_active_line <= 1'b1;
                            interlaced_active_seen <= 1'b1;
                            interlaced_field_line  <= 8'd0;
                        end
                    end
                end
            end
        end
        else begin
            interlaced_ce_div <= 2'd0;
            progressive_ce_div <= ~progressive_ce_div;

            if (progressive_ce) begin
                if (progressive_h == H_TOTAL-1) begin
                    progressive_h <= 12'd0;
                    if (progressive_v == PROG_V_TOTAL-1)
                        progressive_v <= 12'd0;
                    else
                        progressive_v <= progressive_v + 12'd1;
                end
                else begin
                    progressive_h <= progressive_h + 12'd1;
                end

                // Enter interlaced mode only after a complete progressive
                // frame. The first authored field order is fixed here.
                if (interlaced_request_sync[1] &&
                    (progressive_h == H_TOTAL-1) &&
                    (progressive_v == PROG_V_TOTAL-1)) begin
                    interlaced_active      <= 1'b1;
                    interlaced_ce_div      <= 2'd0;
                    interlaced_first_field <= ~top_field_first_sync[1];
                    interlaced_field       <= ~top_field_first_sync[1];
                    interlaced_field_tick  <= 18'd0;
                    interlaced_field_line  <= 8'd0;
                    interlaced_tail_window_d <= 1'b0;
                    interlaced_h <=
                        top_field_first_sync[1] ? 12'd0 : 12'd429;

                    if (top_field_first_sync[1]) begin
                        interlaced_active_line <= 1'b1;
                        interlaced_active_seen <= 1'b1;
                    end
                    else begin
                        interlaced_active_line <= 1'b0;
                        interlaced_active_seen <= 1'b0;
                    end
                end
            end
        end
    end
end

endmodule
