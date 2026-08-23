// ============================================================================
//  mpeg2_h262_system_time_clock
//
//  Entry 365: the FPGA-owned presentation time base.
//
//  H.222.0 defines presentation timestamps against a 90 kHz System Time Clock.
//  This module owns that clock and is deliberately anchored to the 24.576 MHz
//  audio domain that sys/audio_out.sv already uses, not to the pixel clock.
//  Audio samples leave the fabric at exactly that rate, so a timebase derived
//  from it consumes externally decoded audio drift-free by construction and
//  every correction falls on the video side, where a full field of tolerance
//  exists.  The reverse arrangement would push jitter into audio, where it is
//  immediately audible.
//
//  The counter runs natively at 180 kHz, not 90 kHz, because a field period is
//  not an integral number of 90 kHz ticks: at 29.97 Hz a frame is 3003 ticks
//  and a field is 1501.5.  In 180 kHz half-ticks a field is 3003, a frame 6006
//  and a repeat_first_field frame 9009 -- all exact.  That is what lets 3:2
//  pulldown be expressed later without reworking this arithmetic.  The 90 kHz
//  value the timestamps are compared against is simply the half-tick count
//  shifted right, so the two can never disagree.
//
//  The divide is exact rather than approximate: 180000/24576000 reduces to
//  15/2048, so an 11-bit accumulator incremented by 15 overflows exactly
//  180000 times per second with no accumulated error.
// ============================================================================

module mpeg2_h262_system_time_clock
(
    input  wire        clk,              // 24.576 MHz audio domain
    input  wire        reset,

    input  wire        run,              // gate advance while paused
    input  wire        load_valid,       // first-timestamp anchor or seek
    input  wire [32:0] load_value,       // 90 kHz units

    output wire [32:0] stc_90k,
    output reg         tick_90k,
    output reg  [33:0] stc_180k_half,

    // One-cycle pulse every 90000 ticks.  This is the hardware bring-up
    // observable: it is a single bit, so it crosses into the decoder clock
    // domain through an ordinary two-flop synchroniser with no risk of the
    // tearing a multi-bit counter would suffer across a carry, and counting
    // it over ten minutes measures the clock rate directly.
    output reg         pulse_1hz
);

localparam [10:0] ACC_INCREMENT = 11'd15;
localparam [16:0] TICKS_PER_SECOND = 17'd90000;

reg [16:0] second_counter;

reg  [10:0] accumulator;
wire [11:0] accumulator_next  = {1'b0, accumulator} + {1'b0, ACC_INCREMENT};
wire        half_tick         = accumulator_next[11];

// The 90 kHz timestamp domain is the half-tick count shifted right, so the
// two views of time are the same counter and cannot drift apart.
assign stc_90k = stc_180k_half[33:1];

always @(posedge clk) begin
    if (reset) begin
        accumulator    <= 11'd0;
        stc_180k_half  <= 34'd0;
        tick_90k       <= 1'b0;
        second_counter <= 17'd0;
        pulse_1hz      <= 1'b0;
    end
    else if (load_valid) begin
        // A first-timestamp anchor or a seek restarts the accumulator phase so
        // the loaded value is exact rather than offset by a partial tick.
        accumulator    <= 11'd0;
        stc_180k_half  <= {load_value, 1'b0};
        tick_90k       <= 1'b0;
        second_counter <= 17'd0;
        pulse_1hz      <= 1'b0;
    end
    else if (run) begin
        accumulator <= accumulator_next[10:0];
        if (half_tick) begin
            stc_180k_half <= stc_180k_half + 34'd1;
            // A 90 kHz tick is every second half-tick: the one that carries
            // the half-tick count from odd to even.
            tick_90k      <= stc_180k_half[0];
            if (stc_180k_half[0]) begin
                if (second_counter == (TICKS_PER_SECOND - 17'd1)) begin
                    second_counter <= 17'd0;
                    pulse_1hz      <= 1'b1;
                end
                else begin
                    second_counter <= second_counter + 17'd1;
                    pulse_1hz      <= 1'b0;
                end
            end
            else
                pulse_1hz <= 1'b0;
        end
        else begin
            tick_90k  <= 1'b0;
            pulse_1hz <= 1'b0;
        end
    end
    else begin
        tick_90k  <= 1'b0;
        pulse_1hz <= 1'b0;
    end
end

endmodule
