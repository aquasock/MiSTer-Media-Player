`timescale 1ns/1ps

module test_mpeg2_output_timing;
reg clk=0,reset=1,interlaced_request=0,top_field_first=1;
wire interlaced_active,ce_pixel,pixel_en,h_sync,v_sync,field;
wire field_window,field_swap_window,frame_window;
wire [11:0] h_pos,v_pos;
integer total_count,active_count,hsync_count,vsync_count,blank_count;
integer field_count,field_active_count;
reg initial_field;

always #5 clk=~clk;

mpeg2_video_output_timing dut(
    .clk(clk),.reset(reset),
    .interlaced_request_async(interlaced_request),
    .top_field_first_async(top_field_first),
    .interlaced_active(interlaced_active),.ce_pixel(ce_pixel),
    .h_pos(h_pos),.v_pos(v_pos),.pixel_en(pixel_en),
    .h_sync(h_sync),.v_sync(v_sync),.field(field),
    .field_window(field_window),.field_swap_window(field_swap_window),
    .frame_window(frame_window)
);

task fail;
input [8*120-1:0] message;
begin $display("FAIL: %0s",message);$fatal(1);end
endtask

task wait_progressive_origin;
begin
    while(interlaced_active || !ce_pixel || h_pos!=0 || v_pos!=0)
        @(negedge clk);
end
endtask

task check_progressive_frame;
begin
    wait_progressive_origin();
    total_count=0;active_count=0;hsync_count=0;vsync_count=0;blank_count=0;
    begin : progressive_loop
        forever begin
            if(!ce_pixel) fail("progressive sample lost pixel enable");
            total_count=total_count+1;
            if(pixel_en) active_count=active_count+1;
            if(!h_sync) hsync_count=hsync_count+1;
            if(!v_sync) vsync_count=vsync_count+1;
            if(frame_window) blank_count=blank_count+1;
            @(negedge clk);
            while(!ce_pixel) @(negedge clk);
            if(h_pos==0 && v_pos==0) disable progressive_loop;
        end
    end
    if(total_count!=450450) fail("progressive total is not 858x525");
    if(active_count!=345600) fail("progressive active region is not 720x480");
    if(hsync_count!=32550) fail("progressive hsync is not 62 samples per line");
    if(vsync_count!=5148) fail("progressive vsync is not six complete lines");
    if(blank_count!=38610) fail("progressive frame window is not 45 lines");
    if(field!==1'b0) fail("progressive output asserted field identity");
end
endtask

task check_one_interlaced_field;
begin
    initial_field=field;field_count=0;field_active_count=0;
    begin : field_loop
        forever begin
            @(negedge clk);
            if(ce_pixel) begin
                if(field!=initial_field) disable field_loop;
                field_count=field_count+1;
                if(pixel_en) field_active_count=field_active_count+1;
            end
        end
    end
    if(field_count!=225225) fail("interlaced field duration changed");
    if(field_active_count!=172800) fail("interlaced field active area changed");
end
endtask

initial begin
    repeat(6) @(posedge clk);reset=0;
    check_progressive_frame();

    // TFF request may take effect only after the current progressive frame.
    interlaced_request=1;
    while(!interlaced_active) @(negedge clk);
    if(field!==1'b0 || h_pos!=0 || v_pos!=0)
        fail("TFF interlaced entry did not start at top-field origin");
    check_one_interlaced_field();

    interlaced_request=0;
    while(interlaced_active) @(negedge clk);
    if(h_pos!=0 || v_pos!=0 || field!==1'b0)
        fail("interlaced exit did not return at progressive frame origin");
    check_progressive_frame();

    // BFF entry retains the accepted half-line phase.
    top_field_first=0;interlaced_request=1;
    while(!interlaced_active) @(negedge clk);
    if(field!==1'b1 || h_pos!=429 || pixel_en!==1'b0)
        fail("BFF interlaced entry lost bottom-field half-line phase");
    interlaced_request=0;
    while(interlaced_active) @(negedge clk);

    $display("PASS: exact 480p timing and frame-safe 480i transitions");
    $finish;
end
endmodule
