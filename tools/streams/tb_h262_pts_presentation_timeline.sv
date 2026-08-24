`timescale 1ns/1ps

module tb_h262_pts_presentation_timeline;
    reg clk=0, reset=1, tick_90k=0, metadata_valid=0;
    reg [32:0] metadata_pts=0;
    reg candidate_valid=0; reg [32:0] candidate_pts=0;
    wire anchored; wire [32:0] stc_90k;
    wire candidate_active, candidate_due;

    always #5 clk=~clk;

    mpeg2_h262_pts_presentation_timeline dut(
        .clk(clk),.reset(reset),.tick_90k(tick_90k),
        .metadata_valid(metadata_valid),.metadata_pts(metadata_pts),
        .candidate_valid(candidate_valid),.candidate_pts(candidate_pts),
        .anchored(anchored),.stc_90k(stc_90k),
        .candidate_active(candidate_active),.candidate_due(candidate_due));

    task pulse_tick;
        begin @(negedge clk); tick_90k=1;
              @(negedge clk); tick_90k=0; #1; end
    endtask

    task anchor(input [32:0] pts);
        begin @(negedge clk); metadata_pts=pts; metadata_valid=1;
              @(negedge clk); metadata_valid=0; #1; end
    endtask

    initial begin
        repeat(3) @(posedge clk); @(negedge clk); reset=0;

        // Missing timestamps never activate the PTS gate before or after an
        // anchor, leaving cadence selection to the scheduler.
        candidate_valid=0; candidate_pts=33'd12; @(posedge clk); #1;
        if(anchored||candidate_active||candidate_due)
            $fatal(1,"unanchored missing candidate became active");

        anchor(33'h1_FFFF_FFFE);
        if(!anchored||(stc_90k!==33'h1_FFFF_FFFE))
            $fatal(1,"first record did not anchor exact STC %h",stc_90k);

        // Later records describe pictures; they must not retime the clock.
        anchor(33'h0_1234_5678);
        if(stc_90k!==33'h1_FFFF_FFFE)
            $fatal(1,"later metadata re-anchored STC %h",stc_90k);

        candidate_valid=1;
        candidate_pts=33'h0_0000_0001;
        #1;
        if(!candidate_active||candidate_due)
            $fatal(1,"future timestamp admitted before modulo wrap");
        pulse_tick();
        if(stc_90k!==33'h1_FFFF_FFFF||candidate_due)
            $fatal(1,"pre-wrap tick/due mismatch stc=%h due=%b",stc_90k,candidate_due);
        pulse_tick();
        if(stc_90k!==33'h0_0000_0000||candidate_due)
            $fatal(1,"wrap tick/due mismatch stc=%h due=%b",stc_90k,candidate_due);
        pulse_tick();
        if(stc_90k!==33'h0_0000_0001||!candidate_due)
            $fatal(1,"equal timestamp was not due after wrap");

        candidate_pts=33'h1_FFFF_FFFF; #1;
        if(!candidate_due)
            $fatal(1,"late timestamp was not immediately due");
        candidate_pts=33'h0_0000_0010; #1;
        if(candidate_due)
            $fatal(1,"ordinary future timestamp was admitted early");
        candidate_valid=0; #1;
        if(candidate_active||candidate_due)
            $fatal(1,"missing candidate did not disable timestamp gate");

        // Download rearm resets both ownership and the anchor, allowing a
        // seek/new file to establish an unrelated first PTS.
        @(negedge clk); reset=1; @(negedge clk); reset=0; #1;
        if(anchored||(stc_90k!==0)||candidate_active)
            $fatal(1,"session reset retained timeline state");
        anchor(33'h0_0000_4000);
        candidate_valid=1; candidate_pts=33'h0_0000_4000; #1;
        if(!candidate_active||!candidate_due)
            $fatal(1,"new session did not re-anchor and admit equality");

        $display("H262_PTS_TIMELINE_PASS anchor=first reset_reanchor=1 wrap=2^33 late=1 future=1 missing=1");
        $finish;
    end

    initial begin repeat(200) @(posedge clk); $fatal(1,"timeline timeout"); end
endmodule
