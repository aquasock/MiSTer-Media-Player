`timescale 1ns/1ps

module tb_h262_prediction_word_cache;
    reg clk=0,reset=1,active=0;
    reg [7:0] request_burstcnt=0;
    reg [28:0] request_addr=0;
    reg request_read=0,request_cacheable=0;
    wire request_busy;
    wire [63:0] request_dout;
    wire request_dout_ready;

    reg downstream_busy=0;
    reg [63:0] downstream_dout=0;
    reg downstream_dout_ready=0;
    wire [7:0] downstream_burstcnt;
    wire [28:0] downstream_addr;
    wire downstream_read;
    wire [31:0] cache_hits,cache_misses,uncached_reads;

    integer downstream_reads=0;
    integer response_delay_config=1;
    integer response_delay=0;
    reg response_pending=0;
    reg [28:0] response_addr=0;

    always #5 clk=~clk;

    function automatic [63:0] word_for;
        input [28:0] addr;
        begin
            word_for={6'd0,addr,addr};
        end
    endfunction

    mpeg2_h262_reference_word_cache dut(
        .clk(clk),.reset(reset),.active(active),
        .request_burstcnt(request_burstcnt),.request_addr(request_addr),
        .request_read(request_read),.request_cacheable(request_cacheable),
        .request_busy(request_busy),.request_dout(request_dout),
        .request_dout_ready(request_dout_ready),
        .downstream_busy(downstream_busy),.downstream_dout(downstream_dout),
        .downstream_dout_ready(downstream_dout_ready),
        .downstream_burstcnt(downstream_burstcnt),
        .downstream_addr(downstream_addr),.downstream_read(downstream_read),
        .cache_hit_count(cache_hits),.cache_miss_count(cache_misses),
        .uncached_count(uncached_reads));

    always @(posedge clk) begin
        downstream_dout_ready<=0;
        if(response_pending) begin
            if(response_delay==0) begin
                downstream_dout<=word_for(response_addr);
                downstream_dout_ready<=1;
                response_pending<=0;
            end else response_delay<=response_delay-1;
        end
        if(downstream_read&&!downstream_busy) begin
            if(response_pending)
                $fatal(1,"cache issued more than one downstream request");
            if(downstream_burstcnt!=8'd1)
                $fatal(1,"wrong downstream burst count %0d",downstream_burstcnt);
            downstream_reads<=downstream_reads+1;
            response_addr<=downstream_addr;
            response_delay<=response_delay_config;
            response_pending<=1;
        end
    end

    task automatic request_word;
        input [28:0] addr;
        input cacheable;
        integer guard;
        begin
            @(negedge clk);
            request_addr=addr;
            request_burstcnt=8'd1;
            request_cacheable=cacheable;
            request_read=1;
            guard=0;
            while(request_busy) begin
                @(negedge clk);
                guard=guard+1;
                if(guard>100)$fatal(1,"request acceptance timeout addr=%h",addr);
            end
            request_read=0;
            guard=0;
            while(!request_dout_ready) begin
                @(negedge clk);
                guard=guard+1;
                if(guard>100)$fatal(1,"request response timeout addr=%h",addr);
            end
            if(request_dout!==word_for(addr))
                $fatal(1,"wrong response addr=%h got=%h expected=%h",
                       addr,request_dout,word_for(addr));
            @(negedge clk);
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);
        reset=0;
        active=1;

        // First access misses; an immediate repeat must hit.
        request_word(29'h00100,1'b1);
        request_word(29'h00100,1'b1);
        if((downstream_reads!=1)||(cache_hits!=1)||(cache_misses!=1))
            $fatal(1,"basic hit/miss accounting failed");

        // Four interleaved reference words fit simultaneously.
        request_word(29'h00101,1'b1);
        request_word(29'h00102,1'b1);
        request_word(29'h00103,1'b1);
        request_word(29'h00100,1'b1);
        if((downstream_reads!=4)||(cache_hits!=2)||(cache_misses!=4))
            $fatal(1,"four-entry interleave failed");

        // Round-robin replacement evicts the oldest entry.
        request_word(29'h00104,1'b1);
        request_word(29'h00100,1'b1);
        if((downstream_reads!=6)||(cache_misses!=6))
            $fatal(1,"replacement did not miss as expected");

        // Verification traffic always bypasses and never fills.
        request_word(29'h00200,1'b0);
        request_word(29'h00200,1'b0);
        request_word(29'h00200,1'b1);
        if((downstream_reads!=9)||(uncached_reads!=2)||
           (cache_misses!=7))
            $fatal(1,"uncached bypass/fill separation failed");

        // Invalidation prevents stale reference-bank reuse.
        active=0;
        repeat(2)@(posedge clk);
        active=1;
        request_word(29'h00100,1'b1);
        if((downstream_reads!=10)||(cache_misses!=8))
            $fatal(1,"transaction invalidation failed");

        // A held downstream busy and a delayed response preserve the request.
        downstream_busy=1;
        response_delay_config=3;
        fork
            begin
                request_word(29'h00300,1'b1);
            end
            begin
                repeat(5)@(posedge clk);
                if(!request_busy)
                    $fatal(1,"request accepted while downstream busy");
                downstream_busy=0;
            end
        join
        if((downstream_reads!=11)||(cache_misses!=9))
            $fatal(1,"backpressure/delayed response failed");

        $display("PREDICTION_WORD_CACHE_RESULT hits=%0d misses=%0d uncached=%0d downstream=%0d",
                 cache_hits,cache_misses,uncached_reads,downstream_reads);
        $finish;
    end

    initial begin
        repeat(3000)@(posedge clk);
        $fatal(1,"prediction word cache timed out");
    end
endmodule
