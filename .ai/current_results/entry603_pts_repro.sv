`timescale 1ns/1ps
module entry603_pts_repro;
reg clk=0,reset=1,swap=0,tick=0,frame_waiting=0,header=0,metadata=0;
reg [1:0] active_bank=0,completed_bank=0;
reg [32:0] metadata_pts=90000;
reg with_pts=0;
integer control=0;
wire [1:0] display_bank,candidate_bank;
wire hold,error,candidate_valid,candidate_scratch,candidate_scratch_bank;
wire [32:0] candidate_pts,stc;
wire pts_valid,anchored,pts_active,pts_due;
always #5 clk=~clk;
mpeg2_h262_picture_timestamp ownership(
 .clk(clk),.reset(reset),.metadata_valid(metadata&&with_pts),.metadata_pts(metadata_pts),
 .picture_coding_extension_valid(1'b0),.picture_top_field_first(1'b1),
 .picture_start(header),.picture_is_b(1'b0),.decode_scratch_bank(1'b0),
 .b_picture_complete(1'b0),.active_frame_bank(active_bank),
 .display_frame_bank(display_bank),.display_scratch(1'b0),.display_scratch_bank(1'b0),
 .candidate_frame_valid(candidate_valid),.candidate_frame_scratch(candidate_scratch),
 .candidate_scratch_bank(candidate_scratch_bank),.candidate_frame_bank(candidate_bank),
 .candidate_pts(candidate_pts),.candidate_pts_valid(pts_valid));
mpeg2_h262_pts_presentation_timeline timeline(
 .clk(clk),.reset(reset),.tick_90k(tick),.metadata_valid(metadata&&with_pts),
 .metadata_pts(metadata_pts),.candidate_valid(pts_valid),.candidate_pts(candidate_pts),
 .anchored(anchored),.stc_90k(stc),.candidate_active(pts_active),.candidate_due(pts_due));
mpeg2_h262_b_presentation_scheduler dut(
 .clk(clk),.reset(reset),.swap_window_pulse(swap),.cadence_tick_pulse(1'b0),
 .frame_rate_code(4'h4),.timestamp_candidate_active(pts_active),.timestamp_candidate_due(pts_due),
 .native_ordinary_overlap_enable(control!=2),.active_frame_bank(active_bank),
 .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
 .reference_frame_bank(completed_bank),.reference_promotion_count(8'd0),
 .b_picture_start(1'b0),.non_b_picture_start(header),.i_picture_start(header),
 .p_picture_start(1'b0),.sequence_end(1'b0),.b_user_success(1'b0),.b_decode_error(1'b0),
 .display_frame_bank(display_bank),.presentation_hold(hold),.presentation_error(error),
 .candidate_frame_valid(candidate_valid),.candidate_frame_scratch(candidate_scratch),
 .candidate_scratch_bank(candidate_scratch_bank),.candidate_frame_bank(candidate_bank));
task cycle;begin @(posedge clk);#1;end endtask
task start_picture(input [32:0] pts);begin
 metadata_pts=pts;metadata=1;cycle();metadata=0;header=1;cycle();header=0;cycle();
end endtask
task complete_picture(input [1:0] bank,input [1:0] next_bank);begin
 completed_bank=bank;active_bank=next_bank;frame_waiting=1;cycle();frame_waiting=0;cycle();
end endtask
initial begin
 if($value$plusargs("CONTROL=%d",control))begin end
 with_pts=(control!=0);
 repeat(3)cycle();reset=0;repeat(3)cycle();
 // First persisted reference is already the initial display bank.
 start_picture(90000);complete_picture(0,1);
 // Second reference remains unclassified until the third I header arrives.
 start_picture(93003);complete_picture(1,2);
 if(pts_active||!dut.pending_frame_valid||dut.pending_frame_released)
  $fatal(1,"unexpected pre-header candidate state");
 start_picture(96006);
 $display("AFTER_HEADER control=%0d anchored=%0d pts_active=%0d due=%0d overlap=%0d pending=%0d bank=%0d hold=%0d",
  control,anchored,pts_active,pts_due,dut.ordinary_reference_decode_open,dut.pending_frame_valid,dut.pending_frame_bank,hold);
 if(control==2)begin
  if(!hold||dut.ordinary_reference_decode_open||error)$fatal(1,"serialized control did not hold safely");
  repeat(10)cycle();
  $display("SERIALIZED_CONTROL_PASS no_overlap=1 held_payload=1 error=%0d",error);$finish;
 end
 if(hold||!dut.ordinary_reference_decode_open||error)$fatal(1,"third-bank overlap not admitted");
 // No display window yet: legal persistence into free bank2 precedes bank1's PTS.
 completed_bank=2;active_bank=0;frame_waiting=1;cycle();frame_waiting=0;
 $display("AFTER_COMPLETE pts_active=%0d secondary=%0d pending_bank=%0d error=%0d",pts_active,dut.ordinary_secondary_valid,dut.pending_frame_bank,error);
 cycle();
 if(control==1)begin
  if(!error)$fatal(1,"expected existing scheduler timestamp/secondary guard did not fire");
  $display("REPRODUCED_PRESENTATION_ERROR timestamped_candidate_appeared_after_overlap_admission=1 owned_banks=0,1,2");
 end else begin
  if(error||!dut.ordinary_secondary_valid)$fatal(1,"untimestamped control failed");
  $display("UNTIMESTAMPED_CONTROL_PASS retained_secondary=1 error=0");
 end
 $finish;
end
endmodule
