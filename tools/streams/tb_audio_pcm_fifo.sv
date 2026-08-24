`timescale 1ns/1ps

// Focused wrapper proof using a behavioral model of Intel's dcfifo primitive.
// The production wrapper itself is compiled unchanged; this model verifies its
// configured depth, full/empty boundaries, show-ahead order and independent
// write/read clocks without requiring Quartus simulation libraries.
module tb_audio_pcm_fifo;
reg reset = 1'b1;
reg wr_clk = 1'b0;
reg rd_clk = 1'b0;
always #5 wr_clk = ~wr_clk;
always #7 rd_clk = ~rd_clk;

reg [34:0] wr_data = 35'd0;
reg wr_en = 1'b0;
wire wr_full;
wire [12:0] wr_used;
reg rd_en = 1'b0;
wire [34:0] rd_data;
wire rd_empty;
wire [12:0] rd_used;
integer index;

audio_pcm_fifo dut(
    .reset(reset),
    .wr_clk(wr_clk), .wr_data(wr_data), .wr_en(wr_en),
    .wr_full(wr_full), .wr_used(wr_used),
    .rd_clk(rd_clk), .rd_en(rd_en), .rd_data(rd_data),
    .rd_empty(rd_empty), .rd_used(rd_used));

initial begin
    repeat (4) @(posedge wr_clk);
    reset = 1'b0;

    for (index = 0; index < 8192; index = index + 1) begin
        @(negedge wr_clk);
        if (wr_full)
            $fatal(1, "FIFO became full early at %0d", index);
        wr_data = {3'b011, index[15:0], ~index[15:0]};
        wr_en = 1'b1;
        @(posedge wr_clk);
        if (index == 4095 && wr_full)
            $fatal(1, "FIFO retained the obsolete 4096-sample depth");
    end
    @(negedge wr_clk);
    wr_en = 1'b0;
    if (!wr_full || wr_used != 13'h1fff)
        $fatal(1, "8192-sample full boundary failed: full=%0d used=%0d",
               wr_full, wr_used);

    for (index = 0; index < 8192; index = index + 1) begin
        @(negedge rd_clk);
        if (rd_empty)
            $fatal(1, "FIFO became empty early at %0d", index);
        if (rd_data !== {3'b011, index[15:0], ~index[15:0]})
            $fatal(1, "show-ahead data mismatch at %0d", index);
        rd_en = 1'b1;
        @(posedge rd_clk);
    end
    @(negedge rd_clk);
    rd_en = 1'b0;
    if (!rd_empty || rd_used != 13'd0)
        $fatal(1, "empty boundary failed: empty=%0d used=%0d",
               rd_empty, rd_used);

    $display("AUDIO_PCM_FIFO_PASS depth=8192 clocks=independent order=exact");
    $finish;
end
endmodule


module dcfifo #(
    parameter integer lpm_numwords = 8192,
    parameter lpm_showahead = "ON",
    parameter lpm_type = "dcfifo",
    parameter integer lpm_width = 35,
    parameter integer lpm_widthu = 13,
    parameter overflow_checking = "ON",
    parameter underflow_checking = "ON",
    parameter use_eab = "ON",
    parameter integer rdsync_delaypipe = 4,
    parameter integer wrsync_delaypipe = 4,
    parameter write_aclr_synch = "ON",
    parameter read_aclr_synch = "ON"
)(
    input wire aclr,
    input wire [lpm_width-1:0] data,
    input wire wrclk,
    input wire wrreq,
    output wire wrfull,
    output wire [lpm_widthu-1:0] wrusedw,
    output wire [lpm_width-1:0] q,
    input wire rdclk,
    input wire rdreq,
    output wire rdempty,
    output wire [lpm_widthu-1:0] rdusedw
);
reg [lpm_width-1:0] memory [0:lpm_numwords-1];
integer write_count = 0;
integer read_count = 0;
wire [lpm_widthu:0] occupancy = write_count - read_count;

assign wrfull = occupancy >= lpm_numwords;
assign rdempty = occupancy == 0;
assign wrusedw = wrfull ? {lpm_widthu{1'b1}} : occupancy[lpm_widthu-1:0];
assign rdusedw = wrusedw;
assign q = memory[read_count % lpm_numwords];

always @(posedge wrclk or posedge aclr) begin
    if (aclr)
        write_count <= 0;
    else if (wrreq && !wrfull) begin
        memory[write_count % lpm_numwords] <= data;
        write_count <= write_count + 1;
    end
end

always @(posedge rdclk or posedge aclr) begin
    if (aclr)
        read_count <= 0;
    else if (rdreq && !rdempty)
        read_count <= read_count + 1;
end
endmodule
