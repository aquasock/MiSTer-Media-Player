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
    input  wire [1:0] completed_frame_bank,
    input  wire [1:0] reference_frame_bank,
    input  wire [7:0] reference_promotion_count,
    input  wire b_picture_start,
    input  wire non_b_picture_start,
    input  wire p_picture_start,
    input  wire sequence_end,
    input  wire b_user_success,
    input  wire b_decode_error,
    output reg [1:0] display_frame_bank,
    output reg  display_scratch,
    output reg  display_scratch_bank,
    output reg  decode_scratch_bank,
    output reg [2:0] framebuffer_swap_reset_count,
    output wire reference_overlap_header,
    output wire presentation_hold,
    output reg  presentation_complete,
    output reg  presentation_error
);

reg pending_frame_valid,pending_frame_released;reg[1:0] pending_frame_bank;
reg terminal_boundary_pending;
reg b_user_success_d;
reg reorder_active,run_closed,decode_inflight;
reg scratch0_pending,scratch1_pending,next_present_scratch_bank;
reg future_frame_pending,future_reference_pending;reg[1:0] future_frame_bank;
reg scratch_presented;
reg [1:0] run_picture_count;
reg overlap_decode_open,overlap_frame_pending;

// Entry 269: while one closed run is being presented, retain the following
// run in a distinct logical generation.  Both generations still share the
// same two physical scratch banks; the availability terms below prevent a
// bank from being reused until display has left it.
reg queued_run_active,queued_run_closed,queued_decode_inflight;
reg queued_scratch0_pending,queued_scratch1_pending;
reg queued_first_scratch_bank;
reg queued_future_frame_pending;reg[1:0] queued_future_frame_bank;
reg queued_future_reference_pending;
reg [1:0] queued_run_picture_count;
reg queued_overlap_decode_open,queued_overlap_frame_pending;
reg decode_generation_queued,promotion_pending;
reg last_bound_reference_valid;
reg [1:0] last_bound_reference_bank;
reg [7:0] last_bound_reference_count;

// Entry 230: the fixed 40 MHz 800x600 raster produces one swap window every
// 1000*800 pixels.  For the current 25 fps compatibility boundary, accumulate
// source-picture credit in nanoseconds.  Saturating at the next due slot
// prevents a decode stall from banking credit and replaying ready pictures on
// consecutive refreshes.
//
// Entry 280: STEP is the real refresh period and must be retuned whenever the
// raster changes.  At the former 1056*628 geometry the 60.3165 Hz grid paced a
// correct 24.9995 fps average, but only by alternating 33.158 and 49.738 ms
// slots, and long-GOP decode missed the narrow slot often enough to settle at
// 23.723813 fps.  The 1000*800 raster is exactly 50.000 Hz, so STEP is exactly
// half of LIMIT and DUE equals STEP.  Because the due comparison is made before
// the credit advances, a frame becomes due every second refresh in a uniform
// 40.000 ms slot at exactly 25 fps, and a saturated slot still cannot replay on
// the immediately following refresh.
localparam [25:0] CADENCE_LIMIT_25FPS = 26'd40000000;
localparam [25:0] CADENCE_STEP_25FPS  = 26'd20000000;
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
wire [1:0] scheduled_frame_bank=future_waiting?future_frame_bank:
                                pending_frame_bank;
wire scheduled_frame_differs=scheduled_frame_scratch?
    (!display_scratch||(scheduled_scratch_bank!=display_scratch_bank)):
    (display_scratch||(scheduled_frame_bank!=display_frame_bank));
wire cadence_25fps=(frame_rate_code==4'h3);
wire cadence_slot=!cadence_25fps||
                  (cadence_credit>=CADENCE_DUE_25FPS);
wire scratch0_available=!scratch0_pending&&!queued_scratch0_pending&&
    !(display_scratch&&!display_scratch_bank)&&
    !(decode_inflight&&!decode_scratch_bank)&&
    !(queued_decode_inflight&&!decode_scratch_bank);
wire scratch1_available=!scratch1_pending&&!queued_scratch1_pending&&
    !(display_scratch&&display_scratch_bank)&&
    !(decode_inflight&&decode_scratch_bank)&&
    !(queued_decode_inflight&&decode_scratch_bank);
wire queued_scratch_available=scratch0_available||scratch1_available;
wire queued_header_capacity=
    (!queued_run_active&&
     (pending_frame_valid||(frame_waiting&&overlap_decode_open))&&
     queued_scratch_available)||
    (queued_run_active&&!queued_run_closed&&!queued_decode_inflight&&
     (queued_run_picture_count<2)&&queued_scratch_available)||
    queued_overlap_decode_open;

// Entry 247: after the accepted P header closes a B run, allow that one P
// transaction to decode while the prior scratch/future sequence is presented.
// Its publication closes the window before a later header can reuse scratch.
assign reference_overlap_header=(reorder_active&&!run_closed)||
                                (queued_run_active&&!queued_run_closed);
assign presentation_hold=reorder_active&&run_closed&&
                         !overlap_decode_open&&!queued_decode_inflight&&
                         (promotion_pending||!queued_header_capacity)&&
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
        overlap_decode_open<=0;overlap_frame_pending<=0;
        queued_run_active<=0;queued_run_closed<=0;
        queued_decode_inflight<=0;
        queued_scratch0_pending<=0;queued_scratch1_pending<=0;
        queued_first_scratch_bank<=0;
        queued_future_frame_pending<=0;queued_future_frame_bank<=0;
        queued_future_reference_pending<=0;
        queued_run_picture_count<=0;
        queued_overlap_decode_open<=0;queued_overlap_frame_pending<=0;
        decode_generation_queued<=0;promotion_pending<=0;
        last_bound_reference_valid<=0;last_bound_reference_bank<=0;
        last_bound_reference_count<=0;
        run_picture_count<=0;presentation_complete<=0;presentation_error<=0;
        cadence_credit<=CADENCE_DUE_25FPS;
    end else begin
        b_user_success_d<=b_user_success;

        // Seed the generation comparison from the first published reference.
        // Thereafter only a B future binding advances it, so a later bank wrap
        // remains distinguishable from an unpublished future reference.
        if(!last_bound_reference_valid&&(reference_promotion_count!=0))begin
            last_bound_reference_valid<=1;
            last_bound_reference_bank<=reference_frame_bank;
            last_bound_reference_count<=reference_promotion_count;
        end

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

        // The publication produced by the one permitted overlap transaction
        // is the next reference candidate, not the retained future reference
        // owned by the B run that is still being displayed.
        if(frame_waiting&&reorder_active&&run_closed&&overlap_decode_open)begin
            pending_frame_valid<=1;
            pending_frame_bank<=completed_frame_bank;
            pending_frame_released<=0;
            overlap_frame_pending<=1;
            overlap_decode_open<=0;
        end

        // The P decoded after the queued B pair is one generation farther
        // ahead.  Keep its publication behind the same classification
        // barrier, but bind it to the queued generation until promotion.
        if(frame_waiting&&queued_run_active&&queued_run_closed&&
           queued_overlap_decode_open)begin
            pending_frame_valid<=1;
            pending_frame_bank<=completed_frame_bank;
            pending_frame_released<=0;
            queued_overlap_frame_pending<=1;
            queued_overlap_decode_open<=0;
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
            last_bound_reference_valid<=1;
            last_bound_reference_bank<=completed_frame_bank;
            last_bound_reference_count<=reference_promotion_count;
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
                overlap_decode_open<=0;overlap_frame_pending<=0;
                decode_generation_queued<=0;
                if(frame_waiting)begin
                    future_frame_bank<=completed_frame_bank;
                    future_reference_pending<=0;
                    last_bound_reference_valid<=1;
                    last_bound_reference_bank<=completed_frame_bank;
                    last_bound_reference_count<=reference_promotion_count;
                end else if(pending_frame_valid)begin
                    future_frame_bank<=pending_frame_bank;
                    future_reference_pending<=0;
                    last_bound_reference_valid<=1;
                    last_bound_reference_bank<=pending_frame_bank;
                    last_bound_reference_count<=reference_promotion_count;
                end else if((!display_scratch&&
                             (display_frame_bank!=reference_frame_bank))||
                            (last_bound_reference_valid&&
                             (reference_promotion_count!=
                              last_bound_reference_count)))begin
                    future_frame_bank<=reference_frame_bank;
                    future_reference_pending<=0;
                    last_bound_reference_valid<=1;
                    last_bound_reference_bank<=reference_frame_bank;
                    last_bound_reference_count<=reference_promotion_count;
                end else begin
                    future_frame_bank<=reference_frame_bank;
                    future_reference_pending<=1;
                end
                if(display_scratch)begin
                    reorder_active<=0;decode_inflight<=0;future_frame_pending<=0;
                    future_reference_pending<=0;presentation_error<=1;
                end
            end else if(!run_closed)begin
                if((future_reference_pending&&!frame_waiting)||
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
                    decode_inflight<=1;decode_generation_queued<=0;
                    run_picture_count<=run_picture_count+1'b1;
                end
            end else if(!queued_run_active)begin
                if(promotion_pending||
                   !(pending_frame_valid||
                     (frame_waiting&&overlap_decode_open))||
                   !queued_scratch_available)begin
                    reorder_active<=0;run_closed<=0;decode_inflight<=0;
                    scratch0_pending<=0;scratch1_pending<=0;
                    future_frame_pending<=0;future_reference_pending<=0;
                    queued_run_active<=0;queued_decode_inflight<=0;
                    queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                    queued_future_frame_pending<=0;
                    presentation_error<=1;
                end else begin
                    queued_run_active<=1;queued_run_closed<=0;
                    queued_decode_inflight<=1;
                    decode_scratch_bank<=scratch0_available?1'b0:1'b1;
                    decode_generation_queued<=1;
                    queued_first_scratch_bank<=scratch0_available?1'b0:1'b1;
                    queued_run_picture_count<=1;
                    queued_scratch0_pending<=0;
                    queued_scratch1_pending<=0;
                    queued_future_frame_pending<=1;
                    queued_future_frame_bank<=
                        (frame_waiting&&overlap_decode_open)?
                        completed_frame_bank:pending_frame_bank;
                    last_bound_reference_valid<=1;
                    last_bound_reference_bank<=
                        (frame_waiting&&overlap_decode_open)?
                        completed_frame_bank:pending_frame_bank;
                    last_bound_reference_count<=reference_promotion_count;
                    queued_future_reference_pending<=0;
                    queued_overlap_decode_open<=0;
                    queued_overlap_frame_pending<=0;
                    pending_frame_valid<=0;pending_frame_released<=0;
                    overlap_frame_pending<=0;overlap_decode_open<=0;
                end
            end else if(!queued_run_closed)begin
                if(queued_decode_inflight||
                   (queued_run_picture_count>=2)||
                   !queued_scratch_available)begin
                    reorder_active<=0;run_closed<=0;decode_inflight<=0;
                    scratch0_pending<=0;scratch1_pending<=0;
                    future_frame_pending<=0;future_reference_pending<=0;
                    queued_run_active<=0;queued_decode_inflight<=0;
                    queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                    queued_future_frame_pending<=0;
                    presentation_error<=1;
                end else begin
                    decode_scratch_bank<=scratch0_available?1'b0:1'b1;
                    queued_decode_inflight<=1;
                    decode_generation_queued<=1;
                    queued_run_picture_count<=queued_run_picture_count+1'b1;
                end
            end else begin
                reorder_active<=0;run_closed<=0;decode_inflight<=0;
                scratch0_pending<=0;scratch1_pending<=0;
                future_frame_pending<=0;future_reference_pending<=0;
                queued_run_active<=0;queued_decode_inflight<=0;
                queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                queued_future_frame_pending<=0;
                presentation_error<=1;
            end
        end

        if(b_user_success_edge)begin
            if(decode_generation_queued)begin
                if(!queued_run_active||!queued_decode_inflight||
                   queued_future_reference_pending)begin
                    reorder_active<=0;run_closed<=0;decode_inflight<=0;
                    future_frame_pending<=0;future_reference_pending<=0;
                    queued_run_active<=0;queued_decode_inflight<=0;
                    queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                    queued_future_frame_pending<=0;
                    presentation_error<=1;
                end else begin
                    queued_decode_inflight<=0;
                    if(decode_scratch_bank)begin
                        if(queued_scratch1_pending||
                           (display_scratch&&display_scratch_bank))begin
                            reorder_active<=0;queued_run_active<=0;
                            queued_future_frame_pending<=0;
                            presentation_error<=1;
                        end else queued_scratch1_pending<=1;
                    end else begin
                        if(queued_scratch0_pending||
                           (display_scratch&&!display_scratch_bank))begin
                            reorder_active<=0;queued_run_active<=0;
                            queued_future_frame_pending<=0;
                            presentation_error<=1;
                        end else queued_scratch0_pending<=1;
                    end
                end
            end else if((future_reference_pending&&!frame_waiting)||
                        !reorder_active||!decode_inflight)begin
                reorder_active<=0;future_frame_pending<=0;
                future_reference_pending<=0;queued_run_active<=0;
                queued_future_frame_pending<=0;presentation_error<=1;
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
            if(!run_closed)begin
                if(future_reference_pending&&!frame_waiting)begin
                    reorder_active<=0;run_closed<=0;decode_inflight<=0;
                    scratch0_pending<=0;scratch1_pending<=0;
                    future_frame_pending<=0;future_reference_pending<=0;
                    presentation_error<=1;
                end else begin
                    run_closed<=1;
                    // A non-B close is overlap-eligible only when it is the P
                    // header explicitly classified by the caller. sequence_end
                    // retains the original immediate presentation hold.
                    overlap_decode_open<=p_picture_start&&
                                         reference_overlap_header;
                end
            end else if(queued_run_active&&!queued_run_closed)begin
                if(queued_future_reference_pending)begin
                    reorder_active<=0;run_closed<=0;decode_inflight<=0;
                    scratch0_pending<=0;scratch1_pending<=0;
                    future_frame_pending<=0;future_reference_pending<=0;
                    queued_run_active<=0;queued_decode_inflight<=0;
                    queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                    queued_future_frame_pending<=0;
                    presentation_error<=1;
                end else begin
                    queued_run_closed<=1;
                    queued_overlap_decode_open<=p_picture_start&&
                                                reference_overlap_header;
                end
            end
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
                future_frame_pending<=0;
                future_reference_pending<=0;
                if(queued_run_active)begin
                    // Retire the visible generation first.  Promotion waits
                    // for any queued B completion edge so that ownership can
                    // never be lost on a coincident cadence window.
                    promotion_pending<=1;
                    overlap_decode_open<=0;
                    overlap_frame_pending<=0;
                end else begin
                    reorder_active<=0;run_closed<=0;
                    overlap_decode_open<=0;
                    // Preserve a reference decoded during this presentation
                    // run.  It becomes the ordinary classification barrier
                    // for the following accepted header.
                    if(overlap_frame_pending||
                       (frame_waiting&&overlap_decode_open))begin
                        pending_frame_valid<=1;
                        pending_frame_released<=0;
                    end else begin
                        pending_frame_valid<=0;
                        pending_frame_released<=0;
                    end
                    overlap_frame_pending<=0;
                    if(scratch_presented&&!presentation_error)
                        presentation_complete<=1;
                    else presentation_error<=1;
                end
            end else begin
                pending_frame_valid<=0;
                pending_frame_released<=0;
            end
        end else if(swap_window_pulse&&future_waiting&&!scheduled_frame_differs)begin
            future_frame_pending<=0;reorder_active<=0;run_closed<=0;
            future_reference_pending<=0;
            pending_frame_valid<=0;pending_frame_released<=0;
            overlap_decode_open<=0;overlap_frame_pending<=0;
            queued_run_active<=0;queued_decode_inflight<=0;
            queued_scratch0_pending<=0;queued_scratch1_pending<=0;
            queued_future_frame_pending<=0;promotion_pending<=0;
            presentation_error<=1;
        end else if(framebuffer_swap_reset_count!=0)
            framebuffer_swap_reset_count<=framebuffer_swap_reset_count-1'b1;

        // Promotion is deliberately a registered ownership handoff after the
        // old future frame becomes visible.  Waiting for queued B persistence
        // eliminates the only ambiguous same-edge completion case.
        if(promotion_pending&&!queued_decode_inflight&&
           !(frame_waiting&&queued_overlap_decode_open))begin
            if(!queued_run_active||!queued_future_frame_pending||
               queued_future_reference_pending)begin
                reorder_active<=0;run_closed<=0;decode_inflight<=0;
                scratch0_pending<=0;scratch1_pending<=0;
                future_frame_pending<=0;future_reference_pending<=0;
                queued_run_active<=0;queued_future_frame_pending<=0;
                promotion_pending<=0;presentation_error<=1;
            end else begin
                reorder_active<=1;
                scratch0_pending<=queued_scratch0_pending;
                scratch1_pending<=queued_scratch1_pending;
                next_present_scratch_bank<=queued_first_scratch_bank;
                future_frame_pending<=queued_future_frame_pending;
                future_frame_bank<=queued_future_frame_bank;
                future_reference_pending<=queued_future_reference_pending;
                scratch_presented<=0;
                run_picture_count<=queued_run_picture_count;
                run_closed<=queued_run_closed;
                decode_inflight<=0;
                overlap_decode_open<=queued_overlap_decode_open;
                overlap_frame_pending<=queued_overlap_frame_pending;
                queued_run_active<=0;queued_run_closed<=0;
                queued_decode_inflight<=0;
                queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                queued_future_frame_pending<=0;
                queued_future_reference_pending<=0;
                queued_run_picture_count<=0;
                queued_overlap_decode_open<=0;
                queued_overlap_frame_pending<=0;
                decode_generation_queued<=0;promotion_pending<=0;
                presentation_complete<=0;
            end
        end

        if(reorder_active&&b_decode_error)begin
            reorder_active<=0;run_closed<=0;decode_inflight<=0;
            scratch0_pending<=0;scratch1_pending<=0;future_frame_pending<=0;
            future_reference_pending<=0;
            overlap_decode_open<=0;
            queued_run_active<=0;queued_run_closed<=0;
            queued_decode_inflight<=0;
            queued_scratch0_pending<=0;queued_scratch1_pending<=0;
            queued_future_frame_pending<=0;
            queued_future_reference_pending<=0;
            queued_overlap_decode_open<=0;
            promotion_pending<=0;
            presentation_error<=1;
        end
    end
end
endmodule
