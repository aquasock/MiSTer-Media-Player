`timescale 1ns/1ps

module tb_audio_pcm_output_adapter;
reg clk=0,reset=1;
always #1 clk=~clk;

reg [34:0] fifo_data=0;
reg fifo_empty=1;
reg [11:0] fifo_used=0;
reg source_ended=0;
wire fifo_rd;
wire [15:0] audio_l,audio_r;
wire underrun,playback_complete;

audio_pcm_output_adapter #(.PREFILL_SAMPLES(12'd3)) dut(
    .clk(clk),.reset(reset),.fifo_data(fifo_data),
    .fifo_empty(fifo_empty),.fifo_used(fifo_used),
    .source_ended(source_ended),.fifo_rd(fifo_rd),
    .audio_l(audio_l),.audio_r(audio_r),.underrun(underrun),
    .playback_complete(playback_complete));

initial begin
    repeat(4) @(posedge clk);reset=0;

    // Playback remains silent below the reserve threshold.
    @(negedge clk);fifo_data={1'b0,1'b1,1'b1,16'h1234,16'hFEDC};
    fifo_empty=0;fifo_used=2;
    repeat(32) @(posedge clk);
    if(fifo_rd||audio_l!==16'd0||audio_r!==16'd0||playback_complete)
        $fatal(1,"PCM started below the prefill threshold");

    // Reaching the reserve releases the first sample.
    @(negedge clk);fifo_used=3;
    wait(fifo_rd);@(negedge clk);
    if(audio_l!==16'h1234||audio_r!==16'hFEDC||underrun)
        $fatal(1,"initial PCM sample failed");

    // A later sample after genuine post-start starvation makes the underrun
    // sticky; the reserve is not applied again once playback has started.
    fifo_empty=1;fifo_used=0;
    while(fifo_rd) @(negedge clk);
    repeat(520) @(posedge clk);
    if(audio_l!==16'd0||audio_r!==16'd0||underrun||!dut.starvation_waiting)
        $fatal(1,"post-start starvation was mishandled");

    @(negedge clk);fifo_data={1'b0,1'b1,1'b1,16'h4321,16'hDCBA};
    fifo_empty=0;fifo_used=1;
    wait(fifo_rd);@(negedge clk);
    if(audio_l!==16'h4321||audio_r!==16'hDCBA||!underrun)
        $fatal(1,"true underrun was not reported");

    // A reset starts a short-stream case whose complete payload is below the
    // threshold. The synchronized source-end level must release it.
    reset=1;fifo_empty=1;fifo_used=0;source_ended=0;
    repeat(4) @(posedge clk);reset=0;
    @(negedge clk);fifo_data={1'b0,1'b1,1'b1,16'h2468,16'h1357};
    fifo_empty=0;fifo_used=1;
    repeat(32) @(posedge clk);
    if(fifo_rd)
        $fatal(1,"short PCM started before source end");
    @(negedge clk);source_ended=1;
    wait(fifo_rd);@(negedge clk);
    if(audio_l!==16'h2468||audio_r!==16'h1357||underrun)
        $fatal(1,"source end did not release short PCM");

    // The end token may become visible after the last sample. Empty-before-end
    // remains provisional and must complete without a false underrun.
    fifo_empty=1;fifo_used=0;
    while(fifo_rd) @(negedge clk);
    repeat(520) @(posedge clk);
    if(underrun||!dut.starvation_waiting)
        $fatal(1,"terminal starvation was not provisional");
    @(negedge clk);
    fifo_data={1'b1,34'd0};
    fifo_empty=0;fifo_used=1;
    wait(fifo_rd);@(negedge clk);
    fifo_empty=1;fifo_used=0;
    if(audio_l!==16'd0||audio_r!==16'd0||underrun||dut.started||
       !playback_complete)
        $fatal(1,"PCM end token did not stop cleanly");

    repeat(600) @(posedge clk);
    if(underrun)
        $fatal(1,"idle after a clean end reported underrun");

    $display("AUDIO_PCM_OUTPUT_ADAPTER_PASS prefill=3 short=1 true_underrun=1 clean_end=1");
    $finish;
end
endmodule
