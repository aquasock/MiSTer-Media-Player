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
    input  wire [3:0] frame_rate_code,
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

reg pending_frame_valid,pending_frame_bank,pending_frame_released;
reg terminal_boundary_pending;
reg b_user_success_d;
reg reorder_active,run_closed,decode_inflight;
reg scratch0_pending,scratch1_pending,next_present_scratch_bank;
reg future_frame_pending,future_frame_bank,future_reference_pending;
reg scratch_presented;
reg [1:0] run_picture_count;

// Entry 230: the fixed 40 MHz 800x600 raster produces one swap window every
// 1056*628 pixels.  For the current 25 fps compatibility boundary, accumulate
// source-picture credit in pixel-clock units.  Saturating at the next due slot
// prevents a decode stall from banking credit and replaying ready pictures on
// consecutive refreshes.
localparam [25:0] CADENCE_LIMIT_25FPS = 26'd40000000;
localparam [25:0] CADENCE_STEP_25FPS  = 26'd16579200;
localparam [25:0] CADENCE_DUE_25FPS =
    CADENCE_LIMIT_25FPS-CADENCE_STEP_25FPS;
reg [25:0] cadence_credit;

wire b_user_success_edge=b_user_success&&!b_user_success_d;
wire scratch_waiting=next_present_scratch_bank?scratch1_pending:scratch0_pending;
wire future_waiting=future_frame_pending&&run_closed&&!decode_inflight&&
                    !future_reference_pending&&
                    !scratch0_pending&&!scratch1_pending&&scratch_presented;
wire scheduled_frame_valid=scratch_waiting||future_waiting||
    (!reorder_active&&!b_picture_start&&pending_frame_valid&&
     pending_frame_released);
wire scheduled_frame_scratch=scratch_waiting;
wire scheduled_scratch_bank=next_present_scratch_bank;
wire scheduled_frame_bank=future_waiting?future_frame_bank:
                          pending_frame_bank;
wire scheduled_frame_differs=scheduled_frame_scratch?
    (!display_scratch||(scheduled_scratch_bank!=display_scratch_bank)):
    (display_scratch||(scheduled_frame_bank!=display_frame_bank));
wire cadence_25fps=(frame_rate_code==4'h3);
wire cadence_slot=!cadence_25fps||
                  (cadence_credit>=CADENCE_DUE_25FPS);

assign presentation_hold=reorder_active&&run_closed&&
                         !presentation_complete&&!presentation_error;

always @(posedge clk) begin
    if(reset) begin
        display_frame_bank<=0;display_scratch<=0;display_scratch_bank<=0;
        decode_scratch_bank<=0;framebuffer_swap_reset_count<=0;
        pending_frame_valid<=0;pending_frame_bank<=0;pending_frame_released<=0;
        terminal_boundary_pending<=0;b_user_success_d<=0;
        reorder_active<=0;run_closed<=0;decode_inflight<=0;
        scratch0_pending<=0;scratch1_pending<=0;next_present_scratch_bank<=0;
        future_frame_pending<=0;future_frame_bank<=0;
        future_reference_pending<=0;scratch_presented<=0;
        run_picture_count<=0;presentation_complete<=0;presentation_error<=0;
        cadence_credit<=CADENCE_DUE_25FPS;
    end else begin
        b_user_success_d<=b_user_success;

        if(swap_window_pulse)begin
            if(!cadence_25fps)
                cadence_credit<=CADENCE_DUE_25FPS;
            else if(cadence_credit<CADENCE_DUE_25FPS)
                cadence_credit<=cadence_credit+CADENCE_STEP_25FPS;
            else
                cadence_credit<=CADENCE_DUE_25FPS;
        end

        // Entry 225: a reference publication is not display-order permission.
        // Hold it until the following accepted header proves whether a B run
        // owns the future reference.  This also makes publication coincident
        // with a swap window safe: the just-published frame cannot win that
        // same swap before the B header arrives.
        if(sequence_end&&!reorder_active&&!pending_frame_valid&&!frame_waiting)
            terminal_boundary_pending<=1;

        if(frame_waiting&&!reorder_active&&!b_picture_start&&!b_user_success_edge)begin
            pending_frame_valid<=1;
            pending_frame_bank<=completed_frame_bank;
            pending_frame_released<=sequence_end||terminal_boundary_pending||
                                    non_b_picture_start;
            terminal_boundary_pending<=0;
        end

        if(pending_frame_valid&&(non_b_picture_start||sequence_end))
            pending_frame_released<=1;

        // Entry 227: the B header can be accepted in the same registered
        // handoff that publishes its future reference.  If the header arrived
        // first, bind that publication directly into the open B transaction;
        // it is not ordinary display work.
        if(frame_waiting&&reorder_active&&future_reference_pending)begin
            future_frame_bank<=completed_frame_bank;
            future_reference_pending<=0;
        end

        if(b_picture_start)begin
            if(!reorder_active)begin
                reorder_active<=1;run_closed<=0;decode_inflight<=1;
                decode_scratch_bank<=0;scratch0_pending<=0;scratch1_pending<=0;
                next_present_scratch_bank<=0;future_frame_pending<=1;
                scratch_presented<=0;
                run_picture_count<=1;presentation_complete<=0;
                presentation_error<=0;pending_frame_valid<=0;
                pending_frame_released<=0;
                if(frame_waiting)begin
                    future_frame_bank<=completed_frame_bank;
                    future_reference_pending<=0;
                end else if(pending_frame_valid)begin
                    future_frame_bank<=pending_frame_bank;
                    future_reference_pending<=0;
                end else if(!display_scratch&&
                            (display_frame_bank!=reference_frame_bank))begin
                    future_frame_bank<=reference_frame_bank;
                    future_reference_pending<=0;
                end else begin
                    future_frame_bank<=reference_frame_bank;
                    future_reference_pending<=1;
                end
                if(display_scratch)begin
                    reorder_active<=0;decode_inflight<=0;future_frame_pending<=0;
                    future_reference_pending<=0;presentation_error<=1;
                end
            end else if((future_reference_pending&&!frame_waiting)||
                decode_inflight||(run_picture_count>=2)||
                (!decode_scratch_bank&&(scratch1_pending||
                 (display_scratch&&display_scratch_bank)))||
                (decode_scratch_bank&&(scratch0_pending||
                 (display_scratch&&!display_scratch_bank))))begin
                reorder_active<=0;decode_inflight<=0;scratch0_pending<=0;
                scratch1_pending<=0;future_frame_pending<=0;
                future_reference_pending<=0;presentation_error<=1;
            end else begin
                decode_scratch_bank<=!decode_scratch_bank;
                decode_inflight<=1;
                run_picture_count<=run_picture_count+1'b1;
            end
        end

        if(b_user_success_edge)begin
            if((future_reference_pending&&!frame_waiting)||
               !reorder_active||!decode_inflight)begin
                reorder_active<=0;future_frame_pending<=0;
                future_reference_pending<=0;presentation_error<=1;
            end else begin
                decode_inflight<=0;
                if(decode_scratch_bank)begin
                    if(scratch1_pending||(display_scratch&&display_scratch_bank))begin
                        reorder_active<=0;future_frame_pending<=0;
                        future_reference_pending<=0;presentation_error<=1;
                    end else scratch1_pending<=1;
                end else begin
                    if(scratch0_pending||(display_scratch&&!display_scratch_bank))begin
                        reorder_active<=0;future_frame_pending<=0;
                        future_reference_pending<=0;presentation_error<=1;
                    end else scratch0_pending<=1;
                end
            end
        end

        if(reorder_active&&(non_b_picture_start||sequence_end))begin
            if(future_reference_pending&&!frame_waiting)begin
                reorder_active<=0;run_closed<=0;decode_inflight<=0;
                scratch0_pending<=0;scratch1_pending<=0;
                future_frame_pending<=0;future_reference_pending<=0;
                presentation_error<=1;
            end else run_closed<=1;
        end

        if(swap_window_pulse&&cadence_slot&&scheduled_frame_valid&&
           scheduled_frame_differs)begin
            if(cadence_25fps)
                cadence_credit<=cadence_credit+CADENCE_STEP_25FPS-
                                CADENCE_LIMIT_25FPS;
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
                future_reference_pending<=0;
                pending_frame_valid<=0;pending_frame_released<=0;
                if(scratch_presented&&!presentation_error)presentation_complete<=1;
                else presentation_error<=1;
            end else begin
                pending_frame_valid<=0;
                pending_frame_released<=0;
            end
        end else if(swap_window_pulse&&future_waiting&&!scheduled_frame_differs)begin
            future_frame_pending<=0;reorder_active<=0;run_closed<=0;
            future_reference_pending<=0;
            pending_frame_valid<=0;pending_frame_released<=0;
            presentation_error<=1;
        end else if(framebuffer_swap_reset_count!=0)
            framebuffer_swap_reset_count<=framebuffer_swap_reset_count-1'b1;

        if(reorder_active&&b_decode_error)begin
            reorder_active<=0;run_closed<=0;decode_inflight<=0;
            scratch0_pending<=0;scratch1_pending<=0;future_frame_pending<=0;
            future_reference_pending<=0;
            presentation_error<=1;
        end
    end
end
endmodule
