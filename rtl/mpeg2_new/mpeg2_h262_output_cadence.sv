//============================================================================
// Exact H.262 source-picture cadence on the 60000/1001 production raster.
//
// One tick represents one progressive output frame. Interlaced callers provide
// one tick per field; code 4 then reaches one source-picture credit per pair.
// A consume event includes the current output tick, matching the scheduler's
// presentation-window semantics and preventing credit from accumulating while
// decode is stalled.
//============================================================================

module mpeg2_h262_output_cadence
(
    input  wire       clk,
    input  wire       reset,
    input  wire       tick,
    input  wire       consume,
    input  wire [3:0] frame_rate_code,
    output wire       slot
);

localparam [11:0] LIMIT_24000_1001 = 12'd5;
localparam [11:0] STEP_24000_1001  = 12'd2;
localparam [11:0] LIMIT_24FPS       = 12'd2500;
localparam [11:0] STEP_24FPS        = 12'd1001;
localparam [11:0] LIMIT_25FPS       = 12'd2400;
localparam [11:0] STEP_25FPS        = 12'd1001;
localparam [11:0] LIMIT_30000_1001 = 12'd2;
localparam [11:0] STEP_30000_1001  = 12'd1;
localparam [11:0] LIMIT_30FPS       = 12'd2000;
localparam [11:0] STEP_30FPS        = 12'd1001;

wire rate_24000_1001 = (frame_rate_code == 4'd1);
wire rate_24fps       = (frame_rate_code == 4'd2);
wire rate_25fps       = (frame_rate_code == 4'd3);
wire rate_30000_1001 = (frame_rate_code == 4'd4);
wire rate_30fps       = (frame_rate_code == 4'd5);
wire rate_supported = rate_24000_1001 || rate_24fps || rate_25fps ||
                      rate_30000_1001 || rate_30fps;

wire [11:0] cadence_limit = rate_24000_1001 ? LIMIT_24000_1001 :
                            rate_24fps       ? LIMIT_24FPS :
                            rate_25fps       ? LIMIT_25FPS :
                            rate_30000_1001 ? LIMIT_30000_1001 :
                                               LIMIT_30FPS;
wire [11:0] cadence_step = rate_24000_1001 ? STEP_24000_1001 :
                           rate_24fps       ? STEP_24FPS :
                           rate_25fps       ? STEP_25FPS :
                           rate_30000_1001 ? STEP_30000_1001 :
                                              STEP_30FPS;
wire [11:0] cadence_due = cadence_limit - cadence_step;

reg [11:0] cadence_credit;
reg [3:0]  rate_code_q;
wire rate_changed = (rate_code_q != frame_rate_code);

assign slot = !rate_changed &&
              (!rate_supported || (cadence_credit >= cadence_due));

always @(posedge clk) begin
    if (reset) begin
        cadence_credit <= LIMIT_24FPS - STEP_24FPS;
        rate_code_q    <= 4'd0;
    end
    else begin
        rate_code_q <= frame_rate_code;

        if (rate_changed)
            cadence_credit <= cadence_due;
        else if (consume && rate_supported)
            cadence_credit <= cadence_credit + cadence_step - cadence_limit;
        else if (tick) begin
            if (!rate_supported)
                cadence_credit <= LIMIT_24FPS - STEP_24FPS;
            else if (cadence_credit < cadence_due)
                cadence_credit <= cadence_credit + cadence_step;
            else
                cadence_credit <= cadence_due;
        end
    end
end

endmodule
