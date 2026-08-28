`timescale 1ns/1ps
module tb_h262_film_cadence;
reg clk=0,reset=1,tick=0,swap=0,field=0,present=1,rff=0,tff=1;
reg waiting=0,header=0,due=1,pts=0;
reg [1:0] completed=1,active=2;
wire [1:0] display;
wire error;
always #5 clk=~clk;
mpeg2_h262_b_presentation_scheduler dut(
 .clk(clk),.reset(reset),.swap_window_pulse(swap),.cadence_tick_pulse(tick),
 .frame_rate_code(4'd4),.native_film_mode(1'b1),.native_field(field),
 .display_picture_present(present),.display_repeat_first_field(rff),.candidate_top_field_first(tff),
 .timestamp_candidate_active(pts),.timestamp_candidate_due(due),.native_ordinary_overlap_enable(1'b0),
 .active_frame_bank(active),.frame_waiting(waiting),.completed_frame_bank(completed),
 .reference_frame_bank(completed),.reference_promotion_count(8'd1),
 .b_picture_start(1'b0),.non_b_picture_start(header),.i_picture_start(header),.p_picture_start(1'b0),
 .sequence_end(1'b0),.b_user_success(1'b0),.b_decode_error(1'b0),
 .display_frame_bank(display),.display_scratch(),.display_scratch_bank(),.decode_scratch_bank(),
 .candidate_frame_valid(),.candidate_frame_scratch(),.candidate_scratch_bank(),.candidate_frame_bank(),
 .cadence_slot_debug(),.candidate_presentable_debug(),.framebuffer_swap_reset_count(),
 .reference_overlap_header(),.presentation_hold(),.scratch_available(),.promotion_active(),
 .presentation_complete(),.presentation_error(error),.debug_state());
task automatic candidate(input [1:0] bank,input bit first);
 begin
  @(negedge clk);completed=bank;tff=first;waiting=1;header=1;
  @(negedge clk);waiting=0;header=0;repeat(2)@(negedge clk);
 end
endtask
task automatic field_end(input [1:0] expected);
 begin
  @(negedge clk);tick=1;
  @(negedge clk);tick=0;repeat(3)@(negedge clk);swap=1;
  @(negedge clk);swap=0;repeat(2)@(negedge clk);
  if(display!==expected||error)$fatal(1,"field admission field=%0d fields=%0d rff=%0d tff=%0d expected=%0d got=%0d err=%0d",field,dut.native_fields_elapsed,rff,tff,expected,display,error);
  field=~field;
 end
endtask
initial begin
 repeat(4)@(negedge clk);reset=0;
 // The first visible picture requires two complete fields.
 candidate(1,1);field_end(0);field_end(1);
 // RFF extends the next picture to three fields and changes successor parity.
 rff=1;candidate(2,0);field_end(1);field_end(1);field_end(2);
 // A BFF picture of two fields retains the next picture's BFF start.
 rff=0;candidate(0,0);field_end(2);field_end(0);
 // A timestamp can delay a ready picture, never shorten current duration.
 pts=1;due=0;rff=1;candidate(1,1);field_end(0);field_end(0);field_end(0);
 due=1;field_end(0);field_end(1); // wrong physical parity still waits one field
 // No scan-visible picture means empty fields do not consume duration.
 pts=0;rff=0;present=0;candidate(2,1);field_end(1);field_end(1);
 present=1;field_end(1);field_end(2);
 $display("FILM_CADENCE_PASS two/three fields, changing TFF, PTS floor, parity, invisible startup");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
