`timescale 1ns/1ps

// Behavioral stand-in for the Intel mixed-width FIFO.  This focused test ties
// both ports to one clock because it validates the wrapper's session-clear and
// readiness contract; Quartus remains responsible for the primitive's built-in
// per-domain asynchronous-clear release synchronizers.
module dcfifo_mixed_widths #(
    parameter lpm_numwords=16384,
    parameter lpm_showahead="ON",
    parameter lpm_type="dcfifo_mixed_widths",
    parameter lpm_width=16,
    parameter lpm_width_r=8,
    parameter lpm_widthu=14,
    parameter lpm_widthu_r=15,
    parameter overflow_checking="ON",
    parameter underflow_checking="ON",
    parameter use_eab="ON",
    parameter rdsync_delaypipe=4,
    parameter wrsync_delaypipe=4,
    parameter write_aclr_synch="ON",
    parameter read_aclr_synch="ON"
)(
    input aclr,
    input [15:0] data,
    input wrclk,
    input wrreq,
    output wire wrfull,
    output wire [13:0] wrusedw,
    output wire wrempty,
    output wire [7:0] q,
    input rdclk,
    input rdreq,
    output wire rdempty
);

reg [7:0] memory [0:32767];
integer write_pointer;
integer read_pointer;
integer byte_count;

assign wrfull  = (byte_count >= 32768);
assign wrusedw = byte_count[14:1];
assign wrempty = (byte_count == 0);
assign rdempty = (byte_count == 0);
assign q = memory[read_pointer];

always @(posedge wrclk or posedge aclr) begin
    if (aclr) begin
        write_pointer <= 0;
        read_pointer  <= 0;
        byte_count    <= 0;
    end
    else begin
        if (wrreq && !wrfull) begin
            memory[write_pointer]     <= data[7:0];
            memory[write_pointer + 1] <= data[15:8];
            write_pointer <= write_pointer + 2;
            byte_count <= byte_count + 2;
        end
        if (rdreq && !rdempty) begin
            read_pointer <= read_pointer + 1;
            byte_count <= byte_count - 1;
        end
    end
end

wire unused = rdclk;
endmodule

module test_mpeg2_stream_fifo;
reg clk=0;
always #5 clk=~clk;

reg reset=1;
reg session_start=0;
reg [15:0] wr_data=0;
reg wr_en=0;
reg wr_attempt=0;
wire wr_full;
wire [14:0] burst_credit;
wire burst_ready;
wire burst_fault;
wire [31:0] burst_words;
wire [15:0] burst_digest;
reg rd_en=0;
wire [7:0] rd_data;
wire rd_empty;

task write_word(input [15:0] value);
begin
    @(negedge clk);
    wr_data=value;
    wr_en=1;
    wr_attempt=1;
    @(negedge clk);
    wr_en=0;
    wr_attempt=0;
end
endtask

task read_byte(input [7:0] expected);
begin
    @(negedge clk);
    if(rd_empty)$fatal(1,"FIFO unexpectedly empty");
    if(rd_data!==expected)$fatal(1,"expected %02x got %02x",expected,rd_data);
    rd_en=1;
    @(negedge clk);
    rd_en=0;
end
endtask

initial begin
    repeat(3)@(posedge clk);
    @(negedge clk);reset=0;
    wait(burst_ready);

    // Leave recognizable stale bytes queued from the old session.
    write_word(16'h2211);
    if(rd_empty)$fatal(1,"old-session word was not queued");

    // Readiness must fall as soon as the new-session event is asserted, the
    // FIFO must become empty, and no writes may be advertised until release.
    @(negedge clk);session_start=1;
    #1;
    if(burst_ready||burst_credit!=0)
        $fatal(1,"session clear did not remove write readiness immediately");
    @(negedge clk);session_start=0;
    if(!rd_empty)$fatal(1,"stale bytes survived session clear");
    repeat(20)begin
        @(negedge clk);
        if(burst_ready)$fatal(1,"FIFO rearmed before reset stretch completed");
    end
    wait(burst_ready);
    if(!rd_empty)$fatal(1,"FIFO not empty after synchronized rearm");

    // Only the first new-session word may emerge after rearm.
    write_word(16'hbbaa);
    read_byte(8'haa);
    read_byte(8'hbb);
    if(!rd_empty)$fatal(1,"unexpected residual byte after new-session word");
    if(burst_words!=2)$fatal(1,"rolling accepted-word counter reset: %0d",burst_words);
    $display("mpeg2 stream fifo: stale session flushed and first new word retained");
    $finish;
end

mpeg2_stream_fifo dut(
    .reset(reset),.session_start(session_start),
    .wr_clk(clk),.wr_data(wr_data),.wr_en(wr_en),.wr_full(wr_full),
    .wr_attempt(wr_attempt),.burst_credit(burst_credit),
    .burst_ready(burst_ready),.burst_fault(burst_fault),
    .burst_words(burst_words),.burst_digest(burst_digest),
    .rd_clk(clk),.rd_en(rd_en),.rd_data(rd_data),.rd_empty(rd_empty));
endmodule
