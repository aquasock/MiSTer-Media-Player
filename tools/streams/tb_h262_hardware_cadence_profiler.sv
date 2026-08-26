`timescale 1ns/1ps

module tb_h262_hardware_cadence_profiler;
reg clk_mpeg2=0,clk_video=0;
always #5 clk_mpeg2=~clk_mpeg2;
always #7 clk_video=~clk_video;

reg reset_mpeg2=1,reset_video=1;
reg fifo_pending=0,decoder_ready=1,presentation_hold=0;
reg destination_hold=0,scratch_available=0,promotion_active=0;
reg frame_waiting=0;
reg [1:0] completed_frame_bank=0;
reg presentation_complete=0,presentation_error=0;
reg [31:0] scheduler_debug_state=0;
reg swap_window_pulse=0,candidate_presentable=0;
reg timestamp_candidate_active=0,timestamp_candidate_due=0,cadence_slot=0;
reg decoder_byte_accepted=0;
reg [2:0] picture_coding_type=3'b001;
reg [9:0] temporal_reference=0;
reg [3:0] frame_rate_code=4'd3;
reg [7:0] picture_count=0;
reg reference_picture_complete=0,b_picture_complete=0;
reg prediction_read=0,prediction_busy=0,prediction_data_ready=0;
reg writer_write=0,writer_busy=0;
reg [1:0] display_frame_bank=0;
reg display_scratch=0,display_scratch_bank=0;
reg sequence_end_seen=0,session_quiet=0,terminal_defer=0;
reg [15:0] error_flags=0;
reg [13:0] stc_seconds=0;
reg [7:0] associated_count=0;
reg [32:0] display_pts=0;
reg [13:0] pcm_sample_count=0;
reg [6:0] pcm_fifo_peak=0;
reg top_field_first=0,repeat_first_field=0;
reg native_active=0;
reg framebuffer_generation_reset=0;
reg framebuffer_picture_present=0;
reg framebuffer_prefill_deadline_missed=0;
reg framebuffer_sequence_phase_error=0;
reg [2:0] framebuffer_first_field_region=0;
reg [2:0] framebuffer_second_field_region=0;
reg framebuffer_luma_return_valid=0;
reg framebuffer_luma_return_first_field=0;
reg [7:0] framebuffer_luma_return_byte=0;
reg framebuffer_first_field_fetch=0;
reg framebuffer_second_field_fetch=0;
integer field_index;
reg [11:0] h_pos=0,v_pos=0;
reg [7:0] base_r=8'h12,base_g=8'h34,base_b=8'h56;
reg base_de=1;
wire [7:0] video_r,video_g,video_b;
wire snapshot_ready;
integer i;
reg [31:0] checksum;

mpeg2_h262_hardware_cadence_profiler #(
    .TERMINAL_SNAPSHOT_DELAY(32),
    .NO_PROGRESS_SNAPSHOT_DELAY(64),
    .OUTLIER_GAP_CYCLES(32'd10),
    .PROFILE_START_STC_SECONDS(14'd5)
) dut(
    .clk_mpeg2(clk_mpeg2),.reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video),.reset_video(reset_video),.pixel_ce(1'b1),
    .native_active(native_active),
    .framebuffer_generation_reset(framebuffer_generation_reset),
    .framebuffer_picture_present(framebuffer_picture_present),
    .framebuffer_prefill_deadline_missed(
        framebuffer_prefill_deadline_missed),
    .framebuffer_sequence_phase_error(framebuffer_sequence_phase_error),
    .framebuffer_first_field_region(framebuffer_first_field_region),
    .framebuffer_second_field_region(framebuffer_second_field_region),
    .framebuffer_luma_return_valid(framebuffer_luma_return_valid),
    .framebuffer_luma_return_first_field(framebuffer_luma_return_first_field),
    .framebuffer_luma_return_byte(framebuffer_luma_return_byte),
    .framebuffer_first_field_fetch(framebuffer_first_field_fetch),
    .framebuffer_second_field_fetch(framebuffer_second_field_fetch),
    .fifo_pending(fifo_pending),.decoder_ready(decoder_ready),
    .presentation_hold(presentation_hold),.destination_hold(destination_hold),
    .scratch_available(scratch_available),.promotion_active(promotion_active),
    .frame_waiting(frame_waiting),.completed_frame_bank(completed_frame_bank),
    .presentation_complete(presentation_complete),
    .presentation_error(presentation_error),
    .scheduler_debug_state(scheduler_debug_state),
    .swap_window_pulse(swap_window_pulse),
    .candidate_presentable(candidate_presentable),
    .timestamp_candidate_active(timestamp_candidate_active),
    .timestamp_candidate_due(timestamp_candidate_due),
    .cadence_slot(cadence_slot),
    .decoder_byte_accepted(decoder_byte_accepted),
    .picture_coding_type(picture_coding_type),
    .temporal_reference(temporal_reference),.frame_rate_code(frame_rate_code),
    .picture_count(picture_count),
    .reference_picture_complete(reference_picture_complete),
    .b_picture_complete(b_picture_complete),
    .prediction_read(prediction_read),.prediction_busy(prediction_busy),
    .prediction_data_ready(prediction_data_ready),
    .writer_write(writer_write),.writer_busy(writer_busy),
    .display_frame_bank(display_frame_bank),.display_scratch(display_scratch),
    .display_scratch_bank(display_scratch_bank),
    .sequence_end_seen(sequence_end_seen),.session_quiet(session_quiet),
    .terminal_defer(terminal_defer),
    .stc_seconds(stc_seconds),.associated_count(associated_count),.display_pts(display_pts),
    .pcm_sample_count(pcm_sample_count),.pcm_fifo_peak(pcm_fifo_peak),
    .top_field_first(top_field_first),
    .repeat_first_field(repeat_first_field),
    .error_flags(error_flags),.h_pos(h_pos),.v_pos(v_pos),
    .base_r(base_r),.base_g(base_g),.base_b(base_b),.base_de(base_de),
    .video_r(video_r),.video_g(video_g),.video_b(video_b),
    .snapshot_ready(snapshot_ready)
);

task activate_session;
begin
    @(negedge clk_mpeg2);decoder_byte_accepted=1;
    @(negedge clk_mpeg2);decoder_byte_accepted=0;
    repeat(3)@(posedge clk_mpeg2);
end
endtask

task pulse_framebuffer_reset;
begin
    @(negedge clk_mpeg2);
    framebuffer_picture_present=0;
    framebuffer_generation_reset=1;
    @(negedge clk_mpeg2);framebuffer_generation_reset=0;
    repeat(2)@(posedge clk_mpeg2);
end
endtask

task publish_framebuffer;
begin
    @(negedge clk_mpeg2);framebuffer_picture_present=1;
    repeat(2)@(posedge clk_mpeg2);
end
endtask

task drive_field_regions;
    input [2:0] first_region;
    input [2:0] second_region;
begin
    @(negedge clk_mpeg2);
    framebuffer_first_field_region=first_region;
    framebuffer_second_field_region=second_region;
    @(posedge clk_mpeg2);
end
endtask

task drive_luma_return;
    input first_field;
    input [7:0] value;
begin
    @(negedge clk_mpeg2);
    framebuffer_luma_return_valid=1;
    framebuffer_luma_return_first_field=first_field;
    framebuffer_luma_return_byte=value;
    @(negedge clk_mpeg2);
    framebuffer_luma_return_valid=0;
end
endtask

task pulse_decoder_progress;
begin
    // Passive framebuffer observations are intentionally not production
    // session progress.  Keep this long directed scenario inside its
    // deliberately short no-progress test budget with a real accepted byte.
    @(negedge clk_mpeg2);decoder_byte_accepted=1;
    @(negedge clk_mpeg2);decoder_byte_accepted=0;
    repeat(2)@(posedge clk_mpeg2);
end
endtask

task drive_field_fetches;
    input integer first_count;
    input integer second_count;
begin
    for(field_index=0;field_index<first_count;field_index=field_index+1)
        @(negedge clk_mpeg2)
            framebuffer_first_field_fetch=~framebuffer_first_field_fetch;
    for(field_index=0;field_index<second_count;field_index=field_index+1)
        @(negedge clk_mpeg2)
            framebuffer_second_field_fetch=~framebuffer_second_field_fetch;
    @(posedge clk_mpeg2);
end
endtask

task pulse_sequence_phase_error;
begin
    @(negedge clk_mpeg2);framebuffer_sequence_phase_error=1;
    @(negedge clk_mpeg2);framebuffer_sequence_phase_error=0;
    @(posedge clk_mpeg2);
end
endtask

task pulse_prefill_miss;
begin
    @(negedge clk_mpeg2);framebuffer_prefill_deadline_missed=1;
    @(negedge clk_mpeg2);framebuffer_prefill_deadline_missed=0;
    repeat(2)@(posedge clk_mpeg2);
end
endtask

task pulse_reference;
begin
    @(negedge clk_mpeg2);reference_picture_complete=1;
    @(negedge clk_mpeg2);reference_picture_complete=0;
    repeat(3)@(posedge clk_mpeg2);
end
endtask

task swap_bank;
    input [1:0] bank;
begin
    @(negedge clk_mpeg2);display_frame_bank=bank;
    repeat(3)@(posedge clk_mpeg2);
end
endtask

task pulse_admission_window;
begin
    @(negedge clk_mpeg2);swap_window_pulse=1;
    @(negedge clk_mpeg2);swap_window_pulse=0;
    repeat(2)@(posedge clk_mpeg2);
end
endtask

task reset_all;
begin
    reset_mpeg2=1;reset_video=1;
    frame_rate_code=4'd3;
    sequence_end_seen=0;session_quiet=0;terminal_defer=0;
    fifo_pending=0;decoder_ready=1;
    presentation_hold=0;destination_hold=0;frame_waiting=0;
    scratch_available=0;promotion_active=0;
    swap_window_pulse=0;candidate_presentable=0;
    timestamp_candidate_active=0;timestamp_candidate_due=0;cadence_slot=0;
    completed_frame_bank=0;display_frame_bank=0;display_scratch=0;
    display_scratch_bank=0;presentation_complete=0;presentation_error=0;
    scheduler_debug_state=0;decoder_byte_accepted=0;error_flags=0;
    pcm_sample_count=0;pcm_fifo_peak=0;
    native_active=0;
    framebuffer_generation_reset=0;
    framebuffer_picture_present=0;
    framebuffer_prefill_deadline_missed=0;
    framebuffer_sequence_phase_error=0;
    framebuffer_first_field_region=0;
    framebuffer_second_field_region=0;
    framebuffer_luma_return_valid=0;
    framebuffer_luma_return_first_field=0;
    framebuffer_luma_return_byte=0;
    framebuffer_first_field_fetch=0;
    framebuffer_second_field_fetch=0;
    stc_seconds=14'd5;
    repeat(5)@(posedge clk_mpeg2);reset_mpeg2=0;
    repeat(5)@(posedge clk_video);reset_video=0;
end
endtask

task verify_checksum;
begin
    checksum=0;
    for(i=0;i<42;i=i+1)
        checksum=checksum^dut.snapshot_sync_2[i*32+:32];
    if(checksum!==dut.snapshot_sync_2[1375:1344])
        $fatal(1,"checksum mismatch %h/%h",checksum,
               dut.snapshot_sync_2[1375:1344]);
end
endtask

// Entry 516: every snapshot word must actually reach the raster.  Checking
// snapshot_sync_2 alone cannot see a missing overlay case branch or a short
// OVERLAY_HEIGHT, both of which silently drop the appended words and let
// synthesis optimize their source logic away.
task verify_overlay_row_coverage;
    input native_mode;
    integer row;
    reg [11:0] y0;
begin
    native_active=native_mode;
    y0=native_mode?12'd308:12'd428;
    for(row=0;row<43;row=row+1)begin
        v_pos=y0+row[11:0]*12'd4;
        @(negedge clk_video);h_pos=0;
        @(posedge clk_video);#1;
        if(dut.overlay_row_index!==row[5:0])
            $fatal(1,"overlay row %0d decoded index %0d",row,
                   dut.overlay_row_index);
        if(dut.overlay_row_word!==dut.snapshot_sync_2[row*32+:32])
            $fatal(1,"overlay row %0d word mismatch %h/%h",row,
                   dut.overlay_row_word,
                   dut.snapshot_sync_2[row*32+:32]);
        if(!((v_pos>=y0)&&(v_pos<(y0+dut.OVERLAY_HEIGHT))))
            $fatal(1,"overlay row %0d lies outside OVERLAY_HEIGHT",row);
    end
end
endtask

task verify_overlay_prefix;
    input native_mode;
    integer x;
begin
    native_active=native_mode;
    v_pos=native_mode?12'd309:12'd429;
    for(x=0;x<=29;x=x+1)begin
        @(negedge clk_video);h_pos=x;
        @(posedge clk_video);#1;
        if((x==9||x==17)&&{video_r,video_g,video_b}!==24'hffffff)
            $fatal(1,"overlay prefix expected white at %0d",x);
        if((x==13||x==21||x==25)&&
           {video_r,video_g,video_b}!==24'h000000)
            $fatal(1,"overlay prefix expected black at %0d",x);
    end
end
endtask

initial begin
    // Entry 468: neither direction may count before the late-window gate.
    reset_all();
    stc_seconds=0;
    activate_session();
    picture_count=1;
    pulse_reference();
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
    repeat(12)@(posedge clk_mpeg2);swap_bank(2);
    if(dut.largest_gap_0!=0||dut.gap_outlier_count!=0)
        $fatal(1,"pre-window display gap was ranked");
    candidate_presentable=1;timestamp_candidate_active=1;
    cadence_slot=1;timestamp_candidate_due=0;
    pulse_admission_window();
    if(dut.timestamp_delay_conflict_count!=0)
        $fatal(1,"pre-window timestamp delay was counted");

    // At and after the gate, count the two mutually exclusive admission
    // conflicts at eligible raster windows and preserve them in word 24.
    stc_seconds=5;repeat(2)@(posedge clk_mpeg2);
    pulse_admission_window();
    cadence_slot=0;timestamp_candidate_due=1;
    pulse_admission_window();
    candidate_presentable=0;timestamp_candidate_active=0;
    sequence_end_seen=1;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[799:768]!=={16'd1,16'd1})
        $fatal(1,"timestamp conflict counts mismatch %h",
               dut.snapshot_sync_2[799:768]);
    if(dut.snapshot_sync_2[863:832]!==0)
        $fatal(1,"pre-window gap contaminated late ranking");
    verify_checksum();

    reset_all();
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();

    // Entry 511: one reset publishes normally, then a second generation is
    // superseded by a third before publication.  The final generation misses
    // its authored prefill origin and eventually publishes.  All observations
    // are passive and must survive in schema-ten words 37 through 39.
    // Entry 518 folds per-field evidence into these same three generations so
    // the established reset, publication, race and prefill counts are
    // unchanged.  The first generation is balanced and resolves both parities
    // into one region; the second starves the first field's DDR service and
    // splits the two parities across regions, which is the signature under
    // investigation.
    pulse_framebuffer_reset();
    repeat(5)@(posedge clk_mpeg2);
    publish_framebuffer();
    drive_field_regions(3'd1,3'd1);
    drive_field_fetches(2,2);
    pulse_framebuffer_reset();
    drive_field_regions(3'd2,3'd1);
    drive_luma_return(1'b1,8'h11);
    drive_luma_return(1'b1,8'h11);
    drive_luma_return(1'b1,8'h11);
    drive_luma_return(1'b0,8'h20);
    drive_luma_return(1'b0,8'h4f);
    pulse_decoder_progress();
    drive_field_fetches(1,3);
    pulse_sequence_phase_error();
    pulse_framebuffer_reset();
    pulse_prefill_miss();
    repeat(7)@(posedge clk_mpeg2);
    publish_framebuffer();

    // Three deliberately different display gaps exercise ranking and ordinals.
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
    repeat(6) @(posedge clk_mpeg2);swap_bank(2);
    presentation_hold=1;scratch_available=1;frame_waiting=1;
    completed_frame_bank=2;scheduler_debug_state=32'h13579bdf;
    pcm_sample_count=14'd10368;pcm_fifo_peak=7'd127;
    repeat(12)@(posedge clk_mpeg2);
    // The ranked state must remain the threshold-crossing value even though
    // all observed inputs release before the display eventually swaps.
    presentation_hold=0;scratch_available=0;frame_waiting=0;
    scheduler_debug_state=32'hdeadbeef;
    repeat(8)@(posedge clk_mpeg2);swap_bank(0);
    sequence_end_seen=1;fifo_pending=0;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);

    if(dut.snapshot_sync_2[31:0]!==32'h4d4d5031)
        $fatal(1,"bad magic %h",dut.snapshot_sync_2[31:0]);
    if(dut.snapshot_sync_2[63:32]!==32'h0e2bea60)
        $fatal(1,"bad format %h",dut.snapshot_sync_2[63:32]);
    if(dut.SNAPSHOT_WORD_40_BITS!=32)
        $fatal(1,"snapshot word 40 width is %0d",
               dut.SNAPSHOT_WORD_40_BITS);
    if(dut.snapshot_sync_2[831:830]!==2'd1)
        $fatal(1,"quiet snapshot reason missing");
    if(dut.snapshot_sync_2[829:816]!==14'd10368)
        $fatal(1,"PCM sample count missing");
    if(dut.snapshot_sync_2[582:576]!==7'd127)
        $fatal(1,"PCM FIFO peak missing");
    if(!(dut.snapshot_sync_2[863:832]>=dut.snapshot_sync_2[959:928]&&
         dut.snapshot_sync_2[959:928]>=dut.snapshot_sync_2[1055:1024]))
        $fatal(1,"gap ranking is not descending");
    if(dut.snapshot_sync_2[927:896]!==32'h13579bdf)
        $fatal(1,"outlier state was not retained at threshold %h",
               dut.snapshot_sync_2[927:896]);
    if(dut.snapshot_sync_2[895:864]!==
       {8'd4,1'b1,1'b0,1'b1,1'b1,1'b1,1'b0,1'b1,
        1'b0,1'b0,1'b0,1'b0,2'd2,2'd2,1'b0,1'b0,7'd0})
        $fatal(1,"outlier context mismatch %h",dut.snapshot_sync_2[895:864]);
    if(dut.snapshot_sync_2[815:800]==0)
        $fatal(1,"expected at least one outlier gap");
    if(dut.snapshot_sync_2[1215:1184]!=={16'd3,16'd2})
        $fatal(1,"framebuffer reset/publication mismatch %h",
               dut.snapshot_sync_2[1215:1184]);
    if(dut.snapshot_sync_2[1247:1216]!=={16'd1,16'd1})
        $fatal(1,"framebuffer race/prefill mismatch %h",
               dut.snapshot_sync_2[1247:1216]);
    if(dut.snapshot_sync_2[1279:1248]==0)
        $fatal(1,"framebuffer publication latency missing");
    if(dut.snapshot_sync_2[1311:1280]!==
       {8'd1,8'd3,1'b0,1'b1,8'd0,3'd2,3'd1})
        $fatal(1,"per-field fetch/region/varied mismatch %h",
               dut.snapshot_sync_2[1311:1280]);
    // First field saw 0x11 three times: unvarying, signature 0x11.
    // Second field saw 0x20 then 0x4f: varied, signature 0x6f.
    if(dut.snapshot_sync_2[1343:1312]!=={8'h11,8'h6f,8'd1,8'd1})
        $fatal(1,"per-field signature/mismatch/phase mismatch %h",
               dut.snapshot_sync_2[1343:1312]);
    verify_checksum();
    verify_overlay_prefix(1'b0);
    verify_overlay_prefix(1'b1);
    verify_overlay_row_coverage(1'b0);
    verify_overlay_row_coverage(1'b1);

    // Native 24 fps uses the same legal three-refresh maximum gap and must
    // retain the same ranked outlier telemetry as the established 25 fps path.
    reset_all();
    frame_rate_code=4'd2;
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();
    swap_bank(1);
    repeat(12)@(posedge clk_mpeg2);swap_bank(2);
    sequence_end_seen=1;fifo_pending=0;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[607:604]!==4'd2)
        $fatal(1,"native 24 fps metadata missing");
    if(dut.snapshot_sync_2[815:800]==0)
        $fatal(1,"native 24 fps outlier was not captured");
    verify_checksum();

    // NTSC film cadence (24000/1001) uses the same legal three-refresh
    // maximum gap and must be visible to the profiler rather than silently
    // bypassing cadence diagnostics as an unsupported rate.
    reset_all();
    frame_rate_code=4'd1;
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();
    swap_bank(1);
    repeat(12)@(posedge clk_mpeg2);swap_bank(2);
    sequence_end_seen=1;fifo_pending=0;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[607:604]!==4'd1)
        $fatal(1,"native 24000/1001 fps metadata missing");
    if(dut.snapshot_sync_2[815:800]==0)
        $fatal(1,"native 24000/1001 fps outlier was not captured");
    verify_checksum();

    // NTSC video cadence (30000/1001) is a supported paced rate and must
    // retain the same diagnostic coverage as the established lower rates.
    reset_all();
    frame_rate_code=4'd4;
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();
    swap_bank(1);
    repeat(12)@(posedge clk_mpeg2);swap_bank(2);
    sequence_end_seen=1;fifo_pending=0;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[607:604]!==4'd4)
        $fatal(1,"native 30000/1001 fps metadata missing");
    if(dut.snapshot_sync_2[815:800]==0)
        $fatal(1,"native 30000/1001 fps outlier was not captured");
    verify_checksum();

    // Exact 30 fps is independently signalled and supported.
    reset_all();
    frame_rate_code=4'd5;
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();
    swap_bank(1);
    repeat(12)@(posedge clk_mpeg2);swap_bank(2);
    sequence_end_seen=1;fifo_pending=0;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[607:604]!==4'd5)
        $fatal(1,"native 30 fps metadata missing");
    if(dut.snapshot_sync_2[815:800]==0)
        $fatal(1,"native 30 fps outlier was not captured");
    verify_checksum();

    // An explicit audio tail pauses the forced terminal timer. Once the audio
    // tail releases, a still-nonquiet video state retains the bounded snapshot.
    reset_all();
    activate_session();
    sequence_end_seen=1;session_quiet=0;terminal_defer=1;
    repeat(96)@(posedge clk_mpeg2);
    if(snapshot_ready)
        $fatal(1,"audio tail did not defer the forced snapshot");
    terminal_defer=0;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[831:830]!==2'd2)
        $fatal(1,"post-audio forced snapshot reason missing");
    verify_checksum();

    // A nonquiet sequence end must still expose the stuck terminal ownership.
    reset_all();
    activate_session();
    completed_frame_bank=2;display_frame_bank=1;frame_waiting=1;
    presentation_hold=1;destination_hold=1;
    scheduler_debug_state=32'ha5c35a69;
    sequence_end_seen=1;session_quiet=0;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[831:830]!==2'd2)
        $fatal(1,"forced snapshot reason missing");
    if(dut.snapshot_sync_2[1151:1143]!==9'b100100111)
        $fatal(1,"terminal state mismatch %h",
               dut.snapshot_sync_2[1151:1120]);
    if(dut.snapshot_sync_2[1183:1152]!==32'ha5c35a69)
        $fatal(1,"scheduler debug mismatch %h",
               dut.snapshot_sync_2[1183:1152]);
    verify_checksum();

    // A sticky fatal result must snapshot even when no sequence end can be
    // accepted after the transport enters fail-open drain.
    reset_all();
    activate_session();
    error_flags=16'h0200;presentation_error=1;terminal_defer=1;
    completed_frame_bank=2;display_frame_bank=1;
    scheduler_debug_state=32'h3140fade;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[831:830]!==2'd3)
        $fatal(1,"fatal snapshot reason missing");
    if(dut.snapshot_sync_2[639:624]!==16'h0200)
        $fatal(1,"fatal error flags missing %h",dut.snapshot_sync_2[639:608]);
    if(dut.snapshot_sync_2[1183:1152]!==32'h3140fade)
        $fatal(1,"fatal scheduler state mismatch");
    verify_checksum();

    // With no fatal flag and no sequence end, a bounded lack of decoder,
    // persistence, presentation, prediction or writer progress must also
    // expose the live terminal state.
    reset_all();
    error_flags=0;presentation_error=0;
    activate_session();
    completed_frame_bank=1;display_frame_bank=2;frame_waiting=1;
    scheduler_debug_state=32'h3140dead;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[831:830]!==2'd3)
        $fatal(1,"no-progress snapshot reason missing");
    if(dut.snapshot_sync_2[1183:1152]!==32'h3140dead)
        $fatal(1,"no-progress scheduler state mismatch");
    verify_checksum();

    @(negedge clk_video);h_pos=300;v_pos=300;
    @(posedge clk_video);#1;
    if({video_r,video_g,video_b}!==24'h123456)
        $fatal(1,"base video changed outside overlay");

    $display("HARDWARE_CADENCE_PROFILER_PASS schema=14 field-content+framebuffer-publication+timestamp-conflicts+audio-defer+forced+fatal+no-progress checksum=%h",
             checksum);
    $finish;
end

initial begin
    repeat(8000)@(posedge clk_mpeg2);
    $fatal(1,"hardware cadence profiler timeout");
end
endmodule
