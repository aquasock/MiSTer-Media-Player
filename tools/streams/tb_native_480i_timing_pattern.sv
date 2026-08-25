`timescale 1ns/1ps

module tb_native_480i_timing_pattern;
reg [11:0] h_pos = 0;
reg pixel_en = 0;
reg h_sync = 0;
reg v_sync = 0;
wire [7:0] r,g,b;
wire de,hs,vs;

mpeg2_native_timing_pattern dut
(
    .h_pos(h_pos),.pixel_en(pixel_en),.h_sync(h_sync),.v_sync(v_sync),
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
    $display("NATIVE_TIMING_PATTERN_PASS field_invariant=1 bars=8");
    $finish;
end
endmodule
