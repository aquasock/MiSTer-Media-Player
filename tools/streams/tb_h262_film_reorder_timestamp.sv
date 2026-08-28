`timescale 1ns/1ps
// Actual scheduler, physical-bank metadata and 90-kHz timeline together.
// Coded I/P/B/B becomes displayed I/B/B/P with 3/2/3/2 native fields.
module tb_h262_film_reorder_timestamp;
reg clk=0,reset=1,metadata=0,pce=0,start=0,is_b=0,success=0;
reg [32:0] pts=0;
reg tff=1,rff=0,tick90=0,tick_field=0,swap=0,field=0;
reg [1:0] active=0,completed=0,reference=0;
reg waiting=0,seqend=0,is_i=0;
reg ordinary_overlap=0;
reg [7:0] promoted=0;
wire [1:0] display,candidate_bank;
wire scratch,scratch_bank,decode_bank,candidate_valid,candidate_scratch,candidate_sb;
wire [32:0] display_pts,candidate_pts,stc;
wire display_pts_valid,display_tff,display_rff,display_progressive,descriptor_valid;
wire candidate_pts_valid,candidate_tff,anchored,pts_active,pts_due,hold,done,error;
integer field_number=0,session,clock_tick;
always #5 clk=~clk;
mpeg2_h262_picture_timestamp metadata_owner(
 .clk(clk),.reset(reset),.metadata_valid(metadata),.metadata_pts(pts),
 .picture_coding_extension_valid(pce),.picture_top_field_first(tff),
 .picture_repeat_first_field(rff),.picture_progressive_frame(1'b1),
 .picture_start(start),.picture_is_b(is_b),.decode_scratch_bank(decode_bank),
 .b_picture_complete(success),.active_frame_bank(active),
 .display_frame_bank(display),.display_scratch(scratch),.display_scratch_bank(scratch_bank),
 .candidate_frame_valid(candidate_valid),.candidate_frame_scratch(candidate_scratch),
 .candidate_scratch_bank(candidate_sb),.candidate_frame_bank(candidate_bank),
 .display_pts(display_pts),.display_pts_valid(display_pts_valid),
 .display_top_field_first(display_tff),.display_repeat_first_field(display_rff),
 .display_progressive_frame(display_progressive),.display_descriptor_valid(descriptor_valid),
 .candidate_top_field_first(candidate_tff),.candidate_pts(candidate_pts),
 .candidate_pts_valid(candidate_pts_valid),.associated_count());
mpeg2_h262_pts_presentation_timeline timeline(
 .clk(clk),.reset(reset),.tick_90k(tick90),.metadata_valid(metadata),.metadata_pts(pts),
 .candidate_valid(candidate_pts_valid),.candidate_pts(candidate_pts),
 .anchored(anchored),.stc_90k(stc),.candidate_active(pts_active),.candidate_due(pts_due));
mpeg2_h262_b_presentation_scheduler scheduler(
 .clk(clk),.reset(reset),.swap_window_pulse(swap),.cadence_tick_pulse(tick_field),
 .frame_rate_code(4'd4),.native_film_mode(1'b1),.native_field(field),
 .display_picture_present(descriptor_valid),.display_repeat_first_field(display_rff),
 .candidate_top_field_first(candidate_tff),.timestamp_candidate_active(pts_active),
 .timestamp_candidate_due(pts_due),.native_ordinary_overlap_enable(ordinary_overlap),
 .active_frame_bank(active),.frame_waiting(waiting),.completed_frame_bank(completed),
 .reference_frame_bank(reference),.reference_promotion_count(promoted),
 .b_picture_start(start&&is_b),.non_b_picture_start(start&&!is_b),
 .i_picture_start(start&&is_i),.p_picture_start(start&&!is_b&&!is_i),
 .sequence_end(seqend),.b_user_success(success),.b_decode_error(1'b0),
 .display_frame_bank(display),.display_scratch(scratch),.display_scratch_bank(scratch_bank),
 .decode_scratch_bank(decode_bank),.candidate_frame_valid(candidate_valid),
 .candidate_frame_scratch(candidate_scratch),.candidate_scratch_bank(candidate_sb),
 .candidate_frame_bank(candidate_bank),.presentation_hold(hold),
 .presentation_complete(done),.presentation_error(error));

task picture(input bit b,input bit i,input bit first,input bit repeat_field,
             input [32:0] timestamp,input bit timestamp_valid);
 begin
  @(negedge clk);metadata=timestamp_valid;pts=timestamp;
  @(negedge clk);metadata=0;start=1;is_b=b;is_i=i;
  @(negedge clk);start=0;tff=first;rff=repeat_field;pce=1;
  @(negedge clk);pce=0;repeat(4)@(negedge clk);
 end
endtask
task commit_reference;
 begin
  @(negedge clk);completed=active;reference=active;active=active+1'b1;
  promoted=promoted+1'b1;waiting=(completed!=display);
  @(negedge clk);waiting=0;repeat(4)@(negedge clk);
 end
endtask
task commit_b;
 begin
  @(negedge clk);success=1;@(negedge clk);success=0;repeat(4)@(negedge clk);
 end
endtask
task field_end(input bit expected_scratch,input bit expected_sb,input [1:0] expected_bank,
               input bit expected_tff,input bit expected_rff);
 begin
  // One 60000/1001 field is exactly 1501.5 ticks; retain the half tick.
  for(clock_tick=0;clock_tick<1501+(field_number%2);clock_tick=clock_tick+1)begin
   @(negedge clk);tick90=1;
  end
  @(negedge clk);tick90=0;tick_field=1;
  @(negedge clk);tick_field=0;repeat(4)@(negedge clk);swap=1;
  @(negedge clk);swap=0;repeat(3)@(negedge clk);
  if(error||scratch!==expected_scratch||
     (scratch ? scratch_bank!==expected_sb : display!==expected_bank)||
     display_tff!==expected_tff||display_rff!==expected_rff||!display_progressive||!descriptor_valid)
   $fatal(1,"film reorder field=%0d bank=%0d scratch=%0d/%0d metadata=%0d/%0d stc=%0d error=%0d",
          field_number,display,scratch,scratch_bank,display_tff,display_rff,stc,error);
  field=~field;field_number=field_number+1;
 end
endtask
initial begin
 if($test$plusargs("EARLY_B_REFERENCE"))begin
  // Native trace: the B classification can precede its I reference's public
  // completion by one clock after an ordinary P has already been displayed.
  // Neither scheduler binding nor metadata retirement may select that old P.
  ordinary_overlap=1;
  repeat(4)@(negedge clk);reset=0;
  picture(0,1,1,1,90000,1);commit_reference();
  picture(0,0,0,0,94504,1);commit_reference();
  picture(0,1,0,1,97507,1);
  field_end(0,0,0,1,1);field_end(0,0,0,1,1);field_end(0,0,1,0,0);
  @(negedge clk);start=1;is_b=1;is_i=0;
  @(negedge clk);start=0;completed=active;reference=active;active=0;
  promoted=promoted+1'b1;waiting=1;
  @(negedge clk);waiting=0;repeat(4)@(negedge clk);
  $display("EARLY_B_REFERENCE_STATE future=%0d pending=%0d descriptor=%0d reference=%0d promoted=%0d bound_count=%0d",
   scheduler.future_frame_bank,scheduler.future_reference_pending,
   metadata_owner.frame_bank_descriptor_valid[2],reference,promoted,scheduler.last_bound_reference_count);
  if(scheduler.future_frame_bank!=2||scheduler.future_reference_pending||
     !metadata_owner.frame_bank_descriptor_valid[2]||
     metadata_owner.frame_bank_top_field_first[2]||
     !metadata_owner.frame_bank_repeat[2]||
     !metadata_owner.frame_bank_progressive[2]||
     !metadata_owner.frame_bank_valid[2]||metadata_owner.frame_bank_pts[2]!=97507)
   $fatal(1,"early B header lost retiring I reference identity or metadata");
  $display("EARLY_B_REFERENCE_PASS");$finish;
 end
 if($test$plusargs("OVERLAP_REFERENCE_ADMISSION"))begin
  // Entry 669: the original opening can complete the allowed overlapping
  // reference on the same edge as the following P header. Once the second
  // scratch picture is displayed, a free scratch bank is NOT permission to
  // decode that P: the sole pending reference slot still owns its predecessor.
  // The following header must also release that predecessor once it retires.
  repeat(4)@(negedge clk);reset=0;
  picture(0,1,1,1,90000,1);commit_reference();
  picture(0,0,1,0,102012,1);commit_reference();
  picture(1,0,0,0,94504,1);commit_b();
  picture(1,0,0,1,97507,1);commit_b();
  picture(0,0,1,0,105015,1);
  @(negedge clk);completed=active;reference=active;active=0;
  promoted=promoted+1'b1;waiting=1;start=1;is_b=0;is_i=0;
  @(negedge clk);waiting=0;start=0;repeat(4)@(negedge clk);
  if(!scheduler.pending_frame_valid||scheduler.pending_frame_bank!=2)
   $fatal(1,"overlap fixture failed to retain predecessor");
  field_end(0,0,0,1,1);field_end(0,0,0,1,1);field_end(1,0,0,0,0);
  field_end(1,0,0,0,0);field_end(1,1,0,0,1);
  $display("OVERLAP_REFERENCE_STATE hold=%0d pending=%0d/%0d released=%0d queued_capacity=%0d run_closed=%0d overlap_open=%0d",
   hold,scheduler.pending_frame_valid,scheduler.pending_frame_bank,
   scheduler.pending_frame_released,scheduler.queued_header_capacity,
   scheduler.run_closed,scheduler.overlap_decode_open);
  if(!hold)$fatal(1,"following P payload admitted with pending reference slot occupied during B drain");
  if(!scheduler.pending_frame_released)
   $fatal(1,"coincident following P header failed to release predecessor");
  field_end(1,1,0,0,1);field_end(1,1,0,0,1);field_end(0,0,1,1,0);
  if(!hold)$fatal(1,"following P escaped ordinary pending ownership");
  field_end(0,0,1,1,0);field_end(0,0,2,1,0);
  if(hold||error)$fatal(1,"following P did not resume after predecessor presentation");
  $display("OVERLAP_REFERENCE_ADMISSION_PASS");$finish;
 end
 for(session=0;session<2;session=session+1)begin
  @(negedge clk);reset=1;active=0;completed=0;reference=0;promoted=0;
  field=0;field_number=0;seqend=0;
  repeat(4)@(negedge clk);reset=0;
  picture(0,1,1,1,90000,1);commit_reference();
  picture(0,0,1,0,102012,1);commit_reference();
  picture(1,0,0,0,94504,1);commit_b();
  picture(1,0,0,1,97507,session==0);commit_b();
  @(negedge clk);seqend=1;@(negedge clk);seqend=0;
  field_end(0,0,0,1,1);field_end(0,0,0,1,1);field_end(1,0,0,0,0);
  if(!display_pts_valid||display_pts!=94504)$fatal(1,"B0 timestamp ownership");
  field_end(1,0,0,0,0);field_end(1,1,0,0,1);
  if(display_pts_valid!=(session==0))$fatal(1,"missing B1 timestamp was not cleared");
  field_end(1,1,0,0,1);field_end(1,1,0,0,1);field_end(0,0,1,1,0);
  if(!display_pts_valid||display_pts!=102012||!done||hold)$fatal(1,"terminal P retirement");
  field_end(0,0,1,1,0);field_end(0,0,1,1,0);
 end
 $display("FILM_REORDER_TIMESTAMP_PASS I_B_B_P fields=3/2/3/2 missing_PTS terminal replay");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
