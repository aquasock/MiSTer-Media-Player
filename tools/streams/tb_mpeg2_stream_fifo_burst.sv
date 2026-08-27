`timescale 1ns/1ps
// Use Quartus's installed altera_mf.v, not the lightweight regression FIFO stub.
// Example: iverilog -g2012 -s tb_mpeg2_stream_fifo_burst -o fifo.vvp \
// rtl/mpeg2_stream_fifo.sv tools/streams/tb_mpeg2_stream_fifo_burst.sv \
// "$QUARTUS_ROOTDIR/eda/sim_lib/altera_mf.v" && vvp fifo.vvp
module tb_mpeg2_stream_fifo_burst;
reg reset=1, wr_clk=0, rd_clk=0, wr_en=0, wr_attempt=0, rd_en=0;
reg [15:0] wr_data=0;
wire wr_full, rd_empty, burst_ready, burst_fault;
wire [7:0] rd_data;
wire [14:0] burst_credit;
wire [31:0] burst_words;
wire [15:0] burst_digest;
integer rd_half=7;
always #5 wr_clk=~wr_clk;
always begin #(rd_half) rd_clk=~rd_clk; end
mpeg2_stream_fifo dut(.*);
`ifdef FIFO_CYCLONE_V
// Quartus synthesis targets Cyclone V; also run the model's literal default.
defparam dut.stream_fifo.intended_device_family = "Cyclone V";
`endif
reg [7:0] expected [0:262143];
integer written=0, consumed=0, batches=0, granted, i, round, full_bytes;
reg [31:0] expected_words=0;
reg [15:0] expected_digest=0;
reg drain=0;
integer read_budget=-1;

always @(negedge rd_clk) rd_en = drain && !rd_empty && (read_budget != 0);
always @(posedge rd_clk) begin
    if (!reset && rd_en && !rd_empty) begin
        if (consumed >= written || rd_data !== expected[consumed])
            $fatal(1,"byte mismatch at %0d got=%h expected=%h",consumed,rd_data,expected[consumed]);
        consumed = consumed+1;
        if (read_budget > 0) read_budget = read_budget-1;
    end
end
always @(posedge wr_clk) begin
    if (!reset && wr_en) begin
        if (wr_full) $fatal(1,"credit allowed write to full FIFO");
        expected[written]=wr_data[7:0]; expected[written+1]=wr_data[15:8];
        written=written+2;
        if (written-consumed > 32768) $fatal(1,"physical capacity exceeded");
        expected_words=expected_words+1;
        expected_digest={expected_digest[14:0],expected_digest[15]} ^ wr_data;
    end
    #1;
    if (!reset) begin
        if (burst_words !== expected_words || burst_digest !== expected_digest)
            $fatal(1,"acceptance count/digest mismatch");
        if (burst_credit > 4096) $fatal(1,"batch cap exceeded");
        // Current credit must fit physical remaining space despite stale usedw.
        // This checks every write clock, including continuous writes/partial reads.
        if (burst_ready && burst_credit*2 > 32766-(written-consumed))
            $fatal(1,"optimistic credit=%0d usedbytes=%0d",burst_credit,written-consumed);
    end
end

task send_word;
    input [15:0] value;
    begin
        @(negedge wr_clk); wr_data=value; wr_en=1; wr_attempt=1;
        @(negedge wr_clk); wr_en=0; wr_attempt=0;
    end
endtask

task reset_fifo;
    begin
        @(negedge wr_clk); reset=1; wr_en=0; wr_attempt=0; drain=0;
        repeat(12) @(negedge wr_clk);
        written=0; consumed=0; expected_words=0; expected_digest=0; read_budget=-1;
        if (burst_credit !== 0 || burst_ready !== 0 || burst_fault !== 0)
            $fatal(1,"reset does not suppress credit/ready/fault");
        reset=0;
        repeat(31) begin
            @(negedge wr_clk);
            if (burst_ready || burst_credit) $fatal(1,"ready before settle window");
        end
        repeat(5) @(negedge wr_clk);
        if (!burst_ready || burst_credit != 4096) $fatal(1,"reset readiness failed");
    end
endtask

initial begin
    #20000000; $fatal(1,"timeout");
end
initial begin
    reset_fifo();
    // No consumer: repeated full credit grants approach the 32-word reserve.
    while (burst_credit) begin
        granted=burst_credit; batches=batches+1;
        for(i=0;i<granted;i=i+1) send_word((written/2)*37+19);
        repeat(10) @(negedge wr_clk);
    end
    if (written != 2*(16384-32)) $fatal(1,"unexpected reserved capacity %0d",written);
    // Ordinary ACK path can use the reserve, but never while full.
    while (!wr_full) send_word((written/2)*37+19);
    repeat(12) @(negedge wr_clk);
    full_bytes=written;
    if ((written != 32766 && written != 32768) || burst_credit != 0) $fatal(1,"full flag/count wrap failed written=%0d credit=%0d wrused=%0d",written,burst_credit,dut.wr_used);
    // Top gates wr_en, but wr_attempt must still report rejected input.
    @(negedge wr_clk); wr_attempt=1;
    @(negedge wr_clk); wr_attempt=0;
    if (!burst_fault) $fatal(1,"overflow attempt not sticky");
    // A single byte does not free a whole word; drain another odd-sized amount.
    read_budget=1; drain=1;
    wait(read_budget==0); repeat(20) @(negedge wr_clk);
    if (burst_credit != 0) $fatal(1,"partial byte freed advertised credit");
    read_budget=65;
    wait(read_budget==0); repeat(20) @(negedge wr_clk);
    if (burst_credit > 2) $fatal(1,"partial-word read over-credited");
    read_budget=-1;
    wait(consumed==written); drain=0;
    repeat(25) @(negedge wr_clk);
    if (burst_credit != 4096 || !burst_fault) $fatal(1,"empty credit/sticky fault failed");

    // Warm reset and asynchronous fast/slow readers. Includes pointer wrap.
    for(round=0;round<3;round=round+1) begin
        rd_half=(round==0 ? 3 : round==1 ? 7 : 17);
        reset_fifo(); drain=1;
        while (written < 100000) begin
            @(negedge wr_clk); granted=burst_credit;
            if (granted) begin
                batches=batches+1;
                for(i=0;i<granted;i=i+1) send_word((written/2)*53+round);
            end
        end
        wait(consumed==written); drain=0;
        repeat(25) @(negedge wr_clk);
        if (burst_fault || !rd_empty || burst_credit != 4096) $fatal(1,"drain completion failed");
    end
    $display("PASS vendor mixed-width FIFO: full_bytes=%0d, %0d credit batches, full/partial-byte counts, 32-word reserve, asynchronous clocks, pointer wrap, reset, overflow and exact data/digest",full_bytes,batches);
    $finish;
end
endmodule
