`timescale 1ns/1ps

module tb_h262_luma_write_fingerprint;

reg clk = 1'b0;
reg reset = 1'b1;
reg writer_accept = 1'b0;
reg luma_word = 1'b0;
reg [2:0] luma_region = 3'd0;
reg luma_row_parity = 1'b0;
reg luma_picture_start = 1'b0;
reg luma_picture_complete = 1'b0;
reg [31:0] luma_position_fingerprint = 32'd0;
reg [2:0] display_region = 3'd0;
wire [31:0] expected_even_fingerprint;
wire [31:0] expected_odd_fingerprint;
wire expected_valid;

always #5 clk = ~clk;

mpeg2_h262_luma_write_fingerprint dut
(
    .clk(clk),
    .reset(reset),
    .writer_accept(writer_accept),
    .luma_word(luma_word),
    .luma_region(luma_region),
    .luma_row_parity(luma_row_parity),
    .luma_picture_start(luma_picture_start),
    .luma_picture_complete(luma_picture_complete),
    .luma_position_fingerprint(luma_position_fingerprint),
    .display_region(display_region),
    .expected_even_fingerprint(expected_even_fingerprint),
    .expected_odd_fingerprint(expected_odd_fingerprint),
    .expected_valid(expected_valid)
);

task accept_word;
    input [2:0] region;
    input parity;
    input start_picture;
    input complete_picture;
    input [31:0] fingerprint;
begin
    @(negedge clk);
    writer_accept = 1'b1;
    luma_word = 1'b1;
    luma_region = region;
    luma_row_parity = parity;
    luma_picture_start = start_picture;
    luma_picture_complete = complete_picture;
    luma_position_fingerprint = fingerprint;
    @(negedge clk);
    writer_accept = 1'b0;
    luma_word = 1'b0;
    luma_picture_start = 1'b0;
    luma_picture_complete = 1'b0;
end
endtask

initial begin
    repeat (3) @(posedge clk);
    reset = 1'b0;

    accept_word(3'd4,1'b0,1'b1,1'b0,32'h00000011);
    accept_word(3'd4,1'b1,1'b0,1'b0,32'h00000022);

    // A nonaccepted and a nonluma request must be invisible.
    @(negedge clk);
    luma_word = 1'b1;
    luma_region = 3'd4;
    luma_position_fingerprint = 32'hffffffff;
    @(negedge clk);
    luma_word = 1'b0;
    writer_accept = 1'b1;
    luma_position_fingerprint = 32'heeeeeeee;
    @(negedge clk);
    writer_accept = 1'b0;

    accept_word(3'd4,1'b0,1'b0,1'b0,32'h00000100);
    accept_word(3'd4,1'b1,1'b0,1'b1,32'h00000200);
    display_region = 3'd4;
    #1;
    if (!expected_valid ||
        (expected_even_fingerprint !== 32'h00000111) ||
        (expected_odd_fingerprint !== 32'h00000222))
        $fatal(1,"region-four fingerprint mismatch %0d %h/%h",
               expected_valid,expected_even_fingerprint,
               expected_odd_fingerprint);

    // Regions are retained independently and a new picture clears validity.
    accept_word(3'd1,1'b0,1'b1,1'b0,32'h00000044);
    accept_word(3'd1,1'b1,1'b0,1'b1,32'h00000088);
    display_region = 3'd1;
    #1;
    if (!expected_valid ||
        (expected_even_fingerprint !== 32'h00000044) ||
        (expected_odd_fingerprint !== 32'h00000088))
        $fatal(1,"region-one fingerprint mismatch");
    display_region = 3'd4;
    #1;
    if (!expected_valid ||
        (expected_even_fingerprint !== 32'h00000111) ||
        (expected_odd_fingerprint !== 32'h00000222))
        $fatal(1,"region-four fingerprint was not retained");
    accept_word(3'd4,1'b0,1'b1,1'b0,32'h00001000);
    #1;
    if (expected_valid ||
        (expected_even_fingerprint !== 32'h00001000) ||
        (expected_odd_fingerprint !== 32'd0))
        $fatal(1,"new picture did not reset selected region");

    $display("LUMA_WRITE_FINGERPRINT_PASS");
    $finish;
end

initial begin
    #10000;
    $fatal(1,"timeout");
end

endmodule
