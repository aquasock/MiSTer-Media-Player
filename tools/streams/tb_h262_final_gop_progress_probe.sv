`timescale 1ns/1ps

module tb_h262_final_gop_progress_probe;
    reg clk=0,reset=1,picture_header=0,picture_complete=0;
    reg [2:0] picture_header_type=0,picture_coding_type=0;
    reg sideband_valid=0,row_persisted=0,picture_persisted=0;
    reg [5:0] sideband_index=0;
    reg b_success=0,display_scratch=0,presentation_complete=0;
    wire [4:0] progress_stage;

    always #5 clk=~clk;

    mpeg2_h262_final_gop_progress_probe dut(
        .clk(clk),.reset(reset),.picture_header(picture_header),
        .picture_header_type(picture_header_type),
        .picture_complete(picture_complete),
        .picture_coding_type(picture_coding_type),
        .sideband_valid(sideband_valid),.sideband_index(sideband_index),
        .row_persisted(row_persisted),
        .picture_persisted(picture_persisted),.b_success(b_success),
        .display_scratch(display_scratch),
        .presentation_complete(presentation_complete),
        .progress_stage(progress_stage));

    task automatic pulse_header;
        input [2:0] kind;
        begin
            @(negedge clk);picture_header_type<=kind;picture_header<=1;
            @(negedge clk);picture_header<=0;
        end
    endtask

    task automatic pulse_picture;
        input [2:0] kind;
        begin
            @(negedge clk);picture_coding_type<=kind;picture_complete<=1;
            @(negedge clk);picture_complete<=0;
        end
    endtask

    task automatic expect_stage;
        input [4:0] expected;
        begin
            #1;
            if(progress_stage!==expected)
                $fatal(1,"stage expected %0d got %0d",expected,progress_stage);
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);@(negedge clk);reset<=0;

        // Pre-third-GOP activity must not arm the probe.
        pulse_header(3'b001);pulse_picture(3'b001);
        pulse_header(3'b010);
        @(negedge clk);sideband_index<=6'h3e;sideband_valid<=1;
        @(negedge clk);sideband_valid<=0;
        pulse_header(3'b001);pulse_picture(3'b001);
        expect_stage(0);

        pulse_header(3'b001);expect_stage(1);
        pulse_picture(3'b001);expect_stage(2);
        pulse_header(3'b010);expect_stage(3);

        @(negedge clk);sideband_index<=6'h3e;sideband_valid<=1;
        @(negedge clk);sideband_valid<=0;expect_stage(4);
        @(negedge clk);row_persisted<=1;
        @(negedge clk);row_persisted<=0;expect_stage(5);
        @(negedge clk);picture_persisted<=1;
        @(negedge clk);picture_persisted<=0;expect_stage(6);
        pulse_picture(3'b010);expect_stage(7);
        pulse_header(3'b011);expect_stage(8);
        @(negedge clk);b_success<=1;
        @(negedge clk);b_success<=0;expect_stage(9);
        @(negedge clk);display_scratch<=1;
        @(negedge clk);expect_stage(10);
        presentation_complete<=1;
        @(negedge clk);expect_stage(11);

        // Later activity cannot lower the deepest stage.
        picture_header<=1;picture_header_type<=3'b001;
        @(negedge clk);picture_header<=0;presentation_complete<=0;
        expect_stage(11);

        reset<=1;@(negedge clk);expect_stage(0);
        $display("FINAL_GOP_PROGRESS_RESULT stages=11 reset=1");
        $finish;
    end

    initial begin repeat(200)@(posedge clk);$fatal(1,"progress test timed out");end
endmodule
