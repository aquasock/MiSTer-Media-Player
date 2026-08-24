//============================================================================
// MiSTer Media Player - diagnostic progressive / native 720x480i timing
//
// The native mode is CTA VIC 6/7 geometry at a 13.5 MHz logical sample rate:
//   H: 720 active, sync 739..800, total 858 (negative polarity)
//   V: 480 active, sync 488..493, total 525 (negative polarity, interlaced)
//
// clk is 54 MHz. Native ce_pixel is therefore an exact divide-by-four. The
// legacy 800x600 diagnostic raster uses a 20/27 clock-enable accumulator to
// retain its 40 MHz logical rate while sharing the one MiSTer video domain.
// Native horizontal phase never resets at a field boundary: 225225 logical
// samples per field advances it by exactly 429 samples, producing the required
// half-line relationship between alternating fields.
//============================================================================

module mpeg2_video_output_timing
(
    input  wire        clk,
    input  wire        reset,
    input  wire        native_request_async,
    input  wire        top_field_first_async,

    output reg         native_active,
    output wire        ce_pixel,
    output wire [11:0] h_pos,
    output wire [11:0] v_pos,
    output wire        pixel_en,
    output wire        h_sync,
    output wire        v_sync,
    output wire        field,
    output wire        field_window,
    output wire        frame_window
);

localparam integer DIAG_H_ACTIVE = 800;
localparam integer DIAG_H_TOTAL  = 1056;
localparam integer DIAG_V_ACTIVE = 600;
localparam integer DIAG_V_TOTAL  = 628;

localparam integer NTSC_H_ACTIVE     = 720;
localparam integer NTSC_H_SYNC_START = 739;
localparam integer NTSC_H_SYNC_END   = 801;
localparam integer NTSC_H_TOTAL      = 858;
localparam integer NTSC_FIELD_TICKS  = 225225;
localparam integer NTSC_ACTIVE_TICKS = 205920;
localparam integer NTSC_TOP_VS_START = 209352;
localparam integer NTSC_TOP_VS_END   = 211926;
localparam integer NTSC_BOT_VS_START = 209781;
localparam integer NTSC_BOT_VS_END   = 212355;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] native_request_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] top_field_first_sync;

reg [5:0] diag_ce_phase;
reg [1:0] native_ce_div;

wire diag_ce = ({1'b0, diag_ce_phase} + 7'd20) >= 7'd27;
wire native_ce = (native_ce_div == 2'd3);
assign ce_pixel = native_active ? native_ce : diag_ce;

reg [11:0] diag_h;
reg [11:0] diag_v;

reg [11:0] native_h;
reg [17:0] native_field_tick;
reg [7:0]  native_field_line;
reg        native_field;
reg        native_first_field;
reg        native_active_line;
reg        native_active_seen;

wire native_hsync_low =
    (native_h >= NTSC_H_SYNC_START) &&
    (native_h <  NTSC_H_SYNC_END);

wire native_vsync_low = !native_field ?
    ((native_field_tick >= NTSC_TOP_VS_START) &&
     (native_field_tick <  NTSC_TOP_VS_END)) :
    ((native_field_tick >= NTSC_BOT_VS_START) &&
     (native_field_tick <  NTSC_BOT_VS_END));

wire native_tail_window = !native_active_line && native_active_seen;

assign h_pos = native_active ? native_h : diag_h;
assign v_pos = native_active ?
    {3'd0, native_field_line, native_field} : diag_v;
assign pixel_en = native_active ?
    (native_active_line && (native_h < NTSC_H_ACTIVE)) :
    ((diag_h < DIAG_H_ACTIVE) && (diag_v < DIAG_V_ACTIVE));

assign h_sync = native_active ? !native_hsync_low :
    ((diag_h >= 12'd840) && (diag_h < 12'd968));
assign v_sync = native_active ? !native_vsync_low :
    ((diag_v >= 12'd601) && (diag_v < 12'd605));

assign field = native_active && native_field;
assign field_window = native_active ? native_tail_window :
    (diag_v >= DIAG_V_ACTIVE);
assign frame_window = native_active ?
    (native_tail_window && (native_field != native_first_field)) :
    (diag_v >= DIAG_V_ACTIVE);

always @(posedge clk) begin
    if (reset) begin
        native_request_sync   <= 2'b00;
        top_field_first_sync  <= 2'b11;
        native_active         <= 1'b0;
        diag_ce_phase         <= 6'd0;
        native_ce_div         <= 2'd0;
        diag_h                <= 12'd0;
        diag_v                <= 12'd0;
        native_h              <= 12'd0;
        native_field_tick     <= 18'd0;
        native_field_line     <= 8'd0;
        native_field          <= 1'b0;
        native_first_field    <= 1'b0;
        native_active_line    <= 1'b1;
        native_active_seen    <= 1'b1;
    end
    else begin
        native_request_sync  <= {native_request_sync[0],
                                 native_request_async};
        top_field_first_sync <= {top_field_first_sync[0],
                                 top_field_first_async};

        if (native_active) begin
            diag_ce_phase <= 6'd0;
            native_ce_div <= native_ce_div + 2'd1;

            if (native_ce) begin
                if (native_h == NTSC_H_TOTAL-1)
                    native_h <= 12'd0;
                else
                    native_h <= native_h + 12'd1;

                if (native_field_tick == NTSC_FIELD_TICKS-1) begin
                    native_field_tick  <= 18'd0;
                    native_field       <= ~native_field;
                    native_field_line  <= 8'd0;

                    // A top field starts at horizontal phase zero and can
                    // begin active video immediately. A bottom field begins
                    // at the half-line phase and reaches active h=0 after 429
                    // logical samples.
                    if (native_field) begin
                        native_active_line <= 1'b1;
                        native_active_seen <= 1'b1;
                    end
                    else begin
                        native_active_line <= 1'b0;
                        native_active_seen <= 1'b0;
                    end

                    // Leave native mode only at the complete-frame boundary,
                    // immediately before the session's authored first field.
                    if (!native_request_sync[1] &&
                        ((~native_field) == native_first_field)) begin
                        native_active <= 1'b0;
                        diag_ce_phase <= 6'd0;
                        diag_h        <= 12'd0;
                        diag_v        <= 12'd0;
                    end
                end
                else begin
                    native_field_tick <= native_field_tick + 18'd1;

                    if (native_h == NTSC_H_TOTAL-1) begin
                        if (native_active_line) begin
                            if (native_field_line == 8'd239)
                                native_active_line <= 1'b0;
                            else
                                native_field_line <= native_field_line + 8'd1;
                        end
                        else if (native_field && !native_active_seen) begin
                            native_active_line <= 1'b1;
                            native_active_seen <= 1'b1;
                            native_field_line  <= 8'd0;
                        end
                    end
                end
            end
        end
        else begin
            native_ce_div <= 2'd0;

            if (diag_ce) begin
                diag_ce_phase <= diag_ce_phase + 6'd20 - 6'd27;

                if (diag_h == DIAG_H_TOTAL-1) begin
                    diag_h <= 12'd0;
                    if (diag_v == DIAG_V_TOTAL-1)
                        diag_v <= 12'd0;
                    else
                        diag_v <= diag_v + 12'd1;
                end
                else begin
                    diag_h <= diag_h + 12'd1;
                end

                // Switch only after the complete diagnostic raster. The
                // synchronized field-order bit is then fixed for the native
                // session; a separate tracker withdraws native_request if a
                // later picture changes order.
                if (native_request_sync[1] &&
                    (diag_h == DIAG_H_TOTAL-1) &&
                    (diag_v == DIAG_V_TOTAL-1)) begin
                    native_active      <= 1'b1;
                    native_ce_div      <= 2'd0;
                    native_first_field <= ~top_field_first_sync[1];
                    native_field       <= ~top_field_first_sync[1];
                    native_field_tick  <= 18'd0;
                    native_field_line  <= 8'd0;
                    native_h <= top_field_first_sync[1] ? 12'd0 : 12'd429;

                    if (top_field_first_sync[1]) begin
                        native_active_line <= 1'b1;
                        native_active_seen <= 1'b1;
                    end
                    else begin
                        native_active_line <= 1'b0;
                        native_active_seen <= 1'b0;
                    end
                end
            end
            else begin
                diag_ce_phase <= diag_ce_phase + 6'd20;
            end
        end
    end
end

endmodule
