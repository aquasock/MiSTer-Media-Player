`timescale 1ns/1ps

module test_h262_restart_normalization;

localparam integer PREFIX_BYTES = 191;
localparam [PREFIX_BYTES*8-1:0] CAPTURED_PREFIX = {
    256'h000001b32d01e024138823821010101010101010101010101010101010101010,
    256'h1010101010101010101010101010101010101010101010101010101010101010,
    256'h1010101010101010101010110808080808080808080808080808080808080808,
    256'h0808080808080808080808080808080808080808080808080808080808080808,
    256'h080808080808080808080808000001b5148200010000000001b5250606060872,
    248'h0f00000001b88008004000000100000a23e0000001b58ffff3c08000000101
};

reg clk = 1'b0;
reg reset = 1'b1;
reg [7:0] stream_data = 8'd0;
reg stream_valid = 1'b0;
wire frontend_ready;
wire phase1_supported;
wire native_film_supported;
wire syntax_error;
wire [4:0] syntax_error_source;
wire slice_seen;
wire progressive_sequence;
wire [1:0] chroma_format;
wire [2:0] picture_coding_type;
wire [1:0] picture_structure;
wire progressive_frame;
wire chroma_420_type;

always #5 clk = ~clk;

mpeg2_h262_frontend dut (
    .clk(clk),
    .reset(reset),
    .stream_data(stream_data),
    .stream_valid(stream_valid),
    .frontend_ready(frontend_ready),
    .phase1_supported(phase1_supported),
    .native_film_supported(native_film_supported),
    .syntax_error(syntax_error),
    .syntax_error_source(syntax_error_source),
    .slice_seen(slice_seen),
    .progressive_sequence(progressive_sequence),
    .chroma_format(chroma_format),
    .picture_coding_type(picture_coding_type),
    .picture_structure(picture_structure),
    .progressive_frame(progressive_frame),
    .chroma_420_type(chroma_420_type)
);

task reset_dut;
begin
    @(negedge clk);
    reset = 1'b1;
    stream_valid = 1'b0;
    stream_data = 8'd0;
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
end
endtask

task feed_prefix;
    input integer normalize;
    integer index;
    reg [7:0] value;
begin
    for (index = 0; index < PREFIX_BYTES; index = index + 1) begin
        value = CAPTURED_PREFIX[(PREFIX_BYTES-index)*8-1 -: 8];
        if (normalize != 0 && index == 185)
            value = value | 8'h01;
        @(negedge clk);
        stream_data = value;
        stream_valid = 1'b1;
    end
    @(negedge clk);
    stream_valid = 1'b0;
    stream_data = 8'd0;
    repeat (3) @(posedge clk);
end
endtask

initial begin
    reset_dut();
    feed_prefix(0);
    if (!syntax_error || syntax_error_source != 5'd21)
        $fatal(1, "captured prefix did not raise syntax source 21");
    if (!slice_seen)
        $fatal(1, "captured prefix did not reach its first slice");
    if (progressive_sequence || chroma_format != 2'b01 ||
        picture_coding_type != 3'b001 || picture_structure != 2'b11 ||
        !progressive_frame || chroma_420_type)
        $fatal(1, "captured prefix fields changed");

    reset_dut();
    feed_prefix(1);
    if (syntax_error)
        $fatal(1, "normalized prefix retained syntax error source %0d",
               syntax_error_source);
    if (!slice_seen || !frontend_ready || !phase1_supported ||
        !native_film_supported)
        $fatal(1, "normalized prefix was not admitted");
    if (progressive_sequence || chroma_format != 2'b01 ||
        picture_coding_type != 3'b001 || picture_structure != 2'b11 ||
        !progressive_frame || !chroma_420_type)
        $fatal(1, "normalized prefix fields are not the expected film frame");

    $display("H262 restart normalization: source 21 clears and first slice is admitted");
    $finish;
end

endmodule
