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
reg sequence_end_seen=0,session_quiet=0;
reg [15:0] error_flags=0;
reg [13:0] stc_seconds=0;
reg [7:0] associated_count=0;
reg [32:0] display_pts=0;
reg top_field_first=0,repeat_first_field=0;
reg [11:0] h_pos=0,v_pos=0;
reg [7:0] base_r=8'h12,base_g=8'h34,base_b=8'h56;
reg base_de=1;
wire [7:0] video_r,video_g,video_b;
wire snapshot_ready;
integer i;
reg [31:0] checksum;

mpeg2_h262_hardware_cadence_profiler #(
    .DETAILED_TELEMETRY(1),
    .TERMINAL_SNAPSHOT_DELAY(32),
    .NO_PROGRESS_SNAPSHOT_DELAY(64),
    .OUTLIER_GAP_CYCLES(32'd10)
) dut(
    .transport_status(256'h12345678),
    .audio_frames(32'd1250),.audio_samples(32'd1440000),.audio_status(32'd15),
    .clk_mpeg2(clk_mpeg2),.reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video),.reset_video(reset_video),
    .fifo_pending(fifo_pending),.decoder_ready(decoder_ready),
    .presentation_hold(presentation_hold),.destination_hold(destination_hold),
    .scratch_available(scratch_available),.promotion_active(promotion_active),
    .frame_waiting(frame_waiting),.completed_frame_bank(completed_frame_bank),
    .presentation_complete(presentation_complete),
    .presentation_error(presentation_error),
    .scheduler_debug_state(scheduler_debug_state),
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
    .stc_seconds(stc_seconds),.associated_count(associated_count),.display_pts(display_pts),
    .top_field_first(top_field_first),
    .repeat_first_field(repeat_first_field),
    .error_flags(error_flags),.h_pos(h_pos),.v_pos(v_pos),
    .base_r(base_r),.base_g(base_g),.base_b(base_b),.base_de(base_de),
    .video_r(video_r),.video_g(video_g),.video_b(video_b),
    .snapshot_ready(snapshot_ready)
);
wire [7:0] compact_r,compact_g,compact_b;
wire compact_ready;
mpeg2_h262_hardware_cadence_profiler #(
    .DETAILED_TELEMETRY(0),
    .TERMINAL_SNAPSHOT_DELAY(32),
    .NO_PROGRESS_SNAPSHOT_DELAY(64),
    .OUTLIER_GAP_CYCLES(32'd10)
) compact(
    .transport_status(256'h12345678),
    .audio_frames(32'd1250),.audio_samples(32'd1440000),.audio_status(32'd15),
    .clk_mpeg2(clk_mpeg2),.reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video),.reset_video(reset_video),
    .fifo_pending(fifo_pending),.decoder_ready(decoder_ready),
    .presentation_hold(presentation_hold),.destination_hold(destination_hold),
    .scratch_available(scratch_available),.promotion_active(promotion_active),
    .frame_waiting(frame_waiting),.completed_frame_bank(completed_frame_bank),
    .presentation_complete(presentation_complete),
    .presentation_error(presentation_error),
    .scheduler_debug_state(scheduler_debug_state),
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
    .stc_seconds(stc_seconds),.associated_count(associated_count),.display_pts(display_pts),
    .top_field_first(top_field_first),
    .repeat_first_field(repeat_first_field),
    .error_flags(error_flags),.h_pos(h_pos),.v_pos(v_pos),
    .base_r(base_r),.base_g(base_g),.base_b(base_b),.base_de(base_de),
    .video_r(compact_r),.video_g(compact_g),.video_b(compact_b),
    .snapshot_ready(compact_ready)
);

task activate_session;
begin
    @(negedge clk_mpeg2);decoder_byte_accepted=1;
    @(negedge clk_mpeg2);decoder_byte_accepted=0;
    repeat(3)@(posedge clk_mpeg2);
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

task reset_all;
begin
    reset_mpeg2=1;reset_video=1;
    frame_rate_code=4'd3;
    sequence_end_seen=0;session_quiet=0;fifo_pending=0;decoder_ready=1;
    presentation_hold=0;destination_hold=0;frame_waiting=0;
    scratch_available=0;promotion_active=0;
    completed_frame_bank=0;display_frame_bank=0;display_scratch=0;
    display_scratch_bank=0;presentation_complete=0;presentation_error=0;
    scheduler_debug_state=0;decoder_byte_accepted=0;error_flags=0;
    repeat(5)@(posedge clk_mpeg2);reset_mpeg2=0;
    repeat(5)@(posedge clk_video);reset_video=0;
end
endtask

task verify_checksum;
reg [31:0] compact_sum;
begin
    if(!compact_ready || compact.snapshot_sync_2[63:32]!==32'h0a19ea60)
        $fatal(1,"compact snapshot/header missing");
    if(compact.snapshot_sync_2[0*32+:32]!==dut.snapshot_sync_2[0*32+:32])
        $fatal(1,"compact retained field 0/0 differs");
    if(compact.snapshot_sync_2[2*32+:32]!==dut.snapshot_sync_2[2*32+:32])
        $fatal(1,"compact retained field 2/2 differs");
    if(compact.snapshot_sync_2[3*32+:32]!==dut.snapshot_sync_2[3*32+:32])
        $fatal(1,"compact retained field 3/3 differs");
    if(compact.snapshot_sync_2[4*32+:32]!==dut.snapshot_sync_2[4*32+:32])
        $fatal(1,"compact retained field 4/4 differs");
    if(compact.snapshot_sync_2[5*32+:32]!==dut.snapshot_sync_2[5*32+:32])
        $fatal(1,"compact retained field 5/5 differs");
    if(compact.snapshot_sync_2[6*32+:32]!==dut.snapshot_sync_2[6*32+:32])
        $fatal(1,"compact retained field 6/6 differs");
    if(compact.snapshot_sync_2[7*32+:32]!==dut.snapshot_sync_2[17*32+:32])
        $fatal(1,"compact retained field 7/17 differs");
    if(compact.snapshot_sync_2[8*32+:32]!==dut.snapshot_sync_2[18*32+:32])
        $fatal(1,"compact retained field 8/18 differs");
    if(compact.snapshot_sync_2[9*32+:32]!==dut.snapshot_sync_2[19*32+:32])
        $fatal(1,"compact retained field 9/19 differs");
    if(compact.snapshot_sync_2[10*32+:32]!==dut.snapshot_sync_2[25*32+:32])
        $fatal(1,"compact retained field 10/25 differs");
    if(compact.snapshot_sync_2[11*32+:32]!==dut.snapshot_sync_2[26*32+:32])
        $fatal(1,"compact retained field 11/26 differs");
    if(compact.snapshot_sync_2[12*32+:32]!==dut.snapshot_sync_2[35*32+:32])
        $fatal(1,"compact retained field 12/35 differs");
    if(compact.snapshot_sync_2[13*32+:32]!==dut.snapshot_sync_2[37*32+:32])
        $fatal(1,"compact retained field 13/37 differs");
    if(compact.snapshot_sync_2[14*32+:32]!==dut.snapshot_sync_2[38*32+:32])
        $fatal(1,"compact retained field 14/38 differs");
    if(compact.snapshot_sync_2[15*32+:32]!==dut.snapshot_sync_2[39*32+:32])
        $fatal(1,"compact retained field 15/39 differs");
    if(compact.snapshot_sync_2[16*32+:32]!==dut.snapshot_sync_2[40*32+:32])
        $fatal(1,"compact retained field 16/40 differs");
    if(compact.snapshot_sync_2[17*32+:32]!==dut.snapshot_sync_2[41*32+:32])
        $fatal(1,"compact retained field 17/41 differs");
    if(compact.snapshot_sync_2[18*32+:32]!==dut.snapshot_sync_2[42*32+:32])
        $fatal(1,"compact retained field 18/42 differs");
    if(compact.snapshot_sync_2[19*32+:32]!==dut.snapshot_sync_2[43*32+:32])
        $fatal(1,"compact retained field 19/43 differs");
    if(compact.snapshot_sync_2[20*32+:32]!==dut.snapshot_sync_2[44*32+:32])
        $fatal(1,"compact retained field 20/44 differs");
    if(compact.snapshot_sync_2[21*32+:32]!==dut.snapshot_sync_2[45*32+:32])
        $fatal(1,"compact retained field 21/45 differs");
    if(compact.snapshot_sync_2[22*32+:32]!==dut.snapshot_sync_2[46*32+:32])
        $fatal(1,"compact retained field 22/46 differs");
    if(compact.snapshot_sync_2[23*32+:32]!==dut.snapshot_sync_2[47*32+:32])
        $fatal(1,"compact retained field 23/47 differs");
    compact_sum=0;
    for(i=0;i<24;i=i+1)compact_sum=compact_sum^compact.snapshot_sync_2[i*32+:32];
    if(compact_sum!==compact.snapshot_sync_2[24*32+:32])$fatal(1,"compact checksum mismatch");
    $write("COMPACT_WORDS");
    for(i=0;i<25;i=i+1)$write(" %08x",compact.snapshot_sync_2[i*32+:32]);
    $write("\n");

    if(dut.snapshot_sync_2[1215:1184]!=1250||dut.snapshot_sync_2[1247:1216]!=1440000||dut.snapshot_sync_2[1279:1248]!=15)
        $fatal(1,"audio telemetry missing");
    if(dut.snapshot_sync_2[1311:1280]!==32'h12345678) $fatal(1,"transport telemetry missing");
    checksum=0;
    for(i=0;i<48;i=i+1)
        checksum=checksum^dut.snapshot_sync_2[i*32+:32];
    if(checksum!==dut.snapshot_sync_2[1567:1536])
        $fatal(1,"checksum mismatch %h/%h",checksum,
               dut.snapshot_sync_2[1567:1536]);
end
endtask

task verify_overlay_prefix;
    integer x;
begin
    v_pos=12'd313;
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

// Capture actual registered overlay RGB, including untouched background.
// This is consumed by the host screenshot decoder regression.
task dump_compact_overlay;
 integer fd,x,y;reg [2047:0] path;
 begin
  if($value$plusargs("OVERLAY_PPM=%s",path))begin
   fd=$fopen(path,"w");
   $fwrite(fd,"P3\n180 384\n255\n");
   for(y=0;y<384;y=y+1)begin
    for(x=0;x<180;x=x+1)begin
     @(negedge clk_video);h_pos=x;v_pos=y;
     @(posedge clk_video);#1;
     $fwrite(fd,"%0d %0d %0d\n",compact_r,compact_g,compact_b);
    end
   end
   $fclose(fd);
  end
 end
endtask

initial begin
    reset_all();
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();

    // Three deliberately different display gaps exercise ranking and ordinals.
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
    repeat(6) @(posedge clk_mpeg2);swap_bank(2);
    presentation_hold=1;scratch_available=1;frame_waiting=1;
    completed_frame_bank=2;scheduler_debug_state=32'h13579bdf;
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
    if(dut.snapshot_sync_2[63:32]!==32'h0931ea60)
        $fatal(1,"bad format %h",dut.snapshot_sync_2[63:32]);
    if(dut.snapshot_sync_2[831:830]!==2'd1)
        $fatal(1,"quiet snapshot reason missing");
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
    verify_checksum();
    verify_overlay_prefix();
    dump_compact_overlay();

    // Native 24 fps uses the same legal three-refresh maximum gap and must
    // retain the same ranked outlier telemetry as the established 25 fps path.
    reset_all();
    frame_rate_code=4'd2;
    fifo_pending=1;
    activate_session();
    picture_count=1;
    pulse_reference();
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
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
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
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
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
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
    repeat(12)@(posedge clk_mpeg2);swap_bank(1);
    sequence_end_seen=1;fifo_pending=0;session_quiet=1;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[607:604]!==4'd5)
        $fatal(1,"native 30 fps metadata missing");
    if(dut.snapshot_sync_2[815:800]==0)
        $fatal(1,"native 30 fps outlier was not captured");
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
    error_flags=16'h0200;presentation_error=1;
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

    // A failed first host read must be visible without any decoder byte.
    reset_all();error_flags=16'h4000;
    wait(snapshot_ready);repeat(4)@(posedge clk_video);
    if(dut.snapshot_sync_2[95:64]!=0 || !dut.snapshot_sync_2[638])
        $fatal(1,"pre-decode transport error was not captured");
    verify_checksum();

    $display("HARDWARE_CADENCE_PROFILER_PASS schema=9/10 retained-fields-equivalent compact-checksum gap-state+forced+fatal+no-progress checksum=%h",
             checksum);
    $finish;
end

initial begin
    repeat(200000)@(posedge clk_mpeg2);
    $fatal(1,"hardware cadence profiler timeout");
end
endmodule
