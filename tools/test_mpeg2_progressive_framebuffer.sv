`timescale 1ns/1ps

module test_mpeg2_progressive_framebuffer;
reg pixel_en;
reg [11:0] h_pos,v_pos,picture_width;
reg [10:0] picture_height;
wire [11:0] origin_x,origin_y,source_x,source_y;
wire source_window;

mpeg2_progressive_geometry dut(
    .pixel_en(pixel_en),.h_pos(h_pos),.v_pos(v_pos),
    .picture_width(picture_width),.picture_height(picture_height),
    .origin_x(origin_x),.origin_y(origin_y),
    .source_window(source_window),.source_x(source_x),.source_y(source_y)
);

task fail;
input [8*120-1:0] message;
begin $display("FAIL: %0s",message);$fatal(1);end
endtask

initial begin
    pixel_en=1;picture_width=720;picture_height=480;h_pos=0;v_pos=0;#1;
    if(origin_x!=0||origin_y!=0||!source_window||source_x!=0||source_y!=0)
        fail("720x480 progressive origin is not direct raster order");
    h_pos=719;v_pos=479;#1;
    if(!source_window||source_x!=719||source_y!=479)
        fail("720x480 progressive final pixel is not direct raster order");
    h_pos=720;#1;if(source_window)fail("pixel beyond 720x480 was admitted");

    picture_width=352;picture_height=240;h_pos=184;v_pos=120;#1;
    if(origin_x!=184||origin_y!=120||!source_window||source_x!=0||source_y!=0)
        fail("352x240 progressive picture is not centered");
    h_pos=535;v_pos=359;#1;
    if(!source_window||source_x!=351||source_y!=239)
        fail("centered progressive final pixel is wrong");
    h_pos=183;#1;if(source_window)fail("left border entered source window");
    h_pos=536;#1;if(source_window)fail("right border entered source window");
    h_pos=184;v_pos=119;#1;if(source_window)fail("top border entered source window");
    v_pos=360;#1;if(source_window)fail("bottom border entered source window");
    pixel_en=0;h_pos=184;v_pos=120;#1;
    if(source_window)fail("blanked pixel entered source window");

    $display("PASS: progressive framebuffer geometry is centered and sequential");
    $finish;
end
endmodule
