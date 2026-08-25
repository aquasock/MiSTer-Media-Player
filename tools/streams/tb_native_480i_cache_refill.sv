`timescale 1ns/1ps

module altsyncram #(
    parameter operation_mode="", width_a=1, widthad_a=1, numwords_a=1,
    width_b=1, widthad_b=1, numwords_b=1, outdata_reg_b="",
    address_reg_b="", read_during_write_mode_mixed_ports="",
    ram_block_type="", intended_device_family=""
)(
    input clock0, input clock1,
    input [widthad_a-1:0] address_a,
    input [width_a-1:0] data_a, input wren_a,
    input [widthad_b-1:0] address_b,
    output [width_b-1:0] q_b,
    input aclr0, input aclr1, input addressstall_a, input addressstall_b,
    input byteena_a, input byteena_b,
    input [width_b-1:0] data_b, input wren_b,
    output [width_a-1:0] q_a
);
assign q_b = {width_b{1'b0}};
assign q_a = {width_a{1'b0}};
endmodule

module tb_native_480i_cache_refill;

reg mem_clk = 1'b0;
reg rd_clk = 1'b0;
reg reset = 1'b1;
reg picture_complete = 1'b0;
reg running = 1'b0;
reg [1:0] ce_div = 2'd0;
reg [11:0] h_pos = 12'd0;
reg [8:0] sequence_line = 9'd0;

always #8.333 mem_clk = ~mem_clk;
always #9.259 rd_clk = ~rd_clk;

wire pixel_ce = (ce_div == 2'd3);
wire pixel_en = running && (h_pos < 12'd720);
wire [11:0] v_pos = {3'd0, sequence_line[7:0], 1'b0};

wire [7:0] ddram_burstcnt;
wire [28:0] ddram_addr;
wire ddram_rd;
reg [63:0] ddram_dout = 64'h8080808080808080;
reg ddram_dout_ready = 1'b0;
wire cache_ready;
wire read_seen;
wire cache_error;
wire bank_overlap_error;
wire [7:0] video_r;
wire [7:0] video_g;
wire [7:0] video_b;
wire video_de;
wire video_hs;
wire video_vs;

mpeg2_luma_framebuffer dut
(
    .reset              (reset),
    .mem_clk            (mem_clk),
    .picture_complete   (picture_complete),
    .horizontal_size    (14'd720),
    .vertical_size      (14'd480),
    .native_interlaced  (1'b1),
    .top_field_first    (1'b1),
    .ddram_busy         (1'b0),
    .ddram_dout         (ddram_dout),
    .ddram_dout_ready   (ddram_dout_ready),
    .ddram_burstcnt     (ddram_burstcnt),
    .ddram_addr         (ddram_addr),
    .ddram_rd           (ddram_rd),
    .cache_ready        (cache_ready),
    .read_seen          (read_seen),
    .cache_error        (cache_error),
    .bank_overlap_error (bank_overlap_error),
    .rd_clk             (rd_clk),
    .h_pos              (h_pos),
    .v_pos              (v_pos),
    .pixel_ce           (pixel_ce),
    .pixel_en           (pixel_en),
    .h_sync             (1'b1),
    .v_sync             (1'b1),
    .video_r            (video_r),
    .video_g            (video_g),
    .video_b            (video_b),
    .video_de           (video_de),
    .video_hs           (video_hs),
    .video_vs           (video_vs)
);

integer response_latency;
integer response_delay = 0;
integer response_words = 0;
reg slow_mode = 1'b0;

always @(posedge mem_clk) begin
    ddram_dout_ready <= 1'b0;

    if (reset) begin
        response_delay <= 0;
        response_words <= 0;
    end
    else if ((response_words == 0) && ddram_rd) begin
        response_delay <= response_latency;
        response_words <= ddram_burstcnt;
    end
    else if (response_words != 0) begin
        if (response_delay != 0)
            response_delay <= response_delay - 1;
        else begin
            ddram_dout_ready <= 1'b1;
            response_words <= response_words - 1;
        end
    end
end

always @(posedge rd_clk) begin
    ce_div <= ce_div + 2'd1;
    if (reset) begin
        ce_div <= 2'd0;
        h_pos <= 12'd0;
        sequence_line <= 9'd0;
    end
    else if (pixel_ce && running) begin
        if (h_pos == 12'd857) begin
            h_pos <= 12'd0;
            sequence_line <= sequence_line + 9'd1;
            if (sequence_line == 9'd11)
                running <= 1'b0;
        end
        else begin
            h_pos <= h_pos + 12'd1;
        end
    end
end

initial begin
    slow_mode = $test$plusargs("SLOW");
    response_latency = slow_mode ? 3400 : 64;

    repeat (8) @(posedge mem_clk);
    reset = 1'b0;
    @(posedge mem_clk);
    picture_complete = 1'b1;
    @(posedge mem_clk);
    picture_complete = 1'b0;

    wait (cache_ready);
    repeat (8) @(posedge rd_clk);
    running = 1'b1;
    wait (!running);
    repeat (400) @(posedge mem_clk);

    if (slow_mode) begin
        if (!bank_overlap_error)
            $fatal(1, "late DDR return did not flag cache-bank overlap");
        $display({"NATIVE_CACHE_REFILL_PASS mode=delayed overlap=1 ",
                  "latency=3400"});
    end
    else begin
        if (cache_error || bank_overlap_error)
            $fatal(1, "ordinary DDR service flagged cache error %0d/%0d",
                   cache_error, bank_overlap_error);
        $display({"NATIVE_CACHE_REFILL_PASS mode=ordinary overlap=0 ",
                  "latency=64"});
    end
    $finish;
end

initial begin
    #5000000;
    $fatal(1, "timeout");
end

endmodule
