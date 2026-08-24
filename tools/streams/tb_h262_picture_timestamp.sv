`timescale 1ns/1ps
// Entry 372: proves timestamps follow their picture through reordering, which
// is the property decode order makes non-obvious.  The sequence replayed here
// is I P B, decoded in that order but displayed I B P, so a design that simply
// reported the most recent timestamp would disagree with this test.
module tb_h262_picture_timestamp;

    reg clk=0, reset=1;
    reg metadata_valid=0; reg [32:0] metadata_pts=0;
    reg picture_coding_extension_valid=0, picture_top_field_first=1;
    reg picture_start=0, picture_is_b=0, decode_scratch_bank=0;
    reg b_picture_complete=0;
    reg [1:0] active_frame_bank=0, display_frame_bank=0;
    reg display_scratch=0, display_scratch_bank=0;
    reg candidate_frame_valid=0, candidate_frame_scratch=0;
    reg candidate_scratch_bank=0; reg [1:0] candidate_frame_bank=0;
    wire [32:0] display_pts; wire display_pts_valid; wire [7:0] associated_count;
    wire [32:0] candidate_pts; wire candidate_pts_valid;
    wire display_top_field_first;

    always #5 clk=~clk;

    mpeg2_h262_picture_timestamp dut(.clk(clk),.reset(reset),
        .metadata_valid(metadata_valid),.metadata_pts(metadata_pts),
        .picture_coding_extension_valid(picture_coding_extension_valid),
        .picture_top_field_first(picture_top_field_first),
        .picture_start(picture_start),.picture_is_b(picture_is_b),
        .decode_scratch_bank(decode_scratch_bank),
        .b_picture_complete(b_picture_complete),
        .active_frame_bank(active_frame_bank),
        .display_frame_bank(display_frame_bank),
        .display_scratch(display_scratch),
        .display_scratch_bank(display_scratch_bank),
        .candidate_frame_valid(candidate_frame_valid),
        .candidate_frame_scratch(candidate_frame_scratch),
        .candidate_scratch_bank(candidate_scratch_bank),
        .candidate_frame_bank(candidate_frame_bank),
        .display_pts(display_pts),.display_pts_valid(display_pts_valid),
        .display_top_field_first(display_top_field_first),
        .candidate_pts(candidate_pts),.candidate_pts_valid(candidate_pts_valid),
        .associated_count(associated_count));

    task record(input [32:0] p);
        begin @(negedge clk); metadata_pts=p; metadata_valid=1;
              @(negedge clk); metadata_valid=0; end
    endtask
    task start_picture; begin @(negedge clk); picture_start=1;
              @(negedge clk); picture_start=0; end endtask
    task field_order(input tff);
        begin @(negedge clk); picture_top_field_first=tff;
              picture_coding_extension_valid=1;
              @(negedge clk); picture_coding_extension_valid=0; end
    endtask
    task complete_b;
        begin @(negedge clk); b_picture_complete=1;
              @(negedge clk); b_picture_complete=0;
              repeat(2) @(posedge clk); end
    endtask
    task complete;   // bookkeeper toggles the active bank on persistence
        begin @(negedge clk); active_frame_bank=active_frame_bank^2'd1;
              repeat(2) @(posedge clk); end
    endtask

    initial begin
        repeat(3) @(posedge clk); reset=0; @(posedge clk);

        // I picture -> bank 0
        record(33'h0_0007_7EF2); start_picture(); field_order(1); complete();
        // P picture -> bank 1
        record(33'h0_0007_8AC0); start_picture(); field_order(0); complete();

        // Display order asks for bank 0 first even though bank 1 decoded last.
        @(negedge clk); display_frame_bank=2'd0; @(posedge clk);
        if (display_pts !== 33'h0_0007_7EF2 || !display_pts_valid)
            $fatal(1,"bank0 pts %h valid %b, expected 00077ef2",display_pts,display_pts_valid);
        if (!display_top_field_first)
            $fatal(1,"bank0 lost TFF ownership");
        @(negedge clk); display_frame_bank=2'd1; @(posedge clk);
        if (display_pts !== 33'h0_0007_8AC0)
            $fatal(1,"bank1 pts %h, expected 00078ac0",display_pts);
        if (display_top_field_first)
            $fatal(1,"bank1 lost BFF ownership");
        if (associated_count !== 8'd2)
            $fatal(1,"associated %0d, expected 2",associated_count);

        // A picture with no preceding record must not inherit a stale value.
        start_picture(); field_order(1); complete();
        @(negedge clk); display_frame_bank=2'd0; @(posedge clk);
        if (display_pts_valid !== 1'b0)
            $fatal(1,"unannotated picture inherited a timestamp");
        if (associated_count !== 8'd2)
            $fatal(1,"unannotated picture was counted as associated");

        // Association survives a record arriving well before its picture.
        record(33'h0_0000_1234);
        repeat(20) @(posedge clk);
        start_picture(); field_order(1); complete();
        @(negedge clk); display_frame_bank=2'd1; @(posedge clk);
        if (display_pts !== 33'h0_0000_1234 || !display_pts_valid)
            $fatal(1,"delayed record lost: %h valid %b",display_pts,display_pts_valid);
        if (associated_count !== 8'd3)
            $fatal(1,"associated %0d, expected 3",associated_count);

        // A record arriving in the same cycle as its picture start must still
        // associate.  This is the case the sticky-level bug silently lost.
        @(negedge clk); metadata_pts=33'h0_0000_ABCD; metadata_valid=1; picture_start=1;
        @(negedge clk); metadata_valid=0; picture_start=0;
        field_order(1); complete();
        @(negedge clk); display_frame_bank=2'd0; @(posedge clk);
        if (display_pts !== 33'h0_0000_ABCD || !display_pts_valid)
            $fatal(1,"coincident record lost: %h valid %b",display_pts,display_pts_valid);
        if (associated_count !== 8'd4)
            $fatal(1,"associated %0d, expected 4",associated_count);

        // Reordered B pictures persist into two scheduler-owned scratch banks.
        // Their timestamps must follow those banks rather than the later
        // reference decode order.
        record(33'h0_0000_2000);
        @(negedge clk); picture_is_b=1; decode_scratch_bank=0;
        start_picture(); field_order(1); complete_b();
        record(33'h0_0000_1000);
        @(negedge clk); decode_scratch_bank=1;
        start_picture(); field_order(0); complete_b();
        @(negedge clk); picture_is_b=0;

        @(negedge clk); display_scratch=1; display_scratch_bank=0;
        @(posedge clk);
        if (display_pts !== 33'h0_0000_2000 || !display_pts_valid)
            $fatal(1,"scratch0 pts %h valid %b",display_pts,display_pts_valid);
        if (!display_top_field_first)
            $fatal(1,"scratch0 lost TFF ownership");
        @(negedge clk); display_scratch_bank=1; @(posedge clk);
        if (display_pts !== 33'h0_0000_1000 || !display_pts_valid)
            $fatal(1,"scratch1 pts %h valid %b",display_pts,display_pts_valid);
        if (display_top_field_first)
            $fatal(1,"scratch1 lost BFF ownership");

        // Candidate order is independent of decode order: ask for scratch 1,
        // then reference bank 1, and receive the exact retained timestamps.
        @(negedge clk); candidate_frame_valid=1;
        candidate_frame_scratch=1; candidate_scratch_bank=1;
        @(posedge clk);
        if (candidate_pts !== 33'h0_0000_1000 || !candidate_pts_valid)
            $fatal(1,"scratch candidate query lost reordered timestamp");
        @(negedge clk); candidate_frame_scratch=0; candidate_frame_bank=1;
        @(posedge clk);
        if (candidate_pts !== 33'h0_0000_1234 || !candidate_pts_valid)
            $fatal(1,"reference candidate query returned %h/%b",
                   candidate_pts,candidate_pts_valid);
        if (associated_count !== 8'd6)
            $fatal(1,"associated %0d, expected 6",associated_count);

        // Reusing a scratch bank for an unannotated B explicitly clears its
        // validity, preserving per-picture cadence fallback.
        @(negedge clk); picture_is_b=1; decode_scratch_bank=0;
        start_picture(); field_order(1); complete_b();
        @(negedge clk); candidate_frame_scratch=1;
        candidate_scratch_bank=0;
        @(posedge clk);
        if (candidate_pts_valid)
            $fatal(1,"unannotated B inherited scratch timestamp");
        if (associated_count !== 8'd6)
            $fatal(1,"unannotated B changed association count");

        $display("H262_PICTURE_TIMESTAMP_PASS reference=1 scratch=2 reorder=1 unannotated=reference/b delayed=1 coincident=1 candidate_query=1 count=%0d",
                 associated_count);
        $finish;
    end
endmodule
