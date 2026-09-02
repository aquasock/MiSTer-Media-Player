`timescale 1ns/1ps

module test_telemetry_visibility;
reg clk_mpeg2 = 0;
reg clk_video = 0;
reg reset_mpeg2 = 1;
reg reset_video = 1;
reg telemetry_visible = 0;
reg [11:0] h_pos = 0;
reg [11:0] v_pos = 12'd224;
wire [7:0] video_r;
wire [7:0] video_g;
wire [7:0] video_b;
wire snapshot_ready;

always #4 clk_mpeg2 = ~clk_mpeg2;
always #5 clk_video = ~clk_video;

mpeg2_h262_hardware_cadence_profiler dut (
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

initial begin
    repeat (4) @(posedge clk_video);
    reset_mpeg2 = 0;
    reset_video = 0;
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
