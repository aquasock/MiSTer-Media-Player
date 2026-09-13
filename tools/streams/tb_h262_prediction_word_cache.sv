`timescale 1ns/1ps

`ifndef H262_PREDICTION_DESCRIPTOR_DEPTH
`define H262_PREDICTION_DESCRIPTOR_DEPTH 4
`endif

module tb_h262_prediction_word_cache;
    localparam integer EXPECTED_DEPTH=`H262_PREDICTION_DESCRIPTOR_DEPTH;
    reg clk=0,reset=1,active=0;
    reg [7:0] request_burstcnt=0;
    reg [28:0] request_addr=0;
    reg request_read=0,request_cacheable=0;
    reg lookup_request=0,lookup_consume=0;
    wire lookup_ready,lookup_hit;
    wire [63:0] lookup_data;
    wire request_busy;
    wire [63:0] request_dout;
    wire request_dout_ready;

    reg downstream_busy_override=0;
    reg [63:0] downstream_dout=0;
    reg downstream_dout_ready=0;
    wire [7:0] downstream_burstcnt;
    wire [28:0] downstream_addr;
    wire downstream_read;
    wire [31:0] cache_hits,cache_misses,uncached_reads;

    integer downstream_reads=0;
    integer response_delay_config=1;
    integer memory_cycle=0;
    integer response_head=0,response_tail=0,response_count=0;
    integer response_due[0:7];
    reg [28:0] response_addr[0:7];
    reg memory_model_enabled=1;
    integer max_response_descriptors=0;
    wire downstream_busy=downstream_busy_override||
        (memory_model_enabled&&(response_count>=EXPECTED_DEPTH)&&
         !downstream_dout_ready);

    integer ordered_baseline_cycles=0;
    integer ordered_depth2_cycles=0;
    integer ordered_depth2_stalled_cycles=0;
    integer ordered_zero_latency_cycles=0;
    integer ordered_accepts=0;
    integer ordered_returns=0;
    integer test_index;

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
        .lookup_request(lookup_request),.lookup_consume(lookup_consume),
        .lookup_ready(lookup_ready),.lookup_hit(lookup_hit),
        .lookup_data(lookup_data),
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
        memory_cycle<=memory_cycle+1;
        if(dut.response_descriptor_count>max_response_descriptors)
            max_response_descriptors<=dut.response_descriptor_count;
        if(memory_model_enabled) begin
            if((response_count!=0)&&
               (response_due[response_head]<=memory_cycle)) begin
                downstream_dout<=word_for(response_addr[response_head]);
                downstream_dout_ready<=1;
                response_head<=(response_head+1)&7;
            end
            if(downstream_read&&!downstream_busy) begin
                if(response_count>=8)
                    $fatal(1,"downstream response queue overflow");
                if(downstream_burstcnt!=8'd1)
                    $fatal(1,"wrong downstream burst count %0d",downstream_burstcnt);
                downstream_reads<=downstream_reads+1;
                response_addr[response_tail]<=downstream_addr;
                response_due[response_tail]<=memory_cycle+
                    response_delay_config;
                response_tail<=(response_tail+1)&7;
            end
            case({downstream_read&&!downstream_busy,
                  (response_count!=0)&&
                  (response_due[response_head]<=memory_cycle)})
                2'b10:response_count<=response_count+1;
                2'b01:response_count<=response_count-1;
                default:response_count<=response_count;
            endcase
        end
    end

    task automatic issue_word;
        input [28:0] addr;
        input cacheable;
        integer guard;
        begin
            @(negedge clk);
            request_addr=addr;
            request_burstcnt=8'd1;
            request_cacheable=cacheable;
            request_read=1;
            #1;
            guard=0;
            while(request_busy) begin
                @(negedge clk); #1;
                guard=guard+1;
                if(guard>100)$fatal(1,"request acceptance timeout addr=%h",addr);
            end
            @(posedge clk);
            @(negedge clk);
            request_read=0;
        end
    endtask

    task automatic expect_word;
        input [28:0] addr;
        integer guard;
        begin
            guard=0;
            while(!request_dout_ready) begin
                @(negedge clk);
                guard=guard+1;
                if(guard>100)$fatal(1,"request response timeout addr=%h",addr);
            end
            if(request_dout!==word_for(addr))
                $fatal(1,"wrong ordered response addr=%h got=%h expected=%h",
                       addr,request_dout,word_for(addr));
            @(negedge clk);
        end
    endtask

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
            #1;
            guard=0;
            while(request_busy) begin
                @(negedge clk); #1;
                guard=guard+1;
                if(guard>100)$fatal(1,"request acceptance timeout addr=%h",addr);
            end
            @(posedge clk);
            @(negedge clk);
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

    task automatic consume_lookup;
        input [28:0] addr;
        begin
            @(negedge clk);
            request_addr=addr;
            request_cacheable=1;
            request_read=0;
            lookup_request=1;
            @(negedge clk);
            lookup_request=0;
            if(!lookup_ready||!lookup_hit)
                $fatal(1,"direct lookup missed addr=%h",addr);
            if(lookup_data!==word_for(addr))
                $fatal(1,"wrong direct lookup data addr=%h",addr);
            lookup_consume=1;
            @(negedge clk);
            lookup_consume=0;
        end
    endtask

    // Entry 250 proposal model.  The MiSTer bridge accepts a later read while
    // an earlier response is outstanding and returns responses in command
    // order.  Model the deliberately bounded decoder contract: only the
    // current demand and its one exact registered successor may be in flight.
    // A response frees its descriptor before command arbitration, exercising
    // the legal same-cycle return/next-accept boundary.
    task automatic run_ordered_model;
        input integer depth;
        input integer service_latency;
        input integer request_count;
        input integer inject_backpressure;
        output integer elapsed_cycles;
        output integer accepted_count;
        output integer returned_count;
        integer due_cycle[0:127];
        integer request_id[0:127];
        integer head,tail,count,cycle,next_id,next_return;
        integer command_busy;
        begin
            head=0;
            tail=0;
            count=0;
            cycle=0;
            next_id=0;
            next_return=0;
            accepted_count=0;
            returned_count=0;
            while(returned_count<request_count) begin
                if((count!=0)&&(due_cycle[head]<=cycle)) begin
                    if(request_id[head]!=next_return)
                        $fatal(1,"ordered model response association failed got=%0d expected=%0d",
                               request_id[head],next_return);
                    head=(head+1)&127;
                    count=count-1;
                    next_return=next_return+1;
                    returned_count=returned_count+1;
                end

                // Deterministic command backpressure covers a held exact
                // successor without affecting response retirement.
                command_busy=inject_backpressure&&
                    (((cycle%11)==2)||((cycle%11)==3));
                if((next_id<request_count)&&(count<depth)&&!command_busy) begin
                    due_cycle[tail]=cycle+service_latency;
                    request_id[tail]=next_id;
                    tail=(tail+1)&127;
                    count=count+1;
                    next_id=next_id+1;
                    accepted_count=accepted_count+1;

                    // A zero-latency service may legally accept and return on
                    // the same edge.  Keep the descriptor ordering check live.
                    if((service_latency==0)&&(count!=0)&&
                       (due_cycle[head]<=cycle)) begin
                        if(request_id[head]!=next_return)
                            $fatal(1,"zero-latency response association failed");
                        head=(head+1)&127;
                        count=count-1;
                        next_return=next_return+1;
                        returned_count=returned_count+1;
                    end
                end
                cycle=cycle+1;
                if(cycle>100000)
                    $fatal(1,"ordered model timed out depth=%0d",depth);
            end
            elapsed_cycles=cycle;
        end
    endtask

    task automatic check_owner_order;
        integer owner_queue[0:2];
        integer owner_head,owner_tail,owner_count;
        integer response0,response1,response2;
        begin
            owner_head=0;
            owner_tail=0;
            owner_count=0;

            // Prediction demand is accepted first.  A display request arrives
            // before the prediction successor and wins the next command slot.
            owner_queue[owner_tail]=1; // prediction
            owner_tail=owner_tail+1;
            owner_count=owner_count+1;
            owner_queue[owner_tail]=0; // display
            owner_tail=owner_tail+1;
            owner_count=owner_count+1;

            response0=owner_queue[owner_head];
            owner_head=owner_head+1;
            owner_count=owner_count-1;

            // The first response frees one descriptor, so the held exact
            // successor can now be accepted without overtaking display.
            owner_queue[owner_tail]=1;
            owner_tail=owner_tail+1;
            owner_count=owner_count+1;
            response1=owner_queue[owner_head];
            owner_head=owner_head+1;
            owner_count=owner_count-1;
            response2=owner_queue[owner_head];
            owner_head=owner_head+1;
            owner_count=owner_count-1;
            if((response0!=1)||(response1!=0)||(response2!=1)||
               (owner_count!=0))
                $fatal(1,"display/prediction owner order failed %0d/%0d/%0d",
                       response0,response1,response2);
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);
        reset=0;
        active=1;
        #1;
        if(request_busy)
            $fatal(1,"cache did not advertise idle request readiness");

        // First access misses; an immediate direct lookup must hit without a
        // registered request or downstream transaction.
        request_word(29'h00100,1'b1);
        consume_lookup(29'h00100);
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
        downstream_busy_override=1;
        response_delay_config=3;
        fork
            begin
                request_word(29'h00300,1'b1);
            end
            begin
                repeat(5)@(posedge clk);
                if(!request_busy)
                    $fatal(1,"request accepted while downstream busy");
                @(negedge clk);
                downstream_busy_override=0;
            end
        join
        if((downstream_reads!=11)||(cache_misses!=9))
            $fatal(1,"backpressure/delayed response failed");

        // Exercise the live RTL contract rather than only the abstract model:
        // The configured number of misses may be accepted before any response
        // returns, and every response must retain request order.
        response_delay_config=EXPECTED_DEPTH*4+4;
        for(test_index=0;test_index<EXPECTED_DEPTH;
            test_index=test_index+1)
            issue_word(29'h00400+test_index,1'b1);
        if(dut.response_descriptor_count!=EXPECTED_DEPTH)
            $fatal(1,"cache did not retain configured descriptors count=%0d",
                   dut.response_descriptor_count);
        for(test_index=0;test_index<EXPECTED_DEPTH;
            test_index=test_index+1)
            expect_word(29'h00400+test_index);

        // A resident word behind an older miss may not respond early.  It is
        // deliberately reissued downstream and returns after the older miss.
        response_delay_config=6;
        issue_word(29'h00405,1'b1);
        issue_word(29'h00401,1'b1);
        expect_word(29'h00405);
        expect_word(29'h00401);

        // A response may retire the head descriptor on the same edge that a
        // held successor is accepted into the newly freed tail slot.
        response_delay_config=EXPECTED_DEPTH*2+2;
        for(test_index=0;test_index<EXPECTED_DEPTH;
            test_index=test_index+1)
            issue_word(29'h00410+test_index,1'b1);
        fork
            issue_word(29'h00410+EXPECTED_DEPTH,1'b1);
            expect_word(29'h00410);
        join
        for(test_index=1;test_index<=EXPECTED_DEPTH;
            test_index=test_index+1)
            expect_word(29'h00410+test_index);

        if(max_response_descriptors!=EXPECTED_DEPTH)
            $fatal(1,"cache descriptor depth coverage failed max=%0d",
                   max_response_descriptors);

        // Preserve the bridge's legal zero-latency boundary: an accepted miss
        // and its response may share one edge without allocating a descriptor.
        if(response_count!=0||dut.response_descriptor_count!=0)
            $fatal(1,"cache not empty before direct-response test");
        memory_model_enabled=0;
        @(negedge clk);
        request_addr=29'h00420;
        request_burstcnt=8'd1;
        request_cacheable=1;
        request_read=1;
        downstream_dout=word_for(29'h00420);
        downstream_dout_ready=1;
        #1;
        if(request_busy||!downstream_read)
            $fatal(1,"direct-response request was not accepted");
        @(posedge clk);
        @(negedge clk);
        request_read=0;
        downstream_dout_ready=0;
        if(!request_dout_ready||(request_dout!==word_for(29'h00420))||
           (dut.response_descriptor_count!=0))
            $fatal(1,"direct-response association failed");
        memory_model_enabled=1;
        @(negedge clk);

        run_ordered_model(1,10,64,0,ordered_baseline_cycles,
                          ordered_accepts,ordered_returns);
        if((ordered_accepts!=64)||(ordered_returns!=64))
            $fatal(1,"one-outstanding ordered model lost requests");
        run_ordered_model(2,10,64,0,ordered_depth2_cycles,
                          ordered_accepts,ordered_returns);
        if((ordered_accepts!=64)||(ordered_returns!=64)||
           (ordered_depth2_cycles*100>ordered_baseline_cycles*55))
            $fatal(1,"depth-two model did not hide substantial occupancy baseline=%0d depth2=%0d",
                   ordered_baseline_cycles,ordered_depth2_cycles);
        run_ordered_model(2,10,64,1,ordered_depth2_stalled_cycles,
                          ordered_accepts,ordered_returns);
        if((ordered_accepts!=64)||(ordered_returns!=64)||
           (ordered_depth2_stalled_cycles>=ordered_baseline_cycles))
            $fatal(1,"backpressured depth-two model lost its advantage");
        run_ordered_model(2,0,64,0,ordered_zero_latency_cycles,
                          ordered_accepts,ordered_returns);
        if((ordered_accepts!=64)||(ordered_returns!=64)||
           (ordered_zero_latency_cycles!=64))
            $fatal(1,"same-cycle acceptance/return model failed cycles=%0d",
                   ordered_zero_latency_cycles);
        check_owner_order();

        $display("PREDICTION_WORD_CACHE_RESULT hits=%0d misses=%0d uncached=%0d downstream=%0d depth=%0d ordered=1 same_cycle_reuse=1 direct_response=1",
                 cache_hits,cache_misses,uncached_reads,downstream_reads,
                 max_response_descriptors);
        $display("ORDERED_READ_MODEL_RESULT baseline=%0d depth2=%0d depth2_backpressure=%0d zero_latency=%0d requests=64 owner_order=P/D/P",
                 ordered_baseline_cycles,ordered_depth2_cycles,
                 ordered_depth2_stalled_cycles,ordered_zero_latency_cycles);
        $finish;
    end

    initial begin
        repeat(3000)@(posedge clk);
        $fatal(1,"prediction word cache timed out");
    end
endmodule
