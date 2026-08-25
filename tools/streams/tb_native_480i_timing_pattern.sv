`timescale 1ns/1ps

module tb_native_480i_timing_pattern;
reg clk = 0;
reg reset = 1;
reg moving = 0;
reg frame_window = 0;
reg [11:0] h_pos = 0;
reg [11:0] v_pos = 0;
reg pixel_en = 0;
reg h_sync = 0;
reg v_sync = 0;
wire [7:0] r,g,b;
wire de,hs,vs;

always #5 clk = ~clk;

mpeg2_native_timing_pattern dut
(
    .clk(clk),.reset(reset),.moving(moving),.frame_window(frame_window),
    .h_pos(h_pos),.v_pos(v_pos),.pixel_en(pixel_en),
    .h_sync(h_sync),.v_sync(v_sync),
    .video_r(r),.video_g(g),.video_b(b),.video_de(de),
    .video_hs(hs),.video_vs(vs)
);

task automatic expect_rgb(
    input [11:0] x,input [7:0] er,input [7:0] eg,input [7:0] eb);
begin
    h_pos=x; pixel_en=1'b1; #1;
    if ({r,g,b,de} !== {er,eg,eb,1'b1})
        $fatal(1,"x=%0d rgb=%02x%02x%02x de=%0d",x,r,g,b,de);
end
endtask

task automatic expect_moving_rgb(
    input [11:0] x,input [11:0] y,
    input [7:0] er,input [7:0] eg,input [7:0] eb);
begin
    h_pos=x; v_pos=y; pixel_en=1'b1; #1;
    if ({r,g,b,de} !== {er,eg,eb,1'b1})
        $fatal(1,"moving x=%0d y=%0d rgb=%02x%02x%02x de=%0d",
               x,y,r,g,b,de);
end
endtask

task automatic pulse_frame_window;
begin
    @(negedge clk); frame_window=1'b1;
    @(negedge clk); frame_window=1'b0;
    @(negedge clk);
end
endtask

task automatic pulse_frames(input integer count);
integer n;
begin
    for (n=0;n<count;n=n+1)
        pulse_frame_window();
end
endtask

initial begin
    h_sync=1'b1; v_sync=1'b0; #1;
    if (!hs || vs) $fatal(1,"sync passthrough failed");
    pixel_en=1'b0; h_pos=12'd350; #1;
    if ({r,g,b,de} !== 25'd0) $fatal(1,"blanking was not black");
    expect_rgb(12'd0,   8'hbf,8'hbf,8'hbf);
    expect_rgb(12'd90,  8'hbf,8'hbf,8'h00);
    expect_rgb(12'd180, 8'h00,8'hbf,8'hbf);
    expect_rgb(12'd270, 8'h00,8'hbf,8'h00);
    expect_rgb(12'd360, 8'hbf,8'h00,8'hbf);
    expect_rgb(12'd450, 8'hbf,8'h00,8'h00);
    expect_rgb(12'd540, 8'h00,8'h00,8'hbf);
    expect_rgb(12'd630, 8'h10,8'h10,8'h10);

    repeat (3) @(negedge clk);
    reset=1'b0;
    moving=1'b1;
    @(negedge clk);

    expect_moving_rgb(12'd47,12'd200,8'h10,8'h10,8'h10);
    expect_moving_rgb(12'd48,12'd200,8'hbf,8'hbf,8'hbf);
    expect_moving_rgb(12'd63,12'd201,8'hbf,8'hbf,8'hbf);
    expect_moving_rgb(12'd64,12'd201,8'h10,8'h10,8'h10);
    expect_moving_rgb(12'd0,12'd120,8'h50,8'h50,8'h50);
    expect_moving_rgb(12'd0,12'd121,8'h50,8'h50,8'h50);

    pulse_frames(28);
    @(negedge clk); frame_window=1'b1;
    repeat (8) @(negedge clk);
    frame_window=1'b0;
    @(negedge clk);
    expect_moving_rgb(12'd48,12'd200,8'hbf,8'hbf,8'hbf);
    pulse_frame_window();
    expect_moving_rgb(12'd48,12'd200,8'h10,8'h10,8'h10);
    expect_moving_rgb(12'd144,12'd200,8'hbf,8'hbf,8'hbf);

    pulse_frames(150);
    expect_moving_rgb(12'd624,12'd200,8'hbf,8'hbf,8'hbf);
    pulse_frames(30);
    expect_moving_rgb(12'd48,12'd200,8'hbf,8'hbf,8'hbf);

    pixel_en=1'b0; #1;
    if ({r,g,b,de} !== 25'd0) $fatal(1,"moving blanking was not black");
    $display({"NATIVE_TIMING_PATTERN_PASS static_bars=8 moving_hold=30 ",
              "moving_step=96 moving_positions=7 field_invariant=1"});
    $finish;
end
endmodule
