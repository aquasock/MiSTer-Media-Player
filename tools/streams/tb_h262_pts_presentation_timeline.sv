`timescale 1ns/1ps

module tb_h262_pts_presentation_timeline;
    reg clk=0, reset=1, tick_90k=0;
    reg candidate_valid=0; reg [32:0] candidate_pts=0;
    wire anchored; wire [32:0] stc_90k;
    wire candidate_active, candidate_due;
    integer waited;

    always #5 clk=~clk;

    mpeg2_h262_pts_presentation_timeline dut(
        .clk(clk),.reset(reset),.tick_90k(tick_90k),
        .candidate_valid(candidate_valid),.candidate_pts(candidate_pts),
        .anchored(anchored),.stc_90k(stc_90k),
        .candidate_active(candidate_active),.candidate_due(candidate_due));

    task pulse_tick;
        begin @(negedge clk); tick_90k=1;
              @(negedge clk); tick_90k=0; #1; end
    endtask

    // Present a candidate and let one edge pass so an unanchored timeline can
    // take it as its origin.
    task offer(input [32:0] pts);
        begin @(negedge clk); candidate_pts=pts; candidate_valid=1;
              @(posedge clk); #1; end
    endtask

    initial begin
        repeat(3) @(posedge clk); @(negedge clk); reset=0;

        // A stream without timestamps never presents a valid candidate, so it
        // never anchors and the scheduler keeps its free-running cadence.
        candidate_valid=0; candidate_pts=33'd12;
        repeat(4) @(posedge clk); #1;
        if(anchored||candidate_active||candidate_due)
            $fatal(1,"untimestamped stream anchored the timeline");

        // Entry 426 regression: the first candidate is the origin, so however
        // far into the multiplex its timestamp sits, it is due at once rather
        // than after that many ticks of black screen.  1.372 s at 90 kHz is
        // 123,480 ticks, the offset measured on hardware for 047f5b2.
        offer(33'd123480);
        if(!anchored||(stc_90k!==33'd123480))
            $fatal(1,"first candidate did not become the origin, stc=%0d",stc_90k);
        if(!candidate_active||!candidate_due)
            $fatal(1,"first candidate was not immediately due");

        // Only the origin moved: a picture one frame later at 29.97 Hz still
        // waits its full 3003 ticks and not one fewer.
        @(negedge clk); candidate_pts=33'd126483; #1;
        if(candidate_due)
            $fatal(1,"next picture was admitted before its interval elapsed");
        waited=0;
        while(!candidate_due && waited<4000) begin pulse_tick(); waited=waited+1; end
        if(waited!==3003)
            $fatal(1,"interval was not preserved, waited %0d ticks",waited);
        if(stc_90k!==33'd126483)
            $fatal(1,"interval end left stc at %0d",stc_90k);

        // A timestamp already behind the clock is due immediately.
        @(negedge clk); candidate_pts=33'd126000; #1;
        if(!candidate_due)
            $fatal(1,"late timestamp was not immediately due");

        // Modulo 2^33 arithmetic still separates future from late across wrap.
        @(negedge clk); reset=1; @(negedge clk); reset=0; #1;
        if(anchored||(stc_90k!==0)||candidate_active)
            $fatal(1,"session reset retained timeline state");
        candidate_valid=0; #1;
        offer(33'h1_FFFF_FFFE);
        if(stc_90k!==33'h1_FFFF_FFFE||!candidate_due)
            $fatal(1,"re-anchor after reset failed stc=%h",stc_90k);
        @(negedge clk); candidate_pts=33'h0_0000_0001; #1;
        if(candidate_due)
            $fatal(1,"future timestamp admitted before modulo wrap");
        pulse_tick();
        if(stc_90k!==33'h1_FFFF_FFFF||candidate_due)
            $fatal(1,"pre-wrap tick/due mismatch stc=%h",stc_90k);
        pulse_tick();
        if(stc_90k!==33'h0_0000_0000||candidate_due)
            $fatal(1,"wrap tick/due mismatch stc=%h",stc_90k);
        pulse_tick();
        if(stc_90k!==33'h0_0000_0001||!candidate_due)
            $fatal(1,"equal timestamp was not due after wrap");

        // An individually missing timestamp drops back to cadence without
        // disturbing the established origin.
        @(negedge clk); candidate_valid=0; #1;
        if(candidate_active||candidate_due)
            $fatal(1,"missing candidate did not disable timestamp gate");
        if(stc_90k!==33'h0_0000_0001)
            $fatal(1,"missing candidate disturbed the origin");

        $display("H262_PTS_TIMELINE_PASS anchor=first_candidate immediate=1 interval=3003 wrap=2^33 late=1 missing=1 reset_reanchor=1");
        $finish;
    end

    initial begin repeat(40000) @(posedge clk); $fatal(1,"timeline timeout"); end
endmodule
