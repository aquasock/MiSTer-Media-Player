`timescale 1ns/1ps

module tb_h262_stream_transport_gate;
    reg clk=0;
    reg reset=1;
    reg fifo_empty=1;
    reg decoder_ready=0;
    reg fatal_error=0;
    wire fifo_read,decoder_valid;
    integer fifo_count=0;
    integer drained=0;

    mpeg2_h262_stream_transport_gate dut(
        .clk(clk),.reset(reset),
        .fifo_empty(fifo_empty),.decoder_ready(decoder_ready),
        .fatal_error(fatal_error),.fifo_read(fifo_read),
        .decoder_valid(decoder_valid));

    always #5 clk=~clk;

    task check_gate;
        input expected_read;
        input expected_valid;
        begin
            #1;
            if((fifo_read!==expected_read)||(decoder_valid!==expected_valid))
                $fatal(1,"transport gate mismatch empty=%0d ready=%0d fatal=%0d read=%0d valid=%0d",
                       fifo_empty,decoder_ready,fatal_error,fifo_read,decoder_valid);
        end
    endtask

    initial begin
        repeat(2)@(posedge clk);
        @(negedge clk);reset=0;
        check_gate(0,0);
        fifo_empty=0;
        check_gate(0,0);
        decoder_ready=1;
        check_gate(1,1);

        // The live fault no longer enters the combinational ingress path.
        // It changes transport behavior only after the next decoder clock.
        fatal_error=1;
        check_gate(1,1);
        @(posedge clk);#1;
        check_gate(1,0);
        fatal_error=0;
        decoder_ready=0;
        check_gate(1,0);
        fifo_empty=1;
        check_gate(0,0);

        // Model a blocked decoder with sixteen bytes already resident.  Once
        // the sticky fatal result asserts, every byte must retire and none may
        // be delivered as valid syntax.
        fifo_count=16;
        fifo_empty=0;
        drained=0;
        while(fifo_count!=0)begin
            check_gate(1,0);
            if(fifo_read)begin
                fifo_count=fifo_count-1;
                drained=drained+1;
                if(fifo_count==0)fifo_empty=1;
            end
        end
        check_gate(0,0);
        if(drained!=16)$fatal(1,"expected 16 drained bytes, got %0d",drained);

        // Sticky drain clears only at the session reset boundary.
        reset=1;
        @(posedge clk);#1;
        reset=0;
        fifo_empty=0;
        decoder_ready=1;
        check_gate(1,1);
        $display("H262_STREAM_TRANSPORT_GATE_PASS drained=%0d",drained);
        $finish;
    end
endmodule
