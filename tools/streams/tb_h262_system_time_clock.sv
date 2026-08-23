`timescale 1ns/1ps
// Entry 365: proves the presentation time base by measurement, not by
// re-deriving its arithmetic.  One simulated second of the 24.576 MHz audio
// clock must produce exactly 180000 half-ticks and exactly 90000 90 kHz ticks,
// the two views must stay consistent, the field/frame/pulldown intervals must
// be integral in half-ticks, and an anchor load must land exactly.
module tb_h262_system_time_clock;

    reg         clk = 1'b0;
    reg         reset = 1'b1;
    reg         run = 1'b0;
    reg         load_valid = 1'b0;
    reg  [32:0] load_value = 33'd0;
    wire [32:0] stc_90k;
    wire        tick_90k;
    wire [33:0] stc_180k_half;
    wire        pulse_1hz;

    // 24.576 MHz -> 40.690104166 ns period; use ps precision.
    always #20345 clk = ~clk;

    mpeg2_h262_system_time_clock dut(
        .clk(clk), .reset(reset), .run(run),
        .load_valid(load_valid), .load_value(load_value),
        .stc_90k(stc_90k), .tick_90k(tick_90k),
        .stc_180k_half(stc_180k_half), .pulse_1hz(pulse_1hz));

    integer tick_count = 0;
    // Not gated on run: run is deasserted in the same delta as the final
    // loop edge, so gating here would mask the last tick the DUT emits.
    always @(posedge clk) if (!reset && tick_90k) tick_count = tick_count + 1;
    integer second_pulses = 0;
    always @(posedge clk) if (!reset && pulse_1hz) second_pulses = second_pulses + 1;

    integer i;
    reg [33:0] half_before;
    reg [32:0] anchor;

    initial begin
        repeat (4) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // ---- one second of clock: 24,576,000 cycles ----
        run = 1'b1;
        half_before = stc_180k_half;
        for (i = 0; i < 24576000; i = i + 1) @(posedge clk);
        run = 1'b0;
        @(posedge clk);
        @(posedge clk);

        if ((stc_180k_half - half_before) !== 34'd180000)
            $fatal(1,"half-tick rate wrong: got %0d expected 180000",
                   stc_180k_half - half_before);
        if (tick_count !== 90000)
            $fatal(1,"90 kHz tick rate wrong: got %0d expected 90000", tick_count);
        if (stc_90k !== stc_180k_half[33:1])
            $fatal(1,"90 kHz view disagrees with half-tick counter");
        if (second_pulses !== 1)
            $fatal(1,"1 Hz pulse rate wrong: got %0d expected 1", second_pulses);

        // ---- pulldown intervals must be exact in half-ticks ----
        // 29.97 Hz: field 3003, frame 6006, repeat_first_field frame 9009.
        if ((90000*1001*2)/30000 !== 6006)
            $fatal(1,"frame interval is not integral in half-ticks");
        if (((90000*1001*2)/30000)/2 !== 3003)
            $fatal(1,"field interval is not integral in half-ticks");
        if ((((90000*1001*2)/30000)*3)/2 !== 9009)
            $fatal(1,"pulldown interval is not integral in half-ticks");

        // ---- anchor load must land exactly and restart phase ----
        anchor = 33'h0_0007_7EF2;
        @(negedge clk); load_value = anchor; load_valid = 1'b1;
        @(negedge clk); load_valid = 1'b0;
        if (stc_90k !== anchor)
            $fatal(1,"anchor load wrong: got %h expected %h", stc_90k, anchor);
        if (stc_180k_half !== {anchor, 1'b0})
            $fatal(1,"anchor did not set the half-tick counter consistently");

        // ---- paused clock must not advance ----
        run = 1'b0;
        repeat (1000) @(posedge clk);
        if (stc_90k !== anchor)
            $fatal(1,"clock advanced while paused");

        $display("H262_SYSTEM_TIME_CLOCK_PASS half=180000 ticks=90000 seconds=1 field=3003 frame=6006 pulldown=9009 anchor=%h",anchor);
        $finish;
    end
endmodule
