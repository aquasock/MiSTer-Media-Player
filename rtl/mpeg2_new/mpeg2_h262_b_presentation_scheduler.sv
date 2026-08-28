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
    input  wire native_film_mode,
    input  wire native_field,
    input  wire display_picture_present,
    input  wire display_repeat_first_field,
    input  wire candidate_top_field_first,
    // Entry 470: cadence is the mandatory floor for every retained picture.
    // A timestamp may hold its candidate beyond that slot but may never admit
    // it early; untimestamped candidates use the exact-rate cadence alone.
    input  wire timestamp_candidate_active,
    input  wire timestamp_candidate_due,
    // Native full-frame presentation has one safe swap boundary every two
    // fields.  The ordinary-reference overlap below may decode one I/P picture
    // into the already existing third frame region while its predecessor
    // waits for that boundary. Other modes retain the
    // established serialized ownership path.
    input  wire native_ordinary_overlap_enable,
    input  wire [1:0] active_frame_bank,
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
// A free scratch bank admits a B header, not a second reference payload.
// Retain a following I/P classification until the occupied reference slot
// leaves the draining run. This also preserves a header before completion.
reg deferred_reference_payload;
// A following reference header may arrive before the preceding reference's
// public completion. Keep its classification permission with that completion
// instead of leaving the new pending slot unreleased and overwritable.
reg [1:0] reference_headers_inflight;
reg [1:0] active_frame_bank_q;
reg early_reference_release;
wire reference_completed = frame_waiting || (active_frame_bank != active_frame_bank_q);
// A B header following an overlapped reference belongs to the secondary
// bank. Its payload may use scratch as soon as that reference completes, but
// the older ordinary candidate must still be presented before the scratch.
reg deferred_ordinary_b_start;
reg ordinary_reference_before_b;
// Once a closed B run has no prediction work left, its old reference bank
// can hold a second ordinary successor while scratch/future presentation
// drains. Keep that transaction distinct from the run's first successor.
reg ordinary_drain_overlap;

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
reg ordinary_reference_decode_open;
reg [1:0] ordinary_reference_decode_bank;
// Native all-I decode can now finish slightly ahead of its 30000/1001
// presentation slot.  With three ordinary DDR regions, retain the completed
// third bank here while pending_frame_* continues to own its predecessor.
reg ordinary_secondary_valid;
reg [1:0] ordinary_secondary_bank;
reg ordinary_secondary_released;
reg ordinary_resume_pending;
reg ordinary_terminal_drain_pending;

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
reg [1:0] native_fields_elapsed;
wire [1:0] native_field_duration=display_repeat_first_field ? 2'd3 : 2'd2;
reg [25:0] cadence_credit;
reg [3:0] cadence_rate_code_q;

wire ordinary_b_header_wait=pending_frame_valid&&
    (ordinary_secondary_valid||ordinary_reference_decode_open);
wire ordinary_b_header_ready=deferred_ordinary_b_start&&!reorder_active&&
    !ordinary_reference_decode_open&&(ordinary_secondary_valid||pending_frame_valid);
wire admitted_b_picture_start=(b_picture_start&&!ordinary_b_header_wait)||
    ordinary_b_header_ready;
wire new_b_retains_primary=admitted_b_picture_start&&!reorder_active&&
    ordinary_secondary_valid&&pending_frame_valid;
wire ordinary_before_b_waiting=(ordinary_reference_before_b||new_b_retains_primary)&&
    pending_frame_valid&&pending_frame_released;
wire b_user_success_edge=b_user_success&&!b_user_success_d;
wire scratch_waiting=next_present_scratch_bank?scratch1_pending:scratch0_pending;
wire future_waiting=future_frame_pending&&run_closed&&!decode_inflight&&
                    !future_reference_pending&&
                    !scratch0_pending&&!scratch1_pending&&scratch_presented;
wire scheduled_frame_valid=ordinary_before_b_waiting||scratch_waiting||future_waiting||
    (!reorder_active&&!admitted_b_picture_start&&pending_frame_valid&&
     pending_frame_released);
wire scheduled_frame_scratch=!ordinary_before_b_waiting&&scratch_waiting;
wire scheduled_scratch_bank=next_present_scratch_bank;
wire [1:0] scheduled_frame_bank=(future_waiting&&!ordinary_before_b_waiting)?future_frame_bank:
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
wire cadence_slot=native_film_mode ?
    ((native_fields_elapsed>=native_field_duration) &&
     (candidate_top_field_first==native_field)) :
    (!cadence_scale_changed && (!cadence_supported||(cadence_credit>=cadence_due)));
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
// A released ordinary reference normally occupies the scheduler's sole
// pending slot. Native 30000/1001 playback has three ordinary frame regions,
// so one proven I/P transaction may use the third region while cadence
// consumes its predecessor. Candidate timestamp validity changes
// when classification releases a frame, so it must not govern queue capacity.
// Each retained bank keeps its timestamp; presentation_slot still requires
// both cadence credit and that candidate's due time before a swap.
wire ordinary_reference_waiting=!reorder_active&&pending_frame_valid&&
    pending_frame_released&&
    (display_scratch||(pending_frame_bank!=display_frame_bank));
wire ordinary_reference_overlap_safe=
    native_ordinary_overlap_enable&&
    (frame_rate_code==4'h4)&&
    !reorder_active&&
    !display_scratch&&
    !ordinary_secondary_valid&&
    !ordinary_resume_pending&&
    pending_frame_valid&&
    (pending_frame_released||non_b_picture_start)&&
    (pending_frame_bank!=display_frame_bank)&&
    (active_frame_bank!=display_frame_bank)&&
    (active_frame_bank!=pending_frame_bank);
wire ordinary_drain_mode_safe=
    native_ordinary_overlap_enable&&(frame_rate_code==4'h4)&&
    reorder_active&&run_closed&&!decode_inflight&&!queued_run_active&&
    !deferred_queued_b_start&&!promotion_pending&&
    future_frame_pending&&!future_reference_pending;
wire ordinary_drain_overlap_safe=ordinary_drain_mode_safe&&
    overlap_frame_pending&&!overlap_decode_open&&
    pending_frame_valid&&(pending_frame_released||non_b_picture_start)&&
    !ordinary_secondary_valid&&!ordinary_resume_pending&&
    (display_scratch||(active_frame_bank!=display_frame_bank))&&
    (active_frame_bank!=future_frame_bank)&&
    (active_frame_bank!=pending_frame_bank);
wire ordinary_reference_present_now=
    swap_window_pulse&&presentation_slot&&scheduled_frame_valid&&
    scheduled_frame_differs&&!scheduled_frame_scratch&&!future_waiting;
wire ordinary_secondary_mode_safe=
    native_ordinary_overlap_enable&&
    (frame_rate_code==4'h4)&&
    ((!display_scratch&&!reorder_active)||
     (ordinary_drain_overlap&&ordinary_drain_mode_safe));
wire ordinary_secondary_release_now=
    ordinary_secondary_valid&&!ordinary_secondary_released&&
    (sequence_end||ordinary_terminal_drain_pending||
     ((i_picture_start||p_picture_start)&&ordinary_secondary_mode_safe));
wire ordinary_secondary_resume_now=
    ordinary_secondary_valid&&!ordinary_secondary_released&&
    (i_picture_start||p_picture_start)&&ordinary_secondary_mode_safe;
assign presentation_hold=deferred_ordinary_b_start||
                         (ordinary_reference_before_b&&run_closed)||
                         (ordinary_reference_waiting&&
                          !ordinary_reference_decode_open&&
                          !(ordinary_secondary_valid&&
                            !ordinary_secondary_released))||
                         (ordinary_secondary_valid&&
                          ordinary_secondary_released)||
                         (reorder_active&&run_closed&&
                          !presentation_complete&&!presentation_error&&
                          ((deferred_reference_payload&&!ordinary_reference_decode_open)||
                           deferred_queued_b_start||
                           (!overlap_decode_open&&!ordinary_reference_decode_open&&!queued_decode_inflight&&
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
        deferred_reference_payload<=0;
        reference_headers_inflight<=0;
        active_frame_bank_q<=0;
        early_reference_release<=0;
        deferred_ordinary_b_start<=0;
        ordinary_reference_before_b<=0;
        ordinary_drain_overlap<=0;
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
        ordinary_reference_decode_open<=0;
        ordinary_reference_decode_bank<=0;
        ordinary_secondary_valid<=0;
        ordinary_secondary_bank<=0;
        ordinary_secondary_released<=0;
        ordinary_resume_pending<=0;
        ordinary_terminal_drain_pending<=0;
        run_picture_count<=0;presentation_complete<=1;presentation_error<=0;
        cadence_credit<=CADENCE_DUE_24FPS;cadence_rate_code_q<=0;
        native_fields_elapsed<=0;
    end else begin
        b_user_success_d<=b_user_success;
        if(b_picture_start&&ordinary_b_header_wait)
            deferred_ordinary_b_start<=1;
        else if(ordinary_b_header_ready)
            deferred_ordinary_b_start<=0;
        active_frame_bank_q<=active_frame_bank;
        if(!reorder_active)ordinary_drain_overlap<=0;
        case ({non_b_picture_start,reference_completed})
            2'b10: if(reference_headers_inflight!=2)
                       reference_headers_inflight<=reference_headers_inflight+1'b1;
            2'b01: if(reference_headers_inflight!=0)
                       reference_headers_inflight<=reference_headers_inflight-1'b1;
            2'b11: if(reference_headers_inflight==0)
                       reference_headers_inflight<=1;
            default: begin end
        endcase
        if(reference_completed)
            early_reference_release<=0;
        else if(non_b_picture_start&&(reference_headers_inflight!=0))
            early_reference_release<=1;
        if(!reorder_active||presentation_error)
            deferred_reference_payload<=0;
        else if(non_b_picture_start&&run_closed&&
                !(queued_run_active&&!queued_run_closed))
            deferred_reference_payload<=1;
        cadence_rate_code_q<=frame_rate_code;
        if(!native_film_mode) native_fields_elapsed<=0;
        else if(cadence_tick_pulse && display_picture_present && native_fields_elapsed!=3)
            native_fields_elapsed<=native_fields_elapsed+1'b1;

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

        if(frame_waiting&&!reorder_active&&!admitted_b_picture_start&&
           !b_user_success_edge&&
           !(ordinary_reference_decode_open&&pending_frame_valid&&
             !ordinary_reference_present_now))begin
            pending_frame_valid<=1;
            pending_frame_bank<=completed_frame_bank;
            pending_frame_released<=sequence_end||
                                    ordinary_terminal_drain_pending||
                                    terminal_boundary_pending||
                                    early_reference_release||
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
            pending_frame_released<=non_b_picture_start||
                                    deferred_reference_payload||early_reference_release||sequence_end||
                                    terminal_boundary_pending;
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
            pending_frame_released<=non_b_picture_start||
                                    deferred_reference_payload||early_reference_release||sequence_end||
                                    terminal_boundary_pending;
            queued_overlap_frame_pending<=1;
            queued_overlap_decode_open<=0;
        end

        if(pending_frame_valid&&(non_b_picture_start||sequence_end||
                                ordinary_terminal_drain_pending))
            pending_frame_released<=1;

        // The raw sequence-end event is only one cycle wide.  Native all-I
        // ownership may promote a secondary identity on that same edge, so
        // retain terminal permission until the complete ordinary queue drains.
        if(sequence_end&&ordinary_secondary_mode_safe)
            ordinary_terminal_drain_pending<=1;
        else if(ordinary_terminal_drain_pending&&
                !pending_frame_valid&&!ordinary_secondary_valid&&
                !ordinary_reference_decode_open&&!frame_waiting)
            ordinary_terminal_drain_pending<=0;

        // A native I/P stream may use the third ordinary frame region while
        // the preceding completed reference waits for its full-frame boundary.
        // The header which releases that predecessor also fixes the new decode
        // class. A header accepted before completion or behind a draining B
        // run may use the same proof once its predecessor occupies this slot.
        if((i_picture_start||p_picture_start||(reference_headers_inflight!=0))&&
           (ordinary_reference_overlap_safe||ordinary_drain_overlap_safe)&&
           !ordinary_reference_decode_open)begin
            ordinary_reference_decode_open<=1;
            ordinary_reference_decode_bank<=active_frame_bank;
            if(ordinary_drain_overlap_safe)ordinary_drain_overlap<=1;
        end

        // When all three ordinary banks are owned, admit exactly the next I/P
        // classification boundary but hold its payload.  That header releases
        // the completed secondary frame; decode resumes only after the primary
        // pending frame presents and frees its old display bank.
        if(ordinary_secondary_release_now)begin
            ordinary_secondary_released<=1;
            if(ordinary_secondary_resume_now)
                ordinary_resume_pending<=1;
        end

        // Ownership must remain fixed for the complete overlapped decode.  A
        // violated invariant is fatal to presentation but never permits the
        // displayed or waiting bank to be overwritten silently.
        if(ordinary_reference_decode_open&&!frame_waiting&&
           ((active_frame_bank!=ordinary_reference_decode_bank)||
            (!display_scratch&&(active_frame_bank==display_frame_bank))||
            (ordinary_drain_overlap&&reorder_active&&
             (!ordinary_drain_mode_safe||(active_frame_bank==future_frame_bank)))))begin
            ordinary_reference_decode_open<=0;
            presentation_error<=1;
        end

        if(frame_waiting&&ordinary_reference_decode_open)begin
            ordinary_reference_decode_open<=0;
            if(completed_frame_bank!=ordinary_reference_decode_bank)
                presentation_error<=1;
            else if(pending_frame_valid&&!ordinary_reference_present_now)begin
                if(ordinary_secondary_valid||
                   (completed_frame_bank==pending_frame_bank)||
                   (!display_scratch&&(completed_frame_bank==display_frame_bank))||
                   (ordinary_drain_overlap&&reorder_active&&
                    (completed_frame_bank==future_frame_bank)))
                    presentation_error<=1;
                else begin
                    ordinary_secondary_valid<=1;
                    ordinary_secondary_bank<=completed_frame_bank;
                    ordinary_secondary_released<=sequence_end||
                                                   ordinary_terminal_drain_pending||
                                                   early_reference_release||non_b_picture_start;
                    ordinary_resume_pending<=0;
                end
            end
        end

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

        if(deferred_queued_b_start&&!admitted_b_picture_start&&
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

        if(admitted_b_picture_start)begin
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
                if(ordinary_secondary_valid)begin
                    // Decode B into scratch now, while the older ordinary
                    // picture still owns first presentation priority.
                    future_frame_bank<=ordinary_secondary_bank;
                    future_reference_pending<=0;
                    ordinary_reference_before_b<=1;
                    pending_frame_valid<=1;
                    pending_frame_released<=1;
                    ordinary_secondary_valid<=0;
                    ordinary_secondary_released<=0;
                    ordinary_resume_pending<=0;
                    last_bound_reference_valid<=1;
                    last_bound_reference_bank<=ordinary_secondary_bank;
                    last_bound_reference_count<=reference_promotion_count;
                end else if(frame_waiting)begin
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
                // A promotion since the last B run may be an ordinary P
                // already on screen. It cannot be this B's future reference.
                // With no retained publication, only a distinct physical
                // reference can be bound; otherwise await its completion.
                end else if(!display_scratch&&
                            (display_frame_bank!=reference_frame_bank))begin
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
            native_fields_elapsed<=0;
            display_scratch<=scheduled_frame_scratch;
            if(scheduled_frame_scratch)display_scratch_bank<=scheduled_scratch_bank;
            else display_frame_bank<=scheduled_frame_bank;
            framebuffer_swap_reset_count<=4;
            if(ordinary_before_b_waiting)begin
                pending_frame_valid<=0;
                pending_frame_released<=0;
                ordinary_reference_before_b<=0;
            end else if(scratch_waiting)begin
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
                // A just-completed native overlap can coincide exactly with
                // presentation of its predecessor.  Preserve the completed
                // bank as the new (unreleased) candidate rather than letting
                // the predecessor's retirement clear it on this same edge.
                if(ordinary_secondary_valid)begin
                    pending_frame_valid<=1;
                    pending_frame_bank<=ordinary_secondary_bank;
                    pending_frame_released<=ordinary_secondary_released||
                                            ordinary_secondary_release_now||
                                            ordinary_terminal_drain_pending;
                    ordinary_secondary_valid<=0;
                    ordinary_secondary_released<=0;
                    if((ordinary_resume_pending||
                        ordinary_secondary_resume_now)&&
                       (active_frame_bank!=scheduled_frame_bank)&&
                       (active_frame_bank!=ordinary_secondary_bank))begin
                        ordinary_reference_decode_open<=1;
                        ordinary_reference_decode_bank<=active_frame_bank;
                    end else if(ordinary_resume_pending||
                                ordinary_secondary_resume_now)
                        presentation_error<=1;
                    ordinary_resume_pending<=0;
                    terminal_boundary_pending<=0;
                end else if(frame_waiting&&ordinary_reference_decode_open)begin
                    pending_frame_valid<=1;
                    pending_frame_bank<=completed_frame_bank;
                    pending_frame_released<=sequence_end||
                                            ordinary_terminal_drain_pending||
                                            terminal_boundary_pending||
                                            early_reference_release||
                                            non_b_picture_start;
                    terminal_boundary_pending<=0;
                end else begin
                    pending_frame_valid<=0;
                    pending_frame_released<=0;
                end
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

        if((reorder_active||deferred_ordinary_b_start)&&b_decode_error)begin
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

        // The secondary ordinary slot still requires the native timing and
        // ordinary display ownership used to admit its transaction.
        if((ordinary_secondary_valid||ordinary_resume_pending)&&
           (!native_ordinary_overlap_enable||(frame_rate_code!=4'h4)||
            (display_scratch&&!(ordinary_drain_overlap&&ordinary_drain_mode_safe))))
            presentation_error<=1;
        if(ordinary_secondary_valid&&frame_waiting&&
           !ordinary_reference_decode_open)
            presentation_error<=1;

        if(presentation_error)begin
            deferred_ordinary_b_start<=0;
            ordinary_reference_before_b<=0;
            ordinary_drain_overlap<=0;
            deferred_queued_b_start<=0;
            ordinary_reference_decode_open<=0;
            ordinary_secondary_valid<=0;
            ordinary_secondary_released<=0;
            ordinary_resume_pending<=0;
            ordinary_terminal_drain_pending<=0;
        end
    end
end
endmodule
