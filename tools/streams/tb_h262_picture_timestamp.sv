`timescale 1ns/1ps
// Entry 372: proves timestamps follow their picture through reordering, which
// is the property decode order makes non-obvious.  The sequence replayed here
// is I P B, decoded in that order but displayed I B P, so a design that simply
// reported the most recent timestamp would disagree with this test.
module tb_h262_picture_timestamp;

    reg clk=0, reset=1;
    reg metadata_valid=0; reg [32:0] metadata_pts=0;
    reg picture_start=0;
    reg [1:0] active_frame_bank=0, display_frame_bank=0;
    wire [32:0] display_pts; wire display_pts_valid; wire [7:0] associated_count;

    always #5 clk=~clk;

    mpeg2_h262_picture_timestamp dut(.clk(clk),.reset(reset),
        .metadata_valid(metadata_valid),.metadata_pts(metadata_pts),
        .picture_start(picture_start),.active_frame_bank(active_frame_bank),
        .display_frame_bank(display_frame_bank),
        .display_pts(display_pts),.display_pts_valid(display_pts_valid),
        .associated_count(associated_count));

    task record(input [32:0] p);
        begin @(negedge clk); metadata_pts=p; metadata_valid=1;
              @(negedge clk); metadata_valid=0; end
    endtask
    task start_picture; begin @(negedge clk); picture_start=1;
              @(negedge clk); picture_start=0; end endtask
    task complete;   // bookkeeper toggles the active bank on persistence
        begin @(negedge clk); active_frame_bank=active_frame_bank^2'd1;
              repeat(2) @(posedge clk); end
    endtask

    initial begin
        repeat(3) @(posedge clk); reset=0; @(posedge clk);

        // I picture -> bank 0
        record(33'h0_0007_7EF2); start_picture(); complete();
        // P picture -> bank 1
        record(33'h0_0007_8AC0); start_picture(); complete();

        // Display order asks for bank 0 first even though bank 1 decoded last.
        @(negedge clk); display_frame_bank=2'd0; @(posedge clk);
        if (display_pts !== 33'h0_0007_7EF2 || !display_pts_valid)
            $fatal(1,"bank0 pts %h valid %b, expected 00077ef2",display_pts,display_pts_valid);
        @(negedge clk); display_frame_bank=2'd1; @(posedge clk);
        if (display_pts !== 33'h0_0007_8AC0)
            $fatal(1,"bank1 pts %h, expected 00078ac0",display_pts);
        if (associated_count !== 8'd2)
            $fatal(1,"associated %0d, expected 2",associated_count);

        // A picture with no preceding record must not inherit a stale value.
        start_picture(); complete();
        @(negedge clk); display_frame_bank=2'd0; @(posedge clk);
        if (display_pts_valid !== 1'b0)
            $fatal(1,"unannotated picture inherited a timestamp");
        if (associated_count !== 8'd2)
            $fatal(1,"unannotated picture was counted as associated");

        // Association survives a record arriving well before its picture.
        record(33'h0_0000_1234);
        repeat(20) @(posedge clk);
        start_picture(); complete();
        @(negedge clk); display_frame_bank=2'd1; @(posedge clk);
        if (display_pts !== 33'h0_0000_1234 || !display_pts_valid)
            $fatal(1,"delayed record lost: %h valid %b",display_pts,display_pts_valid);
        if (associated_count !== 8'd3)
            $fatal(1,"associated %0d, expected 3",associated_count);

        // A record arriving in the same cycle as its picture start must still
        // associate.  This is the case the sticky-level bug silently lost.
        @(negedge clk); metadata_pts=33'h0_0000_ABCD; metadata_valid=1; picture_start=1;
        @(negedge clk); metadata_valid=0; picture_start=0;
        complete();
        @(negedge clk); display_frame_bank=2'd0; @(posedge clk);
        if (display_pts !== 33'h0_0000_ABCD || !display_pts_valid)
            $fatal(1,"coincident record lost: %h valid %b",display_pts,display_pts_valid);
        if (associated_count !== 8'd4)
            $fatal(1,"associated %0d, expected 4",associated_count);

        $display("H262_PICTURE_TIMESTAMP_PASS reorder=1 unannotated=1 delayed=1 coincident=1 count=%0d",
                 associated_count);
        $finish;
    end
endmodule
