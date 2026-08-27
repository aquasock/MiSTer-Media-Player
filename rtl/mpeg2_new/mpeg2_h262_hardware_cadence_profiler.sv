//============================================================================
// MiSTer Media Player - development hardware cadence profiler
//
// Entry 312: retain schema-v3 aggregates and capture the scheduler/hold state
// when each ranked gap first exceeds the legal cadence window.
// All inputs are observational; no output feeds decoder or presentation logic.
//============================================================================
`timescale 1ns/1ps
module mpeg2_h262_hardware_cadence_profiler #(
    parameter [23:0] TERMINAL_SNAPSHOT_DELAY = 24'd15000000,
    parameter [26:0] NO_PROGRESS_SNAPSHOT_DELAY = 27'd60000000,
    parameter [31:0] OUTLIER_GAP_CYCLES = 32'd3000000,
    // Entry 468: rank gaps and admission conflicts only in the requested
    // late-session window. A zero default preserves unit-level reuse.
    parameter [13:0] PROFILE_START_STC_SECONDS = 14'd0
)(
    input wire clk_mpeg2,input wire reset_mpeg2,
    input wire clk_video,input wire reset_video,input wire pixel_ce,
    input wire native_active,
    input wire framebuffer_generation_reset,
    input wire framebuffer_picture_present,
    input wire framebuffer_prefill_deadline_missed,
    // Entry 516: per-field readout evidence.  The phase level and the two
    // displayed-line toggles are synchronized video-domain signals; the two
    // DDR service toggles are generated on this clock.
    input wire framebuffer_sequence_phase_error,
    input wire [2:0] framebuffer_first_field_region,
    input wire [2:0] framebuffer_second_field_region,
    input wire framebuffer_luma_fetch_valid,
    input wire framebuffer_luma_fetch_first_field,
    input wire [8:0] framebuffer_luma_fetch_row,
    input wire [2:0] framebuffer_display_region,
    input wire framebuffer_cache_write_valid,
    input wire framebuffer_cache_write_first_field,
    input wire [7:0] framebuffer_cache_write_addr,
    input wire framebuffer_luma_return_valid,
    input wire framebuffer_luma_return_first_field,
    input wire [7:0] framebuffer_luma_return_byte,
    input wire framebuffer_luma_fingerprint_valid,
    input wire framebuffer_luma_fingerprint_first_field,
    input wire [31:0] framebuffer_luma_fingerprint_raw,
    input wire [31:0] framebuffer_luma_fingerprint_display,
    input wire framebuffer_luma_fingerprint_mismatch,
    input wire framebuffer_luma_provenance_valid,
    input wire framebuffer_luma_provenance_first_field,
    input wire framebuffer_luma_provenance_tag_mismatch,
    input wire framebuffer_luma_provenance_content_mismatch,
    input wire framebuffer_luma_provenance_expected_bank,
    input wire framebuffer_luma_provenance_tagged_bank,
    input wire [10:0] framebuffer_luma_provenance_expected_row,
    input wire [10:0] framebuffer_luma_provenance_tagged_row,
    input wire [7:0] framebuffer_luma_provenance_expected_generation,
    input wire [7:0] framebuffer_luma_provenance_tagged_generation,
    input wire [31:0] framebuffer_luma_provenance_raw_fingerprint,
    input wire [31:0] framebuffer_luma_provenance_display_fingerprint,
    input wire framebuffer_luma_write_read_valid,
    input wire framebuffer_luma_write_read_first_field,
    input wire framebuffer_luma_write_read_expected_valid,
    input wire [2:0] framebuffer_luma_write_read_region,
    input wire [31:0] framebuffer_luma_write_read_expected_fingerprint,
    input wire [31:0] framebuffer_luma_write_read_raw_fingerprint,
    input wire framebuffer_luma_write_read_mismatch,
    input wire framebuffer_first_field_fetch,
    input wire framebuffer_second_field_fetch,
    input wire fifo_pending,input wire decoder_ready,
    input wire presentation_hold,input wire destination_hold,
    input wire scratch_available,input wire promotion_active,
    input wire frame_waiting,input wire [1:0] completed_frame_bank,
    input wire presentation_complete,input wire presentation_error,
    input wire [31:0] scheduler_debug_state,
    input wire swap_window_pulse,input wire candidate_presentable,
    input wire timestamp_candidate_active,input wire timestamp_candidate_due,
    input wire cadence_slot,
    input wire decoder_byte_accepted,
    input wire [2:0] picture_coding_type,
    input wire [9:0] temporal_reference,
    input wire [3:0] frame_rate_code,input wire [7:0] picture_count,
    input wire reference_picture_complete,input wire b_picture_complete,
    input wire prediction_read,input wire prediction_busy,
    input wire prediction_data_ready,input wire writer_write,
    input wire writer_busy,input wire [1:0] display_frame_bank,
    input wire display_scratch,input wire display_scratch_bank,
    input wire sequence_end_seen,input wire session_quiet,
    input wire terminal_defer,
    // Entry 365: presentation-clock bring-up observables.  stc_seconds is
    // counted in this domain from a single-bit 1 Hz pulse crossed from the
    // 24.576 MHz audio domain, so no multi-bit counter crosses domains.
    input wire [13:0] stc_seconds,
    // Entry 369: in-band record telemetry.  The low PTS bits are carried so
    // an injected timestamp can be matched exactly rather than merely seen
    // to be non-zero.
    // Entry 372: the reported timestamp moves one stage downstream, from the
    // most recently extracted record to the frame actually being displayed.
    // Association implies extraction, so the extractor's own count is no
    // longer carried; entry 371 records its validation.
    input wire [7:0] associated_count,input wire [32:0] display_pts,
    input wire [13:0] pcm_sample_count,input wire [6:0] pcm_fifo_peak,
    input wire top_field_first,input wire repeat_first_field,
    input wire [15:0] error_flags,input wire [11:0] h_pos,
    input wire [11:0] v_pos,input wire [7:0] base_r,
    input wire [7:0] base_g,input wire [7:0] base_b,input wire base_de,
    output reg [7:0] video_r,output reg [7:0] video_g,
    output reg [7:0] video_b,output wire snapshot_ready
);

localparam integer SNAPSHOT_WORDS=64;
localparam integer SNAPSHOT_BITS=SNAPSHOT_WORDS*32;
localparam [23:0] TERMINAL_SNAPSHOT_LIMIT=
    TERMINAL_SNAPSHOT_DELAY-24'd1;
localparam [26:0] NO_PROGRESS_SNAPSHOT_LIMIT=
    NO_PROGRESS_SNAPSHOT_DELAY-27'd1;
localparam [31:0] SNAPSHOT_MAGIC=32'h4d4d5031;
localparam [31:0] SNAPSHOT_FORMAT={8'd18,8'd64,16'd60000};
// Entry 511: keep all 41 rows visible without changing their encoding. The
// mode observation is already in clk_video and affects overlay placement only.
localparam [11:0] OVERLAY_X=12'd8;
// Entry 516: schema 11 appends two packed words, so both origins move eight
// rows up to keep the final row flush with the diagnostic and native rasters.
localparam [11:0] OVERLAY_DIAG_Y=12'd344;
localparam [11:0] OVERLAY_NATIVE_Y=12'd224;
localparam [11:0] OVERLAY_WIDTH=12'd172,OVERLAY_HEIGHT=12'd256;

reg session_active;
reg fifo_pending_q,decoder_ready_q,presentation_hold_q,destination_hold_q;
reg scratch_available_q,promotion_active_q,frame_waiting_q;
reg [1:0] completed_frame_bank_q;
reg presentation_complete_q,presentation_error_q;
reg [31:0] scheduler_debug_state_q;
reg swap_window_pulse_q,candidate_presentable_q;
reg timestamp_candidate_active_q,timestamp_candidate_due_q,cadence_slot_q;
reg decoder_byte_accepted_q;
reg [2:0] picture_coding_type_q;
reg [9:0] temporal_reference_q;
reg [3:0] frame_rate_code_q;
reg [7:0] picture_count_q;
reg reference_picture_complete_q,b_picture_complete_q;
reg prediction_read_q,prediction_busy_q,prediction_data_ready_q;
reg writer_write_q,writer_busy_q;
reg [1:0] display_frame_bank_q;
reg display_scratch_q,display_scratch_bank_q;
reg sequence_end_seen_q,session_quiet_q,terminal_defer_q;
reg [15:0] error_flags_q;
reg [13:0] stc_seconds_q;
reg [7:0] associated_count_q;
reg [32:0] display_pts_q;
reg [13:0] pcm_sample_count_q;
reg [6:0] pcm_fifo_peak_q;
reg top_field_first_q,repeat_first_field_q;

reg [31:0] session_cycles,accepted_bytes;
reg [31:0] first_present_cycle,last_present_cycle;
reg first_present_valid;
reg [31:0] decoder_stall_cycles,presentation_stall_cycles;
reg [31:0] destination_stall_cycles;
reg [31:0] presentation_hold_total_cycles,destination_hold_total_cycles;
reg [31:0] hold_overlap_cycles,hold_scratch_available_cycles;
reg [31:0] hold_promotion_pending_cycles;
reg [31:0] i_stall_cycles,p_stall_cycles,b_stall_cycles;
reg [31:0] prediction_requests,prediction_request_wait_cycles;
reg [31:0] prediction_response_cycles;
reg prediction_outstanding;
reg [31:0] writer_wait_cycles;
reg framebuffer_generation_reset_d;
reg framebuffer_picture_present_d;
reg framebuffer_prefill_deadline_missed_d;
reg framebuffer_sequence_phase_error_d;
reg framebuffer_first_field_fetch_d;
reg framebuffer_second_field_fetch_d;
reg [7:0] gen_first_field_fetches;
reg [7:0] gen_second_field_fetches;
reg [7:0] last_first_field_fetches;
reg [7:0] last_second_field_fetches;
// Entry 548: address-sensitive fetch evidence.  The row XOR distinguishes a
// healthy 240-row sweep from repeated or wrong rows, which every existing
// count cannot.  The region-changed flags close the second blind spot: the
// existing region latch keeps only each parity's last sample per generation.
// Entry 549: per-parity luma cache write evidence.  A healthy generation
// writes 242*90=21780 first-field words and 240*90=21600 second-field words,
// with 16-bit address sums of 48766 and 32656 respectively.
reg [15:0] gen_first_cache_writes;
reg [15:0] gen_second_cache_writes;
reg [15:0] gen_first_cache_addr_sum;
reg [15:0] gen_second_cache_addr_sum;
reg [15:0] last_first_cache_writes;
reg [15:0] last_second_cache_writes;
reg [15:0] last_first_cache_addr_sum;
reg [15:0] last_second_cache_addr_sum;
reg [8:0] gen_first_row_xor;
reg [8:0] gen_second_row_xor;
reg [8:0] last_first_row_xor;
reg [8:0] last_second_row_xor;
reg [2:0] gen_first_region_seed;
reg [2:0] gen_second_region_seed;
reg gen_first_region_seen;
reg gen_second_region_seen;
reg gen_first_region_changed;
reg gen_second_region_changed;
reg last_first_region_changed;
reg last_second_region_changed;
reg [2:0] last_first_field_region;
reg [2:0] last_second_field_region;
reg [7:0] field_region_mismatch_count;
// Entry 520: session-wide per-parity luma return content.  These are cleared
// only with the profiler itself, never per generation, so a parity that never
// receives varying data over the whole session reports varied low regardless
// of which generation happens to precede terminal quiet.
reg [7:0] last_first_field_signature;
reg [7:0] last_second_field_signature;
reg [7:0] first_field_reference;
reg [7:0] second_field_reference;
reg first_field_seen;
reg second_field_seen;
reg last_first_field_varied;
reg last_second_field_varied;
reg [31:0] last_first_field_raw_fingerprint;
reg [31:0] last_first_field_display_fingerprint;
reg [31:0] last_second_field_raw_fingerprint;
reg [31:0] last_second_field_display_fingerprint;
reg [7:0] first_field_fingerprint_count;
reg [7:0] second_field_fingerprint_count;
reg [7:0] first_field_fingerprint_mismatch_count;
reg [7:0] second_field_fingerprint_mismatch_count;
// Entry 531: the single current layout reuses words 42 through 46 for the
// stronger accepted-write versus raw-DDR-return boundary.  If a mismatch is
// ever seen, the pair freezes on the first mismatch; otherwise it follows the
// most recent completed field and proves equality at terminal quiet.
reg [31:0] first_field_write_read_expected;
reg [31:0] first_field_write_read_raw;
reg [31:0] second_field_write_read_expected;
reg [31:0] second_field_write_read_raw;
reg [7:0] first_field_write_read_count;
reg [7:0] second_field_write_read_count;
reg [7:0] first_field_write_read_mismatch_count;
reg [7:0] second_field_write_read_mismatch_count;
reg first_field_write_read_expected_valid;
reg second_field_write_read_expected_valid;
reg [2:0] first_field_write_read_region;
reg [2:0] second_field_write_read_region;
reg [7:0] first_field_tag_mismatch_count;
reg [7:0] second_field_tag_mismatch_count;
reg [7:0] first_field_content_mismatch_count;
reg [7:0] second_field_content_mismatch_count;
reg first_field_tag_mismatch_seen;
reg second_field_tag_mismatch_seen;
reg first_field_content_mismatch_seen;
reg second_field_content_mismatch_seen;
reg [31:0] first_field_tag_mismatch_meta;
reg [31:0] second_field_tag_mismatch_meta;
reg [15:0] first_field_tag_mismatch_generations;
reg [15:0] second_field_tag_mismatch_generations;
reg [31:0] first_field_content_mismatch_meta;
reg [31:0] second_field_content_mismatch_meta;
reg [15:0] first_field_content_mismatch_generations;
reg [15:0] second_field_content_mismatch_generations;
reg [31:0] first_field_content_mismatch_raw;
reg [31:0] first_field_content_mismatch_display;
reg [31:0] second_field_content_mismatch_raw;
reg [31:0] second_field_content_mismatch_display;
reg [7:0] sequence_phase_error_count;
reg framebuffer_publication_pending;
reg [31:0] framebuffer_publication_latency;
reg [31:0] framebuffer_max_publication_latency;
reg [15:0] framebuffer_reset_count;
reg [15:0] framebuffer_publication_count;
reg [15:0] framebuffer_unpublished_reset_count;
reg [15:0] framebuffer_prefill_miss_count;
reg [7:0] reference_picture_count,b_picture_count;
reg [7:0] display_picture_count,display_swap_count;
reg b_picture_complete_d;
reg [1:0] display_frame_bank_d;
reg display_scratch_d,display_scratch_bank_d;

reg [31:0] largest_gap_0,largest_gap_1,largest_gap_2;
reg [31:0] largest_gap_meta_0,largest_gap_meta_1,largest_gap_meta_2;
reg [31:0] largest_gap_state_0,largest_gap_state_1,largest_gap_state_2;
reg [31:0] current_gap_meta,current_gap_state;
reg current_gap_context_valid;
reg [15:0] gap_outlier_count;
reg [15:0] timestamp_delay_conflict_count;
reg [15:0] timestamp_advance_conflict_count;
reg [31:0] profile_last_present_cycle;
reg profile_first_present_valid;
reg [9:0] quiet_count;
reg [23:0] terminal_wait_count;
reg [26:0] no_progress_wait_count;
reg [1:0] snapshot_reason;
reg [SNAPSHOT_BITS-1:0] snapshot_mpeg2;
reg snapshot_ready_mpeg2;

wire b_picture_complete_edge=b_picture_complete_q&&!b_picture_complete_d;
wire display_swap_now=first_present_valid&&
    ((display_frame_bank_q!=display_frame_bank_d)||
     (display_scratch_q!=display_scratch_d)||
     (display_scratch_q&&(display_scratch_bank_q!=display_scratch_bank_d)));
wire prediction_request_accepted=prediction_read_q&&!prediction_busy_q;
wire framebuffer_generation_reset_edge=
    framebuffer_generation_reset&&!framebuffer_generation_reset_d;
wire framebuffer_picture_present_edge=
    framebuffer_picture_present&&!framebuffer_picture_present_d;
wire framebuffer_prefill_deadline_missed_edge=
    framebuffer_prefill_deadline_missed&&
    !framebuffer_prefill_deadline_missed_d;
wire framebuffer_sequence_phase_error_edge=
    framebuffer_sequence_phase_error&&!framebuffer_sequence_phase_error_d;
wire framebuffer_first_field_fetch_edge=
    framebuffer_first_field_fetch!=framebuffer_first_field_fetch_d;
wire framebuffer_second_field_fetch_edge=
    framebuffer_second_field_fetch!=framebuffer_second_field_fetch_d;
wire session_progress=decoder_byte_accepted_q||reference_picture_complete_q||
    b_picture_complete_edge||display_swap_now||prediction_request_accepted||
    prediction_data_ready_q||writer_write_q;
wire [31:0] display_gap_now=session_cycles-last_present_cycle;
wire [31:0] profile_display_gap_now=
    session_cycles-profile_last_present_cycle;
wire profile_window_active=(stc_seconds_q>=PROFILE_START_STC_SECONDS);
wire cadence_rate_supported=(frame_rate_code_q==4'h1)||
                            (frame_rate_code_q==4'h2)||
                            (frame_rate_code_q==4'h3)||
                            (frame_rate_code_q==4'h4)||
                            (frame_rate_code_q==4'h5);
wire [31:0] display_gap_meta_now={
    display_picture_count+1'b1,
    presentation_hold_q,destination_hold_q,fifo_pending_q,decoder_ready_q,
    scratch_available_q,promotion_active_q,frame_waiting_q,
    presentation_complete_q,presentation_error_q,
    sequence_end_seen_q,session_quiet_q,
    completed_frame_bank_q,display_frame_bank_q,
    display_scratch_q,display_scratch_bank_q,
    timestamp_candidate_active_q,timestamp_candidate_due_q,cadence_slot_q,
    candidate_presentable_q,swap_window_pulse_q,2'd0
};
wire [31:0] completed_gap_meta=current_gap_context_valid?
    current_gap_meta:display_gap_meta_now;
wire [31:0] completed_gap_state=current_gap_context_valid?
    current_gap_state:scheduler_debug_state_q;

wire [31:0] snapshot_word_00=SNAPSHOT_MAGIC;
wire [31:0] snapshot_word_01=SNAPSHOT_FORMAT;
wire [31:0] snapshot_word_02=accepted_bytes;
wire [31:0] snapshot_word_03=session_cycles;
wire [31:0] snapshot_word_04=first_present_cycle;
wire [31:0] snapshot_word_05=last_present_cycle;
wire [31:0] snapshot_word_06=last_present_cycle-first_present_cycle;
wire [31:0] snapshot_word_07=decoder_stall_cycles;
wire [31:0] snapshot_word_08=presentation_stall_cycles;
wire [31:0] snapshot_word_09=destination_stall_cycles;
wire [31:0] snapshot_word_10=i_stall_cycles;
wire [31:0] snapshot_word_11=p_stall_cycles;
wire [31:0] snapshot_word_12=b_stall_cycles;
wire [31:0] snapshot_word_13=prediction_requests;
wire [31:0] snapshot_word_14=prediction_request_wait_cycles;
wire [31:0] snapshot_word_15=prediction_response_cycles;
wire [31:0] snapshot_word_16=writer_wait_cycles;
wire [31:0] snapshot_word_17={reference_picture_count,b_picture_count,
    display_picture_count,display_swap_count};
wire [31:0] snapshot_word_18={frame_rate_code_q,picture_coding_type_q,
    temporal_reference_q,picture_count_q,pcm_fifo_peak_q};
wire [31:0] snapshot_word_19={error_flags_q,stc_seconds_q,
    top_field_first_q,repeat_first_field_q};
wire [31:0] snapshot_word_20=presentation_hold_total_cycles;
wire [31:0] snapshot_word_21=destination_hold_total_cycles;
wire [31:0] snapshot_word_22=hold_overlap_cycles;
wire [31:0] snapshot_word_23=hold_scratch_available_cycles;
wire [31:0] snapshot_word_24={timestamp_delay_conflict_count,
    timestamp_advance_conflict_count};
wire [31:0] snapshot_word_25={snapshot_reason,pcm_sample_count_q,
    gap_outlier_count};
wire [31:0] snapshot_word_26=largest_gap_0;
wire [31:0] snapshot_word_27=largest_gap_meta_0;
wire [31:0] snapshot_word_28=largest_gap_state_0;
wire [31:0] snapshot_word_29=largest_gap_1;
wire [31:0] snapshot_word_30=largest_gap_meta_1;
wire [31:0] snapshot_word_31=largest_gap_state_1;
wire [31:0] snapshot_word_32=largest_gap_2;
wire [31:0] snapshot_word_33=largest_gap_meta_2;
wire [31:0] snapshot_word_34=largest_gap_state_2;
wire [31:0] snapshot_word_35={completed_frame_bank_q,display_frame_bank_q,
    display_scratch_q,display_scratch_bank_q,frame_waiting_q,
    presentation_hold_q,destination_hold_q,session_quiet_q,
    sequence_end_seen_q,presentation_complete_q,presentation_error_q,
    associated_count_q,display_pts_q[10:0]};
wire [31:0] snapshot_word_36=scheduler_debug_state_q;
wire [31:0] snapshot_word_37={framebuffer_reset_count,
    framebuffer_publication_count};
wire [31:0] snapshot_word_38={framebuffer_unpublished_reset_count,
    framebuffer_prefill_miss_count};
wire [31:0] snapshot_word_39=framebuffer_max_publication_latency;
// 8 + 8 + 1 + 1 + 8 + 3 + 3 = 32.  The padding must keep this exact, or the
// whole word shifts right and every field decodes from the wrong bits.
localparam integer SNAPSHOT_WORD_40_BITS=8+8+1+1+8+3+3;
wire [SNAPSHOT_WORD_40_BITS-1:0] snapshot_word_40_payload;
assign snapshot_word_40_payload[31:24]=last_first_field_fetches;
assign snapshot_word_40_payload[23:16]=last_second_field_fetches;
assign snapshot_word_40_payload[15]=last_first_field_varied;
assign snapshot_word_40_payload[14]=last_second_field_varied;
assign snapshot_word_40_payload[13]=1'b1;
assign snapshot_word_40_payload[12]=first_field_write_read_expected_valid;
assign snapshot_word_40_payload[11]=second_field_write_read_expected_valid;
assign snapshot_word_40_payload[10:8]=first_field_write_read_region;
assign snapshot_word_40_payload[7:6]=2'd0;
assign snapshot_word_40_payload[5:3]=last_first_field_region;
assign snapshot_word_40_payload[2:0]=last_second_field_region;
wire [31:0] snapshot_word_40=snapshot_word_40_payload;
// Entry 520: this assertion is independent of the expected snapshot literal.
// A repeated malformed concatenation in the test therefore cannot validate
// the same width defect a second time.
generate
if(SNAPSHOT_WORD_40_BITS!=32)begin:invalid_snapshot_word_40_width
    initial $fatal(1,"snapshot word 40 is %0d bits, expected 32",
                   SNAPSHOT_WORD_40_BITS);
end
endgenerate
wire [31:0] snapshot_word_41={last_first_field_signature,
    last_second_field_signature,field_region_mismatch_count,
    sequence_phase_error_count};
wire [31:0] snapshot_word_42=first_field_write_read_expected;
wire [31:0] snapshot_word_43=first_field_write_read_raw;
wire [31:0] snapshot_word_44=second_field_write_read_expected;
wire [31:0] snapshot_word_45=second_field_write_read_raw;
localparam integer SNAPSHOT_WORD_46_BITS=8+8+8+8;
wire [SNAPSHOT_WORD_46_BITS-1:0] snapshot_word_46_payload;
assign snapshot_word_46_payload[31:24]=first_field_write_read_count;
assign snapshot_word_46_payload[23:16]=second_field_write_read_count;
assign snapshot_word_46_payload[15:8]=
    first_field_write_read_mismatch_count;
assign snapshot_word_46_payload[7:0]=
    second_field_write_read_mismatch_count;
wire [31:0] snapshot_word_46=snapshot_word_46_payload;
wire [31:0] luma_provenance_meta_now={
    framebuffer_luma_provenance_expected_row,
    framebuffer_luma_provenance_tagged_row,
    framebuffer_luma_provenance_expected_bank,
    framebuffer_luma_provenance_tagged_bank,8'd0};
wire [15:0] luma_provenance_generations_now={
    framebuffer_luma_provenance_expected_generation,
    framebuffer_luma_provenance_tagged_generation};
generate
if(SNAPSHOT_WORD_46_BITS!=32)begin:invalid_snapshot_word_46_width
    initial $fatal(1,"snapshot word 46 is %0d bits, expected 32",
                   SNAPSHOT_WORD_46_BITS);
end
endgenerate
wire [31:0] snapshot_word_47={first_field_tag_mismatch_count,
    second_field_tag_mismatch_count,first_field_content_mismatch_count,
    second_field_content_mismatch_count};
wire [31:0] snapshot_word_48=first_field_tag_mismatch_meta;
wire [31:0] snapshot_word_49={first_field_tag_mismatch_generations,16'd0};
wire [31:0] snapshot_word_50=second_field_tag_mismatch_meta;
wire [31:0] snapshot_word_51={second_field_tag_mismatch_generations,16'd0};
wire [31:0] snapshot_word_52=first_field_content_mismatch_meta;
wire [31:0] snapshot_word_53={first_field_content_mismatch_generations,16'd0};
wire [31:0] snapshot_word_54=first_field_content_mismatch_raw;
wire [31:0] snapshot_word_55=first_field_content_mismatch_display;
wire [31:0] snapshot_word_56=second_field_content_mismatch_meta;
wire [31:0] snapshot_word_57={second_field_content_mismatch_generations,16'd0};
wire [31:0] snapshot_word_58=second_field_content_mismatch_raw;
wire [31:0] snapshot_word_59=second_field_content_mismatch_display;
// 9 + 9 + 1 + 1 + 12 = 32.
wire [31:0] snapshot_word_60={last_first_row_xor,last_second_row_xor,
    last_first_region_changed,last_second_region_changed,12'd0};
wire [31:0] snapshot_word_61={last_first_cache_writes,
    last_second_cache_writes};
wire [31:0] snapshot_word_62={last_first_cache_addr_sum,
    last_second_cache_addr_sum};
wire [31:0] snapshot_word_63=snapshot_word_00^snapshot_word_01^
    snapshot_word_02^snapshot_word_03^snapshot_word_04^snapshot_word_05^
    snapshot_word_06^snapshot_word_07^snapshot_word_08^snapshot_word_09^
    snapshot_word_10^snapshot_word_11^snapshot_word_12^snapshot_word_13^
    snapshot_word_14^snapshot_word_15^snapshot_word_16^snapshot_word_17^
    snapshot_word_18^snapshot_word_19^snapshot_word_20^snapshot_word_21^
    snapshot_word_22^snapshot_word_23^snapshot_word_24^snapshot_word_25^
    snapshot_word_26^snapshot_word_27^snapshot_word_28^snapshot_word_29^
    snapshot_word_30^snapshot_word_31^snapshot_word_32^snapshot_word_33^
    snapshot_word_34^snapshot_word_35^snapshot_word_36^snapshot_word_37^
    snapshot_word_38^snapshot_word_39^snapshot_word_40^snapshot_word_41^
    snapshot_word_42^snapshot_word_43^snapshot_word_44^snapshot_word_45^
    snapshot_word_46^snapshot_word_47^snapshot_word_48^snapshot_word_49^
    snapshot_word_50^snapshot_word_51^snapshot_word_52^snapshot_word_53^
    snapshot_word_54^snapshot_word_55^snapshot_word_56^snapshot_word_57^
    snapshot_word_58^snapshot_word_59^snapshot_word_60^
    snapshot_word_61^snapshot_word_62;

task capture_snapshot;
begin
    snapshot_mpeg2<={snapshot_word_63,snapshot_word_62,snapshot_word_61,
        snapshot_word_60,snapshot_word_59,
        snapshot_word_58,
        snapshot_word_57,snapshot_word_56,snapshot_word_55,snapshot_word_54,
        snapshot_word_53,snapshot_word_52,snapshot_word_51,snapshot_word_50,
        snapshot_word_49,snapshot_word_48,snapshot_word_47,
        snapshot_word_46,snapshot_word_45,
        snapshot_word_44,snapshot_word_43,snapshot_word_42,snapshot_word_41,
        snapshot_word_40,snapshot_word_39,snapshot_word_38,
        snapshot_word_37,snapshot_word_36,snapshot_word_35,
        snapshot_word_34,snapshot_word_33,snapshot_word_32,
        snapshot_word_31,snapshot_word_30,snapshot_word_29,snapshot_word_28,
        snapshot_word_27,snapshot_word_26,snapshot_word_25,snapshot_word_24,
        snapshot_word_23,snapshot_word_22,snapshot_word_21,snapshot_word_20,
        snapshot_word_19,snapshot_word_18,snapshot_word_17,snapshot_word_16,
        snapshot_word_15,snapshot_word_14,snapshot_word_13,snapshot_word_12,
        snapshot_word_11,snapshot_word_10,snapshot_word_09,snapshot_word_08,
        snapshot_word_07,snapshot_word_06,snapshot_word_05,snapshot_word_04,
        snapshot_word_03,snapshot_word_02,snapshot_word_01,snapshot_word_00};
    snapshot_ready_mpeg2<=1'b1;
end
endtask

always @(posedge clk_mpeg2) begin
    if(reset_mpeg2)begin
        session_active<=0;fifo_pending_q<=0;decoder_ready_q<=0;
        presentation_hold_q<=0;destination_hold_q<=0;
        scratch_available_q<=0;promotion_active_q<=0;frame_waiting_q<=0;
        completed_frame_bank_q<=0;presentation_complete_q<=0;
        presentation_error_q<=0;scheduler_debug_state_q<=0;
        swap_window_pulse_q<=0;candidate_presentable_q<=0;
        timestamp_candidate_active_q<=0;timestamp_candidate_due_q<=0;
        cadence_slot_q<=0;
        decoder_byte_accepted_q<=0;picture_coding_type_q<=0;
        temporal_reference_q<=0;frame_rate_code_q<=0;picture_count_q<=0;
        reference_picture_complete_q<=0;b_picture_complete_q<=0;
        prediction_read_q<=0;prediction_busy_q<=0;
        prediction_data_ready_q<=0;writer_write_q<=0;writer_busy_q<=0;
        display_frame_bank_q<=0;display_scratch_q<=0;
        display_scratch_bank_q<=0;sequence_end_seen_q<=0;
        session_quiet_q<=0;terminal_defer_q<=0;error_flags_q<=0;
        stc_seconds_q<=0;top_field_first_q<=0;repeat_first_field_q<=0;
        associated_count_q<=0;display_pts_q<=0;
        pcm_sample_count_q<=0;pcm_fifo_peak_q<=0;
        session_cycles<=0;accepted_bytes<=0;first_present_cycle<=0;
        last_present_cycle<=0;first_present_valid<=0;
        decoder_stall_cycles<=0;presentation_stall_cycles<=0;
        destination_stall_cycles<=0;presentation_hold_total_cycles<=0;
        destination_hold_total_cycles<=0;hold_overlap_cycles<=0;
        hold_scratch_available_cycles<=0;hold_promotion_pending_cycles<=0;
        i_stall_cycles<=0;p_stall_cycles<=0;b_stall_cycles<=0;
        prediction_requests<=0;prediction_request_wait_cycles<=0;
        prediction_response_cycles<=0;prediction_outstanding<=0;
        writer_wait_cycles<=0;reference_picture_count<=0;b_picture_count<=0;
        framebuffer_generation_reset_d<=0;
        framebuffer_picture_present_d<=0;
        framebuffer_prefill_deadline_missed_d<=0;
        framebuffer_publication_pending<=0;
        framebuffer_publication_latency<=0;
        framebuffer_max_publication_latency<=0;
        framebuffer_reset_count<=0;framebuffer_publication_count<=0;
        framebuffer_unpublished_reset_count<=0;
        framebuffer_prefill_miss_count<=0;
        framebuffer_sequence_phase_error_d<=0;
        framebuffer_first_field_fetch_d<=0;
        framebuffer_second_field_fetch_d<=0;
        gen_first_field_fetches<=0;gen_second_field_fetches<=0;
        last_first_field_fetches<=0;last_second_field_fetches<=0;
        last_first_field_region<=0;last_second_field_region<=0;
        gen_first_row_xor<=0;gen_second_row_xor<=0;
        last_first_row_xor<=0;last_second_row_xor<=0;
        gen_first_cache_writes<=0;gen_second_cache_writes<=0;
        gen_first_cache_addr_sum<=0;gen_second_cache_addr_sum<=0;
        last_first_cache_writes<=0;last_second_cache_writes<=0;
        last_first_cache_addr_sum<=0;last_second_cache_addr_sum<=0;
        gen_first_region_seed<=0;gen_second_region_seed<=0;
        gen_first_region_seen<=0;gen_second_region_seen<=0;
        gen_first_region_changed<=0;gen_second_region_changed<=0;
        last_first_region_changed<=0;last_second_region_changed<=0;
        field_region_mismatch_count<=0;sequence_phase_error_count<=0;
        last_first_field_signature<=0;last_second_field_signature<=0;
        first_field_reference<=0;second_field_reference<=0;
        first_field_seen<=0;second_field_seen<=0;
        last_first_field_varied<=0;last_second_field_varied<=0;
        last_first_field_raw_fingerprint<=0;
        last_first_field_display_fingerprint<=0;
        last_second_field_raw_fingerprint<=0;
        last_second_field_display_fingerprint<=0;
        first_field_fingerprint_count<=0;
        second_field_fingerprint_count<=0;
        first_field_fingerprint_mismatch_count<=0;
        second_field_fingerprint_mismatch_count<=0;
        first_field_write_read_expected<=0;
        first_field_write_read_raw<=0;
        second_field_write_read_expected<=0;
        second_field_write_read_raw<=0;
        first_field_write_read_count<=0;
        second_field_write_read_count<=0;
        first_field_write_read_mismatch_count<=0;
        second_field_write_read_mismatch_count<=0;
        first_field_write_read_expected_valid<=0;
        second_field_write_read_expected_valid<=0;
        first_field_write_read_region<=0;
        second_field_write_read_region<=0;
        first_field_tag_mismatch_count<=0;
        second_field_tag_mismatch_count<=0;
        first_field_content_mismatch_count<=0;
        second_field_content_mismatch_count<=0;
        first_field_tag_mismatch_seen<=0;
        second_field_tag_mismatch_seen<=0;
        first_field_content_mismatch_seen<=0;
        second_field_content_mismatch_seen<=0;
        first_field_tag_mismatch_meta<=0;
        second_field_tag_mismatch_meta<=0;
        first_field_tag_mismatch_generations<=0;
        second_field_tag_mismatch_generations<=0;
        first_field_content_mismatch_meta<=0;
        second_field_content_mismatch_meta<=0;
        first_field_content_mismatch_generations<=0;
        second_field_content_mismatch_generations<=0;
        first_field_content_mismatch_raw<=0;
        first_field_content_mismatch_display<=0;
        second_field_content_mismatch_raw<=0;
        second_field_content_mismatch_display<=0;
        display_picture_count<=0;display_swap_count<=0;
        b_picture_complete_d<=0;display_frame_bank_d<=0;
        display_scratch_d<=0;display_scratch_bank_d<=0;
        largest_gap_0<=0;largest_gap_1<=0;largest_gap_2<=0;
        largest_gap_meta_0<=0;largest_gap_meta_1<=0;largest_gap_meta_2<=0;
        largest_gap_state_0<=0;largest_gap_state_1<=0;largest_gap_state_2<=0;
        current_gap_meta<=0;current_gap_state<=0;current_gap_context_valid<=0;
        gap_outlier_count<=0;timestamp_delay_conflict_count<=0;
        timestamp_advance_conflict_count<=0;
        profile_last_present_cycle<=0;profile_first_present_valid<=0;
        quiet_count<=0;terminal_wait_count<=0;
        no_progress_wait_count<=0;
        snapshot_reason<=0;snapshot_mpeg2<=0;snapshot_ready_mpeg2<=0;
    end else begin
        fifo_pending_q<=fifo_pending;decoder_ready_q<=decoder_ready;
        presentation_hold_q<=presentation_hold;
        destination_hold_q<=destination_hold;
        scratch_available_q<=scratch_available;promotion_active_q<=promotion_active;
        frame_waiting_q<=frame_waiting;completed_frame_bank_q<=completed_frame_bank;
        presentation_complete_q<=presentation_complete;
        presentation_error_q<=presentation_error;
        scheduler_debug_state_q<=scheduler_debug_state;
        swap_window_pulse_q<=swap_window_pulse;
        candidate_presentable_q<=candidate_presentable;
        timestamp_candidate_active_q<=timestamp_candidate_active;
        timestamp_candidate_due_q<=timestamp_candidate_due;
        cadence_slot_q<=cadence_slot;
        decoder_byte_accepted_q<=decoder_byte_accepted;
        picture_coding_type_q<=picture_coding_type;
        temporal_reference_q<=temporal_reference;frame_rate_code_q<=frame_rate_code;
        picture_count_q<=picture_count;
        reference_picture_complete_q<=reference_picture_complete;
        b_picture_complete_q<=b_picture_complete;
        prediction_read_q<=prediction_read;prediction_busy_q<=prediction_busy;
        prediction_data_ready_q<=prediction_data_ready;
        writer_write_q<=writer_write;writer_busy_q<=writer_busy;
        display_frame_bank_q<=display_frame_bank;display_scratch_q<=display_scratch;
        display_scratch_bank_q<=display_scratch_bank;
        sequence_end_seen_q<=sequence_end_seen;session_quiet_q<=session_quiet;
        terminal_defer_q<=terminal_defer;
        error_flags_q<=error_flags;
        stc_seconds_q<=stc_seconds;
        associated_count_q<=associated_count;
        display_pts_q<=display_pts;
        pcm_sample_count_q<=pcm_sample_count;
        pcm_fifo_peak_q<=pcm_fifo_peak;
        top_field_first_q<=top_field_first;
        repeat_first_field_q<=repeat_first_field;
        framebuffer_generation_reset_d<=framebuffer_generation_reset;
        framebuffer_picture_present_d<=framebuffer_picture_present;
        framebuffer_prefill_deadline_missed_d<=
            framebuffer_prefill_deadline_missed;
        framebuffer_sequence_phase_error_d<=framebuffer_sequence_phase_error;
        framebuffer_first_field_fetch_d<=framebuffer_first_field_fetch;
        framebuffer_second_field_fetch_d<=framebuffer_second_field_fetch;
        b_picture_complete_d<=b_picture_complete_q;
        display_frame_bank_d<=display_frame_bank_q;
        display_scratch_d<=display_scratch_q;
        display_scratch_bank_d<=display_scratch_bank_q;

        if(decoder_byte_accepted_q)session_active<=1;
        if(!snapshot_ready_mpeg2&&(session_active||decoder_byte_accepted_q))begin
            session_cycles<=session_cycles+1'b1;
            if(decoder_byte_accepted_q)accepted_bytes<=accepted_bytes+1'b1;
            if(fifo_pending_q)begin
                if(!decoder_ready_q)begin
                    decoder_stall_cycles<=decoder_stall_cycles+1'b1;
                    case(picture_coding_type_q)
                    3'b001:i_stall_cycles<=i_stall_cycles+1'b1;
                    3'b010:p_stall_cycles<=p_stall_cycles+1'b1;
                    3'b011:b_stall_cycles<=b_stall_cycles+1'b1;
                    default:;
                    endcase
                end else if(presentation_hold_q)
                    presentation_stall_cycles<=presentation_stall_cycles+1'b1;
                else if(destination_hold_q)
                    destination_stall_cycles<=destination_stall_cycles+1'b1;
            end
            if(presentation_hold_q)
                presentation_hold_total_cycles<=presentation_hold_total_cycles+1'b1;
            if(destination_hold_q)
                destination_hold_total_cycles<=destination_hold_total_cycles+1'b1;
            if(presentation_hold_q&&destination_hold_q)
                hold_overlap_cycles<=hold_overlap_cycles+1'b1;
            if(presentation_hold_q&&scratch_available_q)
                hold_scratch_available_cycles<=hold_scratch_available_cycles+1'b1;
            if(presentation_hold_q&&promotion_active_q)
                hold_promotion_pending_cycles<=hold_promotion_pending_cycles+1'b1;
            if(prediction_request_accepted)
                prediction_requests<=prediction_requests+1'b1;
            if(prediction_read_q&&prediction_busy_q)
                prediction_request_wait_cycles<=prediction_request_wait_cycles+1'b1;
            if(prediction_outstanding)
                prediction_response_cycles<=prediction_response_cycles+1'b1;
            if(writer_write_q&&writer_busy_q)
                writer_wait_cycles<=writer_wait_cycles+1'b1;
            if(framebuffer_cache_write_valid)begin
                if(framebuffer_cache_write_first_field)begin
                    if(gen_first_cache_writes!=16'hffff)
                        gen_first_cache_writes<=gen_first_cache_writes+1'b1;
                    gen_first_cache_addr_sum<=gen_first_cache_addr_sum+
                        {8'd0,framebuffer_cache_write_addr};
                end
                else begin
                    if(gen_second_cache_writes!=16'hffff)
                        gen_second_cache_writes<=gen_second_cache_writes+1'b1;
                    gen_second_cache_addr_sum<=gen_second_cache_addr_sum+
                        {8'd0,framebuffer_cache_write_addr};
                end
            end
            if(framebuffer_luma_fetch_valid)begin
                if(framebuffer_luma_fetch_first_field)begin
                    gen_first_row_xor<=gen_first_row_xor^framebuffer_luma_fetch_row;
                    if(!gen_first_region_seen)begin
                        gen_first_region_seen<=1;
                        gen_first_region_seed<=framebuffer_display_region;
                    end
                    else if(framebuffer_display_region!=gen_first_region_seed)
                        gen_first_region_changed<=1;
                end
                else begin
                    gen_second_row_xor<=gen_second_row_xor^framebuffer_luma_fetch_row;
                    if(!gen_second_region_seen)begin
                        gen_second_region_seen<=1;
                        gen_second_region_seed<=framebuffer_display_region;
                    end
                    else if(framebuffer_display_region!=gen_second_region_seed)
                        gen_second_region_changed<=1;
                end
            end
            if(framebuffer_luma_return_valid)begin
                if(framebuffer_luma_return_first_field)begin
                    last_first_field_signature<=last_first_field_signature^
                        framebuffer_luma_return_byte;
                    if(!first_field_seen)begin
                        first_field_seen<=1;
                        first_field_reference<=framebuffer_luma_return_byte;
                    end
                    else if(framebuffer_luma_return_byte!=first_field_reference)
                        last_first_field_varied<=1;
                end
                else begin
                    last_second_field_signature<=last_second_field_signature^
                        framebuffer_luma_return_byte;
                    if(!second_field_seen)begin
                        second_field_seen<=1;
                        second_field_reference<=framebuffer_luma_return_byte;
                    end
                    else if(framebuffer_luma_return_byte!=second_field_reference)
                        last_second_field_varied<=1;
                end
            end
            if(framebuffer_luma_fingerprint_valid)begin
                if(framebuffer_luma_fingerprint_first_field)begin
                    last_first_field_raw_fingerprint<=
                        framebuffer_luma_fingerprint_raw;
                    last_first_field_display_fingerprint<=
                        framebuffer_luma_fingerprint_display;
                    if(first_field_fingerprint_count!=8'hff)
                        first_field_fingerprint_count<=
                            first_field_fingerprint_count+1'b1;
                    if(framebuffer_luma_fingerprint_mismatch&&
                       (first_field_fingerprint_mismatch_count!=8'hff))
                        first_field_fingerprint_mismatch_count<=
                            first_field_fingerprint_mismatch_count+1'b1;
                end
                else begin
                    last_second_field_raw_fingerprint<=
                        framebuffer_luma_fingerprint_raw;
                    last_second_field_display_fingerprint<=
                        framebuffer_luma_fingerprint_display;
                    if(second_field_fingerprint_count!=8'hff)
                        second_field_fingerprint_count<=
                            second_field_fingerprint_count+1'b1;
                    if(framebuffer_luma_fingerprint_mismatch&&
                       (second_field_fingerprint_mismatch_count!=8'hff))
                        second_field_fingerprint_mismatch_count<=
                            second_field_fingerprint_mismatch_count+1'b1;
                end
            end
            if(framebuffer_luma_write_read_valid)begin
                if(framebuffer_luma_write_read_first_field)begin
                    if(first_field_write_read_count!=8'hff)
                        first_field_write_read_count<=
                            first_field_write_read_count+1'b1;
                    if(framebuffer_luma_write_read_mismatch&&
                       (first_field_write_read_mismatch_count!=8'hff))
                        first_field_write_read_mismatch_count<=
                            first_field_write_read_mismatch_count+1'b1;
                    if(first_field_write_read_mismatch_count==8'd0)begin
                        first_field_write_read_expected<=
                            framebuffer_luma_write_read_expected_fingerprint;
                        first_field_write_read_raw<=
                            framebuffer_luma_write_read_raw_fingerprint;
                        first_field_write_read_expected_valid<=
                            framebuffer_luma_write_read_expected_valid;
                        first_field_write_read_region<=
                            framebuffer_luma_write_read_region;
                    end
                end
                else begin
                    if(second_field_write_read_count!=8'hff)
                        second_field_write_read_count<=
                            second_field_write_read_count+1'b1;
                    if(framebuffer_luma_write_read_mismatch&&
                       (second_field_write_read_mismatch_count!=8'hff))
                        second_field_write_read_mismatch_count<=
                            second_field_write_read_mismatch_count+1'b1;
                    if(second_field_write_read_mismatch_count==8'd0)begin
                        second_field_write_read_expected<=
                            framebuffer_luma_write_read_expected_fingerprint;
                        second_field_write_read_raw<=
                            framebuffer_luma_write_read_raw_fingerprint;
                        second_field_write_read_expected_valid<=
                            framebuffer_luma_write_read_expected_valid;
                        second_field_write_read_region<=
                            framebuffer_luma_write_read_region;
                    end
                end
            end
            if(framebuffer_luma_provenance_valid)begin
                if(framebuffer_luma_provenance_first_field)begin
                    if(framebuffer_luma_provenance_tag_mismatch)begin
                        if(first_field_tag_mismatch_count!=8'hff)
                            first_field_tag_mismatch_count<=
                                first_field_tag_mismatch_count+1'b1;
                        if(!first_field_tag_mismatch_seen)begin
                            first_field_tag_mismatch_seen<=1'b1;
                            first_field_tag_mismatch_meta<=
                                luma_provenance_meta_now;
                            first_field_tag_mismatch_generations<=
                                luma_provenance_generations_now;
                        end
                    end
                    else if(framebuffer_luma_provenance_content_mismatch)begin
                        if(first_field_content_mismatch_count!=8'hff)
                            first_field_content_mismatch_count<=
                                first_field_content_mismatch_count+1'b1;
                        if(!first_field_content_mismatch_seen)begin
                            first_field_content_mismatch_seen<=1'b1;
                            first_field_content_mismatch_meta<=
                                luma_provenance_meta_now;
                            first_field_content_mismatch_generations<=
                                luma_provenance_generations_now;
                            first_field_content_mismatch_raw<=
                                framebuffer_luma_provenance_raw_fingerprint;
                            first_field_content_mismatch_display<=
                                framebuffer_luma_provenance_display_fingerprint;
                        end
                    end
                end
                else begin
                    if(framebuffer_luma_provenance_tag_mismatch)begin
                        if(second_field_tag_mismatch_count!=8'hff)
                            second_field_tag_mismatch_count<=
                                second_field_tag_mismatch_count+1'b1;
                        if(!second_field_tag_mismatch_seen)begin
                            second_field_tag_mismatch_seen<=1'b1;
                            second_field_tag_mismatch_meta<=
                                luma_provenance_meta_now;
                            second_field_tag_mismatch_generations<=
                                luma_provenance_generations_now;
                        end
                    end
                    else if(framebuffer_luma_provenance_content_mismatch)begin
                        if(second_field_content_mismatch_count!=8'hff)
                            second_field_content_mismatch_count<=
                                second_field_content_mismatch_count+1'b1;
                        if(!second_field_content_mismatch_seen)begin
                            second_field_content_mismatch_seen<=1'b1;
                            second_field_content_mismatch_meta<=
                                luma_provenance_meta_now;
                            second_field_content_mismatch_generations<=
                                luma_provenance_generations_now;
                            second_field_content_mismatch_raw<=
                                framebuffer_luma_provenance_raw_fingerprint;
                            second_field_content_mismatch_display<=
                                framebuffer_luma_provenance_display_fingerprint;
                        end
                    end
                end
            end
            if(framebuffer_first_field_fetch_edge&&
               (gen_first_field_fetches!=8'hff))
                gen_first_field_fetches<=gen_first_field_fetches+1'b1;
            if(framebuffer_second_field_fetch_edge&&
               (gen_second_field_fetches!=8'hff))
                gen_second_field_fetches<=gen_second_field_fetches+1'b1;
            if(framebuffer_sequence_phase_error_edge&&
               (sequence_phase_error_count!=8'hff))
                sequence_phase_error_count<=sequence_phase_error_count+1'b1;
            if(framebuffer_generation_reset_edge)begin
                if(framebuffer_reset_count!=16'hffff)
                    framebuffer_reset_count<=framebuffer_reset_count+1'b1;
                // Entry 516: close the generation just ended.  Both fields of
                // a native frame present the same number of lines, so an
                // inequality is itself the defect; the retained pair keeps the
                // last generation's absolute figures for inspection.
                last_first_field_fetches<=gen_first_field_fetches;
                last_second_field_fetches<=gen_second_field_fetches;
                last_first_cache_writes<=gen_first_cache_writes;
                last_second_cache_writes<=gen_second_cache_writes;
                last_first_cache_addr_sum<=gen_first_cache_addr_sum;
                last_second_cache_addr_sum<=gen_second_cache_addr_sum;
                gen_first_cache_writes<=0;gen_second_cache_writes<=0;
                gen_first_cache_addr_sum<=0;gen_second_cache_addr_sum<=0;
                last_first_row_xor<=gen_first_row_xor;
                last_second_row_xor<=gen_second_row_xor;
                last_first_region_changed<=gen_first_region_changed;
                last_second_region_changed<=gen_second_region_changed;
                gen_first_row_xor<=0;gen_second_row_xor<=0;
                gen_first_region_seen<=0;gen_second_region_seen<=0;
                gen_first_region_changed<=0;gen_second_region_changed<=0;
                last_first_field_region<=framebuffer_first_field_region;
                last_second_field_region<=framebuffer_second_field_region;

                if((framebuffer_first_field_region!=
                    framebuffer_second_field_region)&&
                   (field_region_mismatch_count!=8'hff))
                    field_region_mismatch_count<=
                        field_region_mismatch_count+1'b1;
                gen_first_field_fetches<=0;gen_second_field_fetches<=0;
                if(framebuffer_publication_pending&&
                   (framebuffer_unpublished_reset_count!=16'hffff))
                    framebuffer_unpublished_reset_count<=
                        framebuffer_unpublished_reset_count+1'b1;
                framebuffer_publication_pending<=1;
                framebuffer_publication_latency<=0;
            end else if(framebuffer_publication_pending&&
                        (framebuffer_publication_latency!=32'hffffffff))
                framebuffer_publication_latency<=
                    framebuffer_publication_latency+1'b1;
            if(framebuffer_picture_present_edge)begin
                if(framebuffer_publication_count!=16'hffff)
                    framebuffer_publication_count<=
                        framebuffer_publication_count+1'b1;
                if(framebuffer_publication_pending)begin
                    if(framebuffer_publication_latency>
                       framebuffer_max_publication_latency)
                        framebuffer_max_publication_latency<=
                            framebuffer_publication_latency;
                    framebuffer_publication_pending<=0;
                end
            end
            if(framebuffer_prefill_deadline_missed_edge&&
               (framebuffer_prefill_miss_count!=16'hffff))
                framebuffer_prefill_miss_count<=
                    framebuffer_prefill_miss_count+1'b1;
            if(profile_window_active&&swap_window_pulse_q&&
               candidate_presentable_q&&timestamp_candidate_active_q)begin
                if(cadence_slot_q&&!timestamp_candidate_due_q&&
                   (timestamp_delay_conflict_count!=16'hffff))
                    timestamp_delay_conflict_count<=
                        timestamp_delay_conflict_count+1'b1;
                if(!cadence_slot_q&&timestamp_candidate_due_q&&
                   (timestamp_advance_conflict_count!=16'hffff))
                    timestamp_advance_conflict_count<=
                        timestamp_advance_conflict_count+1'b1;
            end
            case({prediction_request_accepted,prediction_data_ready_q})
            2'b10:prediction_outstanding<=1;
            2'b01:prediction_outstanding<=0;
            2'b11:prediction_outstanding<=1;
            default:;
            endcase
            if(reference_picture_complete_q)begin
                reference_picture_count<=reference_picture_count+1'b1;
                if(!first_present_valid)begin
                    first_present_valid<=1;first_present_cycle<=session_cycles;
                    last_present_cycle<=session_cycles;display_picture_count<=1;
                end
            end
            if(b_picture_complete_edge)b_picture_count<=b_picture_count+1'b1;

            // Entry 468: capture only the approved late-session window. The
            // first swap in that window establishes a local gap origin, so a
            // pre-window interval can never contaminate the ranked results.
            // Blocking state is still retained at threshold crossing rather
            // than at the eventual swap where it may already have released.
            if(profile_window_active&&profile_first_present_valid&&
               !display_swap_now&&
               !current_gap_context_valid&&cadence_rate_supported&&
               (profile_display_gap_now>OUTLIER_GAP_CYCLES))begin
                current_gap_meta<=display_gap_meta_now;
                current_gap_state<=scheduler_debug_state_q;
                current_gap_context_valid<=1;
            end
            if(display_swap_now)begin
                last_present_cycle<=session_cycles;
                display_swap_count<=display_swap_count+1'b1;
                display_picture_count<=display_picture_count+1'b1;
                current_gap_context_valid<=0;
                if(profile_window_active)begin
                    profile_last_present_cycle<=session_cycles;
                    if(!profile_first_present_valid)
                        profile_first_present_valid<=1;
                    else begin
                        if(cadence_rate_supported&&
                           (profile_display_gap_now>OUTLIER_GAP_CYCLES)&&
                           (gap_outlier_count!=16'hffff))
                            gap_outlier_count<=gap_outlier_count+1'b1;
                        if(profile_display_gap_now>largest_gap_0)begin
                            largest_gap_2<=largest_gap_1;
                            largest_gap_meta_2<=largest_gap_meta_1;
                            largest_gap_state_2<=largest_gap_state_1;
                            largest_gap_1<=largest_gap_0;
                            largest_gap_meta_1<=largest_gap_meta_0;
                            largest_gap_state_1<=largest_gap_state_0;
                            largest_gap_0<=profile_display_gap_now;
                            largest_gap_meta_0<=completed_gap_meta;
                            largest_gap_state_0<=completed_gap_state;
                        end else if(profile_display_gap_now>largest_gap_1)begin
                            largest_gap_2<=largest_gap_1;
                            largest_gap_meta_2<=largest_gap_meta_1;
                            largest_gap_state_2<=largest_gap_state_1;
                            largest_gap_1<=profile_display_gap_now;
                            largest_gap_meta_1<=completed_gap_meta;
                            largest_gap_state_1<=completed_gap_state;
                        end else if(profile_display_gap_now>largest_gap_2)begin
                            largest_gap_2<=profile_display_gap_now;
                            largest_gap_meta_2<=completed_gap_meta;
                            largest_gap_state_2<=completed_gap_state;
                        end
                    end
                end
            end
        end

        // Entry 314: a fatal transport result can suppress all later decoder
        // validity, including the sequence-end code that previously gated
        // this snapshot.  Capture the first settled fatal state directly.
        if(!snapshot_ready_mpeg2&&session_active&&(error_flags_q!=0))begin
            snapshot_reason<=3;terminal_wait_count<=0;
            no_progress_wait_count<=0;
            if(quiet_count==10'd1)capture_snapshot();
            else quiet_count<=quiet_count+1'b1;
        end else if(!snapshot_ready_mpeg2&&session_active&&sequence_end_seen_q&&
           session_quiet_q)begin
            snapshot_reason<=1;terminal_wait_count<=0;no_progress_wait_count<=0;
            if(quiet_count==10'd1023)capture_snapshot();
            else quiet_count<=quiet_count+1'b1;
        end else if(!snapshot_ready_mpeg2&&session_active&&sequence_end_seen_q&&
           terminal_defer_q)begin
            snapshot_reason<=2;quiet_count<=0;terminal_wait_count<=0;
            no_progress_wait_count<=0;
        end else if(!snapshot_ready_mpeg2&&session_active&&sequence_end_seen_q)begin
            snapshot_reason<=2;quiet_count<=0;no_progress_wait_count<=0;
            if(terminal_wait_count==TERMINAL_SNAPSHOT_LIMIT)capture_snapshot();
            else terminal_wait_count<=terminal_wait_count+1'b1;
        end else if(!snapshot_ready_mpeg2&&session_active)begin
            snapshot_reason<=3;quiet_count<=0;terminal_wait_count<=0;
            if(session_progress)
                no_progress_wait_count<=0;
            else if(no_progress_wait_count==NO_PROGRESS_SNAPSHOT_LIMIT)begin
                no_progress_wait_count<=0;
                capture_snapshot();
            end else
                no_progress_wait_count<=no_progress_wait_count+1'b1;
        end else begin
            quiet_count<=0;terminal_wait_count<=0;no_progress_wait_count<=0;
        end
    end
end

(* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [SNAPSHOT_BITS-1:0] snapshot_sync_1;
(* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [SNAPSHOT_BITS-1:0] snapshot_sync_2;
(* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] snapshot_ready_sync;
always @(posedge clk_video)begin
    if(reset_video)begin snapshot_sync_1<=0;snapshot_sync_2<=0;
        snapshot_ready_sync<=0;end
    else begin snapshot_sync_1<=snapshot_mpeg2;snapshot_sync_2<=snapshot_sync_1;
        snapshot_ready_sync<={snapshot_ready_sync[1:0],snapshot_ready_mpeg2};end
end
assign snapshot_ready=snapshot_ready_sync[2];

reg [42:0] overlay_shift;
reg [31:0] overlay_row_word;
wire [11:0] overlay_y=native_active?OVERLAY_NATIVE_Y:OVERLAY_DIAG_Y;
wire [11:0] overlay_row_offset=(v_pos-overlay_y)>>2;
wire [5:0] overlay_row_index=overlay_row_offset[5:0];
always @* begin
    case(overlay_row_index)
    0:overlay_row_word=snapshot_sync_2[31:0];
    1:overlay_row_word=snapshot_sync_2[63:32];
    2:overlay_row_word=snapshot_sync_2[95:64];
    3:overlay_row_word=snapshot_sync_2[127:96];
    4:overlay_row_word=snapshot_sync_2[159:128];
    5:overlay_row_word=snapshot_sync_2[191:160];
    6:overlay_row_word=snapshot_sync_2[223:192];
    7:overlay_row_word=snapshot_sync_2[255:224];
    8:overlay_row_word=snapshot_sync_2[287:256];
    9:overlay_row_word=snapshot_sync_2[319:288];
    10:overlay_row_word=snapshot_sync_2[351:320];
    11:overlay_row_word=snapshot_sync_2[383:352];
    12:overlay_row_word=snapshot_sync_2[415:384];
    13:overlay_row_word=snapshot_sync_2[447:416];
    14:overlay_row_word=snapshot_sync_2[479:448];
    15:overlay_row_word=snapshot_sync_2[511:480];
    16:overlay_row_word=snapshot_sync_2[543:512];
    17:overlay_row_word=snapshot_sync_2[575:544];
    18:overlay_row_word=snapshot_sync_2[607:576];
    19:overlay_row_word=snapshot_sync_2[639:608];
    20:overlay_row_word=snapshot_sync_2[671:640];
    21:overlay_row_word=snapshot_sync_2[703:672];
    22:overlay_row_word=snapshot_sync_2[735:704];
    23:overlay_row_word=snapshot_sync_2[767:736];
    24:overlay_row_word=snapshot_sync_2[799:768];
    25:overlay_row_word=snapshot_sync_2[831:800];
    26:overlay_row_word=snapshot_sync_2[863:832];
    27:overlay_row_word=snapshot_sync_2[895:864];
    28:overlay_row_word=snapshot_sync_2[927:896];
    29:overlay_row_word=snapshot_sync_2[959:928];
    30:overlay_row_word=snapshot_sync_2[991:960];
    31:overlay_row_word=snapshot_sync_2[1023:992];
    32:overlay_row_word=snapshot_sync_2[1055:1024];
    33:overlay_row_word=snapshot_sync_2[1087:1056];
    34:overlay_row_word=snapshot_sync_2[1119:1088];
    35:overlay_row_word=snapshot_sync_2[1151:1120];
    36:overlay_row_word=snapshot_sync_2[1183:1152];
    37:overlay_row_word=snapshot_sync_2[1215:1184];
    38:overlay_row_word=snapshot_sync_2[1247:1216];
    39:overlay_row_word=snapshot_sync_2[1279:1248];
    40:overlay_row_word=snapshot_sync_2[1311:1280];
    41:overlay_row_word=snapshot_sync_2[1343:1312];
    42:overlay_row_word=snapshot_sync_2[1375:1344];
    43:overlay_row_word=snapshot_sync_2[1407:1376];
    44:overlay_row_word=snapshot_sync_2[1439:1408];
    45:overlay_row_word=snapshot_sync_2[1471:1440];
    46:overlay_row_word=snapshot_sync_2[1503:1472];
    47:overlay_row_word=snapshot_sync_2[1535:1504];
    48:overlay_row_word=snapshot_sync_2[1567:1536];
    49:overlay_row_word=snapshot_sync_2[1599:1568];
    50:overlay_row_word=snapshot_sync_2[1631:1600];
    51:overlay_row_word=snapshot_sync_2[1663:1632];
    52:overlay_row_word=snapshot_sync_2[1695:1664];
    53:overlay_row_word=snapshot_sync_2[1727:1696];
    54:overlay_row_word=snapshot_sync_2[1759:1728];
    55:overlay_row_word=snapshot_sync_2[1791:1760];
    56:overlay_row_word=snapshot_sync_2[1823:1792];
    57:overlay_row_word=snapshot_sync_2[1855:1824];
    58:overlay_row_word=snapshot_sync_2[1887:1856];
    59:overlay_row_word=snapshot_sync_2[1919:1888];
    60:overlay_row_word=snapshot_sync_2[1951:1920];
    61:overlay_row_word=snapshot_sync_2[1983:1952];
    62:overlay_row_word=snapshot_sync_2[2015:1984];
    63:overlay_row_word=snapshot_sync_2[2047:2016];
    default:overlay_row_word=0;
    endcase
end
always @(posedge clk_video)begin
    if(reset_video)overlay_shift<=0;
    else if(pixel_ce&&h_pos==0)begin
        if(snapshot_ready&&(v_pos>=overlay_y)&&(v_pos<overlay_y+OVERLAY_HEIGHT))
            overlay_shift<={4'b1010,overlay_row_index,overlay_row_word,
                           ^overlay_row_word};
        else overlay_shift<=0;
    end else if(pixel_ce&&(h_pos>=OVERLAY_X)&&(h_pos<OVERLAY_X+OVERLAY_WIDTH)&&
                (h_pos[1:0]==2'b11))
        overlay_shift<={overlay_shift[41:0],1'b0};
end
always @* begin
    video_r=base_r;video_g=base_g;video_b=base_b;
    if(snapshot_ready&&base_de&&(h_pos>=OVERLAY_X)&&
       (h_pos<OVERLAY_X+OVERLAY_WIDTH)&&(v_pos>=overlay_y)&&
       (v_pos<overlay_y+OVERLAY_HEIGHT))begin
        video_r=overlay_shift[42]?8'hff:8'h00;
        video_g=overlay_shift[42]?8'hff:8'h00;
        video_b=overlay_shift[42]?8'hff:8'h00;
    end
end
endmodule
