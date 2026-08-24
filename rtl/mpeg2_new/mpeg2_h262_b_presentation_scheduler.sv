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
    input  wire cadence_tick_pulse,
    input  wire [3:0] frame_rate_code,
    // Entry 470: cadence is the mandatory floor for every retained picture.
    // A timestamp may hold its candidate beyond that slot but may never admit
    // it early; untimestamped candidates use the exact-rate cadence alone.
    input  wire timestamp_candidate_active,
    input  wire timestamp_candidate_due,
    input  wire frame_waiting,
    input  wire [1:0] completed_frame_bank,
    input  wire [1:0] reference_frame_bank,
    input  wire [7:0] reference_promotion_count,
    input  wire b_picture_start,
    input  wire non_b_picture_start,
    input  wire i_picture_start,
    input  wire p_picture_start,
    input  wire sequence_end,
    input  wire b_user_success,
    input  wire b_decode_error,
    output reg [1:0] display_frame_bank,
    output reg  display_scratch,
    output reg  display_scratch_bank,
    output reg  decode_scratch_bank,
    output wire candidate_frame_valid,
    output wire candidate_frame_scratch,
    output wire candidate_scratch_bank,
    output wire [1:0] candidate_frame_bank,
    // Entry 468: passive admission telemetry. These outputs mirror terms
    // already used below and never feed the scheduler back.
    output wire cadence_slot_debug,
    output wire candidate_presentable_debug,
    output reg [2:0] framebuffer_swap_reset_count,
    output wire reference_overlap_header,
    output wire presentation_hold,
    // Entry 282: pure observability taps for the cadence profiler.  These
    // expose existing internal terms so presentation hold can be attributed;
    // they drive no scheduler logic and change no ownership rule.
    output wire scratch_available,
    output wire promotion_active,
    // Completion is high while no B-reordering run is active. A B header
    // clears it until that run's scratch pictures and future reference retire.
    output reg  presentation_complete,
    output reg  presentation_error,
    // Entry 311: passive state export for the development cadence snapshot.
    // No bit feeds scheduler control or timing decisions.
    output wire [31:0] debug_state
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
// Entry 315: one B header may arrive after an overlapping reference header
// but before that reference publishes or an old scratch bank is released.
// The classification byte is retained here while presentation backpressure
// prevents any B payload from reaching the decoder without both resources.
reg deferred_queued_b_start;

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

// Entry 354: the fixed 40 MHz 800x600 raster produces one swap window every
// 1056*628 pixels.  Accumulate source-picture credit in pixel-clock units for
// the 24000/1001, exact 24, 25, 30000/1001, and exact 30 fps Table 6-4 rates.
// The 24000/1001 fractional rate uses the exact reduced ratio
//     (663168 * 24000) / (40000000 * 1001) = 22608 / 56875
// and the 30000/1001 rate uses
//     (663168 * 30000) / (40000000 * 1001) = 5652 / 11375
// so neither drifts or rounds to its neighboring integer rate.  Saturating at
// the next due slot prevents a decode stall from banking credit and replaying
// ready pictures on consecutive refreshes.
localparam [25:0] CADENCE_LIMIT_24000_1001 = 26'd56875;
localparam [25:0] CADENCE_STEP_24000_1001  = 26'd22608;
localparam [25:0] CADENCE_DUE_24000_1001 =
    CADENCE_LIMIT_24000_1001-CADENCE_STEP_24000_1001;
localparam [25:0] CADENCE_LIMIT_24FPS = 26'd40000000;
localparam [25:0] CADENCE_STEP_24FPS  = 26'd15916032;
localparam [25:0] CADENCE_DUE_24FPS =
    CADENCE_LIMIT_24FPS-CADENCE_STEP_24FPS;
localparam [25:0] CADENCE_LIMIT_25FPS = 26'd40000000;
localparam [25:0] CADENCE_STEP_25FPS  = 26'd16579200;
localparam [25:0] CADENCE_DUE_25FPS =
    CADENCE_LIMIT_25FPS-CADENCE_STEP_25FPS;
localparam [25:0] CADENCE_LIMIT_30000_1001 = 26'd11375;
localparam [25:0] CADENCE_STEP_30000_1001  = 26'd5652;
localparam [25:0] CADENCE_DUE_30000_1001 =
    CADENCE_LIMIT_30000_1001-CADENCE_STEP_30000_1001;
localparam [25:0] CADENCE_LIMIT_30FPS = 26'd40000000;
localparam [25:0] CADENCE_STEP_30FPS  = 26'd19895040;
localparam [25:0] CADENCE_DUE_30FPS =
    CADENCE_LIMIT_30FPS-CADENCE_STEP_30FPS;
reg [25:0] cadence_credit;
reg [3:0] cadence_rate_code_q;

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
wire cadence_24000_1001=(frame_rate_code==4'h1);
wire cadence_24fps=(frame_rate_code==4'h2);
wire cadence_25fps=(frame_rate_code==4'h3);
wire cadence_30000_1001=(frame_rate_code==4'h4);
wire cadence_30fps=(frame_rate_code==4'h5);
wire cadence_supported=cadence_24000_1001||cadence_24fps||cadence_25fps||
                       cadence_30000_1001||cadence_30fps;
wire [25:0] cadence_limit=cadence_24000_1001?CADENCE_LIMIT_24000_1001:
                          cadence_30000_1001?CADENCE_LIMIT_30000_1001:
                          CADENCE_LIMIT_24FPS;
wire [25:0] cadence_step=cadence_24000_1001?CADENCE_STEP_24000_1001:
                         cadence_24fps?CADENCE_STEP_24FPS:
                         cadence_25fps?CADENCE_STEP_25FPS:
                         cadence_30000_1001?CADENCE_STEP_30000_1001:
                                             CADENCE_STEP_30FPS;
wire [25:0] cadence_due=cadence_24000_1001?CADENCE_DUE_24000_1001:
                        cadence_24fps?CADENCE_DUE_24FPS:
                        cadence_25fps?CADENCE_DUE_25FPS:
                        cadence_30000_1001?CADENCE_DUE_30000_1001:
                                            CADENCE_DUE_30FPS;
wire cadence_scale_changed=
    (cadence_24000_1001!=(cadence_rate_code_q==4'h1))||
    (cadence_30000_1001!=(cadence_rate_code_q==4'h4));
wire cadence_slot=!cadence_scale_changed&&
                  (!cadence_supported||(cadence_credit>=cadence_due));
wire presentation_slot=cadence_slot&&
                       (!timestamp_candidate_active||timestamp_candidate_due);
assign candidate_frame_valid=scheduled_frame_valid;
assign candidate_frame_scratch=scheduled_frame_scratch;
assign candidate_scratch_bank=scheduled_scratch_bank;
assign candidate_frame_bank=scheduled_frame_bank;
assign cadence_slot_debug=cadence_slot;
assign candidate_presentable_debug=scheduled_frame_valid&&
                                   scheduled_frame_differs;
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
assign scratch_available=queued_scratch_available;
assign promotion_active=promotion_pending;
assign debug_state = {
    presentation_complete,
    last_bound_reference_valid,
    queued_first_scratch_bank,
    terminal_boundary_pending,
    pending_frame_released,
    pending_frame_valid,
    promotion_pending,
    decode_generation_queued,
    queued_overlap_frame_pending,
    queued_overlap_decode_open,
    queued_run_picture_count,
    queued_future_reference_pending,
    queued_future_frame_pending,
    queued_scratch1_pending,
    queued_scratch0_pending,
    queued_decode_inflight,
    queued_run_closed,
    queued_run_active,
    overlap_frame_pending,
    overlap_decode_open,
    run_picture_count,
    scratch_presented,
    future_reference_pending,
    future_frame_pending,
    next_present_scratch_bank,
    scratch1_pending,
    scratch0_pending,
    decode_inflight,
    run_closed,
    reorder_active
};
// A released ordinary reference occupies the scheduler's sole pending slot.
// Stop after its classifying header until cadence consumes it, otherwise a
// lightweight following P can publish and overwrite that undisplayed bank.
// The initial reference is already visible in the reset display bank and does
// not need a synthetic bank change before decode may continue.
wire ordinary_reference_waiting=!reorder_active&&pending_frame_valid&&
    pending_frame_released&&
    (display_scratch||(pending_frame_bank!=display_frame_bank));
assign presentation_hold=ordinary_reference_waiting||
                         (reorder_active&&run_closed&&
                          !presentation_complete&&!presentation_error&&
                          (deferred_queued_b_start||
                           (!overlap_decode_open&&!queued_decode_inflight&&
                            (promotion_pending||!queued_header_capacity))));

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
        deferred_queued_b_start<=0;
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
        run_picture_count<=0;presentation_complete<=1;presentation_error<=0;
        cadence_credit<=CADENCE_DUE_24FPS;cadence_rate_code_q<=0;
    end else begin
        b_user_success_d<=b_user_success;
        cadence_rate_code_q<=frame_rate_code;

        // Seed the generation comparison from the first published reference.
        // Thereafter only a B future binding advances it, so a later bank wrap
        // remains distinguishable from an unpublished future reference.
        if(!last_bound_reference_valid&&(reference_promotion_count!=0))begin
            last_bound_reference_valid<=1;
            last_bound_reference_bank<=reference_frame_bank;
            last_bound_reference_count<=reference_promotion_count;
        end

        if(cadence_scale_changed)
            cadence_credit<=cadence_due;
        else if(cadence_tick_pulse)begin
            if(!cadence_supported)
                cadence_credit<=CADENCE_DUE_24FPS;
            else if(cadence_credit<cadence_due)
                cadence_credit<=cadence_credit+cadence_step;
            else
                cadence_credit<=cadence_due;
        end

        // Entry 225: a reference publication is not display-order permission.
        // Hold it until the following accepted header proves whether a B run
        // owns the future reference.  This also makes publication coincident
        // with a swap window safe: the just-published frame cannot win that
        // same swap before the B header arrives.
        // Entry 320: sequence end can precede publication of the overlapping
        // final P while a reordered run is still draining.  Retain the
        // boundary until that ordinary reference leaves the B generation.
        if(sequence_end&&!pending_frame_valid)
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
        if(frame_waiting&&reorder_active&&run_closed&&overlap_decode_open&&
           !deferred_queued_b_start)begin
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

        // The deferred B already consumed its classification byte, so its
        // overlapping reference publication must be retained even if the old
        // generation presented its future frame and closed overlap_decode_open
        // in the meantime.  Admission below consumes this pending identity as
        // soon as a scratch destination is also safe.
        if(frame_waiting&&deferred_queued_b_start)begin
            pending_frame_valid<=1;
            pending_frame_bank<=completed_frame_bank;
            pending_frame_released<=0;
            overlap_frame_pending<=1;
            overlap_decode_open<=0;
        end

        if(deferred_queued_b_start&&!b_picture_start&&
           (pending_frame_valid||frame_waiting)&&
           queued_scratch_available)begin
            queued_run_active<=1;queued_run_closed<=0;
            queued_decode_inflight<=1;
            decode_scratch_bank<=scratch0_available?1'b0:1'b1;
            decode_generation_queued<=1;
            queued_first_scratch_bank<=scratch0_available?1'b0:1'b1;
            queued_run_picture_count<=1;
            queued_scratch0_pending<=0;
            queued_scratch1_pending<=0;
            queued_future_frame_pending<=1;
            queued_future_frame_bank<=frame_waiting?
                completed_frame_bank:pending_frame_bank;
            last_bound_reference_valid<=1;
            last_bound_reference_bank<=frame_waiting?
                completed_frame_bank:pending_frame_bank;
            last_bound_reference_count<=reference_promotion_count;
            queued_future_reference_pending<=0;
            queued_overlap_decode_open<=0;
            queued_overlap_frame_pending<=0;
            pending_frame_valid<=0;pending_frame_released<=0;
            overlap_frame_pending<=0;overlap_decode_open<=0;
            deferred_queued_b_start<=0;
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
                deferred_queued_b_start<=0;
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
                if(deferred_queued_b_start||promotion_pending)begin
                    reorder_active<=0;run_closed<=0;decode_inflight<=0;
                    scratch0_pending<=0;scratch1_pending<=0;
                    future_frame_pending<=0;future_reference_pending<=0;
                    queued_run_active<=0;queued_decode_inflight<=0;
                    queued_scratch0_pending<=0;queued_scratch1_pending<=0;
                    queued_future_frame_pending<=0;
                    deferred_queued_b_start<=0;
                    presentation_error<=1;
                end else if(overlap_decode_open&&
                            (!(pending_frame_valid||frame_waiting)||
                             !queued_scratch_available))begin
                    // Entry 315: the overlap transaction guarantees that its
                    // reference is already decoding.  Retain this one early B
                    // header and stop before payload until both its future
                    // reference and a released scratch bank are available.
                    deferred_queued_b_start<=1;
                end else if(!(pending_frame_valid||
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
                    // Entry 313: either supported reference picture may use
                    // the one-reference overlap transaction.  In particular,
                    // admitting a new-GOP I here prevents the completed B run
                    // from draining before that future reference is decoded.
                    // sequence_end retains the immediate presentation hold.
                    overlap_decode_open<=(i_picture_start||p_picture_start)&&
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
                    queued_overlap_decode_open<=
                        (i_picture_start||p_picture_start)&&
                        reference_overlap_header;
                end
            end
        end

        if(swap_window_pulse&&presentation_slot&&scheduled_frame_valid&&
           scheduled_frame_differs)begin
            // Entry 470: presentation_slot guarantees cadence_slot here, so a
            // timestamped presentation consumes exactly the same accumulated
            // cadence credit as an untimestamped presentation.
            if(cadence_supported)
                cadence_credit<=cadence_credit+cadence_step-cadence_limit;
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
                if(queued_run_active||deferred_queued_b_start)begin
                    // Retire the visible generation first.  Promotion waits
                    // for any queued B completion edge so that ownership can
                    // never be lost on a coincident cadence window.
                    promotion_pending<=1;
                    overlap_decode_open<=0;
                    overlap_frame_pending<=0;
                end else begin
                    reorder_active<=0;run_closed<=0;
                    overlap_decode_open<=0;
                    terminal_boundary_pending<=0;
                    // Preserve a reference decoded during this presentation
                    // run.  It becomes the ordinary classification barrier
                    // for the following accepted header.
                    if(overlap_frame_pending||
                       (frame_waiting&&overlap_decode_open))begin
                        pending_frame_valid<=1;
                        pending_frame_released<=pending_frame_released||
                                                sequence_end||
                                                terminal_boundary_pending;
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
            deferred_queued_b_start<=0;
            presentation_error<=1;
        end else if(framebuffer_swap_reset_count!=0)
            framebuffer_swap_reset_count<=framebuffer_swap_reset_count-1'b1;

        // Promotion is deliberately a registered ownership handoff after the
        // old future frame becomes visible.  Waiting for queued B persistence
        // eliminates the only ambiguous same-edge completion case.
        if(promotion_pending&&!deferred_queued_b_start&&
           !queued_decode_inflight&&
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
                deferred_queued_b_start<=0;
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
            deferred_queued_b_start<=0;
            promotion_pending<=0;
            presentation_error<=1;
        end

        if(presentation_error)
            deferred_queued_b_start<=0;
    end
end
endmodule
