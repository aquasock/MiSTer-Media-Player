`timescale 1ns/1ps

module tb_audio_pcm_output_adapter;
reg clk=0,reset=1;
always #1 clk=~clk;

reg [34:0] fifo_data=0;
reg fifo_empty=1;
wire fifo_rd;
wire [15:0] audio_l,audio_r;
wire underrun;

audio_pcm_output_adapter dut(
    .clk(clk),.reset(reset),.fifo_data(fifo_data),
    .fifo_empty(fifo_empty),.fifo_rd(fifo_rd),
    .audio_l(audio_l),.audio_r(audio_r),.underrun(underrun));

initial begin
    repeat(4) @(posedge clk);reset=0;

    // A 48 kHz stereo sample is consumed immediately from idle.
    @(negedge clk);fifo_data={1'b0,1'b1,1'b1,16'h1234,16'hFEDC};
    fifo_empty=0;
    wait(fifo_rd);@(negedge clk);
    if(audio_l!==16'h1234||audio_r!==16'hFEDC||underrun)
        $fatal(1,"initial PCM sample failed");

    // The end token may arrive after the FIFO becomes empty because video bytes
    // can separate the final PCM record from the stream terminator. Starvation
    // is provisional until either another sample (real underrun) or end arrives.
    fifo_empty=1;
    while(fifo_rd) @(negedge clk);
    repeat(520) @(posedge clk);
    if(audio_l!==16'd0||audio_r!==16'd0||underrun||!dut.starvation_waiting)
        $fatal(1,"provisional terminal starvation was mishandled");

    fifo_data={1'b1,34'd0};
    fifo_empty=0;
    wait(fifo_rd);@(negedge clk);
    fifo_empty=1;
    if(audio_l!==16'd0||audio_r!==16'd0||underrun||dut.started)
        $fatal(1,"PCM end token did not stop cleanly");

    repeat(600) @(posedge clk);
    if(underrun)
        $fatal(1,"idle after a clean end reported underrun");

    $display("AUDIO_PCM_OUTPUT_ADAPTER_PASS sample=1 clean_end=1 underrun=0");
    $finish;
end
endmodule
