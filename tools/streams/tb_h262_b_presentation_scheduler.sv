`timescale 1ns/1ps

module tb_h262_b_presentation_scheduler;
    reg clk=0,reset=1,swap=0,frame_waiting=0;reg[1:0] completed_bank=0,reference_bank=1;
    reg b_start=0,non_b_start=0,i_start=0,p_start=0,sequence_end=0,b_success=0,b_error=0;
    reg [3:0] frame_rate_code=4'h3;
    reg[7:0] reference_count=0;
    wire[1:0] display_bank;wire display_scratch,display_scratch_bank,decode_scratch_bank;
    wire [2:0] reset_count;
    wire overlap_header,hold,complete,error;
    integer last_pulse_count=0;

    always #5 clk=~clk;
    mpeg2_h262_b_presentation_scheduler dut(
        .clk(clk),.reset(reset),.swap_window_pulse(swap),
        .frame_rate_code(frame_rate_code),
        .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
        .reference_frame_bank(reference_bank),.b_picture_start(b_start),
        .reference_promotion_count(reference_count),
        .non_b_picture_start(non_b_start),.i_picture_start(i_start),
        .p_picture_start(p_start),
        .sequence_end(sequence_end),
        .b_user_success(b_success),.b_decode_error(b_error),
        .display_frame_bank(display_bank),.display_scratch(display_scratch),
        .display_scratch_bank(display_scratch_bank),
        .decode_scratch_bank(decode_scratch_bank),
        .framebuffer_swap_reset_count(reset_count),
        .reference_overlap_header(overlap_header),.presentation_hold(hold),
        .presentation_complete(complete),.presentation_error(error));

    // Entry 282: restored from Entry 280 and revalidated against this
    // unmodified 60.3165 Hz scheduler.  The cadence window counts asserted
    // below are refresh-specific; the invariant they exist to protect is that
    // a stalled decode may never bank credit and replay two presentations on
    // consecutive swap windows.  Assert that directly and at every window.
    wire dut_presents = swap && dut.cadence_slot && dut.scheduled_frame_valid &&
                        dut.scheduled_frame_differs;
    integer swap_window_index=0;
    integer last_present_index=-10;
    integer min_present_gap=1000;
    always @(posedge clk) begin
        // A scheduler reset re-seeds the credit to DUE by design, so the first
        // window after reset is legitimately due.  Restart the comparison there.
        if(reset) last_present_index = -10;
        if(swap) begin
            swap_window_index = swap_window_index+1;
            if(dut_presents) begin
                if(last_present_index>=0) begin
                    if(swap_window_index-last_present_index<min_present_gap)
                        min_present_gap = swap_window_index-last_present_index;
                    if(swap_window_index-last_present_index<2)
                        $fatal(1,"presentations on consecutive swap windows %0d and %0d",
                               last_present_index,swap_window_index);
                end
                last_present_index = swap_window_index;
            end
        end
    end

    task automatic pulse_start;
        begin @(negedge clk);b_start<=1;@(negedge clk);b_start<=0;#1;end
    endtask
    task automatic pulse_success;
        begin @(negedge clk);b_success<=1;@(negedge clk);b_success<=0;#1;end
    endtask
    task automatic pulse_close;
        begin @(negedge clk);non_b_start<=1;@(negedge clk);non_b_start<=0;#1;end
    endtask
    task automatic pulse_p_close;
        begin
            @(negedge clk);non_b_start<=1;p_start<=1;
            @(negedge clk);non_b_start<=0;p_start<=0;#1;
        end
    endtask
    task automatic pulse_i_close;
        begin
            @(negedge clk);non_b_start<=1;i_start<=1;
            @(negedge clk);non_b_start<=0;i_start<=0;#1;
        end
    endtask
    task automatic pulse_window;
        begin @(negedge clk);swap<=1;@(negedge clk);swap<=0;#1;end
    endtask
    task automatic pulse_swap;
        reg before_display_scratch;
        reg before_display_scratch_bank;
        reg[1:0] before_display_bank;
        begin
            before_display_scratch=display_scratch;
            before_display_scratch_bank=display_scratch_bank;
            before_display_bank=display_bank;
            last_pulse_count=0;
            while((display_scratch===before_display_scratch)&&
                  (display_scratch_bank===before_display_scratch_bank)&&
                  (display_bank===before_display_bank))begin
                pulse_window();
                last_pulse_count=last_pulse_count+1;
                if(last_pulse_count>4)
                    $fatal(1,"cadenced presentation did not advance");
            end
        end
    endtask
    task automatic reset_scheduler;
        begin
            @(negedge clk);reset<=1;swap<=0;frame_waiting<=0;b_start<=0;
            non_b_start<=0;i_start<=0;p_start<=0;sequence_end<=0;b_success<=0;b_error<=0;
            reference_count<=0;
            repeat(2)@(negedge clk);reset<=0;#1;
        end
    endtask
    task automatic finish_one_b;
        input[1:0] expected_future_bank;
        begin
            pulse_success();
            pulse_close();
            if(!hold)$fatal(1,"single-B run did not hold compressed input");
            pulse_swap();
            if(!display_scratch||display_scratch_bank)
                $fatal(1,"single-B run did not present scratch 0");
            pulse_swap();
            if(display_scratch||(display_bank!==expected_future_bank)||
               !complete||error||hold)
                $fatal(1,"single-B future reference did not retire");
        end
    endtask

    task automatic verify_cadence_rate;
        input [3:0] rate_code;
        input integer window_count;
        input integer expected_presentations;
        integer window_index;
        integer presentation_count;
        reg [1:0] display_before;
        begin
            frame_rate_code=rate_code;
            reset_scheduler();
            presentation_count=0;
            for(window_index=0;window_index<window_count;
                window_index=window_index+1)begin
                if(!dut.pending_frame_valid)begin
                    completed_bank=(display_bank==2'd0)?2'd1:2'd0;
                    @(negedge clk);frame_waiting<=1;
                    @(negedge clk);frame_waiting<=0;#1;
                    pulse_close();
                end
                display_before=display_bank;
                pulse_window();
                if(display_bank!=display_before)
                    presentation_count=presentation_count+1;
            end
            if(presentation_count!=expected_presentations)
                $fatal(1,"frame_rate_code %0d presented %0d/%0d expected %0d",
                       rate_code,presentation_count,window_count,
                       expected_presentations);
            $display("CADENCE_RATE_PASS code=%0d windows=%0d presentations=%0d",
                     rate_code,window_count,presentation_count);
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);@(negedge clk);reset<=0;

        // Header before publication: P47 is still both the displayed and
        // registered reference.  Do not reject B48; wait for I50 publication.
        reference_bank<=0;completed_bank<=1;
        pulse_start();
        if(!dut.future_reference_pending||error)
            $fatal(1,"B-before-publication did not await future reference");
        @(negedge clk);reference_bank<=1;frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;#1;
        if(dut.future_reference_pending||(dut.future_frame_bank!==1'b1)||
           dut.pending_frame_valid||error)
            $fatal(1,"late publication did not bind open B run");
        finish_one_b(1);

        // Header simultaneous with publication must use completed_frame_bank,
        // not the stale registered reference bank from the preceding cycle.
        reset_scheduler();
        reference_bank<=0;completed_bank<=1;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=1;#1;
        if(dut.future_reference_pending||(dut.future_frame_bank!==1'b1)||
           dut.pending_frame_valid||error)
            $fatal(1,"simultaneous publication used stale reference bank");
        finish_one_b(1);

        // Entry 276: the third reference identity must survive the same
        // publication handoff and become the exact displayed future frame.
        reset_scheduler();
        reference_bank<=2'd1;completed_bank<=2'd2;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=2'd2;#1;
        if(dut.future_reference_pending||(dut.future_frame_bank!==2'd2)||
           !dut.last_bound_reference_valid||
           (dut.last_bound_reference_bank!==2'd2)||error)
            $fatal(1,"third reference bank was truncated at B handoff");
        finish_one_b(2'd2);
        if(display_bank!==2'd2)
            $fatal(1,"third reference bank was truncated at display");

        reset_scheduler();

        // A reference publication on the swap edge must remain hidden until
        // the later B header classifies it and takes future-frame ownership.
        @(negedge clk);completed_bank<=1;reference_bank<=1;
        frame_waiting<=1;swap<=1;
        @(negedge clk);frame_waiting<=0;swap<=0;#1;
        if(display_bank||display_scratch||error||!dut.pending_frame_valid||
           dut.pending_frame_released)
            $fatal(1,"publication/vblank race exposed future reference");

        pulse_start();
        if(decode_scratch_bank||hold||error)$fatal(1,"first B did not select scratch 0");
        pulse_success();
        pulse_start();
        if(!decode_scratch_bank||hold||error)$fatal(1,"second B did not select scratch 1");
        pulse_success();
        pulse_close();
        if(!hold)$fatal(1,"closed B run did not hold compressed input");

        pulse_swap();
        if(last_pulse_count!=1)
            $fatal(1,"first ready scratch missed immediate cadence slot");
        if(!display_scratch||display_scratch_bank)
            $fatal(1,"first swap did not present scratch 0");
        pulse_swap();
        if(last_pulse_count!=3)
            $fatal(1,"second scratch cadence=%0d expected=3",last_pulse_count);
        if(!display_scratch||!display_scratch_bank)
            $fatal(1,"second swap did not present scratch 1");
        pulse_swap();
        if(last_pulse_count!=2)
            $fatal(1,"future cadence=%0d expected=2",last_pulse_count);
        if(display_scratch||!display_bank||!complete||error||hold)
            $fatal(1,"future reference did not retire the B run");

        // Entry 247: decode exactly one following P while the completed B run
        // presents. Its publication must restore hold before a new B header,
        // survive retirement of the old run, and then become that B's future.
        reset_scheduler();
        reference_bank<=0;completed_bank<=1;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=1;#1;
        pulse_success();
        pulse_start();
        pulse_success();
        if(!overlap_header)$fatal(1,"closed-run P header was not overlap eligible");
        pulse_p_close();
        if(hold||!dut.overlap_decode_open)
            $fatal(1,"following P was not admitted during prior presentation");
        completed_bank<=0;reference_bank<=0;
        @(negedge clk);frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;#1;
        if(!hold||!dut.pending_frame_valid||
           (dut.pending_frame_bank!==1'b0)||!dut.overlap_frame_pending)
            $fatal(1,"overlap P publication did not restore presentation hold");
        pulse_swap();
        if(!display_scratch||display_scratch_bank)
            $fatal(1,"overlap run did not present scratch 0");
        pulse_swap();
        if(!display_scratch||!display_scratch_bank)
            $fatal(1,"overlap run did not present scratch 1");
        pulse_swap();
        if(display_scratch||!display_bank||!complete||hold||error||
           !dut.pending_frame_valid||dut.pending_frame_released||
           (dut.pending_frame_bank!==1'b0))
            $fatal(1,"overlap reference was not preserved after prior run");
        pulse_start();
        if(error||dut.future_reference_pending||
           (dut.future_frame_bank!==1'b0)||dut.pending_frame_valid)
            $fatal(1,"following B did not claim overlapped future reference");
        reset_scheduler();

        // Entry 315: the next B header may precede both the overlapping I
        // publication and release of the old run's scratch banks.  Retain its
        // classification, present the old generation normally, and admit B
        // payload only after both the third-bank reference and scratch 0 are
        // safe.
        reference_bank<=0;completed_bank<=1;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=1;#1;
        pulse_success();
        pulse_start();
        pulse_success();
        if(!overlap_header)$fatal(1,"closed-run I header was not overlap eligible");
        pulse_i_close();
        if(hold||!dut.overlap_decode_open)
            $fatal(1,"following I was not admitted during prior presentation");
        pulse_start();
        if(!hold||!dut.deferred_queued_b_start||dut.queued_run_active||error)
            $fatal(1,"early B header was not deferred behind I publication");
        pulse_swap();
        if(!display_scratch||display_scratch_bank||!hold||error)
            $fatal(1,"deferred B disturbed old scratch 0 presentation");
        pulse_swap();
        if(!display_scratch||!display_scratch_bank||!hold||error)
            $fatal(1,"deferred B disturbed old scratch 1 presentation");
        pulse_swap();
        if(display_scratch||(display_bank!==2'd1)||
           !dut.promotion_pending||!hold||error)
            $fatal(1,"deferred B lost ownership when old future retired");
        completed_bank<=2;reference_bank<=2;
        @(negedge clk);frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;#1;
        if(hold||dut.deferred_queued_b_start||!dut.queued_run_active||
           !dut.queued_decode_inflight||
           (dut.queued_future_frame_bank!==2'd2)||error)
            $fatal(1,"delayed I publication did not admit deferred B");
        pulse_success();
        @(posedge clk);#1;
        if(dut.promotion_pending||dut.queued_run_active||
           !dut.scratch0_pending||(dut.future_frame_bank!==2'd2)||
           dut.run_closed||hold||error)
            $fatal(1,"deferred B generation did not promote atomically");
        pulse_start();
        if(!decode_scratch_bank||error)
            $fatal(1,"second deferred-generation B did not claim scratch 1");
        pulse_success();
        pulse_close();
        pulse_swap();
        if(!display_scratch||display_scratch_bank)
            $fatal(1,"deferred generation did not present scratch 0");
        pulse_swap();
        if(!display_scratch||!display_scratch_bank)
            $fatal(1,"deferred generation did not present scratch 1");
        pulse_swap();
        if(display_scratch||(display_bank!==2'd2)||!complete||hold||error)
            $fatal(1,"deferred generation did not present I future reference");
        reset_scheduler();

        // The deferred slot is singular.  A second classified B event before
        // publication cannot be represented safely and must retain fail-open
        // behavior rather than overwriting the first request.
        reference_bank<=0;completed_bank<=1;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=1;#1;
        pulse_success();
        pulse_i_close();
        pulse_start();
        if(!dut.deferred_queued_b_start||!hold||error)
            $fatal(1,"duplicate test did not arm deferred B slot");
        pulse_start();
        if(!error||hold||dut.deferred_queued_b_start)
            $fatal(1,"duplicate deferred B did not fail open");
        reset_scheduler();

        // Entry 269: the first B of the next run may occupy scratch 0 only
        // after the old display leaves it for scratch 1.  It must remain in a
        // separate generation until the old future reference is visible;
        // promotion then exposes that exact identity and admits B two into the
        // reciprocally released scratch 1 bank.
        reference_bank<=0;completed_bank<=1;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=1;#1;
        pulse_success();
        pulse_start();
        pulse_success();
        pulse_p_close();
        completed_bank<=0;reference_bank<=0;
        @(negedge clk);frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;#1;
        if(!hold||!dut.overlap_frame_pending||
           (dut.pending_frame_bank!==1'b0))
            $fatal(1,"next-run future reference was not retained");
        pulse_swap();
        if(!display_scratch||display_scratch_bank||!hold)
            $fatal(1,"first generation scratch 0 ownership was released early");
        pulse_swap();
        if(!display_scratch||!display_scratch_bank||hold)
            $fatal(1,"released scratch 0 did not open next-generation input");
        pulse_start();
        if(decode_scratch_bank||!dut.queued_run_active||
           (dut.queued_future_frame_bank!==1'b0)||
           dut.scratch0_pending||dut.queued_scratch0_pending||hold||error)
            $fatal(1,"next-generation B one did not claim released scratch 0");
        // Let the old future frame display while queued B one still needs
        // compressed bytes.  Promotion may wait, but input must remain open.
        pulse_swap();
        if(!dut.promotion_pending||!dut.queued_decode_inflight||hold||
           display_scratch||(display_bank!==1'b1)||error)
            $fatal(1,"promotion blocked an admitted queued B decode");
        pulse_success();
        if(!dut.queued_scratch0_pending||dut.scratch0_pending||!hold||error)
            $fatal(1,"queued scratch 0 identity leaked into current generation");
        @(posedge clk);#1;
        if(dut.promotion_pending||dut.queued_run_active||
           !dut.scratch0_pending||(dut.next_present_scratch_bank!==1'b0)||
           dut.run_closed||hold||error)
            $fatal(1,"atomic generation promotion lost queued scratch 0");
        pulse_start();
        if(!decode_scratch_bank||error)
            $fatal(1,"reciprocal scratch 1 release did not admit B two");
        pulse_success();
        pulse_p_close();
        completed_bank<=1;reference_bank<=1;
        @(negedge clk);frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;#1;
        pulse_swap();
        if(!display_scratch||display_scratch_bank)
            $fatal(1,"promoted run did not present scratch 0 first");
        pulse_swap();
        if(!display_scratch||!display_scratch_bank)
            $fatal(1,"promoted run did not present scratch 1 second");
        pulse_swap();
        if(display_scratch||display_bank||!complete||hold||error||
           !dut.pending_frame_valid||(dut.pending_frame_bank!==1'b1))
            $fatal(1,"promoted run did not retire to its P6 future reference");
        reset_scheduler();

        // Entry 320: hardware may accept sequence end while the final B run
        // is still visible, before its overlapping last P publication.  The
        // terminal boundary must survive that ordering and release the P
        // after scratch, scratch and future-reference retirement.
        reference_bank<=0;completed_bank<=1;
        @(negedge clk);b_start<=1;frame_waiting<=1;
        @(negedge clk);b_start<=0;frame_waiting<=0;reference_bank<=1;#1;
        pulse_success();
        pulse_start();
        pulse_success();
        pulse_p_close();
        @(negedge clk);sequence_end<=1;
        @(negedge clk);sequence_end<=0;#1;
        completed_bank<=0;reference_bank<=0;
        @(negedge clk);frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;#1;
        pulse_swap();
        pulse_swap();
        pulse_swap();
        if(!complete||error||!dut.pending_frame_valid||
           !dut.pending_frame_released||(dut.pending_frame_bank!==1'b0))
            $fatal(1,"active-run terminal boundary did not release final P");
        pulse_swap();
        if(display_scratch||display_bank||dut.pending_frame_valid||error)
            $fatal(1,"active-run terminal P did not display");
        reset_scheduler();

        // Starvation may make one presentation immediately eligible, but it
        // must not bank enough credit for a consecutive-refresh catch-up.
        repeat(5)pulse_window();
        if(dut.cadence_credit!=dut.CADENCE_DUE_25FPS)
            $fatal(1,"idle cadence credit did not saturate at one slot");

        // With no B owner, the following non-B header releases the queued
        // reference for the next swap rather than the publication swap.
        completed_bank<=1;reference_bank<=1;
        @(negedge clk);frame_waiting<=1;swap<=1;
        @(negedge clk);frame_waiting<=0;swap<=0;#1;
        if(display_bank||!dut.pending_frame_valid||dut.pending_frame_released)
            $fatal(1,"ordinary reference bypassed classification barrier");
        pulse_close();
        if(!dut.pending_frame_released)$fatal(1,"non-B header did not release reference");
        pulse_swap();
        if(last_pulse_count!=1)
            $fatal(1,"late ordinary frame did not consume one saturated slot");
        if(display_scratch||!display_bank||error)
            $fatal(1,"released ordinary reference did not display");

        // A terminal start code may be consumed before persistence publishes
        // the final reference.  Retain that boundary and release on publish.
        @(negedge clk);sequence_end<=1;@(negedge clk);sequence_end<=0;#1;
        completed_bank<=0;reference_bank<=0;
        @(negedge clk);frame_waiting<=1;swap<=1;
        @(negedge clk);frame_waiting<=0;swap<=0;#1;
        if(!display_bank||!dut.pending_frame_valid||!dut.pending_frame_released)
            $fatal(1,"terminal boundary did not release final reference");
        pulse_swap();
        if(last_pulse_count!=2)
            $fatal(1,"terminal frame caught up after only %0d later windows",
                   last_pulse_count);
        if(display_scratch||display_bank||error)
            $fatal(1,"terminal reference did not display");

        // A failed later B must release ownership/backpressure and leave the
        // ordinary reference presentation path usable.
        reference_bank<=1;
        pulse_start();
        @(negedge clk);sequence_end<=1;@(negedge clk);sequence_end<=0;#1;
        if(!hold)$fatal(1,"sequence-end close did not hold pending B run state=%0d/%0d/%0d future=%0d/%0d pending=%0d/%0d last=%0d/%0d display=%0d/%0d",
                        dut.reorder_active,dut.run_closed,dut.decode_inflight,
                        dut.future_frame_pending,dut.future_reference_pending,
                        dut.pending_frame_valid,dut.pending_frame_bank,
                        dut.last_bound_reference_valid,
                        dut.last_bound_reference_bank,display_scratch,
                        display_bank);
        @(negedge clk);b_error<=1;@(negedge clk);b_error<=0;#1;
        if(hold||!error)$fatal(1,"failed B transaction did not fail open");
        completed_bank<=1;frame_waiting<=1;
        @(negedge clk);frame_waiting<=0;
        pulse_close();
        pulse_swap();
        if(display_scratch||!display_bank)
            $fatal(1,"ordinary frame presentation did not recover after abort");

        // 1206 raster swap windows are just under twenty seconds at 60.3165
        // Hz.  Exact rational accumulation distinguishes 24000/1001 from 24
        // fps there (479 versus 480 pictures), while the shorter established
        // windows preserve the exact-24 and 25 fps results.
        verify_cadence_rate(4'h1,1206,479);
        verify_cadence_rate(4'h2,603,240);
        verify_cadence_rate(4'h3,603,250);

        // A later sequence may legally enter the fractional direct rate.
        // Re-seed only when its accumulator scale changes so credit from the
        // 40,000,000-unit exact-rate scale cannot leak into the reduced
        // 56,875-unit ratio and established exact-24/25 timing is untouched.
        frame_rate_code=4'h2;
        reset_scheduler();
        repeat(3)pulse_window();
        @(negedge clk);frame_rate_code=4'h1;
        @(posedge clk);#1;
        if((dut.cadence_rate_code_q!==4'h1)||
           (dut.cadence_credit!==dut.CADENCE_DUE_24000_1001))
            $fatal(1,"24000/1001 rate change did not re-seed credit code=%0d credit=%0d",
                   dut.cadence_rate_code_q,dut.cadence_credit);

        $display("B_PRESENTATION_RESULT handoff=before/same/after race_barrier=1 order=scratch0,scratch1,future cadence=23.976/24/25 min_present_gap=%0d overlap_p=1 overlap_i=1 deferred_b=1 generations=2 bank_reuse=0,1 third_reference=1 starvation=1 ordinary=1 terminal=early/active fail_open=1",min_present_gap);
        $finish;
    end

    initial begin repeat(20000)@(posedge clk);$fatal(1,"presentation test timed out");end
endmodule

module tb_h262_double_scratch_tags;
    reg clk=0,reset=1;
    reg [7:0] value=0;
    reg [11:0] x=0,y=0;
    reg [1:0] component=0;
    reg valid=0,start=0,complete=0,bank=0;
    wire stored,seen,store_error;
    wire [7:0] burstcnt,be;
    wire [28:0] addr;
    wire rd;
    wire [63:0] din;
    wire we;

    always #5 clk=~clk;
    mpeg2_h262_ddram_store dut(
        .clk(clk),.reset(reset),.pixel_value(value),.pixel_x(x),.pixel_y(y),
        .pixel_component(component),.pixel_valid(valid),.block_start(start),
        .block_complete(complete),.frame_bank(bank),.block_stored(stored),
        .write_seen(seen),.store_error(store_error),.ddram_busy(1'b0),
        .ddram_burstcnt(burstcnt),.ddram_addr(addr),.ddram_rd(rd),
        .ddram_din(din),.ddram_be(be),.ddram_we(we));

    task automatic check_tag;
        input [11:0] tag_y;
        input expected_bank;
        input [1:0] expected_component;
        input [28:0] expected_first;
        begin
            @(negedge clk);x<=12'hc00;y<=tag_y;component<=0;start<=1;
            @(negedge clk);start<=0;#1;
            if(!dut.ascratch||(dut.ascratch_bank!==expected_bank)||
               (dut.ac!==expected_component)||(dut.first!==expected_first))
                $fatal(1,"scratch tag %h decoded bank=%0d component=%0d first=%h",
                       tag_y,dut.ascratch_bank,dut.ac,dut.first);
            reset<=1;@(negedge clk);reset<=0;
        end
    endtask

    initial begin
        repeat(3)@(posedge clk);@(negedge clk);reset<=0;
        check_tag(12'h800,0,0,29'h06020000);
        check_tag(12'ha00,0,1,29'h0602a8c0);
        check_tag(12'hc00,0,2,29'h0602d2f0);
        check_tag(12'h200,1,0,29'h06030000);
        check_tag(12'h400,1,1,29'h0603a8c0);
        check_tag(12'h600,1,2,29'h0603d2f0);
        if(store_error)$fatal(1,"valid double-scratch tags raised store error");
        $display("DOUBLE_SCRATCH_TAG_RESULT banks=2 planes=6");
        $finish;
    end
    initial begin repeat(100)@(posedge clk);$fatal(1,"scratch tag test timed out");end
endmodule
