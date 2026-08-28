`timescale 1ns/1ps

module tb_native_ordinary_overlap_ownership;
reg clk=0,reset=1,swap=0,cadence=0,frame_waiting=0,sequence_end=0;
reg [1:0] completed_bank=0,active_bank=1;
reg i_start=0,p_start=0,non_b_start=0;
wire [1:0] display_bank;
wire hold,error;
always #5 clk=~clk;

mpeg2_h262_b_presentation_scheduler dut
(
        .native_film_mode(1'b0),
        .native_field(1'b0),
        .display_picture_present(1'b0),
        .display_repeat_first_field(1'b0),
        .candidate_top_field_first(1'b1),
    .clk(clk),.reset(reset),.swap_window_pulse(swap),
    .cadence_tick_pulse(cadence),.frame_rate_code(4'h4),
    .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),
    .native_ordinary_overlap_enable(1'b1),.active_frame_bank(active_bank),
    .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
    .reference_frame_bank(2'd0),.reference_promotion_count(8'd0),
    .b_picture_start(1'b0),.non_b_picture_start(non_b_start),
    .i_picture_start(i_start),.p_picture_start(p_start),
    .sequence_end(sequence_end),.b_user_success(1'b0),.b_decode_error(1'b0),
    .display_frame_bank(display_bank),.presentation_hold(hold),
    .presentation_error(error)
);

task automatic reset_case;
begin
    reset=1; swap=0; cadence=0; frame_waiting=0;
    completed_bank=0; active_bank=1;
    i_start=0; p_start=0; non_b_start=0; sequence_end=0;
    repeat(2) @(posedge clk); #1; reset=0;
    repeat(2) @(posedge clk); #1;
end
endtask

task automatic publish_bank1;
begin
    completed_bank=1; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0; active_bank=2;
end
endtask

task automatic header_i;
begin
    i_start=1; non_b_start=1;
    @(posedge clk); #1; i_start=0; non_b_start=0;
end
endtask

task automatic prepare_secondary;
begin
    reset_case(); publish_bank1(); header_i();
    completed_bank=2; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0; active_bank=0;
end
endtask

task automatic pulse_end;
begin
    sequence_end=1;
    @(posedge clk); #1; sequence_end=0;
end
endtask

task automatic pulse_swap;
begin
    swap=1;
    @(posedge clk); #1; swap=0;
end
endtask

task automatic accrue_frame_slot;
begin
    cadence=1; @(posedge clk); #1; cadence=0;
    @(posedge clk); #1;
    cadence=1; @(posedge clk); #1; cadence=0;
    @(posedge clk); #1;
end
endtask

task automatic require_terminal_empty;
begin
    accrue_frame_slot(); pulse_swap();
    @(posedge clk); #1;
    if (error || display_bank != 2 || dut.pending_frame_valid ||
        dut.ordinary_secondary_valid ||
        dut.ordinary_terminal_drain_pending || hold)
        $fatal(1,"terminal ordinary queue did not drain");
end
endtask

initial begin
    // A P picture can use the free third bank under the same ownership proof.
    reset_case(); publish_bank1();
    p_start=1; non_b_start=1;
    @(posedge clk); #1; p_start=0; non_b_start=0;
    if (!dut.ordinary_reference_decode_open || hold || error)
        $fatal(1,"safe P overlap did not open");
    completed_bank=2; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0; active_bank=0;
    p_start=1; non_b_start=1;
    @(posedge clk); #1; p_start=0; non_b_start=0;
    if(!dut.ordinary_secondary_valid||!dut.ordinary_secondary_released||
       !dut.ordinary_resume_pending||!hold||error)
        $fatal(1,"P successor escaped full reference capacity");
    pulse_swap();
    if(display_bank!=1||dut.pending_frame_bank!=2||
       !dut.ordinary_reference_decode_open||dut.ordinary_reference_decode_bank!=0||hold||error)
        $fatal(1,"P successor did not resume in newly freed bank");

    // Changing the decode destination to the displayed bank is fatal.
    reset_case(); publish_bank1(); header_i();
    if (!dut.ordinary_reference_decode_open || hold || error)
        $fatal(1,"safe I overlap did not open");
    active_bank=0;
    @(posedge clk); #1;
    if (!error) $fatal(1,"display-bank ownership violation was not caught");

    // A faster all-I decode may retain one completed successor without
    // overwriting the predecessor that still owns the primary pending slot.
    reset_case(); publish_bank1(); header_i();
    completed_bank=2; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0; active_bank=0;
    if (error) $fatal(1,"safe secondary completion raised an error");
    if (!dut.ordinary_secondary_valid || dut.ordinary_secondary_bank != 2)
        $fatal(1,"secondary completion was not retained");
    if (dut.pending_frame_bank != 1)
        $fatal(1,"secondary completion overwrote predecessor bank");
    if (hold) $fatal(1,"next I classification boundary was not admitted");
    header_i();
    if (!dut.ordinary_secondary_released ||
        !dut.ordinary_resume_pending || !hold || error)
        $fatal(1,"secondary release did not apply bounded backpressure");
    swap=1;
    @(posedge clk); #1; swap=0;
    if (error || display_bank != 1 || !dut.pending_frame_valid ||
        dut.pending_frame_bank != 2 || !dut.pending_frame_released)
        $fatal(1,"secondary promotion did not preserve presentation order");
    if (dut.ordinary_secondary_valid ||
        !dut.ordinary_reference_decode_open ||
        dut.ordinary_reference_decode_bank != 0 || hold)
        $fatal(1,"decode did not resume into the newly freed bank");

    // A completed bank may never alias the predecessor still waiting.
    reset_case(); publish_bank1(); header_i();
    completed_bank=1; frame_waiting=1;
    @(posedge clk); #1; frame_waiting=0;
    if (!error) $fatal(1,"duplicate pending-bank completion was not caught");

    // Sequence end before promotion must remain sticky through both queued
    // presentations and retire the secondary as the final displayed frame.
    prepare_secondary(); pulse_end();
    if (!dut.ordinary_terminal_drain_pending ||
        !dut.ordinary_secondary_released || !hold || error)
        $fatal(1,"pre-promotion sequence end was not retained");
    pulse_swap();
    if (dut.pending_frame_bank != 2 || !dut.pending_frame_released)
        $fatal(1,"terminal secondary was not promoted released");
    require_terminal_empty();

    // The one-cycle terminal event may coincide with secondary completion.
    reset_case(); publish_bank1(); header_i();
    completed_bank=2; frame_waiting=1; sequence_end=1;
    @(posedge clk); #1;
    frame_waiting=0; sequence_end=0; active_bank=0;
    if (!dut.ordinary_secondary_valid ||
        !dut.ordinary_secondary_released ||
        !dut.ordinary_terminal_drain_pending || error)
        $fatal(1,"completion-coincident sequence end was lost");
    pulse_swap(); require_terminal_empty();

    // It may also coincide with promotion or arrive just after promotion.
    prepare_secondary(); sequence_end=1; swap=1;
    @(posedge clk); #1; sequence_end=0; swap=0;
    if (dut.pending_frame_bank != 2 || !dut.pending_frame_released ||
        !dut.ordinary_terminal_drain_pending || error)
        $fatal(1,"promotion-coincident sequence end was lost");
    require_terminal_empty();

    prepare_secondary(); pulse_swap();
    if (dut.pending_frame_bank != 2 || dut.pending_frame_released || hold)
        $fatal(1,"unreleased post-promotion control is invalid");
    pulse_end();
    if (!dut.pending_frame_released ||
        !dut.ordinary_terminal_drain_pending || error)
        $fatal(1,"post-promotion sequence end was lost");
    require_terminal_empty();

    $display({"NATIVE_ORDINARY_OWNERSHIP_PASS p_overlap=1 display_guard=1 ",
              "secondary_queue=1 ordered_resume=1 duplicate_guard=1 ",
              "terminal=before/completion/promotion/after"});
    $finish;
end
endmodule

// Exercise the same timestamp ownership/timeline wiring as the core. Candidate
// validity is deliberately allowed to change after an overlap was admitted.
module tb_native_ordinary_pts_ownership;
reg clk=0,reset=1,swap=0,cadence=0,tick90=0,metadata=0;
reg frame_waiting=0,i_start=0,p_start=0,b_start=0,sequence_end=0;
reg native_enable=1;
reg [3:0] rate_code=4;
reg [1:0] active_bank=0,completed_bank=0;
reg [32:0] metadata_pts=90000;
wire [1:0] display_bank,candidate_bank;
wire hold,error,candidate_valid,candidate_scratch,candidate_scratch_bank;
wire [32:0] candidate_pts,stc;
wire candidate_pts_valid,anchored,pts_active,pts_due;
wire [7:0] associated_count;
integer checks=0;
always #5 clk=~clk;

mpeg2_h262_picture_timestamp ownership(
        .picture_repeat_first_field(1'b0),
        .picture_progressive_frame(1'b0),
 .clk(clk),.reset(reset),.metadata_valid(metadata),.metadata_pts(metadata_pts),
 .picture_coding_extension_valid(1'b0),.picture_top_field_first(1'b1),
 .picture_start(i_start||p_start||b_start),.picture_is_b(b_start),
 .decode_scratch_bank(1'b0),.b_picture_complete(1'b0),.active_frame_bank(active_bank),
 .display_frame_bank(display_bank),.display_scratch(1'b0),.display_scratch_bank(1'b0),
 .candidate_frame_valid(candidate_valid),.candidate_frame_scratch(candidate_scratch),
 .candidate_scratch_bank(candidate_scratch_bank),.candidate_frame_bank(candidate_bank),
 .candidate_pts(candidate_pts),.candidate_pts_valid(candidate_pts_valid),
 .associated_count(associated_count));
mpeg2_h262_pts_presentation_timeline timeline(
 .clk(clk),.reset(reset),.tick_90k(tick90),.metadata_valid(metadata),.metadata_pts(metadata_pts),
 .candidate_valid(candidate_pts_valid),.candidate_pts(candidate_pts),.anchored(anchored),
 .stc_90k(stc),.candidate_active(pts_active),.candidate_due(pts_due));
mpeg2_h262_b_presentation_scheduler dut(
        .native_film_mode(1'b0),
        .native_field(1'b0),
        .display_picture_present(1'b0),
        .display_repeat_first_field(1'b0),
        .candidate_top_field_first(1'b1),
 .clk(clk),.reset(reset),.swap_window_pulse(swap),.cadence_tick_pulse(cadence),
 .frame_rate_code(rate_code),.timestamp_candidate_active(pts_active),.timestamp_candidate_due(pts_due),
 .native_ordinary_overlap_enable(native_enable),.active_frame_bank(active_bank),
 .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
 .reference_frame_bank(completed_bank),.reference_promotion_count(8'd0),
 .b_picture_start(b_start),.non_b_picture_start(i_start||p_start),.i_picture_start(i_start),
 .p_picture_start(p_start),.sequence_end(sequence_end),.b_user_success(1'b0),.b_decode_error(1'b0),
 .display_frame_bank(display_bank),.presentation_hold(hold),.presentation_error(error),
 .candidate_frame_valid(candidate_valid),.candidate_frame_scratch(candidate_scratch),
 .candidate_scratch_bank(candidate_scratch_bank),.candidate_frame_bank(candidate_bank));

task automatic cycle; begin @(posedge clk); #1; end endtask
task automatic reset_case;
begin
 reset=1;swap=0;cadence=0;tick90=0;metadata=0;frame_waiting=0;
 i_start=0;p_start=0;b_start=0;sequence_end=0;active_bank=0;completed_bank=0;
 native_enable=1;rate_code=4;metadata_pts=90000;
 repeat(3)cycle();reset=0;repeat(3)cycle();
 if(anchored||candidate_pts_valid||error||dut.ordinary_secondary_valid)
  $fatal(1,"reset retained old timestamp/queue ownership");
end
endtask

task automatic header_i(input bit annotated,input [32:0] pts);
begin
 if(annotated)begin metadata=1;metadata_pts=pts;cycle();metadata=0;end
 i_start=1;cycle();i_start=0;cycle();
end
endtask

task automatic publish(input [1:0] bank,input [1:0] next_bank);
begin
 completed_bank=bank;active_bank=next_bank;frame_waiting=1;
 cycle();frame_waiting=0;cycle();
end
endtask

task automatic accrue;
begin
 cadence=1;cycle();cadence=0;cycle();
 cadence=1;cycle();cadence=0;cycle();
end
endtask

task automatic pulse_swap;
begin swap=1;cycle();swap=0;cycle();end
endtask

task automatic advance_to(input [32:0] value);
begin
 if(stc>value)$fatal(1,"test clock would run backwards");
 while(stc<value)begin tick90=1;cycle();end
 tick90=0;cycle();
end
endtask

task automatic prepare_secondary;
begin
 reset_case();header_i(1,90000);publish(0,1);
 header_i(1,93003);publish(1,2);
 if(pts_active||!dut.pending_frame_valid||dut.pending_frame_released)
  $fatal(1,"unreleased reference is not a timestamped candidate yet");
 header_i(1,96006);
 if(!anchored||!pts_active||pts_due||hold||!dut.ordinary_reference_decode_open)
  $fatal(1,"timestamp activation lost safe third-bank overlap");
 publish(2,0);
 if(error||!dut.ordinary_secondary_valid||dut.pending_frame_bank!=1||
    dut.ordinary_secondary_bank!=2||candidate_pts!=93003)
  $fatal(1,"timestamped secondary completion lost ownership or raised error");
 checks=checks+1;
end
endtask

initial begin
 // Reproduce the hardware failure, then fill the queue and exercise real
 // future timestamps, primary/secondary promotion and terminal ownership.
 prepare_secondary();header_i(1,99009);
 if(!hold||!dut.ordinary_resume_pending||!dut.ordinary_secondary_released)
  $fatal(1,"all three banks occupied without payload backpressure");
 accrue();advance_to(93002);pulse_swap();
 if(display_bank!=0||!hold||error)$fatal(1,"future PTS presented early");
 advance_to(93003);pulse_swap();
 if(display_bank!=1||candidate_bank!=2||candidate_pts!=96006||
    !dut.ordinary_reference_decode_open||hold||error)
  $fatal(1,"due primary did not promote secondary and free old display bank");
 publish(0,1);
 sequence_end=1;cycle();sequence_end=0;cycle();
 if(!hold||!dut.ordinary_secondary_released||error)
  $fatal(1,"terminal secondary was not retained under timestamps");
 accrue();advance_to(96005);pulse_swap();
 if(display_bank!=1||error)$fatal(1,"secondary PTS presented early");
 advance_to(96006);pulse_swap();
 if(display_bank!=2||candidate_bank!=0||candidate_pts!=99009||error)
  $fatal(1,"second timestamp/identity lost during promotion");
 accrue();advance_to(99008);pulse_swap();
 if(display_bank!=2||error)$fatal(1,"final PTS presented early");
 advance_to(99009);pulse_swap();repeat(2)cycle();
 if(display_bank!=0||dut.pending_frame_valid||dut.ordinary_secondary_valid||
    dut.ordinary_terminal_drain_pending||hold||error||associated_count!=4)
  $fatal(1,"timestamped terminal queue did not drain exactly");
 checks=checks+1;

 // A missing record must not inherit an old timestamp or invalidate the
 // following annotated secondary when it becomes the candidate.
 reset_case();header_i(1,90000);publish(0,1);
 header_i(0,0);publish(1,2);header_i(1,96006);publish(2,0);
 if(pts_active||error||candidate_bank!=1)$fatal(1,"missing record inherited timestamp");
 sequence_end=1;cycle();sequence_end=0;accrue();pulse_swap();
 if(display_bank!=1||!pts_active||candidate_pts!=96006||error)
  $fatal(1,"annotated secondary did not restore its own timestamp");
 accrue();pulse_swap();
 if(display_bank!=1||error)$fatal(1,"future secondary bypassed its due gate");
 advance_to(96006);pulse_swap();
 if(display_bank!=2||error)$fatal(1,"missing-record terminal failed");
 checks=checks+1;

 // A late timestamp cannot bypass cadence, and publication coincident with
 // presentation must retain the new completed bank with its own timestamp.
 reset_case();header_i(1,90000);publish(0,1);
 header_i(1,90000);publish(1,2);header_i(1,90000);accrue();pulse_swap();
 if(display_bank!=1||!dut.ordinary_reference_decode_open||error)
  $fatal(1,"primary did not present while third-bank decode was open");
 publish(2,0);header_i(1,90000);
 if(!pts_due||dut.cadence_slot)$fatal(1,"late candidate incorrectly owns cadence credit");
 pulse_swap();if(display_bank!=1||error)$fatal(1,"late PTS bypassed cadence floor");
 accrue();completed_bank=0;active_bank=1;frame_waiting=1;swap=1;
 cycle();frame_waiting=0;swap=0;cycle();
 if(display_bank!=2||!dut.pending_frame_valid||dut.pending_frame_bank!=0||error)
  $fatal(1,"coincident completion/presentation lost successor");
 sequence_end=1;cycle();sequence_end=0;accrue();pulse_swap();
 if(display_bank!=0||error)$fatal(1,"coincident completion terminal failed");
 checks=checks+1;

 // A P releases the secondary but waits until the primary frees a bank.
 prepare_secondary();p_start=1;cycle();p_start=0;cycle();
 if(error||!hold||!dut.ordinary_secondary_released||!dut.ordinary_resume_pending)
  $fatal(1,"P transition lost secondary ownership");
 accrue();advance_to(93003);pulse_swap();
 if(error||hold||display_bank!=1||candidate_bank!=2||candidate_pts!=96006||
    !dut.ordinary_reference_decode_open||dut.ordinary_reference_decode_bank!=0)
  $fatal(1,"P transition resumed without freed-bank/timestamp ownership");
 // A B belongs to the secondary future reference, but the primary must
 // display first. Its early header cannot discard that older picture.
 prepare_secondary();b_start=1;cycle();b_start=0;cycle();
 if(error||!hold||!dut.deferred_ordinary_b_start||dut.pending_frame_bank!=1)
  $fatal(1,"B transition discarded ordinary predecessor");
 accrue();advance_to(93003);pulse_swap();repeat(3)cycle();
 if(error||hold||display_bank!=1||!dut.reorder_active||
    dut.future_frame_bank!=2||dut.future_reference_pending||
    dut.pending_frame_valid||dut.ordinary_secondary_valid)
  $fatal(1,"B transition did not bind secondary after predecessor presentation");
 // Mode and alias guards still apply to every reference class.
 prepare_secondary();native_enable=0;cycle();
 if(!error)$fatal(1,"native-mode transition escaped secondary ownership guard");
 prepare_secondary();rate_code=3;cycle();
 if(!error)$fatal(1,"rate transition escaped secondary ownership guard");
 reset_case();header_i(1,90000);publish(0,1);
 header_i(1,93003);publish(1,2);header_i(1,96006);
 completed_bank=1;frame_waiting=1;cycle();frame_waiting=0;cycle();
 if(!error)$fatal(1,"timestamped alias completion was not rejected");
 checks=checks+1;

 // A reset during an occupied timestamped queue clears both lifetimes.
 prepare_secondary();reset_case();header_i(1,123);publish(0,1);
 if(!anchored||stc!=123||associated_count!=1||error)
  $fatal(1,"new session retained old timeline or queue");
 $display("NATIVE_PTS_OWNERSHIP_PASS checks=%0d future=1 late=1 missing=1 terminal=1 coincident=1 guards=1 reset=1",checks);
 $finish;
end
initial begin repeat(50000)cycle();$fatal(1,"timestamp ownership test timeout");end
endmodule
