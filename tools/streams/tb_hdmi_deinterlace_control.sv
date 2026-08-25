`timescale 1ns/1ps

module tb_hdmi_deinterlace_control;

reg clk = 1'b0;
reg reset = 1'b1;
reg native_interlaced = 1'b0;
reg bob_selected_async = 1'b0;
wire hdmi_bob_deint;
integer errors = 0;

mpeg2_hdmi_deinterlace_control dut
(
    .clk                (clk),
    .reset              (reset),
    .native_interlaced  (native_interlaced),
    .bob_selected_async (bob_selected_async),
    .hdmi_bob_deint     (hdmi_bob_deint)
);

always #5 clk = ~clk;

task expect_bob;
    input expected;
    input [8*80-1:0] message;
    begin
        #1;
        if (hdmi_bob_deint !== expected) begin
            $display("FAIL %0s got=%0b expected=%0b",
                     message, hdmi_bob_deint, expected);
            errors = errors + 1;
        end
    end
endtask

initial begin
    native_interlaced = 1'b1;
    repeat (2) @(posedge clk);
    expect_bob(1'b0, "reset forces weave");

    reset = 1'b0;
    repeat (3) @(posedge clk);
    expect_bob(1'b0, "native weave remains disabled");

    bob_selected_async = 1'b1;
    repeat (3) @(posedge clk);
    expect_bob(1'b1, "native bob selection asserts request");

    native_interlaced = 1'b0;
    expect_bob(1'b0, "progressive output suppresses bob");

    bob_selected_async = 1'b0;
    repeat (3) @(posedge clk);
    native_interlaced = 1'b1;
    expect_bob(1'b0, "return to native weave stays disabled");

    bob_selected_async = 1'b1;
    repeat (3) @(posedge clk);
    expect_bob(1'b1, "second native bob selection asserts request");

    reset = 1'b1;
    @(posedge clk);
    expect_bob(1'b0, "reset clears synchronized selection");

    if (errors != 0)
        $fatal(1, "HDMI deinterlace control errors=%0d", errors);

    $display("RESULT progressive=weave native_weave=0 native_bob=1 PASS");
    $finish;
end

endmodule
