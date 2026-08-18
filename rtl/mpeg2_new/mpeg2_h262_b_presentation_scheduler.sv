//============================================================================
// MiSTer Media Player - consecutive-B presentation scheduler
//
// Entry 206: retain as many as two adjacent non-reference B pictures in
// separate scratch frames, present them in coded/display order, then present
// the future reference.  Header inputs are one-cycle pulses derived from
// accepted compressed-stream bytes.  Any decode or ownership failure aborts
// the transaction without retaining compressed-stream backpressure.
//============================================================================
module mpeg2_h262_b_presentation_scheduler
(
    input  wire clk,
    input  wire reset,
    input  wire swap_window_pulse,
    input  wire frame_waiting,
    input  wire completed_frame_bank,
    input  wire reference_frame_bank,
    input  wire b_picture_start,
    input  wire non_b_picture_start,
    input  wire sequence_end,
    input  wire b_user_success,
    input  wire b_decode_error,
    output reg  display_frame_bank,
    output reg  display_scratch,
    output reg  display_scratch_bank,
    output reg  decode_scratch_bank,
    output reg [2:0] framebuffer_swap_reset_count,
    output wire presentation_hold,
    output reg  presentation_complete,
    output reg  presentation_error
);

reg pending_frame_valid,pending_frame_bank;
reg b_user_success_d;
reg reorder_active,run_closed,decode_inflight;
reg scratch0_pending,scratch1_pending,next_present_scratch_bank;
reg future_frame_pending,future_frame_bank,scratch_presented;
reg [1:0] run_picture_count;

wire b_user_success_edge=b_user_success&&!b_user_success_d;
wire scratch_waiting=next_present_scratch_bank?scratch1_pending:scratch0_pending;
wire future_waiting=future_frame_pending&&run_closed&&!decode_inflight&&
                    !scratch0_pending&&!scratch1_pending&&scratch_presented;
wire scheduled_frame_valid=scratch_waiting||future_waiting||
    (!reorder_active&&!b_picture_start&&(frame_waiting||pending_frame_valid));
wire scheduled_frame_scratch=scratch_waiting;
wire scheduled_scratch_bank=next_present_scratch_bank;
wire scheduled_frame_bank=future_waiting?future_frame_bank:
                          frame_waiting?completed_frame_bank:pending_frame_bank;
wire scheduled_frame_differs=scheduled_frame_scratch?
    (!display_scratch||(scheduled_scratch_bank!=display_scratch_bank)):
    (display_scratch||(scheduled_frame_bank!=display_frame_bank));

assign presentation_hold=reorder_active&&run_closed&&
                         !presentation_complete&&!presentation_error;

always @(posedge clk) begin
    if(reset) begin
        display_frame_bank<=0;display_scratch<=0;display_scratch_bank<=0;
        decode_scratch_bank<=0;framebuffer_swap_reset_count<=0;
        pending_frame_valid<=0;pending_frame_bank<=0;b_user_success_d<=0;
        reorder_active<=0;run_closed<=0;decode_inflight<=0;
        scratch0_pending<=0;scratch1_pending<=0;next_present_scratch_bank<=0;
        future_frame_pending<=0;future_frame_bank<=0;scratch_presented<=0;
        run_picture_count<=0;presentation_complete<=0;presentation_error<=0;
    end else begin
        b_user_success_d<=b_user_success;

        if(frame_waiting&&!reorder_active&&!b_picture_start&&!b_user_success_edge)begin
            pending_frame_valid<=1;
            pending_frame_bank<=completed_frame_bank;
        end

        if(b_picture_start)begin
            if(!reorder_active)begin
                reorder_active<=1;run_closed<=0;decode_inflight<=1;
                decode_scratch_bank<=0;scratch0_pending<=0;scratch1_pending<=0;
                next_present_scratch_bank<=0;future_frame_pending<=1;
                future_frame_bank<=reference_frame_bank;scratch_presented<=0;
                run_picture_count<=1;presentation_complete<=0;
                presentation_error<=0;pending_frame_valid<=0;
                if(display_scratch||(display_frame_bank==reference_frame_bank))begin
                    reorder_active<=0;decode_inflight<=0;future_frame_pending<=0;
                    presentation_error<=1;
                end
            end else if(decode_inflight||(run_picture_count>=2)||
                (!decode_scratch_bank&&(scratch1_pending||
                 (display_scratch&&display_scratch_bank)))||
                (decode_scratch_bank&&(scratch0_pending||
                 (display_scratch&&!display_scratch_bank))))begin
                reorder_active<=0;decode_inflight<=0;scratch0_pending<=0;
                scratch1_pending<=0;future_frame_pending<=0;presentation_error<=1;
            end else begin
                decode_scratch_bank<=!decode_scratch_bank;
                decode_inflight<=1;
                run_picture_count<=run_picture_count+1'b1;
            end
        end

        if(b_user_success_edge)begin
            if(!reorder_active||!decode_inflight)begin
                reorder_active<=0;future_frame_pending<=0;presentation_error<=1;
            end else begin
                decode_inflight<=0;
                if(decode_scratch_bank)begin
                    if(scratch1_pending||(display_scratch&&display_scratch_bank))begin
                        reorder_active<=0;future_frame_pending<=0;presentation_error<=1;
                    end else scratch1_pending<=1;
                end else begin
                    if(scratch0_pending||(display_scratch&&!display_scratch_bank))begin
                        reorder_active<=0;future_frame_pending<=0;presentation_error<=1;
                    end else scratch0_pending<=1;
                end
            end
        end

        if(reorder_active&&(non_b_picture_start||sequence_end))run_closed<=1;

        if(swap_window_pulse&&scheduled_frame_valid&&scheduled_frame_differs)begin
            display_scratch<=scheduled_frame_scratch;
            if(scheduled_frame_scratch)display_scratch_bank<=scheduled_scratch_bank;
            else display_frame_bank<=scheduled_frame_bank;
            framebuffer_swap_reset_count<=4;
            if(scratch_waiting)begin
                if(next_present_scratch_bank)scratch1_pending<=0;
                else scratch0_pending<=0;
                next_present_scratch_bank<=!next_present_scratch_bank;
                scratch_presented<=1;
            end else if(future_waiting)begin
                future_frame_pending<=0;reorder_active<=0;run_closed<=0;
                pending_frame_valid<=0;
                if(scratch_presented&&!presentation_error)presentation_complete<=1;
                else presentation_error<=1;
            end else pending_frame_valid<=0;
        end else if(swap_window_pulse&&future_waiting&&!scheduled_frame_differs)begin
            future_frame_pending<=0;reorder_active<=0;run_closed<=0;
            pending_frame_valid<=0;presentation_error<=1;
        end else if(framebuffer_swap_reset_count!=0)
            framebuffer_swap_reset_count<=framebuffer_swap_reset_count-1'b1;

        if(reorder_active&&b_decode_error)begin
            reorder_active<=0;run_closed<=0;decode_inflight<=0;
            scratch0_pending<=0;scratch1_pending<=0;future_frame_pending<=0;
            presentation_error<=1;
        end
    end
end
endmodule
