`timescale 1ns/1ps

module test_telemetry_visibility;
reg clk_mpeg2 = 0;
reg clk_video = 0;
reg reset_mpeg2 = 1;
reg reset_video = 1;
reg telemetry_visible = 0;
reg [11:0] h_pos = 0;
reg [11:0] v_pos = 12'd224;
reg decoder_byte_accepted = 0;
reg swap_window_pulse = 0;
reg candidate_presentable = 0;
reg timestamp_candidate_active = 0;
reg timestamp_candidate_due = 0;
reg cadence_slot = 0;
reg presentation_stc_valid = 0;
reg [32:0] presentation_stc_90k = 0;
reg display_pts_valid = 0;
reg [32:0] display_pts = 0;
reg candidate_pts_valid = 0;
reg [32:0] candidate_pts = 0;
reg [31:0] audio_pcm_dequeue_count = 0;
wire [7:0] video_r;
wire [7:0] video_g;
wire [7:0] video_b;
wire snapshot_ready;

always #4 clk_mpeg2 = ~clk_mpeg2;
always #5 clk_video = ~clk_video;

mpeg2_h262_hardware_cadence_profiler #(
    .OVERLAY_DIAGNOSTICS(1'b1)
) dut (
    .clk_mpeg2(clk_mpeg2),
    .reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video),
    .reset_video(reset_video),
    .pixel_ce(1'b1),
    .h_pos(h_pos),
    .v_pos(v_pos),
    .base_r(8'h12),
    .base_g(8'h34),
    .base_b(8'h56),
    .base_de(1'b1),
    .telemetry_visible(telemetry_visible),
    .decoder_byte_accepted(decoder_byte_accepted),
    .swap_window_pulse(swap_window_pulse),
    .candidate_presentable(candidate_presentable),
    .timestamp_candidate_active(timestamp_candidate_active),
    .timestamp_candidate_due(timestamp_candidate_due),
    .cadence_slot(cadence_slot),
    .presentation_stc_valid(presentation_stc_valid),
    .presentation_stc_90k(presentation_stc_90k),
    .display_pts_valid(display_pts_valid),
    .display_pts(display_pts),
    .candidate_pts_valid(candidate_pts_valid),
    .candidate_pts(candidate_pts),
    .audio_pcm_dequeue_count(audio_pcm_dequeue_count),
    .video_r(video_r),
    .video_g(video_g),
    .video_b(video_b),
    .snapshot_ready(snapshot_ready)
);

task line_start;
begin
    h_pos = 0;
    @(posedge clk_video);
    #1;
    h_pos = 12'd8;
    #1;
end
endtask

task sample_window;
input presentable;
input cadence;
input timestamp_active;
input timestamp_due;
begin
    candidate_presentable = presentable;
    cadence_slot = cadence;
    timestamp_candidate_active = timestamp_active;
    timestamp_candidate_due = timestamp_due;
    swap_window_pulse = 1;
    @(posedge clk_mpeg2);
    #1;
    swap_window_pulse = 0;
    @(posedge clk_mpeg2);
    #1;
end
endtask

initial begin
    repeat (4) @(posedge clk_video);
    reset_mpeg2 = 0;
    reset_video = 0;

    force dut.session_active = 1'b1;
    force dut.profile_first_present_valid = 1'b1;
    force dut.snapshot_ready_mpeg2 = 1'b0;
    sample_window(0, 0, 0, 0);
    sample_window(1, 0, 0, 0);
    sample_window(1, 1, 1, 0);
    presentation_stc_valid = 1;
    presentation_stc_90k = 33'd100000;
    display_pts_valid = 1;
    display_pts = 33'd90000;
    candidate_pts_valid = 1;
    candidate_pts = 33'd101000;
    audio_pcm_dequeue_count = 32'd1440000;
    repeat (2) @(posedge clk_mpeg2);
    #1;
    force dut.display_picture_count_full = 16'd900;
    force dut.display_swap_count_full = 16'd899;
    if (dut.snapshot_word_01[31:24] !== 8'd22)
        $fatal(1, "schema 22 was not selected");
    if (dut.snapshot_word_58 !== {16'd900, 16'd899})
        $fatal(1, "full display progress word is incorrect");
    if (dut.snapshot_word_59 !== 32'd1440000)
        $fatal(1, "audio dequeue count word is incorrect");
    if (dut.snapshot_word_60 !== 32'd10000)
        $fatal(1, "display lateness word is incorrect");
    if (dut.snapshot_word_61 !== 32'hfffffc18)
        $fatal(1, "candidate lateness word is incorrect");
    if (dut.snapshot_word_62 !== {2'b11, 10'd1, 10'd1, 10'd1})
        $fatal(1, "presentation-window cause word is incorrect");
    release dut.display_picture_count_full;
    release dut.display_swap_count_full;
    release dut.snapshot_ready_mpeg2;
    release dut.profile_first_present_valid;
    release dut.session_active;

    force dut.snapshot_mpeg2 = {2048{1'b1}};
    force dut.snapshot_ready_mpeg2 = 1'b1;
    repeat (4) @(posedge clk_video);

    if (!snapshot_ready)
        $fatal(1, "captured snapshot did not cross while hidden");
    line_start();
    if (video_r !== 8'h12 || video_g !== 8'h34 || video_b !== 8'h56)
        $fatal(1, "default-off telemetry altered base video");

    telemetry_visible = 1;
    repeat (4) @(posedge clk_video);
    line_start();
    if (video_r !== 8'hff || video_g !== 8'hff || video_b !== 8'hff)
        $fatal(1, "live telemetry enable did not reveal captured snapshot");

    telemetry_visible = 0;
    repeat (4) @(posedge clk_video);
    line_start();
    if (video_r !== 8'h12 || video_g !== 8'h34 || video_b !== 8'h56)
        $fatal(1, "live telemetry disable did not restore base video");

    $display("telemetry visibility: hidden capture, live reveal and re-hide pass");
    $finish;
end
endmodule
