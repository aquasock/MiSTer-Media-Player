`timescale 1ns/1ps

module tb_h262_download_rearm;
    reg clk=0;
    reg reset=1;
    reg download_async=0;
    reg fifo_not_empty=0;
    reg decoder_ready=1;
    integer pulse_count=0;
    integer pulse_cycles=0;
    integer blocked_read_cycles=0;

    wire rearm_reset;
    wire fifo_read=fifo_not_empty&&decoder_ready&&!rearm_reset;

    always #9 clk=~clk;

    mpeg2_h262_download_rearm dut(
        .clk(clk),
        .reset(reset),
        .download_async(download_async),
        .rearm_reset(rearm_reset)
    );

    always @(posedge rearm_reset) begin
        pulse_count=pulse_count+1;
        pulse_cycles=0;
    end

    always @(posedge clk) begin
        if(rearm_reset)begin
            pulse_cycles=pulse_cycles+1;
            if(fifo_not_empty&&!fifo_read)
                blocked_read_cycles=blocked_read_cycles+1;
            if(fifo_read)
                $fatal(1,"FIFO read escaped during rearm");
        end
    end

    task wait_for_complete_pulse;
        input integer expected_pulses;
        begin
            wait(pulse_count==expected_pulses);
            @(negedge rearm_reset);
            #1;
            if(pulse_cycles!=8)
                $fatal(1,"pulse %0d lasted %0d cycles, expected 8",
                       expected_pulses,pulse_cycles);
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);
        #2 reset=0;
        repeat(5)@(posedge clk);
        if(rearm_reset||pulse_count!=0)
            $fatal(1,"spurious rearm after system-reset release");

        // Make a byte visible before the synchronized boundary.  Once the
        // boundary arrives, every reset edge must suppress the read request.
        #5 fifo_not_empty=1;
        download_async=1;
        wait_for_complete_pulse(1);
        if(blocked_read_cycles!=8)
            $fatal(1,"first download blocked %0d read cycles, expected 8",
                   blocked_read_cycles);

        // A transfer is a level, not a pulse: remaining high must not retrigger.
        repeat(20)@(posedge clk);
        if(pulse_count!=1||rearm_reset)
            $fatal(1,"download level retriggered rearm");

        // The synchronized low interval arms the next transfer.
        #4 download_async=0;
        repeat(8)@(posedge clk);
        #7 download_async=1;
        wait_for_complete_pulse(2);
        if(blocked_read_cycles!=16)
            $fatal(1,"two downloads blocked %0d read cycles, expected 16",
                   blocked_read_cycles);

        repeat(12)@(posedge clk);
        if(pulse_count!=2||rearm_reset)
            $fatal(1,"second download failed to release cleanly");

        $display("PASS: two downloads, %0d reset cycles, no retrigger, FIFO gated",
                 blocked_read_cycles);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1,"timeout");
    end
endmodule
